import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/note_authorization.dart';
import '../view_models/app_settings_vm.dart';
import '../view_models/di.dart';

/// Covers the complete navigator, including pushed editors and media viewers.
class PrivacyHost extends ConsumerStatefulWidget {
  const PrivacyHost({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<PrivacyHost> createState() => _PrivacyHostState();
}

class _PrivacyHostState extends ConsumerState<PrivacyHost>
    with WidgetsBindingObserver {
  late final NoteAuthorization _authorization;
  final _pin = TextEditingController();
  bool _inactive = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _authorization = ref.read(noteAuthorizationProvider);
    final settings = ref.read(appSettingsProvider);
    _authorization.configureAppLock(settings.isBiometricEnabled);
    _authorization.configureTimeout(
      Duration(minutes: settings.autoLockMinutes),
    );
    if (settings.isBiometricEnabled) {
      _authorization.relock(requireAppUnlock: true);
    }
    _authorization.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
  }

  void _changed() {
    if (_authorization.blocked || _authorization.backgrounded) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inactive = state != AppLifecycleState.resumed;
    if (_inactive) FocusManager.instance.primaryFocus?.unfocus();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _pin.clear();
      _authorization.enterBackground(
        requireAppUnlock: ref.read(appSettingsProvider).isBiometricEnabled,
      );
    } else if (state == AppLifecycleState.resumed) {
      _authorization.enterForeground();
    }
    if (mounted) setState(() {});
  }

  Future<void> _unlock({required bool device}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final service = ref.read(lockServiceProvider);
    final pin = _pin.text;
    _pin.clear();
    final ok = device
        ? await service.resumeWithDevice()
        : await service.resumeWithPin(pin);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) {
        _error =
            'Authentication not accepted. Repeated PIN failures require a waiting period.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appSettingsProvider, (previous, next) {
      _authorization.configureAppLock(next.isBiometricEnabled);
      _authorization.configureTimeout(Duration(minutes: next.autoLockMinutes));
    });
    final shield = _inactive || _authorization.blocked;
    return Stack(
      children: [
        ExcludeFocus(
          excluding: shield,
          child: Offstage(offstage: shield, child: widget.child),
        ),
        if (shield)
          Positioned.fill(
            child: Overlay.wrap(
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                child: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline, size: 40),
                            const SizedBox(height: 16),
                            Text(
                              'Digital Memory is locked',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _pin,
                              obscureText: true,
                              maxLength: 6,
                              enableSuggestions: false,
                              autocorrect: false,
                              keyboardType: TextInputType.number,
                              enabled: !_busy && !_inactive,
                              decoration: const InputDecoration(
                                labelText: 'PIN',
                              ),
                              onSubmitted: (_) => _unlock(device: false),
                            ),
                            if (_error != null)
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            FilledButton(
                              onPressed: _busy || _inactive
                                  ? null
                                  : () => _unlock(device: false),
                              child: Text(
                                _busy ? 'Authenticating…' : 'Unlock with PIN',
                              ),
                            ),
                            TextButton(
                              onPressed: _busy || _inactive
                                  ? null
                                  : () => _unlock(device: true),
                              child: const Text('Use device authentication'),
                            ),
                            const Text(
                              'Use your configured PIN or device screen lock. Canceling authentication keeps the app locked.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authorization.removeListener(_changed);
    _pin.dispose();
    super.dispose();
  }
}
