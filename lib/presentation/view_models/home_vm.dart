import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/attachment_entity.dart';
import '../../domain/entities/note_entity.dart';
import '../../domain/repositories/note_repository.dart';
import '../../core/services/note_authorization.dart';
import 'di.dart';

final homeVmProvider = ChangeNotifierProvider<HomeViewModel>((ref) {
  return HomeViewModel(ref.read(noteRepoProvider), ref.read(noteAuthorizationProvider));
});

enum SortOption { updated, created, title }

enum ViewMode { grid, list }

class HomeViewModel extends ChangeNotifier {
  HomeViewModel(this._repo, this._authorization) {
    _changeSub = _repo.changes.listen((_) => loadNotes());
  }

  final NoteRepository _repo;
  final NoteAuthorization _authorization;
  bool _disposed = false;
  StreamSubscription<void>? _changeSub;
  SharedPreferences? _prefs;

  bool _loading = false;
  bool get isLoading => _loading;

  SortOption _sortOption = SortOption.updated;
  SortOption get sortOption => _sortOption;

  // Default to list view as requested
  ViewMode _viewMode = ViewMode.list;
  ViewMode get viewMode => _viewMode;

  List<NoteEntity> _notes = [];
  List<NoteEntity> get notes => _notes;

  final Map<int, List<AttachmentEntity>> _attachments = {};
  final Set<int> _loadingAttachments = {};

  static const _prefSortKey = 'home_sort';
  static const _prefViewKey = 'home_view_mode';

  Future<void> init() async {
    await _loadPrefs();
    await loadNotes();
  }

  Future<void> _loadPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    
    // Load sort preference
    final sortString = _prefs!.getString(_prefSortKey);
    if (sortString != null) {
      _sortOption = SortOption.values.firstWhere(
        (o) => o.name == sortString,
        orElse: () => SortOption.updated,
      );
    }
    
    // Load view mode preference (defaults to list)
    final viewString = _prefs!.getString(_prefViewKey);
    if (viewString != null) {
      _viewMode = ViewMode.values.firstWhere(
        (v) => v.name == viewString,
        orElse: () => ViewMode.list,
      );
    } else {
      // Set default to list if no preference exists
      _viewMode = ViewMode.list;
      await _prefs!.setString(_prefViewKey, ViewMode.list.name);
    }
  }

  List<AttachmentEntity> attachmentsFor(int? noteId) {
    if (noteId == null) return const [];
    final owners = _notes.where((note) => note.id == noteId);
    if (owners.isEmpty || (owners.first.isLocked &&
        !_authorization.allows(noteId, NoteOperation.attachment))) {
      return const [];
    }
    final cached = _attachments[noteId];
    if (cached != null) return cached;

    if (!_loadingAttachments.contains(noteId)) {
      _loadingAttachments.add(noteId);
      _repo.listAttachments(noteId).then((list) {
        if (_disposed) return;
        _attachments[noteId] = list;
        _loadingAttachments.remove(noteId);
        notifyListeners();
      }).onError<NoteAccessDenied>((_, __) {
        _loadingAttachments.remove(noteId);
      });
    }

    return const [];
  }

  Object? _error;
  Object? get error => _error;

  Future<void> loadNotes() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final fetched = await _repo.listNotes();
      _notes = _applySort(fetched);
      _attachments.clear();
      _loadingAttachments.clear();

      if (_notes.isNotEmpty) {
        final ids = _notes.map((n) => n.id!).toList();
        final attachmentsMap = await _repo.getAttachmentsForNotes(ids);
        for (final id in ids) {
          _attachments[id] = attachmentsMap[id] ?? [];
        }
      }
    } catch (e, st) {
      _error = e;
      debugPrint('Error loading notes: $e\n$st');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setSort(SortOption option, {bool persist = true}) async {
    if (_sortOption == option) return;
    _sortOption = option;
    _notes = _applySort(_notes);
    if (persist) {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_prefSortKey, option.name);
    }
    notifyListeners();
  }

  // Enhanced setViewMode with persistence
  Future<void> setViewMode(ViewMode mode) async {
    if (_viewMode == mode) return;
    _viewMode = mode;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_prefViewKey, mode.name);
    notifyListeners();
  }

  // Toggle view mode helper
  Future<void> toggleViewMode() async {
    final newMode = _viewMode == ViewMode.grid ? ViewMode.list : ViewMode.grid;
    await setViewMode(newMode);
  }

  List<NoteEntity> _applySort(List<NoteEntity> list) {
    final sorted = [...list];
    switch (_sortOption) {
      case SortOption.updated:
        sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case SortOption.created:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.title:
        sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
    }
    return sorted;
  }

  @override
  void dispose() {
    _disposed = true;
    _changeSub?.cancel();
    super.dispose();
  }

  Future<void> deleteNote(int id) async {
    await _repo.deleteNote(id);
    await loadNotes();
  }
}