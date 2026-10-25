import 'dart:math';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../data/local/databases/app_drift_database.dart';
import '../../../domain/entities/note_entity.dart';
import '../../view_models/di.dart';
import '../../view_models/tasks_vm.dart';
import '../note_preview/note_preview_screen.dart';
import '../tasks/task_editor_screen.dart';

class ScheduleTab extends ConsumerStatefulWidget {
  const ScheduleTab({super.key});

  @override
  ConsumerState<ScheduleTab> createState() => _ScheduleTabState();
}

enum _ScheduleViewMode { today, week }

class _ScheduleTabState extends ConsumerState<ScheduleTab> {
  static const int _startHour = 6;
  static const int _endHour = 22;
  static const double _hourHeight = 64;
  static const double _minBlockHeight = 44;

  late DateTime _focusedDay;
  late DateTime _selectedDay;
  Map<DateTime, List<Schedule>> _weekSchedules = {};
  Map<DateTime, List<_NoteReminder>> _weekNoteReminders = {};
  bool _loading = false;
  _ScheduleViewMode _viewMode = _ScheduleViewMode.today;
  bool _showSchedules = true;
  bool _showTasks = true;
  bool _showNotes = true;
  bool _showFocus = true;
  bool _hideCompletedTasks = true;
  int _rangeStartHour = _startHour;
  int _rangeEndHour = _endHour;
  final GlobalKey _timelineKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _dayKey(_focusedDay);
    _loadWeek(_focusedDay);
  }

  Future<void> _loadWeek(DateTime day) async {
    setState(() => _loading = true);
    final start = _startOfWeek(day);
    final end = start.add(const Duration(days: 7));
    final scheduleRepo = ref.read(scheduleRepoProvider);
    final reminderRepo = ref.read(reminderRepoProvider);
    final noteRepo = ref.read(noteRepoProvider);
    final results = await Future.wait([
      scheduleRepo.betweenUtc(start.toUtc(), end.toUtc()),
      reminderRepo.betweenUtc(
        startUtc: start.toUtc(),
        endUtc: end.toUtc(),
        ownerType: 'note',
      ),
    ]);
    final schedules = results[0] as List<Schedule>;
    final reminders = results[1] as List<Reminder>;
    final scheduleMap = <DateTime, List<Schedule>>{};
    for (final s in schedules) {
      final local = s.startAt.toLocal();
      final key = _dayKey(local);
      scheduleMap.putIfAbsent(key, () => []).add(s);
    }

    final noteIds = reminders.map((r) => r.ownerId).toSet().toList();
    final notes = await Future.wait(noteIds.map(noteRepo.getNote));
    final notesById = <int, NoteEntity>{};
    for (int i = 0; i < noteIds.length; i++) {
      final note = notes[i];
      if (note != null && note.id != null) {
        notesById[noteIds[i]] = note;
      }
    }
    final noteMap = <DateTime, List<_NoteReminder>>{};
    for (final r in reminders) {
      final note = notesById[r.ownerId];
      if (note == null) continue;
      final local = r.fireAt.toLocal();
      final key = _dayKey(local);
      noteMap
          .putIfAbsent(key, () => [])
          .add(_NoteReminder(note: note, fireAt: local));
    }
    for (final list in noteMap.values) {
      list.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    }
    if (!mounted) return;
    setState(() {
      _weekSchedules = scheduleMap;
      _weekNoteReminders = noteMap;
      _loading = false;
    });
  }

  DateTime _startOfWeek(DateTime day) {
    final local = _dayKey(day);
    final delta = local.weekday - DateTime.monday;
    return local.subtract(Duration(days: delta));
  }

  DateTime _dayKey(DateTime day) => DateTime(day.year, day.month, day.day);

  List<Schedule> _eventsForDay(DateTime day) {
    return _weekSchedules[_dayKey(day)] ?? const [];
  }

  List<Task> _tasksForDay(
    DateTime day,
    List<Task> tasks, {
    required bool includeCompleted,
  }) {
    final key = _dayKey(day);
    return tasks.where((t) {
      if (!includeCompleted && t.isCompleted) return false;
      final due = t.dueAt?.toLocal();
      if (due == null) return false;
      return _dayKey(due) == key;
    }).toList();
  }

  List<_NoteReminder> _noteRemindersForDay(DateTime day) {
    return _weekNoteReminders[_dayKey(day)] ?? const [];
  }

  _HourRange _hourRangeForItems(List<_AgendaItem> items) {
    if (items.isEmpty) {
      return const _HourRange(_startHour, _endHour);
    }
    int earliest = 23;
    int latest = 0;
    for (final item in items) {
      earliest = min(earliest, item.start.hour);
      latest = max(latest, item.end.hour);
    }
    var startHour = max(0, earliest - 1);
    var endHour = min(23, latest + 1);
    if (endHour <= startHour) {
      endHour = min(23, startHour + 1);
    }
    return _HourRange(startHour, endHour);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tasksVm = ref.watch(tasksVmProvider);
    final allTasks = tasksVm.allTasks;
    final daySchedules =
        _showSchedules ? _eventsForDay(_selectedDay) : const <Schedule>[];
    final dayTasks = _showTasks
        ? _tasksForDay(
            _selectedDay,
            allTasks,
            includeCompleted: !_hideCompletedTasks,
          )
        : const <Task>[];
    final focusTasks = _tasksForDay(
      _selectedDay,
      allTasks,
      includeCompleted: false,
    );
    final dayNotes =
        _showNotes ? _noteRemindersForDay(_selectedDay) : const <_NoteReminder>[];
    final timelineItems = _buildTimelineItems(
      schedules: daySchedules,
      tasks: dayTasks,
      notes: dayNotes,
      includeFocus: _showFocus,
      focusTasks: focusTasks,
    );
    final range = _hourRangeForItems(timelineItems);
    _rangeStartHour = range.start;
    _rangeEndHour = range.end;
    final calendarEvents = (DateTime day) {
      final events = <Object>[];
      if (_showSchedules) {
        events.addAll(_eventsForDay(day));
      }
      if (_showTasks) {
        events.addAll(
          _tasksForDay(
            day,
            allTasks,
            includeCompleted: !_hideCompletedTasks,
          ),
        );
      }
      if (_showNotes) {
        events.addAll(_noteRemindersForDay(day));
      }
      return events;
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                'Schedule',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              SegmentedButton<_ScheduleViewMode>(
                segments: const [
                  ButtonSegment(
                    value: _ScheduleViewMode.today,
                    label: Text('Today'),
                    icon: Icon(Icons.today_outlined),
                  ),
                  ButtonSegment(
                    value: _ScheduleViewMode.week,
                    label: Text('Week'),
                    icon: Icon(Icons.calendar_view_week_outlined),
                  ),
                ],
                selected: {_viewMode},
                onSelectionChanged: (value) {
                  setState(() {
                    _viewMode = value.first;
                    if (_viewMode == _ScheduleViewMode.today) {
                      final now = DateTime.now();
                      _selectedDay = _dayKey(now);
                      _focusedDay = _selectedDay;
                    }
                  });
                  _loadWeek(_focusedDay);
                },
              ),
            ],
          ),
        ),
        _SummaryStrip(
          date: _selectedDay,
          schedules: daySchedules,
          tasks: dayTasks,
          notes: dayNotes,
          focusCount: timelineItems
              .where((i) => i.type == _AgendaItemType.focus)
              .length,
          nextLabel: _nextUpcomingLabel(
            context,
            daySchedules,
            dayTasks,
            dayNotes,
            timelineItems,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LegendChip(
                label: 'Schedules',
                color: colors.primary,
                selected: _showSchedules,
                onSelected: (v) => setState(() => _showSchedules = v),
              ),
              _LegendChip(
                label: 'Tasks',
                color: colors.secondary,
                selected: _showTasks,
                onSelected: (v) => setState(() => _showTasks = v),
              ),
              _LegendChip(
                label: 'Notes',
                color: colors.tertiary,
                selected: _showNotes,
                onSelected: (v) => setState(() => _showNotes = v),
              ),
              _LegendChip(
                label: 'Focus',
                color: colors.primaryContainer,
                selected: _showFocus,
                onSelected: (v) => setState(() => _showFocus = v),
                filled: true,
              ),
              FilterChip(
                label: const Text('Hide completed'),
                selected: _hideCompletedTasks,
                onSelected: (v) =>
                    setState(() => _hideCompletedTasks = v),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TableCalendar(
            focusedDay: _focusedDay,
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2030),
            calendarFormat: CalendarFormat.week,
            availableGestures: _viewMode == _ScheduleViewMode.week
                ? AvailableGestures.horizontalSwipe
                : AvailableGestures.none,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              leftChevronVisible: false,
              rightChevronVisible: false,
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: colors.onSurfaceVariant),
              weekendStyle: TextStyle(color: colors.onSurfaceVariant),
            ),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: calendarEvents,
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return const SizedBox.shrink();
                final markers = <Color>[];
                for (final e in events) {
                  if (e is Schedule) {
                    markers.add(colors.primary);
                  } else if (e is Task) {
                    markers.add(
                      e.priority == kPriorityHigh
                          ? colors.error
                          : colors.secondary,
                    );
                  } else if (e is _NoteReminder) {
                    markers.add(colors.tertiary);
                  }
                }
                final unique = <Color>[];
                for (final c in markers) {
                  if (unique.contains(c)) continue;
                  unique.add(c);
                }
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final c in unique.take(3))
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          width: 6,
                          height: 6,
                          decoration:
                              BoxDecoration(color: c, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                );
              },
            ),
            enabledDayPredicate: _viewMode == _ScheduleViewMode.week
                ? null
                : (day) => isSameDay(day, _selectedDay),
            onDaySelected: (selectedDay, focusedDay) {
              if (_viewMode != _ScheduleViewMode.week) return;
              setState(() {
                _selectedDay = _dayKey(selectedDay);
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              if (_viewMode != _ScheduleViewMode.week) return;
              _focusedDay = focusedDay;
              _loadWeek(focusedDay);
            },
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              todayDecoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: TextStyle(color: colors.onPrimary),
              markerSize: 5,
              markerDecoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 3,
              markerMargin: const EdgeInsets.symmetric(horizontal: 1.5),
            ),
          ),
        ),
        Expanded(
          child: PageTransitionSwitcher(
            duration: const Duration(milliseconds: 240),
            transitionBuilder: (child, animation, secondaryAnimation) {
              return SharedAxisTransition(
                animation: animation,
                secondaryAnimation: secondaryAnimation,
                transitionType: SharedAxisTransitionType.horizontal,
                child: child,
              );
            },
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _ScheduleDayView(
                    key: ValueKey(_dayKey(_selectedDay)),
                    schedules: daySchedules,
                    timelineItems: timelineItems,
                    timelineKey: _timelineKey,
                    selectedDay: _selectedDay,
                    startHour: _rangeStartHour,
                    endHour: _rangeEndHour,
                    onDrop: _handleDrop,
                    onItemTap: _showDetails,
                    onQuickAdd: _showQuickAddSheet,
                    onResize: _handleResize,
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleDrop(Schedule schedule, Offset globalOffset) async {
    final box = _timelineKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalOffset);
    final durationMinutes = _durationMinutes(schedule);
    final maxStartMinutes =
        max(0, ((_rangeEndHour - _rangeStartHour + 1) * 60) - durationMinutes);
    final rawMinutes = (local.dy / _hourHeight * 60).round();
    final snappedMinutes = (rawMinutes / 15).round() * 15;
    final clampedMinutes = snappedMinutes.clamp(0, maxStartMinutes);
    final startBase = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      _rangeStartHour,
    );
    final newStartLocal = startBase.add(Duration(minutes: clampedMinutes));
    await _reschedule(schedule, newStartLocal);
    if (!mounted) return;
    final time = TimeOfDay.fromDateTime(newStartLocal).format(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Rescheduled to $time'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  int _durationMinutes(Schedule schedule) {
    final start = schedule.startAt.toLocal();
    final end = schedule.endAt?.toLocal();
    if (end != null && end.isAfter(start)) {
      return max(15, end.difference(start).inMinutes);
    }
    return 30;
  }

  Future<void> _reschedule(Schedule schedule, DateTime newStartLocal) async {
    final startLocal = schedule.startAt.toLocal();
    final duration = Duration(minutes: _durationMinutes(schedule));
    final newEndLocal = newStartLocal.add(duration);
    final delta = newStartLocal.difference(startLocal);
    final reminderAtUtc = schedule.reminderAt == null
        ? null
        : schedule.reminderAt!.toLocal().add(delta).toUtc();
    await ref.read(scheduleRepoProvider).upsertSchedule(
          id: schedule.id,
          title: schedule.title,
          description: schedule.description,
          startAtUtc: newStartLocal.toUtc(),
          endAtUtc: newEndLocal.toUtc(),
          isAllDay: schedule.isAllDay,
          recurrenceRule: schedule.recurrenceRule,
          reminderAtUtc: reminderAtUtc,
          notificationId: schedule.notificationId,
          noteId: schedule.noteId,
          location: schedule.location,
        );
    await _loadWeek(_focusedDay);
  }

  List<_AgendaItem> _buildTimelineItems({
    required List<Schedule> schedules,
    required List<Task> tasks,
    required List<_NoteReminder> notes,
    required bool includeFocus,
    required List<Task> focusTasks,
  }) {
    final items = <_AgendaItem>[];
    for (final s in schedules) {
      if (s.isAllDay) continue;
      final title = s.title.trim().isEmpty ? 'Schedule' : s.title.trim();
      final start = s.startAt.toLocal();
      final end =
          (s.endAt?.toLocal()) ?? start.add(const Duration(minutes: 30));
      items.add(
        _AgendaItem(
          type: _AgendaItemType.schedule,
          title: title,
          start: start,
          end: end,
          idSeed: s.id,
          schedule: s,
        ),
      );
    }
    for (final t in tasks) {
      final due = t.dueAt?.toLocal();
      if (due == null) continue;
      final title = t.title.trim().isEmpty ? 'Task' : t.title.trim();
      items.add(
        _AgendaItem(
          type: _AgendaItemType.task,
          title: title,
          start: due,
          end: due.add(const Duration(minutes: 30)),
          idSeed: t.id,
          task: t,
        ),
      );
    }
    for (final n in notes) {
      final title = n.note.title.trim().isEmpty
          ? 'Note'
          : n.note.title.trim();
      items.add(
        _AgendaItem(
          type: _AgendaItemType.note,
          title: title,
          start: n.fireAt,
          end: n.fireAt.add(const Duration(minutes: 20)),
          idSeed: n.note.id ?? n.fireAt.millisecondsSinceEpoch,
          noteReminder: n,
        ),
      );
    }

    if (includeFocus) {
      items.addAll(_buildFocusBlocks(schedules, focusTasks));
    }

    items.sort((a, b) => a.start.compareTo(b.start));
    return _applyConflicts(items);
  }

  List<_AgendaItem> _buildFocusBlocks(
    List<Schedule> schedules,
    List<Task> tasks,
  ) {
    final focusItems = <_AgendaItem>[];
    final highPriority = tasks
        .where((t) => t.priority == kPriorityHigh && !t.isCompleted)
        .toList();
    if (highPriority.isEmpty) return focusItems;

    final busy = <_TimeRange>[];
    for (final s in schedules) {
      if (s.isAllDay) continue;
      final start = s.startAt.toLocal();
      final end = (s.endAt?.toLocal()) ??
          start.add(const Duration(minutes: 30));
      busy.add(_TimeRange(start, end));
    }

    final dayStart =
        DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, 9);
    final dayEnd =
        DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, 17);
    const blockDuration = Duration(minutes: 60);

    for (final task in highPriority.take(2)) {
      DateTime cursor = dayStart;
      DateTime? slotStart;
      while (cursor.add(blockDuration).isBefore(dayEnd) ||
          cursor.add(blockDuration).isAtSameMomentAs(dayEnd)) {
        final candidate = _TimeRange(cursor, cursor.add(blockDuration));
        final overlaps = busy.any((b) => b.overlaps(candidate));
        if (!overlaps) {
          slotStart = cursor;
          break;
        }
        cursor = cursor.add(const Duration(minutes: 30));
      }
      if (slotStart != null) {
        final focusStart = slotStart;
        final focusEnd = focusStart.add(blockDuration);
        busy.add(_TimeRange(focusStart, focusEnd));
        focusItems.add(
          _AgendaItem(
            type: _AgendaItemType.focus,
            title: 'Focus: ${task.title.trim().isEmpty ? 'Task' : task.title.trim()}',
            start: focusStart,
            end: focusEnd,
            idSeed: task.id * 1000 + focusStart.minute,
            task: task,
          ),
        );
      }
    }
    return focusItems;
  }

  List<_AgendaItem> _applyConflicts(List<_AgendaItem> items) {
    final scheduleItems =
        items.where((i) => i.type == _AgendaItemType.schedule).toList();
    final conflicted = <int>{};
    for (int i = 0; i < scheduleItems.length; i++) {
      for (int j = i + 1; j < scheduleItems.length; j++) {
        final a = scheduleItems[i];
        final b = scheduleItems[j];
        if (a.overlaps(b)) {
          conflicted.add(a.idSeed);
          conflicted.add(b.idSeed);
        }
      }
    }
    if (conflicted.isEmpty) return items;
    return items
        .map(
          (item) => item.type == _AgendaItemType.schedule &&
                  conflicted.contains(item.idSeed)
              ? item.copyWith(hasConflict: true)
              : item,
        )
        .toList();
  }

  String _nextUpcomingLabel(
    BuildContext context,
    List<Schedule> schedules,
    List<Task> tasks,
    List<_NoteReminder> notes,
    List<_AgendaItem> items,
  ) {
    if (items.isEmpty) return 'No upcoming items';
    final now = DateTime.now();
    final isToday = _dayKey(now) == _selectedDay;
    final upcoming = items.where((i) {
      if (!isToday) return true;
      return i.start.isAfter(now);
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    if (upcoming.isEmpty) return 'No upcoming items';
    final next = upcoming.first;
    final time = TimeOfDay.fromDateTime(next.start).format(context);
    return 'Next: $time · ${next.title}';
  }

  Future<void> _showQuickAddSheet(DateTime startLocal) async {
    final result = await showModalBottomSheet<_QuickAddResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _QuickAddScheduleSheet(initialStart: startLocal),
    );
    if (result == null) return;
    final startUtc = result.isAllDay
        ? DateTime.utc(
            result.start.year,
            result.start.month,
            result.start.day,
          )
        : result.start.toUtc();
    final endUtc = result.isAllDay
        ? DateTime.utc(
            result.start.year,
            result.start.month,
            result.start.day,
          ).add(const Duration(days: 1))
        : result.start.add(result.duration).toUtc();
    await ref.read(scheduleRepoProvider).upsertSchedule(
          title: result.title.trim(),
          description: null,
          startAtUtc: startUtc,
          endAtUtc: endUtc,
          isAllDay: result.isAllDay,
          location: result.location?.trim().isEmpty == true
              ? null
              : result.location?.trim(),
        );
    await _loadWeek(_focusedDay);
  }

  Future<void> _handleResize(Schedule schedule, double dragDy) async {
    final startLocal = schedule.startAt.toLocal();
    final currentEnd =
        schedule.endAt?.toLocal() ?? startLocal.add(const Duration(minutes: 30));
    final deltaMinutes = (dragDy / _hourHeight * 60).round();
    final snappedMinutes = (deltaMinutes / 15).round() * 15;
    var newEndLocal = currentEnd.add(Duration(minutes: snappedMinutes));
    final minEnd = startLocal.add(const Duration(minutes: 15));
    if (newEndLocal.isBefore(minEnd)) {
      newEndLocal = minEnd;
    }
    await ref.read(scheduleRepoProvider).upsertSchedule(
          id: schedule.id,
          title: schedule.title,
          description: schedule.description,
          startAtUtc: schedule.startAt,
          endAtUtc: newEndLocal.toUtc(),
          isAllDay: schedule.isAllDay,
          recurrenceRule: schedule.recurrenceRule,
          reminderAtUtc: schedule.reminderAt,
          notificationId: schedule.notificationId,
          noteId: schedule.noteId,
          location: schedule.location,
        );
    await _loadWeek(_focusedDay);
  }

  void _showDetails(BuildContext context, _AgendaItem item) {
    final outerContext = context;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;
        if (item.type == _AgendaItemType.schedule) {
          final schedule = item.schedule!;
          final title = schedule.title.trim().isEmpty
              ? 'Schedule'
              : schedule.title.trim();
          final start = schedule.startAt.toLocal();
          final end = schedule.endAt?.toLocal();
          final timeLabel = end == null
              ? TimeOfDay.fromDateTime(start).format(sheetContext)
              : '${TimeOfDay.fromDateTime(start).format(sheetContext)} - '
                  '${TimeOfDay.fromDateTime(end).format(sheetContext)}';
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 16),
                    const SizedBox(width: 6),
                    Text(timeLabel),
                  ],
                ),
                if (schedule.location?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(schedule.location!.trim())),
                    ],
                  ),
                ],
                if (schedule.description?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Text(
                    schedule.description!.trim(),
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (schedule.noteId != null)
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          Navigator.of(outerContext).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  NotePreviewScreen(noteId: schedule.noteId!),
                            ),
                          );
                        },
                        icon: const Icon(Icons.link),
                        label: const Text('Linked note'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final note = await _pickNote(sheetContext);
                        if (note == null || note.id == null) return;
                        await _linkScheduleNote(schedule, note.id);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                      icon: const Icon(Icons.edit_note_outlined),
                      label: Text(
                        schedule.noteId == null
                            ? 'Link note'
                            : 'Change link',
                      ),
                    ),
                    if (schedule.noteId != null)
                      TextButton(
                        onPressed: () async {
                          await _linkScheduleNote(schedule, null);
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                        child: Text(
                          'Unlink',
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        }
        if (item.type == _AgendaItemType.task) {
          final task = item.task!;
          final due = task.dueAt?.toLocal();
          final timeLabel = due == null
              ? 'No due time'
              : TimeOfDay.fromDateTime(due).format(sheetContext);
          final priorityLabel = _priorityLabel(task.priority);
          final priorityColor = _priorityColor(task.priority, colors);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title.trim().isEmpty ? 'Task' : task.title.trim(),
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.flag_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      priorityLabel,
                      style: TextStyle(color: priorityColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 16),
                    const SizedBox(width: 6),
                    Text(timeLabel),
                  ],
                ),
                if (task.description?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Text(
                    task.description!.trim(),
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(outerContext).push(
                          MaterialPageRoute(
                            builder: (_) => TaskEditorScreen(task: task),
                          ),
                        );
                      },
                      icon: const Icon(Icons.task_alt),
                      label: const Text('Open task'),
                    ),
                    if (task.noteId != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          Navigator.of(outerContext).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  NotePreviewScreen(noteId: task.noteId!),
                            ),
                          );
                        },
                        icon: const Icon(Icons.link),
                        label: const Text('Linked note'),
                      ),
                  ],
                ),
              ],
            ),
          );
        }

        if (item.type == _AgendaItemType.focus) {
          final task = item.task;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.center_focus_strong, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${TimeOfDay.fromDateTime(item.start).format(sheetContext)} - '
                      '${TimeOfDay.fromDateTime(item.end).format(sheetContext)}',
                    ),
                  ],
                ),
                if (task != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(outerContext).push(
                        MaterialPageRoute(
                          builder: (_) => TaskEditorScreen(task: task),
                        ),
                      );
                    },
                    icon: const Icon(Icons.task_alt),
                    label: const Text('Open task'),
                  ),
                ],
              ],
            ),
          );
        }

        final noteReminder = item.noteReminder!;
        final note = noteReminder.note;
        final timeLabel =
            TimeOfDay.fromDateTime(noteReminder.fireAt).format(sheetContext);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title.trim().isEmpty ? 'Note' : note.title.trim(),
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.notifications_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('Reminder at $timeLabel'),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(outerContext).push(
                    MaterialPageRoute(
                      builder: (_) => NotePreviewScreen(
                        noteId: note.id!,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.note_alt_outlined),
                label: const Text('Open note'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _priorityLabel(int priority) {
    if (priority == kPriorityHigh) return 'Critical';
    if (priority == kPriorityLow) return 'Low priority';
    return 'Standard priority';
  }

  Color _priorityColor(int priority, ColorScheme colors) {
    if (priority == kPriorityHigh) return colors.error;
    if (priority == kPriorityLow) return colors.primary;
    return colors.tertiary;
  }

  Future<void> _linkScheduleNote(Schedule schedule, int? noteId) async {
    await ref.read(scheduleRepoProvider).upsertSchedule(
          id: schedule.id,
          title: schedule.title,
          description: schedule.description,
          startAtUtc: schedule.startAt,
          endAtUtc: schedule.endAt,
          isAllDay: schedule.isAllDay,
          recurrenceRule: schedule.recurrenceRule,
          reminderAtUtc: schedule.reminderAt,
          notificationId: schedule.notificationId,
          noteId: noteId,
          location: schedule.location,
        );
    await _loadWeek(_focusedDay);
  }

  Future<NoteEntity?> _pickNote(BuildContext context) {
    return showModalBottomSheet<NoteEntity>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _NotePickerSheet(),
    );
  }
}

class _ScheduleDayView extends StatelessWidget {
  const _ScheduleDayView({
    super.key,
    required this.schedules,
    required this.timelineItems,
    required this.timelineKey,
    required this.selectedDay,
    required this.startHour,
    required this.endHour,
    required this.onDrop,
    required this.onItemTap,
    required this.onQuickAdd,
    required this.onResize,
  });

  final List<Schedule> schedules;
  final List<_AgendaItem> timelineItems;
  final GlobalKey timelineKey;
  final DateTime selectedDay;
  final int startHour;
  final int endHour;
  final void Function(Schedule, Offset) onDrop;
  final void Function(BuildContext, _AgendaItem) onItemTap;
  final void Function(DateTime startLocal) onQuickAdd;
  final void Function(Schedule schedule, double dragDy) onResize;

  static const double _hourHeight = _ScheduleTabState._hourHeight;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final allDay = schedules.where((s) => s.isAllDay).toList();
    final totalHours = (endHour - startHour + 1).clamp(1, 24);

    if (allDay.isEmpty && timelineItems.isEmpty) {
      return Center(
        child: Text(
          'No agenda for this day',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      children: [
        if (allDay.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('All Day', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                _AllDayRow(items: allDay),
              ],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              height: totalHours * _hourHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 56,
                    child: Column(
                      children: [
                        for (int i = 0; i < totalHours; i++)
                          SizedBox(
                            height: _hourHeight,
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Text(
                                _hourLabel(context, startHour + i),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPressStart: (details) =>
                          _handleQuickAdd(details.globalPosition, totalHours),
                      child: DragTarget<Schedule>(
                        onAcceptWithDetails: (details) =>
                            onDrop(details.data, details.offset),
                        builder: (context, _, __) {
                          return Container(
                            key: timelineKey,
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color:
                                    colors.outlineVariant.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Stack(
                              children: [
                                for (int i = 0; i < totalHours; i++)
                                  Positioned(
                                    top: i * _hourHeight,
                                    left: 0,
                                    right: 0,
                                    child: Divider(
                                      height: 1,
                                      color: colors.outlineVariant
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                for (final item in timelineItems)
                                  _TimelineBlock(
                                    item: item,
                                    color: _itemColor(item, colors),
                                    startHour: startHour,
                                    hourHeight: _hourHeight,
                                    onTap: () => onItemTap(context, item),
                                    onResize: item.schedule == null
                                        ? null
                                        : (dy) => onResize(item.schedule!, dy),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _hourLabel(BuildContext context, int hour) {
    final time = TimeOfDay(hour: hour, minute: 0);
    return time.format(context);
  }

  Color _itemColor(_AgendaItem item, ColorScheme colors) {
    if (item.type == _AgendaItemType.task) {
      final task = item.task;
      if (task != null && task.priority == kPriorityHigh) {
        return colors.errorContainer;
      }
      return colors.secondaryContainer;
    }
    if (item.type == _AgendaItemType.note) {
      return colors.tertiaryContainer;
    }
    if (item.type == _AgendaItemType.focus) {
      return colors.surfaceContainerHigh;
    }
    final palette = [
      colors.primaryContainer,
      colors.secondaryContainer,
      colors.tertiaryContainer,
    ];
    return palette[item.idSeed % palette.length];
  }

  void _handleQuickAdd(Offset globalOffset, int totalHours) {
    final box = timelineKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalOffset);
    final maxMinutes = max(0, (totalHours * 60) - 15);
    final rawMinutes = (local.dy / _hourHeight * 60).round();
    final snappedMinutes = (rawMinutes / 15).round() * 15;
    final clampedMinutes = snappedMinutes.clamp(0, maxMinutes);
    final base = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
      startHour,
    );
    final start = base.add(Duration(minutes: clampedMinutes));
    onQuickAdd(start);
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.date,
    required this.schedules,
    required this.tasks,
    required this.notes,
    required this.focusCount,
    required this.nextLabel,
  });

  final DateTime date;
  final List<Schedule> schedules;
  final List<Task> tasks;
  final List<_NoteReminder> notes;
  final int focusCount;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dateLabel = MaterialLocalizations.of(context).formatMediumDate(date);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _CountChip(
                  label: 'Schedules',
                  count: schedules.length,
                  color: colors.primary,
                ),
                _CountChip(
                  label: 'Tasks',
                  count: tasks.length,
                  color: colors.secondary,
                ),
                _CountChip(
                  label: 'Notes',
                  count: notes.length,
                  color: colors.tertiary,
                ),
                _CountChip(
                  label: 'Focus',
                  count: focusCount,
                  color: colors.primaryContainer,
                  filled: true,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.upcoming_outlined,
                    size: 16, color: colors.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    nextLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.count,
    required this.color,
    this.filled = false,
  });

  final String label;
  final int count;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
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
            '$label $count',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onSelected,
    this.filled = false,
  });

  final String label;
  final Color color;
  final bool selected;
  final bool filled;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: onSelected,
      avatar: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

enum _AgendaItemType { schedule, task, note, focus }

class _AgendaItem {
  const _AgendaItem({
    required this.type,
    required this.title,
    required this.start,
    required this.end,
    required this.idSeed,
    this.hasConflict = false,
    this.schedule,
    this.task,
    this.noteReminder,
  });

  final _AgendaItemType type;
  final String title;
  final DateTime start;
  final DateTime end;
  final int idSeed;
  final bool hasConflict;
  final Schedule? schedule;
  final Task? task;
  final _NoteReminder? noteReminder;

  bool overlaps(_AgendaItem other) =>
      start.isBefore(other.end) && end.isAfter(other.start);

  _AgendaItem copyWith({
    bool? hasConflict,
  }) {
    return _AgendaItem(
      type: type,
      title: title,
      start: start,
      end: end,
      idSeed: idSeed,
      hasConflict: hasConflict ?? this.hasConflict,
      schedule: schedule,
      task: task,
      noteReminder: noteReminder,
    );
  }
}

class _NoteReminder {
  const _NoteReminder({
    required this.note,
    required this.fireAt,
  });

  final NoteEntity note;
  final DateTime fireAt;
}

class _TimeRange {
  _TimeRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  bool overlaps(_TimeRange other) =>
      start.isBefore(other.end) && end.isAfter(other.start);
}

class _TimelineBlock extends StatelessWidget {
  const _TimelineBlock({
    required this.item,
    required this.color,
    required this.startHour,
    required this.hourHeight,
    required this.onTap,
    this.onResize,
  });

  final _AgendaItem item;
  final Color color;
  final int startHour;
  final double hourHeight;
  final VoidCallback onTap;
  final void Function(double dragDy)? onResize;

  static const double _minBlockHeight = _ScheduleTabState._minBlockHeight;

  @override
  Widget build(BuildContext context) {
    final start = item.start;
    final end = item.end;
    final dayStart =
        DateTime(start.year, start.month, start.day, startHour);
    final duration =
        end.isAfter(start) ? end.difference(start) : const Duration(minutes: 30);
    final totalMinutes = duration.inMinutes;
    final minutesFromStart = max(0, start.difference(dayStart).inMinutes);
    final top = minutesFromStart / 60 * hourHeight;
    final height =
        max(_minBlockHeight, totalMinutes / 60 * hourHeight);
    final title = item.title;
    final foreground = _foregroundColor(context);
    final border = item.type == _AgendaItemType.focus
        ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1)
        : BorderSide.none;

    final content = _BlockContent(
      title: title,
      timeLabel: _timeLabel(context),
      color: color,
      height: height,
      isDragging: false,
      icon: _itemIcon(),
      typeLabel: _typeLabel(),
      textColor: foreground,
      borderSide: border,
    );

    double dragDy = 0;
    final block = SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(child: content),
          if (item.hasConflict)
            Positioned(
              top: 6,
              right: 8,
              child: Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          if (onResize != null)
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (_) => dragDy = 0,
                  onVerticalDragUpdate: (details) =>
                      dragDy += details.delta.dy,
                  onVerticalDragEnd: (_) {
                    if (dragDy.abs() >= 4) {
                      onResize?.call(dragDy);
                    }
                    dragDy = 0;
                  },
                  child: Container(
                    width: 36,
                    height: 6,
                    decoration: BoxDecoration(
                      color: foreground.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return Positioned(
      top: top,
      left: 8,
      right: 8,
      child: item.type == _AgendaItemType.schedule
          ? LongPressDraggable<Schedule>(
              data: item.schedule!,
              axis: Axis.vertical,
              feedback: _BlockContent(
                title: title,
                timeLabel: _timeLabel(context),
                color: color.withValues(alpha: 0.9),
                height: height,
                isDragging: true,
                icon: _itemIcon(),
                typeLabel: _typeLabel(),
                textColor: foreground,
                borderSide: border,
              ),
              childWhenDragging: Opacity(
                opacity: 0.2,
                child: block,
              ),
              child: GestureDetector(
                onTap: onTap,
                child: block,
              ),
            )
          : GestureDetector(
              onTap: onTap,
              child: block,
            ),
    );
  }

  String _timeLabel(BuildContext context) {
    final startLabel = TimeOfDay.fromDateTime(item.start).format(context);
    if ((item.type == _AgendaItemType.schedule ||
            item.type == _AgendaItemType.focus) &&
        item.end.isAfter(item.start)) {
      final endLabel = TimeOfDay.fromDateTime(item.end).format(context);
      return '$startLabel - $endLabel';
    }
    return startLabel;
  }

  IconData _itemIcon() {
    if (item.type == _AgendaItemType.task) {
      final task = item.task;
      if (task != null && task.priority == kPriorityHigh) {
        return Icons.warning_amber_rounded;
      }
      return Icons.check_circle_outline;
    }
    if (item.type == _AgendaItemType.note) {
      return Icons.note_alt_outlined;
    }
    if (item.type == _AgendaItemType.focus) {
      return Icons.center_focus_strong;
    }
    return Icons.event;
  }

  String _typeLabel() {
    switch (item.type) {
      case _AgendaItemType.task:
        return 'Task';
      case _AgendaItemType.note:
        return 'Note';
      case _AgendaItemType.focus:
        return 'Focus';
      case _AgendaItemType.schedule:
        return 'Schedule';
    }
  }

  Color _foregroundColor(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (item.type == _AgendaItemType.task) {
      final task = item.task;
      if (task != null && task.priority == kPriorityHigh) {
        return colors.onErrorContainer;
      }
      return colors.onSecondaryContainer;
    }
    if (item.type == _AgendaItemType.note) {
      return colors.onTertiaryContainer;
    }
    if (item.type == _AgendaItemType.focus) {
      return colors.onSurface;
    }
    return colors.onPrimaryContainer;
  }
}

class _BlockContent extends StatelessWidget {
  const _BlockContent({
    required this.title,
    required this.timeLabel,
    required this.color,
    required this.height,
    required this.isDragging,
    required this.icon,
    required this.typeLabel,
    required this.textColor,
    required this.borderSide,
  });

  final String title;
  final String timeLabel;
  final Color color;
  final double height;
  final bool isDragging;
  final IconData icon;
  final String typeLabel;
  final Color textColor;
  final BorderSide borderSide;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      elevation: isDragging ? 6 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: borderSide,
      ),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 60;
            final tight = constraints.maxHeight < 48;
            final padding = compact
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
                : const EdgeInsets.all(10);
            final titleLines = tight ? 1 : (compact ? 2 : 2);
            return Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!compact)
                    Row(
                      children: [
                        Icon(icon, size: 14, color: textColor),
                        const SizedBox(width: 6),
                        Text(
                          typeLabel,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: textColor.withValues(alpha: 0.9),
                                  ),
                        ),
                      ],
                    ),
                  if (!compact) const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: titleLines,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                  ),
                  if (!tight) ...[
                    const SizedBox(height: 4),
                    Text(
                      timeLabel,
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: textColor.withValues(alpha: 0.8),
                              ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HourRange {
  const _HourRange(this.start, this.end);

  final int start;
  final int end;
}

class _AllDayRow extends StatelessWidget {
  const _AllDayRow({required this.items});

  final List<Schedule> items;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxChips =
            max(1, (constraints.maxWidth / 140).floor());
        final visibleCount = min(maxChips, items.length);
        final remaining = items.length - visibleCount;
        return Row(
          children: [
            for (int i = 0; i < visibleCount; i++) ...[
              _AllDayChip(
                label: items[i].title.trim().isEmpty
                    ? 'Schedule'
                    : items[i].title.trim(),
              ),
              if (i != visibleCount - 1) const SizedBox(width: 8),
            ],
            if (remaining > 0) ...[
              if (visibleCount > 0) const SizedBox(width: 8),
              ActionChip(
                label: Text('+$remaining more'),
                backgroundColor: colors.surfaceContainerHighest,
                onPressed: () => _showAllDaySheet(context, items),
              ),
            ],
          ],
        );
      },
    );
  }

  void _showAllDaySheet(BuildContext context, List<Schedule> items) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            Text(
              'All day',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            for (final s in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(
                  s.title.trim().isEmpty ? 'Schedule' : s.title.trim(),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AllDayChip extends StatelessWidget {
  const _AllDayChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Chip(
      label: Text(label, overflow: TextOverflow.ellipsis),
      backgroundColor: colors.primaryContainer.withValues(alpha: 0.6),
    );
  }
}

class _QuickAddResult {
  const _QuickAddResult({
    required this.title,
    required this.start,
    required this.duration,
    required this.isAllDay,
    required this.location,
  });

  final String title;
  final DateTime start;
  final Duration duration;
  final bool isAllDay;
  final String? location;
}

class _QuickAddScheduleSheet extends StatefulWidget {
  const _QuickAddScheduleSheet({required this.initialStart});

  final DateTime initialStart;

  @override
  State<_QuickAddScheduleSheet> createState() => _QuickAddScheduleSheetState();
}

class _QuickAddScheduleSheetState extends State<_QuickAddScheduleSheet> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController();
  late DateTime _start;
  bool _allDay = false;
  int _durationMinutes = 30;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      _start = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _start.hour,
        _start.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (picked == null) return;
    setState(() {
      _start = DateTime(
        _start.year,
        _start.month,
        _start.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _save() {
    final title =
        _titleCtrl.text.trim().isEmpty ? 'Schedule' : _titleCtrl.text.trim();
    Navigator.of(context).pop(
      _QuickAddResult(
        title: title,
        start: _start,
        duration: Duration(minutes: _durationMinutes),
        isAllDay: _allDay,
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          top: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick add',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                hintText: 'Title',
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _locationCtrl,
              decoration: InputDecoration(
                hintText: 'Location (optional)',
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(
                      MaterialLocalizations.of(context).formatMediumDate(_start),
                    ),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 8),
                if (!_allDay)
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule_outlined),
                      title: Text(
                        TimeOfDay.fromDateTime(_start).format(context),
                      ),
                      onTap: _pickTime,
                    ),
                  ),
              ],
            ),
            Row(
              children: [
                Switch.adaptive(
                  value: _allDay,
                  onChanged: (v) => setState(() => _allDay = v),
                ),
                const SizedBox(width: 8),
                Text(
                  'All day',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (!_allDay) ...[
              Text(
                'Duration',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final minutes in const [30, 60, 90, 120])
                    ChoiceChip(
                      selected: _durationMinutes == minutes,
                      label: Text('${minutes}m'),
                      onSelected: (_) =>
                          setState(() => _durationMinutes = minutes),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Add schedule'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotePickerSheet extends ConsumerStatefulWidget {
  const _NotePickerSheet();

  @override
  ConsumerState<_NotePickerSheet> createState() => _NotePickerSheetState();
}

class _NotePickerSheetState extends ConsumerState<_NotePickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  Future<List<NoteEntity>>? _notesFuture;

  @override
  void initState() {
    super.initState();
    _notesFuture = _loadNotes('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<NoteEntity>> _loadNotes(String query) {
    final repo = ref.read(noteRepoProvider);
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return repo.listNotes();
    }
    return repo.searchNotes(trimmed);
  }

  void _onSearchChanged(String value) {
    setState(() {
      _notesFuture = _loadNotes(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search notes',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.trim().isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchCtrl.clear();
                              _onSearchChanged('');
                            },
                          ),
                    filled: true,
                    fillColor: colors.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<NoteEntity>>(
                  future: _notesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Unable to load notes.'),
                      );
                    }
                    final notes = snapshot.data ?? [];
                    if (notes.isEmpty) {
                      return Center(
                        child: Text(
                          _searchCtrl.text.trim().isEmpty
                              ? 'No notes yet.'
                              : 'No matching notes.',
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: notes.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        final title = note.title.trim().isEmpty
                            ? 'Untitled note'
                            : note.title.trim();
                        return ListTile(
                          leading: const Icon(Icons.note_alt_outlined),
                          title: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.pop(context, note),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
