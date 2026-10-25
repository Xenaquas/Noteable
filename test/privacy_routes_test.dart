import 'package:digital_memory/core/services/note_authorization.dart';
import 'package:digital_memory/presentation/view_models/attachments_vm.dart';
import 'package:digital_memory/presentation/views/attachments/attachments_screen.dart';
import 'package:digital_memory/presentation/views/note_editor/note_editor_screen.dart';
import 'package:digital_memory/presentation/views/note_preview/note_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'support/privacy_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = PrivacyFixture();
  setUpAll(() async {
    await fixture.open();
    await fixture.lock.setPin('834729');
  });
  tearDownAll(fixture.close);
  setUp(fixture.resetSession);

  for (final editor in [false, true]) {
    testWidgets(
      '${editor ? 'editor' : 'preview'} direct route: cancel denies private data',
      (tester) async {
        await tester.pumpWidget(
          fixture.app(
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => editor
                          ? const NoteEditorScreen(noteId: 2)
                          : const NotePreviewScreen(noteId: 2),
                    ),
                  ),
                  child: const Text('Open note'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open note'));
        await pumpUntil(
          tester,
          () => find.text('Enter PIN').evaluate().isNotEmpty,
        );
        expect(find.text('PRIVATE TITLE'), findsNothing);
        expect(find.textContaining('PRIVATE BODY'), findsNothing);
        expect(find.text('PRIVATE FILE'), findsNothing);
        await tester.tap(find.text('Cancel'));
        await pumpUntil(
          tester,
          () => find.text('Open note').evaluate().isNotEmpty,
        );
        expect(
          fixture.authorization.allows(
            2,
            editor ? NoteOperation.edit : NoteOperation.read,
          ),
          isFalse,
        );
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'File Manager never reveals unauthorized locked attachment metadata',
    (tester) async {
      await tester.pumpWidget(fixture.app(const AttachmentsScreen()));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AttachmentsScreen)),
      );
      await pumpUntil(
        tester,
        () => !container.read(attachmentsVmProvider).isLoading,
      );
      expect(find.text('PRIVATE TITLE'), findsNothing);
      expect(find.text('PRIVATE FILE'), findsNothing);
      expect(find.textContaining('private.txt'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('an unlocked note preview renders without authentication', (
    tester,
  ) async {
    await tester.pumpWidget(fixture.app(const NotePreviewScreen(noteId: 1)));
    await pumpUntil(
      tester,
      () => find.text('PUBLIC TITLE').evaluate().isNotEmpty,
    );
    expect(find.text('Enter PIN'), findsNothing);
    expect(find.text('PUBLIC TITLE'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'verified PIN unlocks only the requested note and expiry covers it',
    (tester) async {
      await tester.pumpWidget(fixture.app(const NotePreviewScreen(noteId: 2)));
      await pumpUntil(
        tester,
        () => find.text('Enter PIN').evaluate().isNotEmpty,
      );
      await tester.enterText(find.byType(TextField), '834729');
      await tester.tap(find.text('Confirm'));
      await pumpUntil(
        tester,
        () => find.text('PRIVATE TITLE').evaluate().isNotEmpty,
      );
      expect(fixture.authorization.allows(2, NoteOperation.read), isTrue);
      expect(fixture.authorization.allows(2, NoteOperation.share), isFalse);
      fixture.authorization.configureTimeout(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('PRIVATE TITLE'), findsNothing);
      expect(find.text('PRIVATE FILE'), findsNothing);
      expect(find.text('Digital Memory is locked'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      fixture.authorization.relock();
    },
  );

  testWidgets('revoking an open PIN prompt permits fresh root authentication', (
    tester,
  ) async {
    await tester.pumpWidget(fixture.app(const NotePreviewScreen(noteId: 2)));
    await pumpUntil(tester, () => find.text('Enter PIN').evaluate().isNotEmpty);
    // Simulate expiration while an operation-specific prompt is pending.
    fixture.authorization.relock(requireAppUnlock: true);
    await tester.pumpAndSettle();
    expect(find.text('Enter PIN'), findsNothing);
    expect(find.text('Digital Memory is locked'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '834729');
    await tester.tap(find.text('Unlock with PIN'));
    await pumpUntil(tester, () => !fixture.authorization.blocked);
    expect(find.text('Digital Memory is locked'), findsNothing);
    expect(fixture.authorization.allows(2, NoteOperation.read), isFalse);
    await tester.pumpWidget(const SizedBox());
    fixture.authorization.relock();
  });
}
