import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_drift_database.g.dart';

/// Shared priorities for tasks (1=high, 2=medium, 3=low).
const int kPriorityHigh = 1;
const int kPriorityMedium = 2;
const int kPriorityLow = 3;

/// Reminder status codes for easy filtering.
const int kReminderScheduled = 0;
const int kReminderFired = 1;
const int kReminderCanceled = 2;

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'second_brain_drift.db'));
    return NativeDatabase(file);
  });
}

class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().named('description').nullable()();
  BoolColumn get isCompleted =>
      boolean().withDefault(const Constant(false))();
  IntColumn get priority =>
      integer().withDefault(const Constant(kPriorityMedium))(); // 1..3
  IntColumn get sortIndex =>
      integer().withDefault(const Constant(0))(); // for manual ordering
  DateTimeColumn get dueAt => dateTime().nullable()(); // stored as UTC
  DateTimeColumn get reminderAt => dateTime().nullable()(); // stored as UTC
  TextColumn get recurrenceRule => text().nullable()(); // RRULE string
  TextColumn get notificationId => text().nullable()();
  IntColumn get noteId => integer().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  List<Index> get indexes => [
        Index('idx_tasks_due',
            'CREATE INDEX idx_tasks_due ON tasks(due_at)'),
        Index('idx_tasks_priority',
            'CREATE INDEX idx_tasks_priority ON tasks(priority)'),
      ];
}

class Schedules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get startAt => dateTime()(); // UTC
  DateTimeColumn get endAt => dateTime().nullable()(); // UTC
  BoolColumn get isAllDay =>
      boolean().withDefault(const Constant(false))();
  TextColumn get recurrenceRule => text().nullable()(); // RRULE string
  DateTimeColumn get reminderAt => dateTime().nullable()(); // UTC
  TextColumn get notificationId => text().nullable()();
  IntColumn get noteId => integer().nullable()();
  TextColumn get location => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  List<Index> get indexes => [
        Index('idx_schedule_start',
            'CREATE INDEX idx_schedule_start ON schedules(start_at)'),
        Index('idx_schedule_end',
            'CREATE INDEX idx_schedule_end ON schedules(end_at)'),
      ];
}

class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ownerType => text()(); // task | schedule | note
  IntColumn get ownerId => integer()();
  DateTimeColumn get fireAt => dateTime()(); // UTC
  IntColumn get status =>
      integer().withDefault(const Constant(kReminderScheduled))();
  TextColumn get notificationId => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  List<Index> get indexes => [
        Index('idx_reminder_owner',
            'CREATE INDEX idx_reminder_owner ON reminders(owner_type, owner_id)'),
        Index('idx_reminder_fire',
            'CREATE INDEX idx_reminder_fire ON reminders(fire_at)'),
      ];
}

class TaskSubtasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId => integer()();
  TextColumn get title => text()();
  BoolColumn get isCompleted =>
      boolean().withDefault(const Constant(false))();
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  List<String> get customConstraints => [
        'FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE',
      ];

  List<Index> get indexes => [
        Index('idx_subtasks_task',
            'CREATE INDEX idx_subtasks_task ON task_subtasks(task_id, sort_index)'),
      ];
}

class TaskLabels extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get color => text().nullable()(); // hex string
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
}

class TaskLabelLinks extends Table {
  IntColumn get taskId => integer()();
  IntColumn get labelId => integer()();

  @override
  Set<Column<Object>> get primaryKey => {taskId, labelId};

  @override
  List<String> get customConstraints => [
        'FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE',
        'FOREIGN KEY(label_id) REFERENCES task_labels(id) ON DELETE CASCADE',
      ];
}

@DriftDatabase(
  tables: [
    Tasks,
    Schedules,
    Reminders,
    TaskSubtasks,
    TaskLabels,
    TaskLabelLinks,
  ],
  daos: [
    TasksDao,
    SchedulesDao,
    RemindersDao,
    TaskLabelsDao,
  ],
)
class AppDriftDatabase extends _$AppDriftDatabase {
  AppDriftDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  // Simple migration placeholder for future schema changes.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (migrator, from, to) async {
          if (from == 1) {
            await migrator.addColumn(tasks, tasks.sortIndex);
          }
          if (from < 3) {
            final rows = await migrator.database
                .customSelect("PRAGMA table_info('schedules')")
                .get();
            final hasNoteId =
                rows.any((row) => row.read<String>('name') == 'note_id');
            if (!hasNoteId) {
              await migrator.addColumn(schedules, schedules.noteId);
            }
          }
        },
      );
}

@DriftAccessor(tables: [Tasks, TaskSubtasks, TaskLabelLinks, TaskLabels])
class TasksDao extends DatabaseAccessor<AppDriftDatabase> with _$TasksDaoMixin {
  TasksDao(AppDriftDatabase db) : super(db);

  Future<int> insertTask(TasksCompanion task) => into(tasks).insert(task);

  Future<int> upsertTask(TasksCompanion task) =>
      into(tasks).insertOnConflictUpdate(task);

  Future<List<Task>> allTasks() {
    return (select(tasks)..orderBy([(t) => OrderingTerm.asc(t.sortIndex)])).get();
  }

