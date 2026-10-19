class NoteEntity {
  final int? id;
  final String title;
  final String category;
  final String contentJson;
  final String contentPlain;
  final bool isLocked;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NoteEntity({
    required this.id,
    required this.title,
    required this.category,
    required this.contentJson,
    required this.contentPlain,
    required this.isLocked,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
  });

  NoteEntity copyWith({
    int? id,
    String? title,
    String? category,
    String? contentJson,
    String? contentPlain,
    bool? isLocked,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      contentJson: contentJson ?? this.contentJson,
      contentPlain: contentPlain ?? this.contentPlain,
      isLocked: isLocked ?? this.isLocked,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
