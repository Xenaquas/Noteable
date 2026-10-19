import 'package:digital_memory/data/local/databases/app_drift_database.dart';
import 'package:digital_memory/presentation/views/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/privacy_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = PrivacyFixture();
  late AppDriftDatabase drift;
  setUpAll(() async {
    await fixture.open();
    drift = AppDriftDatabase();
    await drift.customSelect('SELECT 1').get();
  });
  tearDownAll(() async {
    await drift.close();
    await fixture.close();
  });

  testWidgets('Home renders public notes and redacts private content', (tester) async {
    tester.view.physicalSize = const Size(480, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(fixture.app(const HomeScreen(), drift: drift));
    await tester.tap(find.widgetWithText(Tab, 'Notes'));
    await pumpUntil(tester, () => find.text('PUBLIC TITLE').evaluate().isNotEmpty);
    expect(find.text('Second Brain'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Notes'), findsOneWidget);
    expect(find.text('PRIVATE TITLE'), findsNothing);
    expect(find.textContaining('PRIVATE BODY'), findsNothing);
    expect(find.text('PRIVATE FILE'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
