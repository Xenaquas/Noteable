import 'package:flutter/material.dart';

import '../../../../core/services/lock_service.dart';
import '../../../../core/services/note_authorization.dart';
import '../../../../domain/entities/attachment_entity.dart';
import '../../../../domain/entities/note_entity.dart';
import '../../note_preview/note_preview_screen.dart';

class VaultSession extends ChangeNotifier {
  VaultSession(this._authorization) {
    _authorization.addListener(notifyListeners);
  }
  final NoteAuthorization _authorization;
  bool _unlocked = false;

  bool get unlocked => _unlocked && _authorization.hasReadAccess;

  Future<bool> ensureUnlocked(
    BuildContext context,
    LockService lockService, {
    String reason = 'Unlock private space',
  }) async {
    final ok = await lockService.authorizeVault(context);
    if (ok) {
      _unlocked = true;
      notifyListeners();
    }
    return ok;
  }

  void relock() {
    _authorization.relock();
    _unlocked = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authorization.removeListener(notifyListeners);
    super.dispose();
  }
}

Future<void> showLockedNotesSheet({
  required BuildContext context,
  required VaultSession vaultSession,
  required List<NoteEntity> notes,
  required List<AttachmentEntity> Function(int?) attachmentsFor,
  VoidCallback? onOpenFullPage,
}) async {
  if (!vaultSession.unlocked) {
    return;
  }
  if (notes.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No locked notes yet.')),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      final controller = DraggableScrollableController();
      void maybeOpenFullPage() {
        if (onOpenFullPage == null) return;
        onOpenFullPage!();
      }

      controller.addListener(() {
        if (controller.size >= 0.95) {
          Navigator.of(ctx).maybePop();
          maybeOpenFullPage();
        }
      });

      return DraggableScrollableSheet(
        controller: controller,
        initialChildSize: 0.65,
        minChildSize: 0.45,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, controller) {
          final colors = Theme.of(context).colorScheme;
          final theme = Theme.of(context).textTheme;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(onPressed: vaultSession.relock,
                      tooltip: 'Relock private notes', icon: const Icon(Icons.lock)),
                    Text(
                      'Locked notes',
                      style: theme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            vaultSession.unlocked
                                ? Icons.lock_open_rounded
                                : Icons.lock_outline_rounded,
                            size: 16,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            vaultSession.unlocked ? 'Unlocked' : 'Locked',
                            style: theme.labelMedium?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    controller: controller,
                    itemCount: notes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      final attachments = attachmentsFor(note.id);
                      final updatedLabel =
                          _dateLabel(context, note.updatedAt.toLocal());
                      return _LockedNoteTile(
                        note: note,
                        attachments: attachments.length,
                        updatedLabel: updatedLabel,
                      );
                    },
                  ),
                ),
                if (onOpenFullPage != null) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton.icon(
                      onPressed: maybeOpenFullPage,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open full page'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}

class LockedNotesQuickCard extends StatelessWidget {
  const LockedNotesQuickCard({
    super.key,
    required this.lockedCount,
    required this.unlocked,
    required this.onTap,
  });

  final int lockedCount;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 230,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  unlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                  color: colors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Locked notes',
                      style: theme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lockedCount == 0
                          ? 'Tap to add privacy'
                          : '$lockedCount secured',
                      style: theme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockedNoteTile extends StatelessWidget {
  const _LockedNoteTile({
    required this.note,
    required this.attachments,
    required this.updatedLabel,
  });

  final NoteEntity note;
  final int attachments;
  final String updatedLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final title = note.title.trim().isEmpty ? 'Untitled note' : note.title;

    return ListTile(
      tileColor: colors.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withOpacity(0.3)),
      ),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.lock_outline, color: colors.primary),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 14, color: colors.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              updatedLabel,
              style: theme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.attachment, size: 14, color: colors.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              '$attachments',
              style: theme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      trailing: Icon(Icons.open_in_new, color: colors.onSurfaceVariant),
      onTap: () async {
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NotePreviewScreen(
              noteId: note.id!,
              heroTag: 'vault-note-${note.id}',
            ),
          ),
        );
      },
    );
  }
}

String _dateLabel(BuildContext context, DateTime date) {
  final localizations = MaterialLocalizations.of(context);
  final dateLabel = localizations.formatShortDate(date);
  final timeLabel = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date));
  return '$dateLabel, $timeLabel';
}
