class AttachmentModel {
  final int id;
  final int noteId;
  final String type; // image/file/audio
  final String path;
  final String? name;
  final String? mime;
  final int sortIndex;

  const AttachmentModel({
    required this.id,
    required this.noteId,
    required this.type,
    required this.path,
    required this.sortIndex,
    this.name,
    this.mime,
  });

  factory AttachmentModel.fromMap(Map<String, dynamic> m) => AttachmentModel(
        id: m['id'] as int,
        noteId: m['note_id'] as int,
        type: m['type'] as String,
        path: m['path'] as String,
        name: m['name'] as String?,
        mime: m['mime'] as String?,
        sortIndex: m['sort_index'] as int,
      );
}
