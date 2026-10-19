import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/notification_sync_service.dart';
import '../../data/local/databases/app_drift_database.dart';
import '../../data/repositories/reminder_repository.dart';
import '../../data/repositories/task_repository.dart';
import 'di.dart';

enum TaskFilter { all, active, done, priority }
enum FocusSort { priority, due, updated }

class TasksViewModel extends ChangeNotifier {
  TasksViewModel(
    this._repo,
    this._reminderRepo,
    this._notificationSyncService,
  );

  final TaskRepository _repo;
  final ReminderRepository _reminderRepo;
  final NotificationSyncService _notificationSyncService;
  SharedPreferences? _prefs;
  static const _focusSortKey = 'focus_sort';

  bool _loading = false;
  bool get isLoading => _loading;

  List<Task> _tasks = [];
  List<Task> get allTasks => _tasks;
  List<Task> get tasks => _applyFilter(_tasks);
  bool get hasSearch => _search.trim().isNotEmpty;
  final Map<int, List<TaskSubtask>> _subtasks = {};
  List<TaskSubtask> subtasksFor(int id) => _subtasks[id] ?? const [];

  TaskFilter _filter = TaskFilter.all;
  TaskFilter get filter => _filter;

  String _search = '';
  String get search => _search;
  FocusSort _focusSort = FocusSort.priority;
  FocusSort get focusSort => _focusSort;

