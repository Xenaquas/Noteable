import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/local/databases/app_drift_database.dart';
import '../../view_models/di.dart';
import '../../view_models/search_vm.dart';
import '../note_editor/note_editor_screen.dart';
import '../tasks/task_editor_screen.dart';

final searchVmProvider = ChangeNotifierProvider<SearchViewModel>((ref) {
  return SearchViewModel(
    ref.read(noteRepoProvider),
    ref.read(taskRepoProvider),
  );
});

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(searchVmProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search notes and tasks...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              suffixIcon: vm.query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => ref.read(searchVmProvider).onQueryChanged(''),
                    ),
            ),
            onChanged: vm.onQueryChanged,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _filterChip(context, ref, SearchFilter.all, 'All'),
                _filterChip(context, ref, SearchFilter.notes, 'Notes'),
                _filterChip(context, ref, SearchFilter.tasks, 'Tasks'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: vm.loading
                  ? const _SearchSkeleton()
                  : vm.filtered.isEmpty && vm.query.trim().isNotEmpty
                      ? const _EmptyState()
                      : ListView.separated(
                          itemCount: vm.filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final item = vm.filtered[i];
                            return _SearchTile(item: item);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(
    BuildContext context,
    WidgetRef ref,
    SearchFilter value,
    String label,
  ) {
    final vm = ref.watch(searchVmProvider);
    return ChoiceChip(
      label: Text(label),
      selected: vm.filter == value,
      onSelected: (_) => ref.read(searchVmProvider).setFilter(value),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey.shade600),
          const SizedBox(height: 8),
          const Text('No matches'),
        ],
      ),
    );
  }
}

class _SearchSkeleton extends StatelessWidget {
  const _SearchSkeleton();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (_, i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: base.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      },
    );
  }
}

class _SearchTile extends ConsumerWidget {
  const _SearchTile({required this.item});

  final SearchResultItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        leading: CircleAvatar(
          backgroundColor: colors.primary.withValues(alpha: 0.12),
          child: Icon(
            item.type == SearchResultType.note ? Icons.note_alt : Icons.task_alt,
            color: colors.primary,
          ),
        ),
        title: Text(_title),
        subtitle: _subtitle(context),
        trailing: item.type == SearchResultType.note
            ? Chip(
                label: Text(item.note!.category),
                visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              )
            : _priorityChip(item.task!, colors),
        onTap: () {
          if (item.type == SearchResultType.note) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NoteEditorScreen(noteId: item.note!.id),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TaskEditorScreen(task: item.task!),
              ),
            );
          }
        },
      ),
    );
  }

  String get _title {
    if (item.type == SearchResultType.note) {
      final title = item.note!.title;
      return title.isEmpty ? 'Untitled' : title;
    }
    return item.task!.title;
  }

  Widget? _subtitle(BuildContext context) {
    if (item.type == SearchResultType.note) {
      final text = item.note!.contentPlain.trim();
      if (text.isEmpty) return const Text('Start writing...');
      final snippet = text.length > 120 ? '${text.substring(0, 120)}...' : text;
      return Text(
        snippet,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }

    final t = item.task!;
    final due = t.dueAt?.toLocal();
    final desc = t.description?.trim() ?? '';
    final parts = <String>[];
    if (desc.isNotEmpty) parts.add(desc);
    if (due != null) parts.add(_friendlyDate(context, due));
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _priorityChip(Task task, ColorScheme colors) {
    final label = switch (task.priority) {
      kPriorityHigh => 'High',
      kPriorityLow => 'Low',
      _ => 'Med',
    };
    final color = _priorityColor(task.priority, colors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
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
  if (diff == -1) return 'Yesterday, $time';
  if (diff.abs() <= 7) {
    final weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        [target.weekday - 1];
    return '$weekday, $time';
  }
  return '${target.year}/${target.month}/${target.day}, $time';
}
