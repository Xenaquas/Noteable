import '../entities/attachment_entity.dart';
import '../entities/note_entity.dart';

abstract class NoteRepository {
  Future<int> createEmptyNote({String category = 'Personal'});
  Future<NoteEntity?> getNote(int id);
  Future<List<NoteEntity>> listNotes();
  Future<List<NoteEntity>> searchNotes(String query);
  Future<int> upsert(NoteEntity note);
  Future<void> deleteNote(int id);
  Stream<void> get changes;

  Future<List<AttachmentEntity>> listAttachments(int noteId);
  Future<Map<int, List<AttachmentEntity>>> getAttachmentsForNotes(
    List<int> noteIds,
  );
  Future<void> replaceAttachments({
    required int noteId,
    required List<AttachmentEntity> attachments,
  });

  /// Lists all attachments across notes.
  Future<List<AttachmentEntity>> listAllAttachments();
}
