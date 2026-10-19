import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:sticky_headers/sticky_headers.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../data/local/databases/app_drift_database.dart';
import '../../view_models/tasks_vm.dart';
import '../../view_models/di.dart';
import 'task_editor_screen.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<int> _expandedTaskIds = {};
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = ref.read(tasksVmProvider).search;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(tasksVmProvider);
    final showCompleted = _showCompleted || vm.filter == TaskFilter.done;
    final visibleTasks = showCompleted
        ? vm.tasks
        : vm.tasks.where((t) => !t.isCompleted).toList();
    final groups = _buildGroups(visibleTasks, Theme.of(context).colorScheme);
    final allCount = vm.allTasks.length;
    final pendingCount = vm.allTasks.where((t) => !t.isCompleted).length;
    final doneCount = vm.allTasks.where((t) => t.isCompleted).length;
    final priorityCount =
        vm.allTasks.where((t) => t.priority == kPriorityHigh).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Reminders',
            onPressed: () => _showRemindersSheet(context, vm.allTasks),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const _AgendaScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (value) => ref.read(tasksVmProvider).setSearch(value),
                    decoration: InputDecoration(
                      hintText: 'Search tasks',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: vm.hasSearch
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchCtrl.clear();
                                ref.read(tasksVmProvider).setSearch('');
                              },
                            )
                          : null,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip(
                          label: 'All',
                          count: allCount,
                          selected: vm.filter == TaskFilter.all,
                          onSelected: () => ref.read(tasksVmProvider).setFilter(TaskFilter.all),
                        ),
                        _filterChip(
                          label: 'Pending',
                          count: pendingCount,
                          selected: vm.filter == TaskFilter.active,
                          onSelected: () =>
                              ref.read(tasksVmProvider).setFilter(TaskFilter.active),
                        ),
                        _filterChip(
                          label: 'Done',
                          count: doneCount,
                          selected: vm.filter == TaskFilter.done,
                          onSelected: () => ref.read(tasksVmProvider).setFilter(TaskFilter.done),
                        ),
                        _filterChip(
                          label: 'Priority',
                          count: priorityCount,
                          selected: vm.filter == TaskFilter.priority,
                          onSelected: () =>
                              ref.read(tasksVmProvider).setFilter(TaskFilter.priority),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Show completed',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(width: 6),
                      Switch.adaptive(
                        value: showCompleted,
                        onChanged: (value) =>
                            setState(() => _showCompleted = value),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: vm.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : visibleTasks.isEmpty
                      ? const _EmptyTasks()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          children: [
                            for (final group in groups) ...[
                              StickyHeader(
                                header: _SectionHeader(
                                  label: group.label,
                                  color: group.color,
                                ),
                                content: Column(
                                  children: [
                                    for (final task in group.tasks)
                                      _TaskTile(
                                        key: ValueKey(task.id),
                                        task: task,
                                        subtasks: vm.subtasksFor(task.id),
                                        isExpanded: _expandedTaskIds.contains(task.id),
                                        onToggleExpanded: () =>
                                            _toggleExpanded(task.id),
                                        onToggle: () async {
                                          HapticFeedback.lightImpact();
                                          await ref
                                              .read(tasksVmProvider)
                                              .toggleComplete(task);
                                        },
                                        onDelete: () async {
                                          HapticFeedback.heavyImpact();
                                          final confirmed =
                                              await _confirmDelete(context);
                                          if (confirmed) {
                                            await ref.read(tasksVmProvider).delete(task);
                                          }
                                        },
                                        onEdit: () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => TaskEditorScreen(task: task),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TaskEditorScreen()),
        ),
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('New Task'),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        label: Text('$label ($count)'),
        onSelected: (_) => onSelected(),
      ),
    );
  }

  void _showRemindersSheet(BuildContext context, List<Task> tasks) {
    final now = DateTime.now();
    final reminders = tasks
        .where((t) => !t.isCompleted && t.reminderAt != null)
        .toList()
      ..sort((a, b) => a.reminderAt!.compareTo(b.reminderAt!));
    final overdue =
        reminders.where((t) => t.reminderAt!.isBefore(now)).toList();
    final upcoming =
        reminders.where((t) => !t.reminderAt!.isBefore(now)).toList();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Reminders',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (reminders.isEmpty)
                const Text('No reminders set yet.')
              else ...[
                if (overdue.isNotEmpty) ...[
                  Text(
                    'Overdue',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  ...overdue.map((t) => _reminderTile(context, t)),
                  const SizedBox(height: 12),
                ],
                if (upcoming.isNotEmpty) ...[
                  Text(
                    'Upcoming',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  ...upcoming.map((t) => _reminderTile(context, t)),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _reminderTile(BuildContext context, Task task) {
    final label = _reminderLabel(context, task.reminderAt!.toLocal());
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.notifications_outlined),
      title: Text(task.title),
      subtitle: Text(label),
      onTap: () async {
        Navigator.of(context).pop();
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TaskEditorScreen(task: task),
          ),
        );
      },
    );
  }

  List<_TaskGroup> _buildGroups(List<Task> tasks, ColorScheme colors) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final overdue = <Task>[];
    final todayTasks = <Task>[];
    final upcoming = <Task>[];

    for (final task in tasks) {
      final due = task.dueAt?.toLocal();
      if (due == null) {
        upcoming.add(task);
        continue;
      }
      final dueDate = DateTime(due.year, due.month, due.day);
      if (dueDate.isBefore(today)) {
        overdue.add(task);
      } else if (dueDate == today) {
        todayTasks.add(task);
      } else {
        upcoming.add(task);
      }
    }

    final groups = [
      _TaskGroup(label: 'Overdue', color: colors.error, tasks: overdue),
      _TaskGroup(label: 'Today', color: colors.primary, tasks: todayTasks),
      _TaskGroup(
        label: 'Upcoming',
        color: colors.onSurfaceVariant,
        tasks: upcoming,
      ),
    ];
    return groups.where((g) => g.tasks.isNotEmpty).toList();
  }

  void _toggleExpanded(int taskId) {
    setState(() {
      if (_expandedTaskIds.contains(taskId)) {
        _expandedTaskIds.remove(taskId);
      } else {
        _expandedTaskIds.add(taskId);
      }
    });
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete task?'),
            content: const Text('This will remove the task permanently.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _TaskGroup {
  const _TaskGroup({
    required this.label,
    required this.color,
    required this.tasks,
  });

  final String label;
  final Color color;
  final List<Task> tasks;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _RoundCheckbox extends StatelessWidget {
  const _RoundCheckbox({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final borderColor = value ? colors.primary : colors.outline;
    final fillColor = value ? colors.primary : Colors.transparent;
    return InkWell(
      onTap: onChanged,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: fillColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 2),
        ),
        child: value
            ? Icon(Icons.check, size: 16, color: colors.onPrimary)
            : null,
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    this.subtasks = const [],
    required this.onToggleExpanded,
    required this.isExpanded,
  });

  final Task task;
  final Future<void> Function() onToggle;
  final Future<void> Function() onDelete;
  final VoidCallback onEdit;
  final List<TaskSubtask> subtasks;
  final VoidCallback onToggleExpanded;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dueLabel = task.dueAt == null
        ? null
        : _friendlyDate(context, task.dueAt!.toLocal());
    final extraSubtasks = subtasks.length > 2 ? subtasks.length - 2 : 0;
    final background = task.priority == kPriorityHigh
        ? Colors.red.withValues(alpha: 0.05)
        : colors.surfaceContainerLowest;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Slidable(
        key: key,
        startActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (_) => onEdit(),
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              icon: Icons.edit_outlined,
              label: 'Edit',
            ),
          ],
        ),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: colors.errorContainer,
              foregroundColor: colors.onErrorContainer,
              icon: Icons.delete_outline,
              label: 'Delete',
            ),
          ],
        ),
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RoundCheckbox(
                    value: task.isCompleted,
                    onChanged: onToggle,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                        ),
                        if (dueLabel != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            dueLabel,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                          ),
                        ],
                        if (isExpanded && task.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 6),
                          Text(
                            task.description!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (isExpanded && subtasks.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          ...subtasks.take(2).map(
                                (s) => Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Row(
                                    children: [
                                      Icon(
                                        s.isCompleted
                                            ? Icons.check_circle
                                            : Icons.circle_outlined,
                                        size: 14,
                                        color: colors.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          s.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          if (extraSubtasks > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              '+$extraSubtasks more',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  if (task.noteId != null) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.link, size: 16, color: Colors.blue),
                  ],
                ],
              ),
            ),
          ),
        ).animate().fadeIn(duration: 200.ms),
      ),
    );
  }
}

