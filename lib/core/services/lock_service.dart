import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'note_authorization.dart';
import 'pin_store.dart';

class LockService {
  LockService(SharedPreferences prefs, {
    NoteAuthorization? authorization,
    AuthService? auth,
    Future<bool> Function(int)? isNoteLocked,
    Future<List<int>> Function()? lockedNoteIds,
  }) : authorization = authorization ?? NoteAuthorization(),
       _auth = auth ?? AuthService(), _pins = PinStore(prefs),
       _isNoteLocked = isNoteLocked, _lockedNoteIds = lockedNoteIds;

  final PinStore _pins;
  final AuthService _auth;
  final NoteAuthorization authorization;
  final Future<bool> Function(int)? _isNoteLocked;
  final Future<List<int>> Function()? _lockedNoteIds;

  Future<bool> hasPin() => _pins.hasPin();
  Future<void> setPin(String pin) => _pins.setPin(pin);
  Future<bool> verifyPin(String pin) => _pins.verifyPin(pin);

  Future<bool> authorizeNote({required BuildContext context, required int noteId,
    NoteOperation operation = NoteOperation.read,
  }) async {
    try {
      if (_isNoteLocked == null || !context.mounted) return false;
      final locked = await _isNoteLocked(noteId);
      if (!locked && operation != NoteOperation.changeLock) return true;
      return await authorization.authorize(
        noteIds: [noteId], operation: operation,
        authenticate: () => !locked && operation == NoteOperation.changeLock
            ? ensureProtection(context) : authenticate(context: context),
      );
    } catch (_) { return false; }
  }

  Future<bool> authorizeVault(BuildContext context) async {
    try {
      if (_lockedNoteIds == null) return false;
      return await authorization.authorize(
        noteIds: await _lockedNoteIds(), operation: NoteOperation.read,
        authenticate: () => authenticate(context: context, reason: 'Unlock private notes'),
      );
    } catch (_) { return false; }
  }

  /// Existing protected data without a PIN requires device authentication
  /// before enrollment. Setup is never a replacement for an existing PIN.
  Future<bool> ensureProtection(BuildContext context) async {
    final generation = authorization.generation;
    bool active() => context.mounted && generation == authorization.generation;
    try {
      if (!context.mounted || _lockedNoteIds == null) return false;
      if (!context.mounted || generation != authorization.generation) return false;
      if (await hasPin()) {
        if (!context.mounted || generation != authorization.generation) return false;
        return await authenticate(context: context);
      }
      if ((await _lockedNoteIds()).isNotEmpty &&
          !await _auth.authenticate(reason: 'Authenticate to configure a PIN')) {
        return false;
      }
      if (!context.mounted || generation != authorization.generation) return false;
      final pin = await _showPinDialog(context, title: 'Set a PIN',
          subtitle: 'Use six digits. This PIN protects your private notes.');
      if (!context.mounted || generation != authorization.generation || pin == null) return false;
      if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
        _message(context, 'Use a six-digit PIN');
        return false;
      }
      final confirmation = await _showPinDialog(context, title: 'Confirm PIN',
          subtitle: 'Re-enter your six-digit PIN.');
      if (!context.mounted || confirmation == null || generation != authorization.generation) return false;
      if (confirmation != pin) {
        _message(context, 'PINs did not match');
        return false;
      }
      await setPin(pin);
      return active();
    } catch (_) {
      if (context.mounted) _message(context, 'Privacy setup unavailable. Nothing was unlocked.');
      return false;
    }
  }

  Future<bool> authenticate({required BuildContext context,
    String reason = 'Authenticate to access private notes',
  }) async {
    final generation = authorization.generation;
    bool active() => context.mounted && generation == authorization.generation;
    try {
      // Migration must succeed before any credential grants access.
      final pinAvailable = await hasPin();
      if (!context.mounted || generation != authorization.generation) return false;
      if (await _auth.authenticate(reason: reason)) return active();
      if (!context.mounted || generation != authorization.generation) return false;
      if (!pinAvailable) {
        _message(context, 'Device authentication is required. Configure a device screen lock to access existing private notes.');
        return false;
      }
      final pin = await _showPinDialog(context, title: 'Enter PIN', subtitle: reason);
      if (pin == null || !active()) return false;
      final ok = await verifyPin(pin);
      if (!ok && context.mounted) {
        _message(context, 'PIN not accepted. Repeated failures require a waiting period.');
      }
      return ok && active();
    } catch (_) {
      if (context.mounted) _message(context, 'Authentication unavailable. Nothing was unlocked.');
      return false;
    }
  }

  Future<bool> resumeWithPin(String pin) => authorization.resume(() async {
    try { return await verifyPin(pin); } catch (_) { return false; }
  });

  Future<bool> configureAppProtection(BuildContext context) =>
      authorization.resume(() => ensureProtection(context));

  Future<bool> resumeWithDevice() => authorization.resume(() async {
    try {
      await hasPin();
      return await _auth.authenticate(reason: 'Unlock Digital Memory');
    } catch (_) { return false; }
  });

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _showPinDialog(BuildContext context, {
    required String title, required String subtitle,
  }) async {
    final controller = TextEditingController();
    final navigator = Navigator.of(context, rootNavigator: true);
    final generation = authorization.generation;
    final route = DialogRoute<String>(context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(subtitle),
            TextField(controller: controller, autofocus: true, obscureText: true,
              enableSuggestions: false, autocorrect: false,
              keyboardType: TextInputType.number, maxLength: 6,
              decoration: const InputDecoration(hintText: 'PIN'),
              onSubmitted: (value) => Navigator.pop(ctx, value)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, controller.text),
                child: const Text('Confirm')),
          ],
        ));
    void cancelRevokedPrompt() {
      if (generation != authorization.generation && route.isActive) {
        navigator.removeRoute(route);
      }
    }
    authorization.addListener(cancelRevokedPrompt);
    try {
      return await navigator.push(route);
    } finally {
      authorization.removeListener(cancelRevokedPrompt);
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    }
  }
}
