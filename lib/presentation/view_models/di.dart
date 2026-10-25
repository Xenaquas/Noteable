import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/databases/app_database.dart';
import '../../data/local/databases/app_drift_database.dart';
import '../../data/repositories/note_repository.dart' as data;
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../data/repositories/reminder_repository.dart';
import '../../core/services/lock_service.dart';
import '../../core/services/note_authorization.dart';
import '../../core/services/notification_sync_service.dart';
import '../../data/sources/settings_local_source.dart';
import '../../domain/repositories/note_repository.dart';

final dbProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);
final driftDbProvider = Provider<AppDriftDatabase>((ref) => AppDriftDatabase());

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final settingsLocalSourceProvider = Provider<SettingsLocalSource>((ref) {
  return SettingsLocalSource(ref.read(sharedPreferencesProvider));
});

final noteRepoProvider = Provider<NoteRepository>((ref) {
  return data.NoteRepository(ref.read(dbProvider),
      authorization: ref.read(noteAuthorizationProvider));
});

final noteAuthorizationProvider = Provider<NoteAuthorization>((ref) {
  final authorization = NoteAuthorization();
  ref.onDispose(authorization.dispose);
  return authorization;
});

final taskRepoProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.read(driftDbProvider));
});

final scheduleRepoProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository(ref.read(driftDbProvider));
});

final reminderRepoProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository(ref.read(driftDbProvider));
});

final notificationSyncServiceProvider =
    Provider<NotificationSyncService>((ref) {
  return NotificationSyncService(
    ref.read(reminderRepoProvider),
    ref.read(taskRepoProvider),
  );
});

final lockServiceProvider = Provider<LockService>((ref) {
  final repo = ref.read(noteRepoProvider);
  return LockService(ref.read(sharedPreferencesProvider),
    authorization: ref.read(noteAuthorizationProvider),
    isNoteLocked: repo.isNoteLocked,
    lockedNoteIds: () async => (await repo.listNotes())
        .where((n) => n.isLocked).map((n) => n.id!).toList(),
  );
});
