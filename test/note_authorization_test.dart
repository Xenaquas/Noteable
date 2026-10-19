import 'dart:async';

import 'package:digital_memory/core/services/note_authorization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late NoteAuthorization authorization;
  setUp(() => authorization = NoteAuthorization());
  tearDown(() => authorization.dispose());

  test('canceled and failed authentication never grant capabilities', () async {
    for (final authenticate in <Future<bool> Function()>[
      () async => false,
      () async => throw StateError('unavailable'),
    ]) {
      expect(
        await authorization.authorize(
          noteIds: [7],
          operation: NoteOperation.read,
          authenticate: authenticate,
        ),
        isFalse,
      );
      expect(authorization.allows(7, NoteOperation.read), isFalse);
    }
  });

  test(
    'a valid capability is limited to its note and requested operation',
    () async {
      expect(
        await authorization.authorize(
          noteIds: [7],
          operation: NoteOperation.read,
          authenticate: () async => true,
        ),
        isTrue,
      );
      expect(authorization.allows(7, NoteOperation.read), isTrue);
      expect(authorization.allows(7, NoteOperation.attachment), isTrue);
      expect(authorization.allows(8, NoteOperation.read), isFalse);
      for (final operation in [
        NoteOperation.edit,
        NoteOperation.delete,
        NoteOperation.changeLock,
        NoteOperation.share,
        NoteOperation.export,
      ]) {
        expect(authorization.allows(7, operation), isFalse);
      }
    },
  );

  test(
    'attachment-only authorization cannot expose its owning note content',
    () async {
      await authorization.authorize(
        noteIds: [7],
        operation: NoteOperation.attachment,
        authenticate: () async => true,
      );
      expect(authorization.allows(7, NoteOperation.attachment), isTrue);
      expect(authorization.allows(7, NoteOperation.read), isFalse);
      expect(authorization.allows(7, NoteOperation.edit), isFalse);
    },
  );

  testWidgets('timeout revokes access and requires fresh authentication', (
    tester,
  ) async {
    authorization.configureTimeout(const Duration(seconds: 1));
    await authorization.authorize(
      noteIds: [7],
      operation: NoteOperation.read,
      authenticate: () async => true,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(authorization.allows(7, NoteOperation.read), isFalse);
    expect(authorization.blocked, isTrue);
    expect(await authorization.resume(() async => false), isFalse);
    expect(authorization.allows(7, NoteOperation.read), isFalse);
    expect(await authorization.resume(() async => true), isTrue);
    expect(authorization.allows(7, NoteOperation.read), isTrue);
    authorization.relock();
  });

  test('backgrounding rejects an in-flight authentication result', () async {
    final result = Completer<bool>();
    final pending = authorization.authorize(
      noteIds: [7],
      operation: NoteOperation.edit,
      authenticate: () => result.future,
    );
    authorization.enterBackground();
    authorization.enterForeground();
    result.complete(true);
    expect(await pending, isFalse);
    expect(authorization.allows(7, NoteOperation.edit), isFalse);
  });

  test(
    'timer Off still revokes protected access on background and relock',
    () async {
      authorization.configureTimeout(Duration.zero);
      await authorization.authorize(
        noteIds: [7],
        operation: NoteOperation.edit,
        authenticate: () async => true,
      );
      authorization.enterBackground();
      authorization.enterForeground();
      expect(authorization.allows(7, NoteOperation.edit), isFalse);
      await authorization.resume(() async => true);
      expect(authorization.allows(7, NoteOperation.edit), isTrue);
      authorization.relock();
      expect(authorization.allows(7, NoteOperation.edit), isFalse);
    },
  );

  test(
    'revoked pending authentication cannot block or overwrite a new attempt',
    () async {
      final oldResult = Completer<bool>();
      final old = authorization.authorize(
        noteIds: [7],
        operation: NoteOperation.edit,
        authenticate: () => oldResult.future,
      );
      authorization.relock(requireAppUnlock: true);
      final newResult = Completer<bool>();
      final fresh = authorization.resume(() => newResult.future);
      oldResult.complete(true);
      expect(await old, isFalse);
      // The stale request's finally must not release a newer request's guard.
      expect(await authorization.resume(() async => true), isFalse);
      newResult.complete(true);
      expect(await fresh, isTrue);
      expect(authorization.blocked, isFalse);
      expect(authorization.allows(7, NoteOperation.edit), isFalse);
      authorization.relock();
    },
  );
}
