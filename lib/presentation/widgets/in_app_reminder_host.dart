import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/notification_sync_service.dart';
import '../../data/local/databases/app_drift_database.dart';
import '../../domain/entities/note_entity.dart';
import '../view_models/di.dart';
import '../view_models/tasks_vm.dart';
import '../views/home/home_screen.dart';
import '../views/note_preview/note_preview_screen.dart';
import '../views/tasks/task_editor_screen.dart';
import '../views/tasks/tasks_screen.dart';

class InAppReminderHost extends ConsumerStatefulWidget {
  const InAppReminderHost({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  ConsumerState<InAppReminderHost> createState() => _InAppReminderHostState();
}

class _InAppReminderHostState extends ConsumerState<InAppReminderHost>
    with WidgetsBindingObserver {
  StreamSubscription<ReminderAlert>? _alertSub;
  StreamSubscription<NotificationTap>? _tapSub;
  Timer? _hideTimer;
  ReminderAlert? _activeAlert;
  Task? _activeTask;
  NoteEntity? _activeNote;
  Schedule? _activeSchedule;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final service = ref.read(notificationSyncServiceProvider);
    service.enterForeground();
    _alertSub = service.foregroundAlerts.listen(_showAlert);
    _tapSub = service.tapEvents.listen(_handleTap);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _alertSub?.cancel();
    _tapSub?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final service = ref.read(notificationSyncServiceProvider);
    if (state == AppLifecycleState.resumed) {
      service.enterForeground();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      service.enterBackground();
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<void> _showAlert(ReminderAlert alert) async {
    Task? task;
    NoteEntity? note;
    Schedule? schedule;
    if (alert.ownerType == 'task') {
      task = await _findTask(alert.ownerId);
      if (task == null) return;
    } else if (alert.ownerType == 'note') {
      note = await _findNote(alert.ownerId);
      if (note == null) return;
    } else if (alert.ownerType == 'schedule') {
      schedule = await _findSchedule(alert.ownerId);
      if (schedule == null) return;
    } else {
      return;
    }
    if (!mounted) return;
    setState(() {
      _activeAlert = alert;
      _activeTask = task;
      _activeNote = note;
      _activeSchedule = schedule;
      _visible = true;
    });
    _resetAutoHide();
  }

  Future<void> _handleTap(NotificationTap tap) async {
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;
    if (tap.ownerType == 'task') {
      final task = await _findTask(tap.ownerId);
      if (task != null) {
        navigator.push(
          MaterialPageRoute(builder: (_) => TaskEditorScreen(task: task)),
        );
      } else {
        navigator.push(
          MaterialPageRoute(builder: (_) => const TasksScreen()),
        );
      }
      return;
    }
    if (tap.ownerType == 'note') {
      final note = await _findNote(tap.ownerId);
      if (note == null) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => NotePreviewScreen(
            noteId: note.id!,
            skipLockCheck: true,
          ),
        ),
      );
      return;
    }
    if (tap.ownerType == 'schedule') {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => const HomeScreen(initialTabIndex: 3),
        ),
      );
    }
  }

  Future<Task?> _findTask(int id) async {
    final vm = ref.read(tasksVmProvider);
    Task? task;
    for (final t in vm.allTasks) {
      if (t.id == id) {
        task = t;
        break;
      }
    }
    if (task == null) {
      await vm.load();
      for (final t in vm.allTasks) {
        if (t.id == id) {
          task = t;
          break;
        }
      }
    }
    return task;
  }

  Future<NoteEntity?> _findNote(int id) {
    return ref.read(noteRepoProvider).getNote(id);
  }

  Future<Schedule?> _findSchedule(int id) {
    return ref.read(scheduleRepoProvider).getSchedule(id);
  }

  void _resetAutoHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 7), _dismissBanner);
  }

  void _dismissBanner() {
    if (!mounted) return;
    setState(() => _visible = false);
  }

  Future<void> _markDone() async {
    final task = _activeTask;
    if (task == null) return;
    await ref.read(tasksVmProvider).toggleComplete(task);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task marked done.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    _dismissBanner();
  }

  Future<void> _snooze() async {
    final alert = _activeAlert;
    if (alert == null) return;
    final snoozeAt = DateTime.now().add(const Duration(minutes: 10));
    if (alert.ownerType == 'task') {
      final task = _activeTask;
      if (task == null) return;
      await ref.read(tasksVmProvider).saveTask(
            id: task.id,
            title: task.title,
            description: task.description,
            dueAt: task.dueAt?.toLocal(),
            reminderAt: snoozeAt,
            priority: task.priority,
            noteId: task.noteId,
            subtasks: const [],
            isCompleted: task.isCompleted,
            sortIndex: task.sortIndex,
          );
    } else if (alert.ownerType == 'note') {
      final note = _activeNote;
      if (note == null || note.id == null) return;
      await _scheduleSnooze(
        ownerType: 'note',
        ownerId: note.id!,
        fireAt: snoozeAt,
        title: 'Note due now',
        body: "Note '${_noteTitle(note)}' is due now!",
      );
    } else if (alert.ownerType == 'schedule') {
      final schedule = _activeSchedule;
      if (schedule == null) return;
      await ref.read(scheduleRepoProvider).upsertSchedule(
            id: schedule.id,
            title: schedule.title,
            description: schedule.description,
            startAtUtc: schedule.startAt,
            endAtUtc: schedule.endAt,
            isAllDay: schedule.isAllDay,
            recurrenceRule: schedule.recurrenceRule,
            reminderAtUtc: snoozeAt.toUtc(),
            notificationId: schedule.notificationId,
            noteId: schedule.noteId,
            location: schedule.location,
          );
      await _scheduleSnooze(
        ownerType: 'schedule',
        ownerId: schedule.id,
        fireAt: snoozeAt,
        title: 'Schedule reminder',
        body: "Schedule '${schedule.title}' starts now!",
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Snoozed for 10 minutes.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    _dismissBanner();
  }

  Future<void> _scheduleSnooze({
    required String ownerType,
    required int ownerId,
    required DateTime fireAt,
    required String title,
    required String body,
  }) async {
    final reminderId = await ref.read(reminderRepoProvider).insert(
          ownerType: ownerType,
          ownerId: ownerId,
          fireAtUtc: fireAt.toUtc(),
        );
    await ref.read(notificationSyncServiceProvider).scheduleReminder(
          Reminder(
            id: reminderId,
            ownerType: ownerType,
            ownerId: ownerId,
            fireAt: fireAt.toUtc(),
            status: kReminderScheduled,
            notificationId: null,
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
          title: title,
          body: body,
          tone: ReminderTone.standard,
        );
  }

  String _noteTitle(NoteEntity note) {
    final title = note.title.trim();
    return title.isEmpty ? 'Untitled note' : title;
  }

  String _scheduleTitle(Schedule schedule) {
    final title = schedule.title.trim();
    return title.isEmpty ? 'Schedule' : title;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final message = _buildMessage();
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          right: 12,
          child: IgnorePointer(
            ignoring: !_visible,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              offset: _visible ? Offset.zero : const Offset(0, -1),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _visible ? 1 : 0,
                child: Material(
                  elevation: 6,
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.notifications_active_outlined,
                                color: colors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            Semantics(
                              label: 'Dismiss',
                              button: true,
                              child: IconButton(
                                onPressed: _dismissBanner,
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ],
                        ),
                        _buildActions(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _buildMessage() {
    final alert = _activeAlert;
    if (alert == null) return '';
    if (alert.ownerType == 'task' && _activeTask != null) {
      final title = _activeTask!.title.trim().isEmpty
          ? 'Task'
          : _activeTask!.title.trim();
      return "Task '$title' is due now!";
    }
    if (alert.ownerType == 'note' && _activeNote != null) {
      return "Note '${_noteTitle(_activeNote!)}' is due now!";
    }
    if (alert.ownerType == 'schedule' && _activeSchedule != null) {
      return "Schedule '${_scheduleTitle(_activeSchedule!)}' starts now!";
    }
    return 'Reminder due now!';
  }

  Widget _buildActions() {
    if (_activeAlert == null) return const SizedBox.shrink();
    if (_activeAlert!.ownerType == 'task') {
      return Row(
        children: [
          TextButton(
            onPressed: _markDone,
            child: const Text('Mark Done'),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _snooze,
            child: const Text('Snooze'),
          ),
        ],
      );
    }
    if (_activeAlert!.ownerType == 'note' ||
        _activeAlert!.ownerType == 'schedule') {
      return Row(
        children: [
          TextButton(
            onPressed: _openFromBanner,
            child: const Text('Open'),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _snooze,
            child: const Text('Snooze'),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  void _openFromBanner() {
    final alert = _activeAlert;
    if (alert == null) return;
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;
    if (alert.ownerType == 'note' && _activeNote?.id != null) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => NotePreviewScreen(
            noteId: _activeNote!.id!,
            skipLockCheck: true,
          ),
        ),
      );
    } else if (alert.ownerType == 'schedule') {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => const HomeScreen(initialTabIndex: 3),
        ),
      );
    }
    _dismissBanner();
  }
}
