import 'package:drift/drift.dart';

import '../local/databases/app_drift_database.dart';

class ReminderRepository {
  ReminderRepository(this._db);

  final AppDriftDatabase _db;
  RemindersDao get _dao => _db.remindersDao;

  Future<int> insert({
    required String ownerType,
    required int ownerId,
    required DateTime fireAtUtc,
    String? notificationId,
  }) {
    final data = RemindersCompanion(
      ownerType: Value(ownerType),
      ownerId: Value(ownerId),
      fireAt: Value(fireAtUtc),
      notificationId: Value(notificationId),
    );
    return _dao.insertReminder(data);
  }

  Future<void> markStatus(int id, int status) => _dao.markStatus(id, status);

  Future<void> setNotificationId(int id, String notificationId) =>
      _dao.setNotificationId(id, notificationId);

  Future<void> delete(int id) => _dao.deleteReminder(id);

  Future<List<Reminder>> dueUntilUtc(DateTime untilUtc) =>
      _dao.dueUntil(untilUtc);

  Future<List<Reminder>> betweenUtc({
    required DateTime startUtc,
    required DateTime endUtc,
    String? ownerType,
  }) {
    final query = _db.select(_db.reminders)
      ..where((r) =>
          r.status.equals(kReminderScheduled) &
          r.fireAt.isBiggerOrEqualValue(startUtc) &
          r.fireAt.isSmallerOrEqualValue(endUtc));
    if (ownerType != null) {
      query.where((r) => r.ownerType.equals(ownerType));
    }
    return query.get();
  }

  Future<List<Reminder>> forOwner({
    required String ownerType,
    required int ownerId,
  }) =>
      _dao.byOwner(ownerType, ownerId);
}
