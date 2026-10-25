@Timeout(Duration(minutes: 2))
library;

import 'package:digital_memory/core/services/lock_service.dart';
import 'package:digital_memory/core/services/pin_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('PIN setup rejects short, nonnumeric and whitespace input', () async {
    final service = LockService(await SharedPreferences.getInstance());
    for (final pin in ['1', 'abcd', '123 56', '', '123456789']) {
      await expectLater(service.setPin(pin), throwsArgumentError);
    }
    expect(await service.hasPin(), isFalse);
  });

  test('new PIN is never written to ordinary preferences', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = LockService(prefs);
    await service.setPin('834729');
    expect(prefs.getString('app_pin'), isNull);
    expect(await service.verifyPin('834729'), isTrue);
    expect(await service.verifyPin('834728'), isFalse);
  });

  test('legacy PIN migrates without losing the existing credential', () async {
    SharedPreferences.setMockInitialValues({'app_pin': '1234'});
    final prefs = await SharedPreferences.getInstance();
    final service = LockService(prefs);
    expect(await service.verifyPin('1234'), isTrue);
    expect(prefs.getString('app_pin'), isNull);
    final restarted = LockService(prefs);
    expect(await restarted.verifyPin('9999'), isFalse);
    expect(await restarted.verifyPin('1234'), isTrue);
  });

  test('failed PIN attempts remain throttled after service restart', () async {
    final prefs = await SharedPreferences.getInstance();
    var service = LockService(prefs);
    await service.setPin('834729');
    for (var i = 0; i < 5; i++) {
      expect(await service.verifyPin('000000'), isFalse);
    }
    service = LockService(prefs);
    expect(await service.verifyPin('834729'), isFalse);
  });

  test(
    'a verifier from the earlier storage policy migrates without changing it',
    () async {
      const record =
          '{"version":1,"iterations":600000,"salt":"AAAAAAAAAAAAAAAAAAAAAA==","verifier":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=","failures":3,"blockedUntil":0}';
      FlutterSecureStorage.setMockInitialValues({'noteable.pin.v1': record});
      final prefs = await SharedPreferences.getInstance();
      expect(await PinStore(prefs).hasPin(), isTrue);
      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'noteable.pin.v2'), record);
      expect(await storage.read(key: 'noteable.pin.v1'), isNull);
    },
  );

  test(
    'interrupted migration retries cleanup and preserves current throttling',
    () async {
      const current =
          '{"version":1,"iterations":600000,"salt":"AAAAAAAAAAAAAAAAAAAAAA==","verifier":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=","failures":5,"blockedUntil":9999999999999}';
      const stale =
          '{"version":1,"iterations":600000,"salt":"AAAAAAAAAAAAAAAAAAAAAA==","verifier":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=","failures":0,"blockedUntil":0}';
      FlutterSecureStorage.setMockInitialValues({
        'noteable.pin.v1': stale,
        'noteable.pin.v2': current,
      });
      final prefs = await SharedPreferences.getInstance();
      final pins = PinStore(prefs);
      expect(await pins.hasPin(), isTrue);
      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'noteable.pin.v1'), isNull);
      expect(await storage.read(key: 'noteable.pin.v2'), current);
      expect(await pins.verifyPin('1234'), isFalse);
    },
  );
}
