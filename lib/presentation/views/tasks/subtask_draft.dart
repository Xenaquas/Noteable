part of 'task_editor_screen.dart';

class _SubtaskDraft {
  final String title;
  final bool completed;

  _SubtaskDraft({required this.title, this.completed = false});

  _SubtaskDraft copyWith({String? title, bool? completed}) => _SubtaskDraft(
        title: title ?? this.title,
        completed: completed ?? this.completed,
      );
}
