import 'dart:io';

import 'package:digital_memory/core/services/auth_service.dart';
import 'package:digital_memory/core/services/lock_service.dart';
import 'package:digital_memory/core/services/note_authorization.dart';
import 'package:digital_memory/data/local/databases/app_database.dart';
import 'package:digital_memory/data/local/databases/app_drift_database.dart';
import 'package:digital_memory/data/repositories/note_repository.dart';
import 'package:digital_memory/presentation/view_models/di.dart';
import 'package:digital_memory/presentation/widgets/privacy_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// ignore: depend_on_referenced_packages
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String> getApplicationDocumentsPath() async => path;
  @override
  Future<String> getTemporaryPath() async => path;
}

class UnavailableDeviceAuth extends AuthService {
  @override
  Future<bool> authenticate({
    String reason = '',
    bool biometricOnly = false,
  }) async => false;
}

class TestWakelock extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}
}

/// Real SQLite, repositories and authorization; only device/plugin boundaries
/// are substituted in host widget tests. All files live in an owned temp dir.
class PrivacyFixture {
  late Directory directory;
  late SharedPreferences prefs;
  var authorization = NoteAuthorization();
  late NoteRepository repo;
  late LockService lock;

  Future<void> open() async {
    directory = await Directory.systemTemp.createTemp('noteable-privacy-test-');
    PathProviderPlatform.instance = _Paths(directory.path);
    if (!Platform.isAndroid && !Platform.isIOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      WakelockPlusPlatformInterface.instance = TestWakelock();
    }
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    _createServices();
    final db = await AppDatabase.instance.db;
    if (!p.isWithin(directory.path, db.path)) {
      throw StateError('Unsafe test database path');
    }
    await db.insert('notes', {
      'id': 1,
      'title': 'PUBLIC TITLE',
      'content_json': '[{"insert":"PUBLIC BODY\\n"}]',
      'content_plain': 'PUBLIC BODY',
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
    await db.insert('notes', {
      'id': 2,
      'title': 'PRIVATE TITLE',
      'content_json': '[{"insert":"PRIVATE BODY\\n"}]',
      'content_plain': 'PRIVATE BODY',
      'is_locked': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
    await db.insert('attachments', {
      'note_id': 2,
      'type': 'file',
      'path': p.join(directory.path, 'private.txt'),
      'name': 'PRIVATE FILE',
      'sort_index': 0,
      'created_at': 1,
    });
    await File(
      p.join(directory.path, 'private.txt'),
    ).writeAsString('PRIVATE ATTACHMENT');
  }

  void _createServices() {
    repo = NoteRepository(AppDatabase.instance, authorization: authorization);
    lock = LockService(
      prefs,
      authorization: authorization,
      auth: UnavailableDeviceAuth(),
      isNoteLocked: repo.isNoteLocked,
      lockedNoteIds: () async => (await repo.listNotes())
          .where((n) => n.isLocked)
          .map((n) => n.id!)
          .toList(),
    );
  }

  void resetSession() {
    authorization.dispose();
    authorization = NoteAuthorization();
    _createServices();
  }

  Widget app(Widget home, {bool shield = true, AppDriftDatabase? drift}) =>
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          noteAuthorizationProvider.overrideWithValue(authorization),
          noteRepoProvider.overrideWithValue(repo),
          lockServiceProvider.overrideWithValue(lock),
          if (drift != null) driftDbProvider.overrideWithValue(drift),
        ],
        child: MaterialApp(
          localizationsDelegates: const [FlutterQuillLocalizations.delegate],
          builder: shield ? (_, child) => PrivacyHost(child: child!) : null,
          home: home,
        ),
      );

  Future<void> close() async {
    authorization.dispose();
    await (await AppDatabase.instance.db).close();
    final temp = Directory.systemTemp.absolute.path;
    if (!p.isWithin(temp, directory.absolute.path) ||
        !p.basename(directory.path).startsWith('noteable-privacy-test-')) {
      throw StateError('Unsafe test cleanup path');
    }
    await directory.delete(recursive: true);
  }
}

Future<void> pumpUntil(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 400; i++) {
    await tester.pump(const Duration(milliseconds: 25));
    if (ready()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  fail('Timed out waiting for the application state');
}
