import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/local/databases/app_drift_database.dart';
import '../../../domain/entities/note_entity.dart';
import '../../view_models/di.dart';
import '../home/home_screen.dart';
import '../note_preview/note_preview_screen.dart';
import '../tasks/task_editor_screen.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  late Future<List<_NotificationItem>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _loadItems();
  }

  Future<List<_NotificationItem>> _loadItems() async {
    final reminderRepo = ref.read(reminderRepoProvider);
    final nowUtc = DateTime.now().toUtc();
    final reminders =
        await reminderRepo.dueUntilUtc(nowUtc.add(const Duration(days: 30)));
    final upcoming = reminders.where((r) => !r.fireAt.isBefore(nowUtc)).toList();
    if (upcoming.isEmpty) return [];

    final taskRepo = ref.read(taskRepoProvider);
    final scheduleRepo = ref.read(scheduleRepoProvider);
    final noteRepo = ref.read(noteRepoProvider);

    final tasks = await taskRepo.allTasks();
    final tasksById = {for (final t in tasks) t.id: t};

    final items = <_NotificationItem>[];
    for (final r in upcoming) {
      if (r.ownerType == 'task') {
        final task = tasksById[r.ownerId];
        if (task == null) continue;
        items.add(
          _NotificationItem(
            ownerType: 'task',
            ownerId: task.id,
            title: task.title.trim().isEmpty ? 'Task' : task.title.trim(),
            fireAt: r.fireAt.toLocal(),
            icon: Icons.check_circle_outline,
            task: task,
          ),
        );
      } else if (r.ownerType == 'note') {
        final note = await noteRepo.getNoteSummary(r.ownerId);
        if (note == null || note.id == null) continue;
        items.add(
          _NotificationItem(
            ownerType: 'note',
            ownerId: note.id!,
            title: _noteTitle(note),
            fireAt: r.fireAt.toLocal(),
            icon: Icons.description_outlined,
            note: note,
          ),
        );
      } else if (r.ownerType == 'schedule') {
        final schedule = await scheduleRepo.getSchedule(r.ownerId);
        if (schedule == null) continue;
        items.add(
          _NotificationItem(
            ownerType: 'schedule',
            ownerId: schedule.id,
            title: schedule.title.trim().isEmpty
                ? 'Schedule'
                : schedule.title.trim(),
            fireAt: r.fireAt.toLocal(),
            icon: Icons.event,
            schedule: schedule,
          ),
        );
      }
    }

    items.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return items;
  }

  String _noteTitle(NoteEntity note) {
    final title = note.title.trim();
    return title.isEmpty ? 'Untitled note' : title;
  }

  @override
  Widget build(BuildContext context) {
    final headline = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        );
    return Scaffold(
      appBar: AppBar(
        title: Text('Notification Center', style: headline),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: FutureBuilder<List<_NotificationItem>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              _InfoCard(),
              const SizedBox(height: 12),
              Text(
                'Upcoming reminders',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                ))
              else if (items.isEmpty)
                Text(
                  'No scheduled reminders.',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                ...items.map((item) => _ReminderTile(item: item)),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationItem {
  const _NotificationItem({
    required this.ownerType,
    required this.ownerId,
    required this.title,
    required this.fireAt,
    required this.icon,
    this.task,
    this.note,
    this.schedule,
  });

  final String ownerType;
  final int ownerId;
  final String title;
  final DateTime fireAt;
  final IconData icon;
  final Task? task;
  final NoteEntity? note;
  final Schedule? schedule;
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_active_outlined, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'In-app banners appear while the app is open. System '
              'notifications appear when the app is closed.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.item});

  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final time = DateFormat('MMM d • h:mm a').format(item.fireAt);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openItem(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.outlineVariant.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: colors.primary.withOpacity(0.12),
              child: Icon(item.icon, size: 18, color: colors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }

  void _openItem(BuildContext context) {
    if (item.ownerType == 'task') {
      final task = item.task;
      if (task != null) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TaskEditorScreen(task: task)),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HomeScreen(initialTabIndex: 2)),
        );
      }
      return;
    }
    if (item.ownerType == 'note') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NotePreviewScreen(
            noteId: item.ownerId,
          ),
        ),
      );
      return;
    }
    if (item.ownerType == 'schedule') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const HomeScreen(initialTabIndex: 3),
        ),
      );
    }
  }
}
