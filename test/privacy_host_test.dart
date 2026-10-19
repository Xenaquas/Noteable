import 'package:digital_memory/core/services/lock_service.dart';
import 'package:digital_memory/core/services/note_authorization.dart';
import 'package:digital_memory/presentation/view_models/di.dart';
import 'package:digital_memory/presentation/widgets/privacy_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// ignore: depend_on_referenced_packages
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class TestWakelock extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({'auto_lock_minutes': 1});
    FlutterSecureStorage.setMockInitialValues({});
    WakelockPlusPlatformInterface.instance = TestWakelock();
  });

  testWidgets('expiration hides already pushed private content and semantics', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final authorization = NoteAuthorization();
    final navigator = GlobalKey<NavigatorState>();
    await authorization.authorize(
      noteIds: [7],
      operation: NoteOperation.read,
      authenticate: () async => true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          noteAuthorizationProvider.overrideWithValue(authorization),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) => PrivacyHost(child: child!),
          home: const Scaffold(body: Text('Public home')),
        ),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('PRIVATE BODY')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PRIVATE BODY'), findsOneWidget);
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    expect(find.text('PRIVATE BODY'), findsNothing);
    expect(find.text('Digital Memory is locked'), findsOneWidget);
    expect(await authorization.resume(() async => false), isFalse);
    await tester.pump();
    expect(find.text('PRIVATE BODY'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    authorization.dispose();
  });

  testWidgets('background and resume keep private content covered', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final authorization = NoteAuthorization();
    await authorization.authorize(
      noteIds: [7],
      operation: NoteOperation.read,
      authenticate: () async => true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          noteAuthorizationProvider.overrideWithValue(authorization),
        ],
        child: MaterialApp(
          builder: (_, child) => PrivacyHost(child: child!),
          home: const Scaffold(body: Text('PRIVATE BODY')),
        ),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('PRIVATE BODY'), findsNothing);
    expect(authorization.allows(7, NoteOperation.read), isFalse);
    await tester.pumpWidget(const SizedBox());
    authorization.dispose();
  });

  testWidgets('canceling PIN confirmation creates no credential or access', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final authorization = NoteAuthorization();
    final service = LockService(
      prefs,
      authorization: authorization,
      isNoteLocked: (_) async => false,
      lockedNoteIds: () async => [],
    );
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await service.authorizeNote(
                  context: context,
                  noteId: 7,
                  operation: NoteOperation.changeLock,
                );
              },
              child: const Text('Lock note'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Lock note'));
    await tester.pumpAndSettle();
    expect(find.text('Set a PIN'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '834729');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm PIN'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(await service.hasPin(), isFalse);
    expect(authorization.allows(7, NoteOperation.changeLock), isFalse);
    await tester.pumpWidget(const SizedBox());
    authorization.dispose();
  });

  testWidgets('the privacy shield prevents keyboard access to cached content', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final authorization = NoteAuthorization();
    final focus = FocusNode();
    final text = TextEditingController(text: 'PRIVATE BODY');
    await authorization.authorize(
      noteIds: [7],
      operation: NoteOperation.edit,
      authenticate: () async => true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          noteAuthorizationProvider.overrideWithValue(authorization),
        ],
        child: MaterialApp(
          builder: (_, child) => PrivacyHost(child: child!),
          home: Scaffold(
            body: TextField(
              controller: text,
              focusNode: focus,
              autofocus: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
    var clipboard = '';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        if (call.method == 'Clipboard.getData') return {'text': clipboard};
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await Clipboard.setData(const ClipboardData(text: 'SAFE CLIPBOARD'));
    authorization.relock();
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isFalse);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(
      (await Clipboard.getData(Clipboard.kTextPlain))?.text,
      'SAFE CLIPBOARD',
    );
    await tester.pumpWidget(const SizedBox());
    authorization.dispose();
    text.dispose();
    focus.dispose();
  });
}
