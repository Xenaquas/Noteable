import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/note_entity.dart';
import 'di.dart';
import 'note_view_model.dart';

final notesFutureProvider = FutureProvider.autoDispose<List<NoteEntity>>((ref) async {
  final repo = ref.watch(noteRepoProvider);
  final filter = ref.watch(notesFilterViewModelProvider);
  final notes = await repo.listNotes();

  return notes.where((n) {
    final categoryOk = filter.category.isEmpty || n.category.toLowerCase() == filter.category.toLowerCase();
    final q = filter.query.trim().toLowerCase();
    final queryOk = q.isEmpty || n.title.toLowerCase().contains(q) || n.contentPlain.toLowerCase().contains(q);
    return categoryOk && queryOk;
  }).toList();
});

final allNotesFutureProvider = FutureProvider.autoDispose<List<NoteEntity>>((ref) async {
  final repo = ref.watch(noteRepoProvider);
  return repo.listNotes();
});
