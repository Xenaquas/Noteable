class NoteModel {
  final int id;
  final String title;
  final String category;
  final String contentJson;
  final String contentPlain;
  final bool isLocked;
  final bool isPinned;
  final int createdAt;
  final int updatedAt;

  const NoteModel({
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

  factory NoteModel.fromMap(Map<String, dynamic> m) => NoteModel(
        id: m['id'] as int,
        title: (m['title'] as String?) ?? '',
        category: (m['category'] as String?) ?? 'Personal',
        contentJson: (m['content_json'] as String?) ?? '[]',
        contentPlain: (m['content_plain'] as String?) ?? '',
        isLocked: (m['is_locked'] as int? ?? 0) == 1,
        isPinned: (m['is_pinned'] as int? ?? 0) == 1,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );
}
