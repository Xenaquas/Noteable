import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/attachment_entity.dart';
import '../../domain/entities/note_entity.dart';
import '../../domain/repositories/note_repository.dart' as domain;
import '../local/databases/app_database.dart';
import '../models/attachment_model.dart';
import '../models/note_model.dart';
import '../../core/services/note_authorization.dart';

class NoteRepository implements domain.NoteRepository {
  final AppDatabase _db;
  NoteRepository(this._db, {NoteAuthorization? authorization})
      : _authorization = authorization ?? NoteAuthorization();
  final NoteAuthorization _authorization;

  @override
  Future<bool> isNoteLocked(int id) async {
    final rows = await (await _db.db).query('notes', columns: ['is_locked'],
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw StateError('Note not found');
    return rows.single['is_locked'] == 1;
  }

  Future<void> _require(int id, NoteOperation operation) async {
    if (await isNoteLocked(id)) _authorization.require(id, operation);
  }

  Future<bool> _authorizeMutation(DatabaseExecutor db, int id,
      NoteOperation operation, {bool? nextLocked}) async {
    final rows = await db.query('notes', columns: ['is_locked'],
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw StateError('Note not found');
    final locked = rows.single['is_locked'] == 1;
    if (locked) _authorization.require(id, operation);
    if (nextLocked != null && nextLocked != locked) {
      _authorization.require(id, NoteOperation.changeLock);
    }
    return locked;
  }

  NoteEntity _summary(NoteEntity note) => !note.isLocked ? note : NoteEntity(
    id: note.id, title: 'Locked note', category: '', contentJson: '[]',
    contentPlain: '', isLocked: true, isPinned: false,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  @override
  Future<NoteEntity?> getNoteSummary(int id) async {
    final rows = await (await _db.db).query('notes', where: 'id = ?',
        whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _summary(_noteFromModel(NoteModel.fromMap(rows.single)));
  }

  final StreamController<void> _changeController = StreamController.broadcast();

  @override
  Stream<void> get changes => _changeController.stream;

  void _emitChange() {
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }

  @override
  Future<int> createEmptyNote({String category = 'Personal'}) async {
    final Database db = await _db.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert('notes', {
      'title': '',
      'category': category,
      'content_json': '[]',
      'content_plain': '',
      'is_locked': 0,
      'is_pinned': 0,
      'created_at': now,
      'updated_at': now,
    });
    _emitChange();
    return id;
  }

  @override
  Future<NoteEntity?> getNote(int id, {NoteOperation operation = NoteOperation.read}) async {
    final Database db = await _db.db;
    final rows = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    if (rows.single['is_locked'] == 1) {
      _authorization.require(id, operation);
      _authorization.require(id, NoteOperation.read);
    }
    return _noteFromModel(NoteModel.fromMap(rows.first));
  }

  @override
  Future<List<NoteEntity>> listNotes() async {
    final Database db = await _db.db;
    final rows = await db.query(
      'notes',
      orderBy: 'is_pinned DESC, updated_at DESC',
    );
    return rows.map(NoteModel.fromMap).map(_noteFromModel).map(_summary).toList();
  }

  @override
  Future<List<NoteEntity>> searchNotes(String q) async {
    final Database db = await _db.db;
    final query = '%$q%';
    final rows = await db.query(
      'notes',
      where: '(title LIKE ? OR content_plain LIKE ?) AND is_locked = 0',
      whereArgs: [query, query],
      orderBy: 'updated_at DESC',
    );
    return rows.map(NoteModel.fromMap).map(_noteFromModel).toList();
  }

  @override
  Future<int> upsert(NoteEntity note) async {
    if (note.id == null && note.isLocked) {
      // New locked notes are created unlocked first, then locked under a
      // capability bound to the database-assigned ID.
      throw NoteAccessDenied();
    }
    final Database db = await _db.db;
    final map = {
      'title': note.title,
      'category': note.category,
      'content_json': note.contentJson,
      'content_plain': note.contentPlain,
      'is_locked': note.isLocked ? 1 : 0,
      'is_pinned': note.isPinned ? 1 : 0,
      'created_at': note.createdAt.millisecondsSinceEpoch,
      'updated_at': note.updatedAt.millisecondsSinceEpoch,
    };

    if (note.id == null) {
      final id = await db.insert('notes', map);
      _emitChange();
      return id;
    } else {
      await db.transaction((txn) async {
        final wasLocked = await _authorizeMutation(txn, note.id!,
            NoteOperation.edit, nextLocked: note.isLocked);
        await txn.update('notes', map, where: 'id = ?', whereArgs: [note.id]);
        if (wasLocked) _authorization.require(note.id!, NoteOperation.edit);
        if (wasLocked != note.isLocked) {
          _authorization.require(note.id!, NoteOperation.changeLock);
        }
      });
      _emitChange();
      return note.id!;
    }
  }

  @override
  Future<void> deleteNote(int id) async {
    await _require(id, NoteOperation.delete);
    final Database db = await _db.db;
    await db.transaction((txn) async {
      final locked = await _authorizeMutation(txn, id, NoteOperation.delete);
      await txn.delete('attachments', where: 'note_id = ?', whereArgs: [id]);
      if (locked) _authorization.require(id, NoteOperation.delete);
      await txn.delete('notes', where: 'id = ?', whereArgs: [id]);
      if (locked) _authorization.require(id, NoteOperation.delete);
    });
    _emitChange();
  }

  // Attachments (Phase 1 reorderable)
  @override
  Future<List<AttachmentEntity>> listAttachments(int noteId) async {
    await _require(noteId, NoteOperation.attachment);
    final Database db = await _db.db;
    final rows = await db.query(
      'attachments',
      where: 'note_id = ?',
      whereArgs: [noteId],
      orderBy: 'sort_index ASC',
    );
    await _require(noteId, NoteOperation.attachment);
    return rows
        .map(AttachmentModel.fromMap)
        .map((m) => _attachmentFromModel(m))
        .toList();
  }

  @override
  Future<Map<int, List<AttachmentEntity>>> getAttachmentsForNotes(
    List<int> noteIds,
  ) async {
    if (noteIds.isEmpty) return {};
    final Database db = await _db.db;
    final Map<int, List<AttachmentEntity>> result = {};
    final protectedIds = <int>{};

    const int chunkSize = 500;
    for (var i = 0; i < noteIds.length; i += chunkSize) {
      final end = (i + chunkSize < noteIds.length)
          ? i + chunkSize
          : noteIds.length;
      final chunk = noteIds.sublist(i, end);

      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await db.rawQuery(
        'SELECT a.*, n.is_locked AS owner_locked FROM attachments a '
        'INNER JOIN notes n ON n.id = a.note_id '
        'WHERE a.note_id IN ($placeholders) ORDER BY a.sort_index ASC', chunk);

      for (final row in rows) {
        final model = AttachmentModel.fromMap(row);
        final entity = _attachmentFromModel(model);
        if (row['owner_locked'] == 1) {
          protectedIds.add(entity.noteId);
          if (!_authorization.allows(entity.noteId, NoteOperation.attachment)) continue;
        }
        if (!result.containsKey(entity.noteId)) {
          result[entity.noteId] = [];
        }
        result[entity.noteId]!.add(entity);
      }
    }
    result.removeWhere((id, _) => protectedIds.contains(id) &&
        !_authorization.allows(id, NoteOperation.attachment));
    return result;
  }

  @override
  Future<void> replaceAttachments({
    required int noteId,
    required List<AttachmentEntity> attachments,
  }) async {
    await _require(noteId, NoteOperation.edit);
    final Database db = await _db.db;
    await db.transaction((txn) async {
      final locked = await _authorizeMutation(txn, noteId, NoteOperation.edit);
      await txn.delete(
        'attachments',
        where: 'note_id = ?',
        whereArgs: [noteId],
      );
      for (var i = 0; i < attachments.length; i++) {
        if (locked) _authorization.require(noteId, NoteOperation.edit);
        final a = attachments[i];
        await txn.insert('attachments', {
          'note_id': noteId,
          'type': a.type,
          'path': a.localPath,
          'name': a.name,
          'mime': a.mime,
          'sort_index': i,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
      }
      if (locked) _authorization.require(noteId, NoteOperation.edit);
    });
    _emitChange();
  }

  AttachmentEntity _attachmentFromModel(AttachmentModel m) {
    final ext = p.extension(m.path).replaceFirst('.', '').toLowerCase();
    return AttachmentEntity(
      id: m.id,
      noteId: m.noteId,
      name: m.name ?? p.basename(m.path),
      localPath: m.path,
      extension: ext,
      type: m.type,
      mime: m.mime,
      sortIndex: m.sortIndex,
    );
  }

  @override
  Future<List<AttachmentEntity>> listAllAttachments() async {
    final db = await _db.db;
    final rows = await db.rawQuery(
      'SELECT a.*, n.is_locked AS owner_locked FROM attachments a '
      'INNER JOIN notes n ON n.id = a.note_id ORDER BY a.created_at DESC');
    return rows.where((row) => row['owner_locked'] != 1 ||
        _authorization.allows(row['note_id'] as int, NoteOperation.attachment))
        .map(AttachmentModel.fromMap)
        .map((m) => _attachmentFromModel(m))
        .toList();
  }

  NoteEntity _noteFromModel(NoteModel m) {
    return NoteEntity(
      id: m.id,
      title: m.title,
      category: m.category,
      contentJson: m.contentJson,
      contentPlain: m.contentPlain,
      isLocked: m.isLocked,
      isPinned: m.isPinned,
      createdAt: DateTime.fromMillisecondsSinceEpoch(m.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(m.updatedAt),
    );
  }
}
