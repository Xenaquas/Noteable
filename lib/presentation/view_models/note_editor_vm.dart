import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../domain/entities/attachment_entity.dart';
import '../../domain/entities/note_entity.dart';
import '../../domain/repositories/note_repository.dart';

class NoteEditorViewModel extends ChangeNotifier {
  final NoteRepository _repo;
  final int noteId;

  NoteEditorViewModel(this._repo, {required this.noteId});

  bool loading = true;
  bool saving = false;

  String category = 'Personal';
  final titleCtrl = TextEditingController();

  late QuillController quillCtrl;
  List<AttachmentEntity> attachments = [];
  NoteEntity? _note;

  Future<void> load() async {
    loading = true;
    notifyListeners();

    final note = await _repo.getNote(noteId);
    final now = DateTime.now();
    final noteSafe = note ??
        NoteEntity(
          id: noteId,
          title: '',
          category: 'Personal',
          contentJson: '[]',
          contentPlain: '',
          isLocked: false,
          isPinned: false,
          createdAt: now,
          updatedAt: now,
        );
    _note = noteSafe;

    category = noteSafe.category;
    titleCtrl.text = noteSafe.title;

    final doc = _docFromJson(noteSafe.contentJson);
    quillCtrl = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );

    attachments = await _repo.listAttachments(noteId);

    loading = false;
    notifyListeners();
  }

  Document _docFromJson(String contentJson) {
    try {
      final decoded = jsonDecode(contentJson);
      if (decoded is List) return Document.fromJson(decoded);
      return Document();
    } catch (_) {
      return Document();
    }
  }

  Future<void> save() async {
    saving = true;
    notifyListeners();

    final title = titleCtrl.text.trim();
    final contentJson = jsonEncode(quillCtrl.document.toDelta().toJson());
    final contentPlain = quillCtrl.document
        .toPlainText()
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final now = DateTime.now();
    final base = _note ??
        NoteEntity(
          id: noteId,
          title: '',
          category: category,
          contentJson: '[]',
          contentPlain: '',
          isLocked: false,
          isPinned: false,
          createdAt: now,
          updatedAt: now,
        );

    _note = base.copyWith(
      title: title,
      category: category,
      contentJson: contentJson,
      contentPlain: contentPlain,
      updatedAt: now,
    );

    await _repo.upsert(_note!);

    saving = false;
    notifyListeners();
  }

  // Phase 1: reorder attachments only
  Future<void> reorderAttachments(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = attachments.removeAt(oldIndex);
    attachments.insert(newIndex, item);
    notifyListeners();
    await _repo.replaceAttachments(noteId: noteId, attachments: attachments);
  }

  Future<void> deleteAttachment(int attachmentId) async {
    attachments = attachments.where((a) => a.id != attachmentId).toList();
    await _repo.replaceAttachments(noteId: noteId, attachments: attachments);
    attachments = await _repo.listAttachments(noteId);
    notifyListeners();
  }

  Future<void> addPickedAttachment({
    required String type,
    required String path,
    String? name,
    String? mime,
  }) async {
    final next = [
      ...attachments,
      AttachmentEntity(
        id: null,
        noteId: noteId,
        name: name ?? path.split('/').last,
        localPath: path,
        extension: path.split('.').last,
        type: type,
        mime: mime,
        sortIndex: attachments.length,
      ),
    ];
    await _repo.replaceAttachments(noteId: noteId, attachments: next);
    attachments = await _repo.listAttachments(noteId);
    notifyListeners();
  }
}
