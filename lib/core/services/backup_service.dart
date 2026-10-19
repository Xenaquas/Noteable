import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/note_entity.dart';
import '../../domain/repositories/note_repository.dart';
import '../../presentation/view_models/di.dart';

class BackupService {
  final NoteRepository _noteRepo;

  BackupService(this._noteRepo);

  Future<void> exportAllNotes() async {
    final notes = await _noteRepo.listNotes();

    final jsonString = jsonEncode(notes.map(_encodeNote).toList());
    await _zipAndShare(
      baseName: 'backup_${_timestamp()}',
      jsonString: jsonString,
      shareLabel: 'Digital Memory Backup',
    );
  }

  Future<void> restoreFromBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        if (file.name.endsWith('.json')) {
          final content = utf8.decode(file.content);
          final List<dynamic> jsonList = jsonDecode(content);

          for (final item in jsonList) {
            final note = NoteEntity(
              id: item['id'],
              title: item['title'] ?? '',
              category: item['category'] ?? 'Personal',
              contentJson: item['contentJson'] ?? '',
              contentPlain: item['contentPlain'] ?? '',
              isLocked: item['isLocked'] ?? false,
              isPinned: item['isPinned'] ?? false,
              createdAt:
                  DateTime.tryParse(item['createdAt'] ?? '') ?? DateTime.now(),
              updatedAt:
                  DateTime.tryParse(item['updatedAt'] ?? '') ?? DateTime.now(),
            );
            await _noteRepo.upsert(note);
          }
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> exportNote(NoteEntity note) async {
    final safeTitle = (note.title.isEmpty ? 'note' : note.title)
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .toLowerCase();
    final jsonString = jsonEncode(_encodeNote(note));
    await _zipAndShare(
      baseName: '${safeTitle}_${_timestamp()}',
      jsonString: jsonString,
      shareLabel: 'Digital Memory Note Backup',
    );
  }

  Future<List<NoteEntity>> listNotes() => _noteRepo.listNotes();

  Map<String, dynamic> _encodeNote(NoteEntity n) {
    return {
      'id': n.id,
      'title': n.title,
      'category': n.category,
      'contentJson': n.contentJson,
      'contentPlain': n.contentPlain,
      'isLocked': n.isLocked,
      'isPinned': n.isPinned,
      'createdAt': n.createdAt.toIso8601String(),
      'updatedAt': n.updatedAt.toIso8601String(),
    };
  }

  Future<void> _zipAndShare({
    required String baseName,
    required String jsonString,
    required String shareLabel,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = '$baseName.json';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(jsonString);

    final zipFile = File('${tempDir.path}/$baseName.zip');
    final archive = Archive();
    archive.addFile(
      ArchiveFile(fileName, await file.length(), await file.readAsBytes()),
    );
    final encoder = ZipEncoder();
    await zipFile.writeAsBytes(encoder.encode(archive));

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(zipFile.path)],
        text: shareLabel,
      ),
    );
  }

  String _timestamp() => DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.read(noteRepoProvider));
});
