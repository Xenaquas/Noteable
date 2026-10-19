import 'package:drift/drift.dart';

import '../local/databases/app_drift_database.dart';

/// Repository for tasks and subtasks, converts UTC storage to UTC DateTime objects.
class TaskRepository {
  TaskRepository(this._db);

  final AppDriftDatabase _db;

  TasksDao get _dao => _db.tasksDao;

  Future<int> upsertTask({
    int? id,
    required String title,
    String? description,
    bool isCompleted = false,
    int priority = kPriorityMedium,
    int sortIndex = 0,
    DateTime? dueAtUtc,
    DateTime? reminderAtUtc,
    String? recurrenceRule,
    String? notificationId,
    int? noteId,
  }) {
    final companion = TasksCompanion(
      id: id == null ? const Value.absent() : Value(id),
      title: Value(title),
      description: Value(description),
      isCompleted: Value(isCompleted),
      priority: Value(priority),
      sortIndex: Value(sortIndex),
      dueAt: Value(dueAtUtc),
      reminderAt: Value(reminderAtUtc),
      recurrenceRule: Value(recurrenceRule),
      notificationId: Value(notificationId),
      noteId: Value(noteId),
      updatedAt: Value(DateTime.now().toUtc()),
    );
    return _dao.upsertTask(companion);
  }

  Future<List<Task>> allTasks() => _dao.allTasks();

  Future<Task?> getTask(int id) {
    return (_db.select(_db.tasks)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> reorderTasks(List<int> orderedIds) =>
      _dao.updateTasksOrder(orderedIds);

  Future<List<Task>> tasksForDayUtc(DateTime dayUtc) =>
      _dao.tasksForDay(dayUtc);

  Future<void> toggleComplete(int id, bool complete) =>
      _dao.toggleComplete(id, complete);

  Future<void> deleteTask(int id) => _dao.deleteTask(id);

  Future<int> addSubtask({
    required int taskId,
    required String title,
  }) {
    return _dao.insertSubtask(TaskSubtasksCompanion(
      taskId: Value(taskId),
      title: Value(title),
      sortIndex: const Value(0),
    ));
  }

  Future<void> reorderSubtasks(int taskId, List<int> orderedIds) =>
      _dao.updateSubtasksOrder(taskId, orderedIds);

  Future<void> replaceSubtasks(int taskId, List<String> titles) =>
      _dao.replaceSubtasks(taskId, titles);

  Future<List<TaskSubtask>> subtasksFor(int taskId) =>
      _dao.subtasksFor(taskId);

  Future<void> toggleSubtask(int id, bool complete) =>
      _dao.toggleSubtask(id, complete);
}