  Future<List<Task>> tasksForDay(DateTime dayUtc) {
    final start = DateTime.utc(dayUtc.year, dayUtc.month, dayUtc.day);
    final end = start.add(const Duration(days: 1));
    return (select(tasks)
          ..where((t) => t.dueAt.isBiggerOrEqualValue(start) &
              t.dueAt.isSmallerThanValue(end)))
        .get();
  }

  Future<void> toggleComplete(int id, bool value) async {
    await (update(tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        isCompleted: Value(value),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> deleteTask(int id) async =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  Future<int> insertSubtask(TaskSubtasksCompanion sub) =>
      into(taskSubtasks).insert(sub);

  Future<void> updateSubtasksOrder(int taskId, List<int> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await (update(taskSubtasks)
            ..where((s) => s.id.equals(orderedIds[i])))
          .write(TaskSubtasksCompanion(sortIndex: Value(i)));
    }
  }

  Future<void> updateTasksOrder(List<int> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await (update(tasks)..where((t) => t.id.equals(orderedIds[i]))).write(
        TasksCompanion(sortIndex: Value(i)),
      );
    }
  }

  Future<void> replaceSubtasks(int taskId, List<String> titles) async {
    await (delete(taskSubtasks)..where((s) => s.taskId.equals(taskId))).go();
    for (var i = 0; i < titles.length; i++) {
      await into(taskSubtasks).insert(
        TaskSubtasksCompanion(
          taskId: Value(taskId),
          title: Value(titles[i]),
          sortIndex: Value(i),
        ),
      );
    }
  }

  Future<void> toggleSubtask(int subtaskId, bool value) async {
    await (update(taskSubtasks)..where((s) => s.id.equals(subtaskId))).write(
      TaskSubtasksCompanion(
        isCompleted: Value(value),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<List<TaskSubtask>> subtasksFor(int taskId) {
    return (select(taskSubtasks)
          ..where((s) => s.taskId.equals(taskId))
          ..orderBy([(s) => OrderingTerm.asc(s.sortIndex)]))
        .get();
  }
}

@DriftAccessor(tables: [Schedules])
class SchedulesDao extends DatabaseAccessor<AppDriftDatabase>
    with _$SchedulesDaoMixin {
  SchedulesDao(AppDriftDatabase db) : super(db);

  Future<int> insertSchedule(SchedulesCompanion data) =>
      into(schedules).insert(data);

  Future<int> upsertSchedule(SchedulesCompanion data) =>
      into(schedules).insertOnConflictUpdate(data);

  Future<List<Schedule>> schedulesBetween(DateTime startUtc, DateTime endUtc) {
    return (select(schedules)
          ..where((s) =>
              s.startAt.isSmallerOrEqualValue(endUtc) &
              s.endAt.isBiggerOrEqualValue(startUtc)))
        .get();
  }

  Future<void> deleteSchedule(int id) async =>
      (delete(schedules)..where((s) => s.id.equals(id))).go();
}

@DriftAccessor(tables: [Reminders])
class RemindersDao extends DatabaseAccessor<AppDriftDatabase>
    with _$RemindersDaoMixin {
  RemindersDao(AppDriftDatabase db) : super(db);

  Future<int> insertReminder(RemindersCompanion data) =>
      into(reminders).insert(data);

  Future<void> markStatus(int id, int status) async {
    await (update(reminders)..where((r) => r.id.equals(id))).write(
      RemindersCompanion(
        status: Value(status),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> setNotificationId(int id, String notificationId) async {
    await (update(reminders)..where((r) => r.id.equals(id))).write(
      RemindersCompanion(
        notificationId: Value(notificationId),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<List<Reminder>> byOwner(String ownerType, int ownerId) {
    return (select(reminders)
          ..where((r) =>
              r.ownerType.equals(ownerType) & r.ownerId.equals(ownerId)))
        .get();
  }

  Future<void> deleteReminder(int id) async =>
      (delete(reminders)..where((r) => r.id.equals(id))).go();

  Future<List<Reminder>> dueUntil(DateTime untilUtc) {
    return (select(reminders)
          ..where((r) =>
              r.status.equals(kReminderScheduled) &
              r.fireAt.isSmallerOrEqualValue(untilUtc)))
        .get();
  }
}

@DriftAccessor(tables: [TaskLabels, TaskLabelLinks])
class TaskLabelsDao extends DatabaseAccessor<AppDriftDatabase>
    with _$TaskLabelsDaoMixin {
  TaskLabelsDao(AppDriftDatabase db) : super(db);

  Future<int> insertLabel(TaskLabelsCompanion data) =>
      into(taskLabels).insert(data, mode: InsertMode.insertOrIgnore);

  Future<void> attachLabel(int taskId, int labelId) async {
    await into(taskLabelLinks).insert(
      TaskLabelLinksCompanion(
        taskId: Value(taskId),
        labelId: Value(labelId),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> detachLabel(int taskId, int labelId) async {
    await (delete(taskLabelLinks)
          ..where((l) => l.taskId.equals(taskId) & l.labelId.equals(labelId)))
        .go();
  }

  Future<List<TaskLabel>> allLabels() => select(taskLabels).get();
}
