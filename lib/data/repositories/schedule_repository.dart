import 'package:drift/drift.dart';

import '../local/databases/app_drift_database.dart';

class ScheduleRepository {
  ScheduleRepository(this._db);

  final AppDriftDatabase _db;
  SchedulesDao get _dao => _db.schedulesDao;

  Future<int> upsertSchedule({
    int? id,
    required String title,
    String? description,
    required DateTime startAtUtc,
    DateTime? endAtUtc,
    bool isAllDay = false,
    String? recurrenceRule,
    DateTime? reminderAtUtc,
    String? notificationId,
    int? noteId,
    String? location,
  }) {
    final companion = SchedulesCompanion(
      id: id == null ? const Value.absent() : Value(id),
      title: Value(title),
      description: Value(description),
      startAt: Value(startAtUtc),
      endAt: Value(endAtUtc),
      isAllDay: Value(isAllDay),
      recurrenceRule: Value(recurrenceRule),
      reminderAt: Value(reminderAtUtc),
      notificationId: Value(notificationId),
      noteId: Value(noteId),
      location: Value(location),
      updatedAt: Value(DateTime.now().toUtc()),
    );
    return _dao.upsertSchedule(companion);
  }

  Future<List<Schedule>> betweenUtc(DateTime startUtc, DateTime endUtc) =>
      _dao.schedulesBetween(startUtc, endUtc);

  Future<Schedule?> getSchedule(int id) {
    return (_db.select(_db.schedules)..where((s) => s.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> deleteSchedule(int id) => _dao.deleteSchedule(id);
}
