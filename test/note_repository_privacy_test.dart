import 'dart:io';

import 'package:digital_memory/data/local/databases/app_database.dart';
import 'package:digital_memory/data/repositories/note_repository.dart';
import 'package:digital_memory/core/services/note_authorization.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late NoteRepository repo;
  final authorization = NoteAuthorization();
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('noteable-privacy-');
    PathProviderPlatform.instance = _Paths(directory.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    repo = NoteRepository(AppDatabase.instance, authorization: authorization);
    final db = await AppDatabase.instance.db;
    await db.insert('notes', {
      'id': 1,
      'title': 'PUBLIC',
      'content_plain': 'public body',
      'created_at': 1,
      'updated_at': 1,
    });
    await db.insert('notes', {
      'id': 2,
      'title': 'SECRET TITLE',
      'category': 'Secret category',
      'content_plain': 'SECRET BODY',
      'is_locked': 1,
      'created_at': 1234,
      'updated_at': 5678,
    });
    await db.insert('attachments', {
      'note_id': 2,
      'type': 'file',
      'path': '/secret/location.txt',
      'name': 'SECRET FILE',
      'sort_index': 0,
      'created_at': 1,
    });
  });
  tearDownAll(() async {
    authorization.dispose();
    await (await AppDatabase.instance.db).close();
    await directory.delete(recursive: true);
  });

  test('direct reads of locked content fail closed', () async {
    await expectLater(repo.getNote(2), throwsA(isA<StateError>()));
    expect((await repo.getNote(1))!.contentPlain, 'public body');
  });

  test(
    'lists do not expose locked titles, bodies, category or timestamps',
    () async {
      final locked = (await repo.listNotes()).singleWhere((n) => n.id == 2);
      expect(locked.title, 'Locked note');
      expect(locked.contentPlain, isEmpty);
      expect(locked.category, isEmpty);
      expect(locked.updatedAt.millisecondsSinceEpoch, 0);
    },
  );

  test(
    'File Manager and attachment queries hide protected paths and names',
    () async {
      expect(await repo.listAllAttachments(), isEmpty);
      expect(await repo.getAttachmentsForNotes([1, 2]), isEmpty);
      await expectLater(repo.listAttachments(2), throwsA(isA<StateError>()));
    },
  );

  test('search excludes locked content', () async {
    expect(await repo.searchNotes('SECRET'), isEmpty);
    expect((await repo.searchNotes('public')).single.id, 1);
  });

  test(
    'attachment capability cannot be used to request the owner body',
    () async {
      await authorization.authorize(
        noteIds: [2],
        operation: NoteOperation.attachment,
        authenticate: () async => true,
      );
      expect((await repo.listAttachments(2)).single.name, 'SECRET FILE');
      await expectLater(
        repo.getNote(2, operation: NoteOperation.attachment),
        throwsA(isA<StateError>()),
      );
      authorization.relock();
      expect(await repo.listAllAttachments(), isEmpty);
    },
  );

  test(
    'unauthorized writes and deletion preserve the existing private records',
    () async {
      final db = await AppDatabase.instance.db;
      final before = await db.query('notes', where: 'id = ?', whereArgs: [2]);
      await expectLater(repo.deleteNote(2), throwsA(isA<NoteAccessDenied>()));
      await expectLater(
        repo.replaceAttachments(noteId: 2, attachments: []),
        throwsA(isA<NoteAccessDenied>()),
      );
      expect(await db.query('notes', where: 'id = ?', whereArgs: [2]), before);
      expect(
        await db.query('attachments', where: 'note_id = ?', whereArgs: [2]),
        hasLength(1),
      );
    },
  );
}
