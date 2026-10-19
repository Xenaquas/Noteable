import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/attachment_entity.dart';
import '../../domain/entities/note_entity.dart';
import '../../domain/repositories/note_repository.dart';
import '../../core/services/note_authorization.dart';
import 'di.dart';

enum AttachmentFilter { all, images, pdf, audio, video, other }
enum AttachmentSort { newest, oldest, nameAz, nameZa }

class AttachmentsViewModel extends ChangeNotifier {
  AttachmentsViewModel(this._noteRepo, this._authorization) {
    _changes = _noteRepo.changes.listen((_) => load());
    _authorization.addListener(_privacyChanged);
  }

  final NoteRepository _noteRepo;
  final NoteAuthorization _authorization;
  StreamSubscription<void>? _changes;
  bool _disposed = false;
  int _loadVersion = 0;

  void _privacyChanged() { load(); }
  SharedPreferences? _prefs;
  static const _prefFilterKey = 'attachments_filter';
  static const _prefSortKey = 'attachments_sort';

  bool _loading = false;
  bool get isLoading => _loading;

  AttachmentFilter _filter = AttachmentFilter.all;
  AttachmentFilter get filter => _filter;

  AttachmentSort _sort = AttachmentSort.newest;
  AttachmentSort get sort => _sort;

  List<AttachmentEntity> _all = [];
  List<AttachmentEntity> get items => _applyFilters(_all.where((a) {
    final owner = _notesById[a.noteId];
    return owner != null && (!owner.isLocked ||
        _authorization.allows(a.noteId, NoteOperation.attachment));
  }).toList());

  Map<int, NoteEntity> _notesById = {};
  NoteEntity? noteFor(int id) => _notesById[id];

  Future<void> load() async {
    final version = ++_loadVersion;
    if (_disposed) return;
    _loading = true;
    notifyListeners();
    try {
      await _loadPrefs();
      final attachments = await _noteRepo.listAllAttachments();
      final notes = await _noteRepo.listNotes();
      if (_disposed || version != _loadVersion) return;
      _all = attachments;
      _notesById = {for (final n in notes) n.id!: n};
    } finally {
      _loading = false;
      if (!_disposed && version == _loadVersion) notifyListeners();
    }
  }

  void setFilter(AttachmentFilter filter) async {
    if (_filter == filter) return;
    _filter = filter;
    await _persistPrefs();
    notifyListeners();
  }

  void setSort(AttachmentSort sort) async {
    if (_sort == sort) return;
    _sort = sort;
    await _persistPrefs();
    notifyListeners();
  }

  List<AttachmentEntity> _applyFilters(List<AttachmentEntity> list) {
    Iterable<AttachmentEntity> view = list;
    switch (_filter) {
      case AttachmentFilter.images:
        view = view.where((a) => _isImage(a.extension));
        break;
      case AttachmentFilter.pdf:
        view = view.where((a) => a.extension.toLowerCase() == 'pdf');
        break;
      case AttachmentFilter.audio:
        view = view.where((a) => _isAudio(a.extension));
        break;
      case AttachmentFilter.video:
        view = view.where((a) => _isVideo(a.extension));
        break;
      case AttachmentFilter.other:
        view = view.where((a) =>
            !_isImage(a.extension) &&
            !_isAudio(a.extension) &&
            !_isVideo(a.extension) &&
            a.extension.toLowerCase() != 'pdf');
        break;
      case AttachmentFilter.all:
        break;
    }

    var sorted = view.toList();
    switch (_sort) {
      case AttachmentSort.newest:
        // Already newest-first from the query; keep order.
        break;
      case AttachmentSort.oldest:
        sorted = sorted.reversed.toList();
        break;
      case AttachmentSort.nameAz:
        sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case AttachmentSort.nameZa:
        sorted.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
    }
    return sorted;
  }

  bool _isImage(String ext) =>
      const {'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'}.contains(ext.toLowerCase());
  bool _isAudio(String ext) =>
      const {'mp3', 'wav', 'm4a', 'aac', 'flac'}.contains(ext.toLowerCase());
  bool _isVideo(String ext) =>
      const {'mp4', 'mov', 'avi', 'mkv', 'webm'}.contains(ext.toLowerCase());

  Future<void> _loadPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    final savedFilter = _prefs!.getString(_prefFilterKey);
    final savedSort = _prefs!.getString(_prefSortKey);
    if (savedFilter != null) {
      _filter = AttachmentFilter.values
          .firstWhere((f) => f.name == savedFilter, orElse: () => AttachmentFilter.all);
    }
    if (savedSort != null) {
      _sort = AttachmentSort.values
          .firstWhere((s) => s.name == savedSort, orElse: () => AttachmentSort.newest);
    }
  }

  Future<void> _persistPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_prefFilterKey, _filter.name);
    await _prefs!.setString(_prefSortKey, _sort.name);
  }

  @override
  void dispose() {
    _disposed = true;
    _changes?.cancel();
    _authorization.removeListener(_privacyChanged);
    super.dispose();
  }
}

final attachmentsVmProvider =
    ChangeNotifierProvider<AttachmentsViewModel>((ref) {
  return AttachmentsViewModel(ref.read(noteRepoProvider),
      ref.read(noteAuthorizationProvider))..load();
});