Widget priorityPill(int priority, ColorScheme colors) {
  final color = _priorityColor(priority, colors);
  final label = priority == kPriorityHigh
      ? 'High'
      : priority == kPriorityLow
          ? 'Low'
          : 'Med';
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

Color _priorityColor(int priority, ColorScheme colors) {
  switch (priority) {
    case kPriorityHigh:
      return colors.error;
    case kPriorityLow:
      return colors.primary;
    default:
      return colors.tertiary;
  }
}

String _friendlyDate(BuildContext context, DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = target.difference(today).inDays;
  final time = TimeOfDay.fromDateTime(date).format(context);
  if (diff == 0) return 'Today, $time';
  if (diff == 1) return 'Tomorrow, $time';
  if (diff == 7) return 'Next week, $time';
  return '${date.month}/${date.day}/${date.year}, $time';
}

String _reminderLabel(BuildContext context, DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = target.difference(today).inDays;
  final time = TimeOfDay.fromDateTime(date).format(context);
  if (diff == 0) return 'Reminder today, $time';
  if (diff == 1) return 'Reminder tomorrow, $time';
  if (diff == -1) return 'Reminder yesterday, $time';
  return 'Reminder ${date.month}/${date.day}/${date.year}, $time';
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checklist_rtl, size: 60, color: colors.primary),
          const SizedBox(height: 12),
          const Text('No tasks yet'),
          const SizedBox(height: 4),
          const Text('Tap + to add your first task'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TaskEditorScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add a task'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const _AgendaScreen()),
            ),
            icon: const Icon(Icons.calendar_today_outlined),
            label: const Text('Open Agenda'),
          ),
        ],
      ),
    );
  }
}

