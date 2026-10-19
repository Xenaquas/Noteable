import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotesFilterState {
  final String category; // personal/work/ideas
  final String query;

  const NotesFilterState({required this.category, required this.query});

  NotesFilterState copyWith({String? category, String? query}) {
    return NotesFilterState(
      category: category ?? this.category,
      query: query ?? this.query,
    );
  }
}

class NotesFilterViewModel extends Notifier<NotesFilterState> {
  @override
  NotesFilterState build() => const NotesFilterState(category: 'personal', query: '');

  void setCategory(String category) => state = state.copyWith(category: category);
  void setQuery(String q) => state = state.copyWith(query: q);
}

final notesFilterViewModelProvider =
    NotifierProvider<NotesFilterViewModel, NotesFilterState>(NotesFilterViewModel.new);
