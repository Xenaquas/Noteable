import 'dart:async';

import 'package:flutter/foundation.dart';

enum NoteOperation { read, edit, attachment, changeLock, delete, share, export }

class NoteAccessDenied extends StateError {
  NoteAccessDenied() : super('Unlock required');
}

/// In-memory capabilities, scoped to persisted note identity and operation.
/// No caller-supplied "skip authentication" boolean is accepted.
class NoteAuthorization extends ChangeNotifier {
  final Map<int, Set<NoteOperation>> _grants = {};
  final Map<int, Set<NoteOperation>> _suspended = {};
  final Stopwatch _age = Stopwatch();
  Duration _timeout = const Duration(minutes: 5);
  Timer? _timer;
  int _generation = 0;
  int? _activeAttempt;
  int _nextAttempt = 0;
  bool _disposed = false;
  bool _blocked = false;
  bool _backgrounded = false;
  bool _appLockEnabled = false;

  bool get blocked => _blocked;
  bool get backgrounded => _backgrounded;
  int get generation => _generation;
  bool get hasReadAccess =>
      _grants.keys.any((id) => allows(id, NoteOperation.read));

  void configureAppLock(bool enabled) {
    _appLockEnabled = enabled;
    _scheduleExpiry();
  }

  void configureTimeout(Duration timeout) {
    if (timeout.isNegative) throw ArgumentError('Invalid privacy timeout');
    if (_timeout == timeout) return;
    _timeout = timeout;
    _scheduleExpiry();
  }

  bool allows(int noteId, NoteOperation operation) {
    if (_timeout != Duration.zero &&
        _age.isRunning &&
        _age.elapsed >= _timeout) {
      // Timer handles notification; reads deny immediately even between frames.
      return false;
    }
    return !_blocked &&
        !_backgrounded &&
        (_grants[noteId]?.contains(operation) ?? false);
  }

  void require(int noteId, NoteOperation operation) {
    if (!allows(noteId, operation)) throw NoteAccessDenied();
  }

  Set<NoteOperation> _permissions(NoteOperation operation) => {
    operation,
    if (operation != NoteOperation.attachment) NoteOperation.read,
    NoteOperation.attachment,
    if (operation == NoteOperation.changeLock) NoteOperation.edit,
  };

  Future<bool> authorize({
    required Iterable<int> noteIds,
    required NoteOperation operation,
    required Future<bool> Function() authenticate,
  }) async {
    final ids = noteIds.toSet();
    if (ids.isEmpty || ids.any((id) => id <= 0) || _blocked || _backgrounded) {
      return false;
    }
    if (ids.every((id) => allows(id, operation))) return true;
    return _authenticate(authenticate, () {
      for (final id in ids) {
        _grants.putIfAbsent(id, () => {}).addAll(_permissions(operation));
      }
    });
  }

  Future<bool> _authenticate(
    Future<bool> Function() authenticate,
    VoidCallback grant,
  ) async {
    if (_activeAttempt != null || _backgrounded || _disposed) return false;
    final attempt = ++_nextAttempt;
    _activeAttempt = attempt;
    final generation = _generation;
    try {
      if (!await authenticate() ||
          generation != _generation ||
          _backgrounded ||
          _disposed) {
        return false;
      }
      grant();
      _age.reset();
      _age.start();
      _scheduleExpiry();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    } finally {
      if (_activeAttempt == attempt) _activeAttempt = null;
    }
  }

  /// A new authentication is required before cached protected routes reappear.
  Future<bool> resume(Future<bool> Function() authenticate) =>
      _authenticate(authenticate, () {
        _blocked = false;
        for (final entry in _suspended.entries) {
          _grants[entry.key] = {...entry.value};
        }
        _suspended.clear();
      });

  void relock({bool requireAppUnlock = false}) {
    _generation++;
    _activeAttempt = null;
    _timer?.cancel();
    _age.stop();
    for (final entry in _grants.entries) {
      _suspended.putIfAbsent(entry.key, () => {}).addAll(entry.value);
    }
    _blocked =
        _blocked || _grants.isNotEmpty || requireAppUnlock || _appLockEnabled;
    _grants.clear();
    notifyListeners();
  }

  void enterBackground({bool requireAppUnlock = false}) {
    _backgrounded = true;
    relock(requireAppUnlock: requireAppUnlock);
  }

  void enterForeground() {
    _backgrounded = false;
    notifyListeners();
  }

  void _scheduleExpiry() {
    _timer?.cancel();
    if ((_grants.isEmpty && !_appLockEnabled) ||
        !_age.isRunning ||
        _timeout == Duration.zero)
      return;
    final remaining = _timeout - _age.elapsed;
    _timer = Timer(remaining.isNegative ? Duration.zero : remaining, relock);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _activeAttempt = null;
    _timer?.cancel();
    super.dispose();
  }
}