class _AgendaScreen extends ConsumerStatefulWidget {
  const _AgendaScreen();

  @override
  ConsumerState<_AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<_AgendaScreen> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(tasksVmProvider);
    final scheduleRepo = ref.read(scheduleRepoProvider);
    final events = _buildEvents(vm.tasks);

    return Scaffold(
      appBar: AppBar(title: const Text('Agenda')),
      body: Column(
        children: [
          TableCalendar(
            focusedDay: _focusedDay,
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2030),
            calendarFormat: CalendarFormat.month,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) => events[DateTime(day.year, day.month, day.day)] ?? [],
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
          ),
          Expanded(
            child: FutureBuilder(
              future: scheduleRepo.betweenUtc(
                DateTime.utc(_focusedDay.year, _focusedDay.month, 1),
                DateTime.utc(_focusedDay.year, _focusedDay.month + 1, 0),
              ),
              builder: (context, snapshot) {
                final schedules = snapshot.data ?? [];
                final dayKey = _selectedDay == null
                    ? DateTime.now()
                    : DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
                final dayTasks = events[dayKey] ?? [];
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Tasks', style: Theme.of(context).textTheme.titleMedium),
                    if (dayTasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No tasks for this day.'),
                      )
                    else
                      ...dayTasks.map(
                        (t) => ListTile(
                          title: Text(t.title),
                          subtitle: t.dueAt == null
                              ? null
                              : Text(_friendlyDate(context, t.dueAt!.toLocal())),
                          trailing:
                              priorityPill(t.priority, Theme.of(context).colorScheme),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text('Schedules', style: Theme.of(context).textTheme.titleMedium),
                    ...schedules
                        .where((s) =>
                            isSameDay(s.startAt.toLocal(),
                                _selectedDay ?? DateTime.now()))
                        .map(
                          (s) => ListTile(
                            title: Text(s.title),
                            subtitle: Text(
                              '${s.startAt.toLocal()}'
                              '${s.endAt == null ? '' : ' - ${s.endAt!.toLocal()}'}',
                            ),
                          ),
                        ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Map<DateTime, List<Task>> _buildEvents(List<Task> tasks) {
    final map = <DateTime, List<Task>>{};
    for (final t in tasks) {
      if (t.dueAt == null) continue;
      final key = DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day);
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
  }
}
