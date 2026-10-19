class AttachmentEntity {
  final int? id;
  final int noteId;
  final String name;
  final String localPath;
  final String extension;
  final String type;
  final String? mime;
  final int sortIndex;

  const AttachmentEntity({
    required this.id,
    required this.noteId,
    required this.name,
    required this.localPath,
    required this.extension,
    required this.type,
    required this.sortIndex,
    this.mime,
  });

  AttachmentEntity copyWith({
    int? id,
    int? noteId,
    String? name,
    String? localPath,
    String? extension,
    String? type,
    String? mime,
    int? sortIndex,
  }) {
    return AttachmentEntity(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      name: name ?? this.name,
      localPath: localPath ?? this.localPath,
      extension: extension ?? this.extension,
      type: type ?? this.type,
      mime: mime ?? this.mime,
      sortIndex: sortIndex ?? this.sortIndex,
    );
  }
}
