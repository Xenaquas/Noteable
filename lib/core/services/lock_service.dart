// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LockService {
  LockService(this._prefs);

  final SharedPreferences _prefs;
  static const _pinKey = 'app_pin';
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> authenticate({
    required BuildContext context,
    String reason = 'Authenticate to continue',
  }) async {
    if (!context.mounted) return false;
    final hasBiometric = await _canUseBiometric();
    if (hasBiometric) {
      try {
        final ok = await _auth.authenticate(
          localizedReason: reason,
          persistAcrossBackgrounding: true,
        );
        if (ok) return true;
      } catch (_) {
        // fall through to PIN
      }
    }
    if (!context.mounted) return false;
    return _handlePinFlow(context, reason: reason);
  }

  Future<bool> hasPin() async => _prefs.getString(_pinKey) != null;

  Future<void> setPin(String pin) async {
    await _prefs.setString(_pinKey, pin);
  }

  Future<bool> verifyPin(String pin) async {
    final stored = _prefs.getString(_pinKey);
    return stored != null && stored == pin;
  }

  Future<bool> _handlePinFlow(
    BuildContext context, {
    required String reason,
  }) async {
    if (!context.mounted) return false;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final existing = await hasPin();
    if (!existing) {
      // ignore: use_build_context_synchronously
      final created = await _promptCreatePin(context);
      if (!created || !context.mounted) return false;
    }
    if (!context.mounted) return false;
    return _promptEnterPin(
      context,
      reason: reason,
      messenger: messenger,
    );
  }

  Future<bool> _promptCreatePin(BuildContext context) async {
    final pin = await _showPinDialog(
      context,
      title: 'Set a PIN',
      subtitle: 'Use this PIN when biometrics are unavailable.',
    );
    if (pin == null || pin.isEmpty) return false;

    // ignore: use_build_context_synchronously
    final confirm = await _showPinDialog(
      context,
      title: 'Confirm PIN',
      subtitle: 'Re-enter to confirm.',
    );
    if (!context.mounted) return false;
    if (confirm != null && confirm == pin) {
      await setPin(pin);
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PINs did not match')),
    );
    return false;
  }

  Future<bool> _promptEnterPin(
    BuildContext context, {
    required String reason,
    ScaffoldMessengerState? messenger,
  }) async {
    final pin = await _showPinDialog(
      context,
      title: 'Enter PIN',
      subtitle: reason,
    );
    if (pin == null) return false;
    final ok = await verifyPin(pin);
    if (!ok && context.mounted) {
      messenger ??= ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        const SnackBar(content: Text('Incorrect PIN')),
      );
    }
    return ok;
  }

  Future<String?> _showPinDialog(
    BuildContext context, {
    required String title,
    String? subtitle,
    ValueChanged<String>? onSubmitted,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle != null) ...[
              Text(subtitle),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                counterText: '',
                hintText: 'Enter 4-6 digit PIN',
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              onSubmitted?.call(controller.text);
              Navigator.pop(ctx, controller.text);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<bool> _canUseBiometric() async {
    try {
      final canBio = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      final enrolled = await _auth.getAvailableBiometrics();
      return (canBio || supported) && enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