  final Set<int> _toggling = {};

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    final savedSort = _prefs!.getString(_focusSortKey);
    if (savedSort != null) {
      _focusSort = FocusSort.values
          .firstWhere((v) => v.name == savedSort, orElse: () => FocusSort.priority);
    }
    final list = await _repo.allTasks();
    _tasks = list;
    _subtasks.clear();
    for (final t in list) {
      _subtasks[t.id] = await _repo.subtasksFor(t.id);
    }
    _loading = false;
    notifyListeners();
  }

  void setFilter(TaskFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void setSearch(String value) {
    _search = value;
    notifyListeners();
  }

  Future<void> setFocusSort(FocusSort sort) async {
    if (_focusSort == sort) return;
    _focusSort = sort;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_focusSortKey, sort.name);
    notifyListeners();
  }

  List<Task> _applyFilter(List<Task> list) {
    Iterable<Task> view = list;
    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase();
      view = view.where(
        (t) =>
            t.title.toLowerCase().contains(q) ||
            (t.description ?? '').toLowerCase().contains(q),
      );
    }
    switch (_filter) {
      case TaskFilter.active:
        view = view.where((t) => !t.isCompleted);
        break;
      case TaskFilter.done:
        view = view.where((t) => t.isCompleted);
        break;
      case TaskFilter.priority:
        view = view.where((t) => t.priority == kPriorityHigh);
        break;
      case TaskFilter.all:
        break;
    }
    final sorted = view.toList()
      ..sort((a, b) {
        if (_filter == TaskFilter.priority) {
          final aRank = _dueRank(a.dueAt);
          final bRank = _dueRank(b.dueAt);
          if (aRank != bRank) return aRank.compareTo(bRank);
          if (a.dueAt != null && b.dueAt != null) {
            final dueCompare =
                a.dueAt!.toLocal().compareTo(b.dueAt!.toLocal());
            if (dueCompare != 0) return dueCompare;
          }
          final pr = a.priority.compareTo(b.priority);
          if (pr != 0) return pr;
          return b.updatedAt.compareTo(a.updatedAt);
        }

        final sort = a.sortIndex.compareTo(b.sortIndex);
        if (sort != 0) return sort;
        final pr = a.priority.compareTo(b.priority);
        if (pr != 0) return pr;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return sorted;
  }

  int _dueRank(DateTime? dueAt) {
    if (dueAt == null) return 4;
    final local = dueAt.toLocal();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final target = DateTime(
      local.year,
      local.month,
      local.day,
    );
    final diff = target.difference(todayDate).inDays;
    if (diff < 0) return 0; // overdue
    if (diff == 0) return 1; // today
    if (diff == 1) return 2; // tomorrow
    return 3; // future custom date
  }

  Future<int> addQuickTask(String title) async {
    final sortIndex = _tasks.length;
    final id = await _repo.upsertTask(
      title: title.trim(),
      description: null,
      sortIndex: sortIndex,
    );
    await load();
    return id;
  }

  Future<void> toggleComplete(Task task) async {
    await _repo.toggleComplete(task.id, !task.isCompleted);
    await load();
  }

  Future<bool> toggleCompleteSafe(Task task) async {
    if (_toggling.contains(task.id)) return false;
    _toggling.add(task.id);
    try {
      await toggleComplete(task);
      return true;
    } catch (_) {
      return false;
    } finally {
      _toggling.remove(task.id);
    }
  }

  Future<void> delete(Task task) async {
    await _cancelReminders(task.id);
    await _repo.deleteTask(task.id);
    await load();
  }

  Future<int> saveTask({
    int? id,
    required String title,
    String? description,
    DateTime? dueAt,
    DateTime? reminderAt,
    int priority = kPriorityMedium,
    int? noteId,
    List<String> subtasks = const [],
    bool isCompleted = false,
    int? sortIndex,
  }) async {
    final savedId = await _repo.upsertTask(
      id: id,
      title: title.trim(),
      description: description?.trim(),
      isCompleted: isCompleted,
      dueAtUtc: dueAt?.toUtc(),
      reminderAtUtc: reminderAt?.toUtc(),
      priority: priority,
      noteId: noteId,
      sortIndex: sortIndex ?? (id == null ? _tasks.length : 0),
    );

    // Manage reminders
    await _cancelReminders(savedId);
    if (reminderAt != null) {
      final reminderId = await _reminderRepo.insert(
        ownerType: 'task',
        ownerId: savedId,
        fireAtUtc: reminderAt.toUtc(),
      );
      await _notificationSyncService.scheduleReminder(
        Reminder(
          id: reminderId,
          ownerType: 'task',
          ownerId: savedId,
          fireAt: reminderAt.toUtc(),
          status: kReminderScheduled,
          notificationId: null,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
        title: 'Task due now',
        body: "Task '${title.trim()}' is due now!",
        tone: priority == kPriorityHigh
            ? ReminderTone.critical
            : ReminderTone.standard,
      );
    }

    if (subtasks.isNotEmpty) {
      await _repo.replaceSubtasks(savedId, subtasks);
    }

    await load();
    return savedId;
  }

  Future<void> reorderTasks(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final current = List<Task>.from(tasks);
    final item = current.removeAt(oldIndex);
    current.insert(newIndex, item);
    final orderedIds = current.map((t) => t.id).toList();
    await _repo.reorderTasks(orderedIds);
    await load();
  }

  Future<void> toggleSubtask(int subtaskId, bool value) async {
    await _repo.toggleSubtask(subtaskId, value);
    await load();
  }

  Future<void> markTasksComplete(List<Task> tasks) async {
    for (final t in tasks) {
      if (t.isCompleted) continue;
      await _repo.toggleComplete(t.id, true);
    }
    await load();
  }

  Future<void> _cancelReminders(int taskId) async {
    final reminders = await _reminderRepo.forOwner(ownerType: 'task', ownerId: taskId);
    for (final r in reminders) {
      final idInt = int.tryParse(r.notificationId ?? '') ?? r.id;
      await _notificationSyncService.cancelReminder(idInt);
      await _reminderRepo.delete(r.id);
    }
  }
}

final tasksVmProvider = ChangeNotifierProvider<TasksViewModel>((ref) {
  return TasksViewModel(
    ref.read(taskRepoProvider),
    ref.read(reminderRepoProvider),
    ref.read(notificationSyncServiceProvider),
  )..load();
});
