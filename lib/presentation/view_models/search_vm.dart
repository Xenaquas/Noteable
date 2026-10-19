import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../data/local/databases/app_drift_database.dart';
import '../../domain/entities/note_entity.dart';
import '../../domain/repositories/note_repository.dart';
import '../../data/repositories/task_repository.dart';

enum SearchFilter { all, notes, tasks }
enum SearchResultType { note, task }

class SearchResultItem {
  SearchResultItem.note(this.note)
      : type = SearchResultType.note,
        task = null;
  SearchResultItem.task(this.task)
      : type = SearchResultType.task,
        note = null;

  final SearchResultType type;
  final NoteEntity? note;
  final Task? task;

  DateTime? get updatedAt => switch (type) {
        SearchResultType.note => note?.updatedAt,
        SearchResultType.task => task?.updatedAt,
      };
}

class SearchViewModel extends ChangeNotifier {
  SearchViewModel(this._noteRepo, this._taskRepo);

  final NoteRepository _noteRepo;
  final TaskRepository _taskRepo;

  bool loading = false;
  String query = '';
  List<SearchResultItem> results = [];
  SearchFilter filter = SearchFilter.all;

  Timer? _debounce;

  void setFilter(SearchFilter f) {
    if (filter == f) return;
    filter = f;
    notifyListeners();
  }

  void onQueryChanged(String v) {
    query = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () async {
      await searchNow();
    });
  }

  List<SearchResultItem> get filtered {
    switch (filter) {
      case SearchFilter.notes:
        return results.where((r) => r.type == SearchResultType.note).toList();
      case SearchFilter.tasks:
        return results.where((r) => r.type == SearchResultType.task).toList();
      case SearchFilter.all:
        return results;
    }
  }

  Future<void> searchNow() async {
    loading = true;
    notifyListeners();

    final q = query.trim();
    if (q.isEmpty) {
      results = [];
      loading = false;
      notifyListeners();
      return;
    }

    final notesFuture = _noteRepo.searchNotes(q);
    final tasksFuture = _taskRepo.allTasks();

    final notes = (await notesFuture).where((n) => !n.isLocked).toList();
    final tasks = (await tasksFuture)
        .where((t) =>
            t.title.toLowerCase().contains(q.toLowerCase()) ||
            (t.description ?? '').toLowerCase().contains(q.toLowerCase()))
        .toList();

    final combined = <SearchResultItem>[
      ...notes.map(SearchResultItem.note),
      ...tasks.map(SearchResultItem.task),
    ];

    combined.sort((a, b) {
      final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    results = combined;
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
