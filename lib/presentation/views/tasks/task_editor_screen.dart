import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/databases/app_drift_database.dart';
import '../../../domain/entities/note_entity.dart';
import '../../view_models/tasks_vm.dart';
import '../../widgets/canvas_scaffold.dart';
import '../note_preview/note_preview_screen.dart';
import '../../view_models/di.dart';
part 'subtask_draft.dart';

class TaskEditorScreen extends ConsumerStatefulWidget {
  const TaskEditorScreen({super.key, this.task});

  final Task? task;

  @override
  ConsumerState<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends ConsumerState<TaskEditorScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _dueAt;
  DateTime? _reminderAt;
  int _priority = kPriorityMedium;
  int? _noteId;
  NoteEntity? _linkedNote;
  bool _isCompleted = false;
  bool _showMore = false;
  final List<_SubtaskDraft> _subtasks = [];

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    if (t != null) {
      _titleCtrl.text = t.title;
      _descCtrl.text = t.description ?? '';
      _dueAt = t.dueAt?.toLocal();
      _reminderAt = t.reminderAt?.toLocal();
      _priority = t.priority;
      _noteId = t.noteId;
      _isCompleted = t.isCompleted;
      _loadSubtasks(t.id);
      _loadLinkedNote();
    }
  }

  Future<void> _loadSubtasks(int taskId) async {
    final repo = ref.read(taskRepoProvider);
    final list = await repo.subtasksFor(taskId);
    if (mounted) {
      setState(() {
        _subtasks
          ..clear()
          ..addAll(
            list.map(
              (e) => _SubtaskDraft(
                title: e.title,
                completed: e.isCompleted,
              ),
            ),
          );
      });
    }
  }

  Future<void> _loadLinkedNote() async {
    final id = _noteId;
    if (id == null) return;
    final note = await ref.read(noteRepoProvider).getNote(id);
    if (mounted) {
      setState(() {
        _linkedNote = note;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CanvasScaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'New Task' : 'Edit Task'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleCtrl,
                  decoration: _pillInputDecoration(context, label: 'Title'),
                ),
                if (_noteId != null) ...[
                  const SizedBox(height: 8),
                  _linkedNoteCard(context),
                ],
                const SizedBox(height: 8),
                _linkNoteAction(context),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  decoration: _pillInputDecoration(
                    context,
                    label: 'Description',
                  ),
                  maxLines: null,
                  minLines: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Schedule',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Due date',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                _actionChipRow(
                  context,
                  [
                    _dateActionChip(
                      context,
                      label: 'Today',
                      selected: _presetFor(_dueAt) == _DatePreset.today,
                      onPressed: () => _setDuePreset(_DatePreset.today),
                    ),
                    _dateActionChip(
                      context,
                      label: 'Tomorrow',
                      selected: _presetFor(_dueAt) == _DatePreset.tomorrow,
                      onPressed: () => _setDuePreset(_DatePreset.tomorrow),
                    ),
                    _dateActionChip(
                      context,
                      label: 'Next Week',
                      selected: _presetFor(_dueAt) == _DatePreset.nextWeek,
                      onPressed: () => _setDuePreset(_DatePreset.nextWeek),
                    ),
                    _dateActionChip(
                      context,
                      label: _customChipLabel(
                        _presetFor(_dueAt) == _DatePreset.custom ? _dueAt : null,
                        includeTime: false,
                      ),
                      selected: _presetFor(_dueAt) == _DatePreset.custom,
                      onPressed: _pickDueSheet,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _showMore = !_showMore),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'More',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const Spacer(),
                        Icon(
                          _showMore
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: _showMore
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            Text(
                              'Reminder',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 6),
                            _actionChipRow(
                              context,
                              [
                                _dateActionChip(
                                  context,
                                  label: 'Today',
                                  selected:
                                      _presetFor(_reminderAt) ==
                                          _DatePreset.today,
                                  onPressed: () => _setReminderPreset(
                                    _DatePreset.today,
                                  ),
                                ),
                                _dateActionChip(
                                  context,
                                  label: 'Tomorrow',
                                  selected:
                                      _presetFor(_reminderAt) ==
                                          _DatePreset.tomorrow,
                                  onPressed: () => _setReminderPreset(
                                    _DatePreset.tomorrow,
                                  ),
                                ),
                                _dateActionChip(
                                  context,
                                  label: 'Next Week',
                                  selected:
                                      _presetFor(_reminderAt) ==
                                          _DatePreset.nextWeek,
                                  onPressed: () => _setReminderPreset(
                                    _DatePreset.nextWeek,
                                  ),
                                ),
                                _dateActionChip(
                                  context,
                                  label: _customChipLabel(
                                    _presetFor(_reminderAt) ==
                                            _DatePreset.custom
                                        ? _reminderAt
                                        : null,
                                    includeTime: true,
                                  ),
                                  selected:
                                      _presetFor(_reminderAt) ==
                                          _DatePreset.custom,
                                  onPressed: _pickReminderSheet,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Priority',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                _priorityChoice(
                                  'High',
                                  kPriorityHigh,
                                  colors.error,
                                ),
                                _priorityChoice(
                                  'Medium',
                                  kPriorityMedium,
                                  colors.tertiary,
                                ),
                                _priorityChoice(
                                  'Low',
                                  kPriorityLow,
                                  colors.primary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Subtasks',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _subtasks.length,
                              onReorder: (oldIndex, newIndex) {
                                setState(() {
                                  if (newIndex > oldIndex) newIndex -= 1;
                                  final item = _subtasks.removeAt(oldIndex);
                                  _subtasks.insert(newIndex, item);
                                });
                              },
                              itemBuilder: (context, index) {
                                final sub = _subtasks[index];
                                return Dismissible(
                                  key: ValueKey('sub-${sub.title}-$index'),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    color: colors.errorContainer,
                                    child: Icon(
                                      Icons.delete,
                                      color: colors.onErrorContainer,
                                    ),
                                  ),
                                  onDismissed: (_) {
                                    setState(() {
                                      _subtasks.removeAt(index);
                                    });
                                  },
                                  child: ListTile(
                                    key: ValueKey('subtile-$index'),
                                    dense: true,
                                    leading: Checkbox(
                                      value: sub.completed,
                                      onChanged: (v) => setState(
                                        () => _subtasks[index] =
                                            sub.copyWith(
                                          completed: v ?? false,
                                        ),
                                      ),
                                    ),
                                    title: Text(sub.title),
                                    trailing:
                                        const Icon(Icons.drag_handle),
                                  ),
                                );
                              },
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final title = await _promptSubtask();
                                if (title != null &&
                                    title.trim().isNotEmpty) {
                                  setState(
                                    () => _subtasks.add(
                                      _SubtaskDraft(
                                        title: title.trim(),
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add subtask'),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ],
      bottomBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _isCompleted = !_isCompleted),
                icon: Icon(
                  _isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                ),
                label: Text(_isCompleted ? 'Mark undone' : 'Mark done'),
              ),
              Wrap(
                spacing: 8,
                children: [
                  IconButton(
                    tooltip: 'Due date',
                    onPressed: _pickDueSheet,
                    icon: const Icon(Icons.event_outlined),
                  ),
                  IconButton(
                    tooltip: 'Reminder',
                    onPressed: _pickReminderSheet,
                    icon: const Icon(Icons.notifications_outlined),
                  ),
                  IconButton(
                    tooltip: 'Priority',
                    onPressed: () => _showPrioritySheet(colors),
                    icon: const Icon(Icons.flag_outlined),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _pillInputDecoration(
    BuildContext context, {
    required String label,
  }) {
    final colors = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
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
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.primary, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  Widget _linkedNoteCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = _linkedNote == null
        ? 'Linked note'
        : _noteChipLabel(_linkedNote!);
    return Material(
      color: colors.primaryContainer.withOpacity(0.3),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _noteId == null
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NotePreviewScreen(
                      noteId: _noteId!,
                      skipLockCheck: true,
                    ),
                  ),
                );
              },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colors.primary.withOpacity(0.5),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.description, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() {
                  _linkedNote = null;
                  _noteId = null;
                }),
                tooltip: 'Unlink note',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linkNoteAction(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: const Icon(Icons.link, size: 18),
      label: Text(_linkedNote == null ? 'Link note' : 'Change note'),
      onPressed: _pickNote,
      backgroundColor: colors.surfaceContainerHighest,
      shape: const StadiumBorder(),
      labelStyle: TextStyle(color: colors.onSurfaceVariant),
    );
  }

  Widget _actionChipRow(BuildContext context, List<Widget> chips) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            chips[i],
          ],
        ],
      ),
    );
  }

  Widget _dateActionChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    final colors = Theme.of(context).colorScheme;
    final selectedColor = Colors.blue;
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? selectedColor : colors.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      backgroundColor: selected
          ? selectedColor.withOpacity(0.15)
          : colors.surfaceContainerHighest,
      side: BorderSide(
        color: selected
            ? selectedColor.withOpacity(0.5)
            : colors.outlineVariant.withOpacity(0.4),
      ),
      shape: const StadiumBorder(),
      onPressed: onPressed,
    );
  }

  _DatePreset? _presetFor(DateTime? date) {
    if (date == null) return null;
    final now = DateTime.now();
    if (_isSameDay(date, now)) return _DatePreset.today;
    if (_isSameDay(date, now.add(const Duration(days: 1)))) {
      return _DatePreset.tomorrow;
    }
    if (_isSameDay(date, now.add(const Duration(days: 7)))) {
      return _DatePreset.nextWeek;
    }
    return _DatePreset.custom;
  }

  void _setDuePreset(_DatePreset preset) {
    if (preset == _DatePreset.custom) {
      _pickDueSheet();
      return;
    }
    final now = DateTime.now();
    final base = _dueAt ?? now;
    final target = _presetDate(preset, now);
    setState(() {
      _dueAt = DateTime(
        target.year,
        target.month,
        target.day,
        base.hour,
        base.minute,
      );
    });
  }

  void _setReminderPreset(_DatePreset preset) {
    if (preset == _DatePreset.custom) {
      _pickReminderSheet();
      return;
    }
    final now = DateTime.now();
    final base = _reminderAt ?? now;
    final target = _presetDate(preset, now);
    setState(() {
      _reminderAt = DateTime(
        target.year,
        target.month,
        target.day,
        base.hour,
        base.minute,
      );
    });
  }

  DateTime _presetDate(_DatePreset preset, DateTime now) {
    switch (preset) {
      case _DatePreset.today:
        return now;
      case _DatePreset.tomorrow:
        return now.add(const Duration(days: 1));
      case _DatePreset.nextWeek:
        return now.add(const Duration(days: 7));
      case _DatePreset.custom:
        return now;
    }
  }

  String _customChipLabel(DateTime? date, {required bool includeTime}) {
    if (date == null) return 'Custom';
    final dateLabel = _shortDate(date);
    if (!includeTime) return 'Custom - $dateLabel';
    final time = TimeOfDay.fromDateTime(date).format(context);
    return 'Custom - $dateLabel $time';
  }

  String _noteChipLabel(NoteEntity note) {
    final title = note.title.trim();
    return title.isEmpty ? 'Untitled note' : title;
  }

  String _shortDate(DateTime date) => '${date.month}/${date.day}';

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _priorityChoice(String label, int value, Color color) {
    final selected = _priority == value;
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      selectedColor: color.withValues(alpha: 0.18),
      labelStyle: TextStyle(color: selected ? color : null),
      onSelected: (_) => setState(() => _priority = value),
    );
  }

  Future<void> _pickNote() async {
    final selected = await showModalBottomSheet<NoteEntity>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _NotePickerSheet(),
    );
    final id = selected?.id;
    if (id != null) {
      setState(() {
        _noteId = id;
        _linkedNote = selected;
      });
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title required')),
      );
      return;
    }
    await ref.read(tasksVmProvider).saveTask(
          id: widget.task?.id,
          title: _titleCtrl.text,
          description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
          dueAt: _dueAt,
          reminderAt: _reminderAt,
          priority: _priority,
          noteId: _noteId,
          subtasks: _subtasks.map((s) => s.title).toList(),
          isCompleted: _isCompleted,
          sortIndex: widget.task?.sortIndex,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickDueSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return _DatePickerSheet(
          initial: _dueAt,
          onSelect: (d) => setState(() => _dueAt = d),
        );
      },
    );
  }

  Future<void> _pickReminderSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return _DatePickerSheet(
          initial: _reminderAt,
          includeTime: true,
          onSelect: (d) => setState(() => _reminderAt = d),
        );
      },
    );
  }

  void _showPrioritySheet(ColorScheme colors) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.flag, color: colors.error),
              title: const Text('High'),
              onTap: () {
                setState(() => _priority = kPriorityHigh);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.flag, color: colors.tertiary),
              title: const Text('Medium'),
              onTap: () {
                setState(() => _priority = kPriorityMedium);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.flag, color: colors.primary),
              title: const Text('Low'),
              onTap: () {
                setState(() => _priority = kPriorityLow);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptSubtask() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add subtask'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Subtask title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

enum _DatePreset { today, tomorrow, nextWeek, custom }

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
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                      return const Center(child: Text('Unable to load notes.'));
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

class _DatePickerSheet extends StatefulWidget {
  const _DatePickerSheet({
    required this.onSelect,
    this.initial,
    this.includeTime = false,
  });

  final DateTime? initial;
  final bool includeTime;
  final void Function(DateTime?) onSelect;

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 10,
            children: [
              _quickChip('Today', now),
              _quickChip('Tomorrow', now.add(const Duration(days: 1))),
              _quickChip('Next week', now.add(const Duration(days: 7))),
            ],
          ),
          TextButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selected ?? now,
                firstDate: now.subtract(const Duration(days: 1)),
                lastDate: now.add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => _selected = picked);
              }
            },
            icon: const Icon(Icons.calendar_month),
            label: Text(
              _selected == null
                  ? 'Pick a date'
                  : 'Picked: ${_selected!.month}/${_selected!.day}/${_selected!.year}',
            ),
          ),
          if (widget.includeTime)
            TextButton.icon(
              onPressed: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null && _selected != null) {
                  setState(() {
                    _selected = DateTime(
                      _selected!.year,
                      _selected!.month,
                      _selected!.day,
                      time.hour,
                      time.minute,
                    );
                  });
                }
              },
              icon: const Icon(Icons.schedule),
              label: Text(
                _selected == null
                    ? 'Pick time'
                    : 'Time: ${TimeOfDay.fromDateTime(_selected!).format(context)}',
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  widget.onSelect(null);
                  Navigator.pop(context);
                },
                child: const Text('Clear'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  widget.onSelect(_selected);
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickChip(String label, DateTime date) {
    final selected = _selected != null &&
        _selected!.year == date.year &&
        _selected!.month == date.month &&
        _selected!.day == date.day;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selected = date),
    );
  }
}

String _friendlyDate(BuildContext context, DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = target.difference(today).inDays;
  final time = TimeOfDay.fromDateTime(date).format(context);
  if (diff == 0) return 'Due today, $time';
  if (diff == 1) return 'Due tomorrow, $time';
  if (diff == 7) return 'Due next week, $time';
  return 'Due ${date.month}/${date.day}/${date.year}, $time';
}
