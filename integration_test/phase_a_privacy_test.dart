import 'dart:convert';

import 'package:digital_memory/core/services/auth_service.dart';
import 'package:digital_memory/core/services/pin_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/privacy_routes_test.dart' as routes;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android secure storage preserves the migrated verifier', (
    tester,
  ) async {
    // A separate namespace is used; no existing application credential is read,
    // overwritten or deleted by this test. Run on the dedicated privacy AVD.
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(
        sharedPreferencesName: 'NoteablePrivacyIntegration',
        preferencesKeyPrefix: 'privacy-integration',
      ),
    );
    await storage.delete(key: PinStore.storageKey);
    SharedPreferences.setMockInitialValues({'app_pin': '1234'});
    final prefs = await SharedPreferences.getInstance();
    final pins = PinStore(prefs, storage: storage);
    expect(await pins.verifyPin('1234'), isTrue);
    expect(prefs.getString('app_pin'), isNull);
    final saved =
        jsonDecode((await storage.read(key: PinStore.storageKey))!) as Map;
    expect(saved.containsKey('pin'), isFalse);
    expect(saved['verifier'], isNot('1234'));
    expect(await PinStore(prefs, storage: storage).verifyPin('1234'), isTrue);
    expect(await PinStore(prefs, storage: storage).verifyPin('9999'), isFalse);
    await storage.delete(key: PinStore.storageKey);
  });

  testWidgets(
    'an Android device with no enrolled credentials denies authentication',
    (tester) async {
      // Dedicated AVD is intentionally created without a device screen lock.
      expect(await AuthService().authenticate(), isFalse);
    },
  );

  group('Android routes with real Sqflite persistence', routes.main);
}
