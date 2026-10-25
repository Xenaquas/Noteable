import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-bound PIN verifier. Ordinary preferences are read only for migration.
class PinStore {
  PinStore(
    this._prefs, {
    FlutterSecureStorage? storage,
    DateTime Function()? now,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.unlocked_this_device,
             ),
             mOptions: MacOsOptions(
               accessibility: KeychainAccessibility.unlocked_this_device,
             ),
           ),
       _now = now ?? DateTime.now;

  final SharedPreferences _prefs;
  final FlutterSecureStorage _storage;
  final DateTime Function() _now;
  static const storageKey = 'noteable.pin.v2';
  static const _oldVerifierKey = 'noteable.pin.v1';
  static const _legacyKey = 'app_pin';
  static const _iterations = 600000;
  Future<void> _pending = Future.value();

  // Serialize verification and migration so concurrent requests cannot reset
  // throttling, overwrite a newer verifier, or double-migrate a legacy PIN.
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<Map<String, dynamic>?> _read() async {
    var raw = await _storage.read(key: storageKey);
    var oldStoragePolicy = false;
    if (raw == null) {
      raw = await _storage.read(
        key: _oldVerifierKey,
        iOptions: const IOSOptions(),
        mOptions: const MacOsOptions(),
      );
      oldStoragePolicy = raw != null;
    }
    if (raw != null) {
      final record = jsonDecode(raw) as Map<String, dynamic>;
      if (record['version'] != 1 ||
          record['iterations'] != _iterations ||
          base64Decode(record['salt'] as String).length != 16 ||
          base64Decode(record['verifier'] as String).length != 32 ||
          record['failures'] is! int ||
          record['blockedUntil'] is! int) {
        throw const FormatException('Invalid PIN credential');
      }
      if (oldStoragePolicy) {
        // Distinct key: verify the device-only replacement before deleting the
        // migratable item. Never change accessibility in place: the installed
        // Apple plugin deletes then adds when that attribute changes.
        await _write(record);
      }
      // Retry cleanup even when the replacement was committed by a previous,
      // interrupted migration. The validated v2 record remains authoritative,
      // including its failed-attempt counters.
      if (await _storage.containsKey(
        key: _oldVerifierKey,
        iOptions: const IOSOptions(),
        mOptions: const MacOsOptions(),
      )) {
        await _storage.delete(
          key: _oldVerifierKey,
          iOptions: const IOSOptions(),
          mOptions: const MacOsOptions(),
        );
        if (await _storage.containsKey(
          key: _oldVerifierKey,
          iOptions: const IOSOptions(),
          mOptions: const MacOsOptions(),
        )) {
          throw StateError('PIN migration could not finish');
        }
      }
      // A previous migration may have stopped after secure storage committed.
      if (_prefs.containsKey(_legacyKey) && !await _prefs.remove(_legacyKey)) {
        throw StateError('PIN migration could not finish');
      }
      return record;
    }
    final legacy = _prefs.getString(_legacyKey);
    if (legacy == null) return null;
    if (legacy.isEmpty || legacy.length > 6) {
      throw const FormatException(
        'Unsupported legacy PIN; credential retained',
      );
    }
    // Preserve all previously accepted PINs, including legacy short values.
    // They remain subject to the same persistent attempt limit.
    final record = await _newRecord(legacy);
    await _write(record);
    if (!await _prefs.remove(_legacyKey)) {
      throw StateError('PIN migration could not finish');
    }
    return record;
  }

  Future<List<int>> _derive(String pin, List<int> salt) async {
    final key = await BackgroundPbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: pin, nonce: salt);
    return key.extractBytes();
  }

  Future<Map<String, dynamic>> _newRecord(String pin) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    return {
      'version': 1,
      'iterations': _iterations,
      'salt': base64Encode(salt),
      'verifier': base64Encode(await _derive(pin, salt)),
      'failures': 0,
      'blockedUntil': 0,
    };
  }

  Future<void> _write(Map<String, dynamic> record) async {
    final encoded = jsonEncode(record);
    await _storage.write(key: storageKey, value: encoded);
    if (await _storage.read(key: storageKey) != encoded) {
      throw StateError('PIN credential was not saved');
    }
  }

  Future<bool> hasPin() => _serial(() async => await _read() != null);

  Future<void> setPin(String pin) => _serial(() async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw ArgumentError('Use a six-digit PIN');
    }
    // Replacing an existing credential requires a dedicated authenticated
    // change-PIN flow; setup must never act as a credential reset.
    if (await _read() != null) throw StateError('PIN is already configured');
    await _write(await _newRecord(pin));
  });

  Future<bool> verifyPin(String pin) => _serial(() async {
    final record = await _read();
    if (record == null) return false;
    final now = _now().millisecondsSinceEpoch;
    if (now < (record['blockedUntil'] as int)) return false;
    final expected = base64Decode(record['verifier'] as String);
    final actual = await _derive(pin, base64Decode(record['salt'] as String));
    final ok = constantTimeBytesEquality.equals(expected, actual);
    final failures = ok ? 0 : (record['failures'] as int) + 1;
    final delay = failures < 5
        ? 0
        : min(3600, 30 * (1 << min(7, failures - 5)));
    record['failures'] = failures;
    record['blockedUntil'] = ok ? 0 : now + delay * 1000;
    await _write(record);
    return ok;
  });
}
