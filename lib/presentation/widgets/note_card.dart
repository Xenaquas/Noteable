import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/attachment_entity.dart';
import '../../domain/entities/note_entity.dart';

class NoteCard extends StatelessWidget {
  final NoteEntity note;
  final List<AttachmentEntity> attachments;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String category;
  final DateTime updatedAt;
  final bool isList;
  final String? heroTag;
  final String? backgroundImagePath;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.category,
    required this.updatedAt,
    this.attachments = const [],
    this.onLongPress,
    this.isList = false,
    this.heroTag,
    this.backgroundImagePath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = note.title.trim().isEmpty ? 'Untitled' : note.title.trim();
    final preview = note.contentPlain.trim().isEmpty
        ? 'Start writing...'
        : note.contentPlain.trim();
    final accent = theme.colorScheme.primary;
    final locked = note.isLocked;
    final borderRadius = BorderRadius.circular(isList ? 16 : 18);
    final colors = theme.colorScheme;
    final cardColor = colors.surfaceContainerHighest;
    final shadow = Colors.black.withValues(alpha: isList ? 0.06 : 0.08);

    final hasImage = backgroundImagePath != null && backgroundImagePath!.isNotEmpty;
    final imageFile = hasImage ? File(backgroundImagePath!) : null;
    final dateLabel = DateFormat('MMM d').format(updatedAt);

    // List view layout - horizontal compact design
    final content = isList
        ? Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Thumbnail / fallback icon
                if (hasImage && imageFile != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Image.file(
                        imageFile,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.image_not_supported_outlined,
                          color: colors.onSurfaceVariant,
                          size: 28,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(
                      Icons.folder_open_outlined,
                      color: colors.primary,
                      size: 30,
                    ),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (note.isPinned)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(Icons.push_pin, size: 16, color: accent),
                            ),
                          const SizedBox(width: 6),
                          _CategoryChip(label: category, compact: true),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _AttachmentRow(
                        attachments: attachments,
                        updatedAt: updatedAt,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        // Grid view layout - vertical card design
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (note.isPinned)
                      Icon(Icons.push_pin, size: 18, color: accent),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  locked ? 'Unlock to view content' : preview,
                  maxLines: locked ? 2 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: locked ? Colors.grey.shade500 : null,
                  ),
                ),
              ),
              if (attachments.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: _AttachmentStrip(attachments: attachments),
                ),
              ],
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: 0.2),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          _CategoryChip(label: category, compact: false),
                          const Spacer(),
                          Icon(Icons.calendar_month,
                              size: 14, color: colors.onSurface),
                          const SizedBox(width: 4),
                          Text(
                            dateLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );

    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: borderRadius,
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: hasImage && !isList ? Colors.black : cardColor,
                borderRadius: borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: shadow,
                    blurRadius: isList ? 12 : 18,
                    offset: Offset(0, isList ? 6 : 12),
                  ),
                ],
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.35),
                ),
                image: imageFile != null && !isList
                    ? DecorationImage(
                        image: FileImage(imageFile),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withValues(
                            alpha:
                                theme.brightness == Brightness.dark ? 0.55 : 0.35,
                          ),
                          BlendMode.darken,
                        ),
                      )
                    : null,
              ),
              child: content,
            ),
            if (locked)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      color: colors.surface.withValues(alpha: 0.1),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline, color: accent, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            'Locked Note',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (heroTag == null) return card;

    return Hero(
      tag: heroTag!,
      flightShuttleBuilder: (
        _,
        animation,
        direction,
        fromContext,
        toContext,
      ) {
        return FadeTransition(
          opacity: animation.drive(CurveTween(curve: Curves.easeInOut)),
          child: toContext.widget,
        );
      },
      child: card,
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    final palette = switch (normalized) {
      'ideas' => (const Color(0xFFDDF5ED), const Color(0xFF2F9D79)),
      'work' => (const Color(0xFFF1E6FF), const Color(0xFF8A62D5)),
      'personal' => (const Color(0xFFFFF4D8), const Color(0xFFB59A00)),
      _ => (Colors.grey.shade200, Colors.grey.shade600),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: palette.$1,
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.$2,
          fontWeight: FontWeight.w600,
          fontSize: compact ? 11 : 12,
        ),
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({
    required this.attachments,
    required this.updatedAt,
  });

  final List<AttachmentEntity> attachments;
  final DateTime updatedAt;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('MMM d').format(updatedAt);
    final colors = Theme.of(context).colorScheme;
    final grouped = _groupByType(attachments);
    final visible = grouped.entries.toList().take(4).toList();
    final extra = grouped.length - visible.length;

    return Row(
      children: [
        Expanded(
          child: attachments.isEmpty
              ? const SizedBox.shrink()
              : Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final entry in visible)
                      _AttachmentBadge(
                        label: entry.key,
                        count: entry.value,
                      ),
                    if (extra > 0) _MorePill(count: extra),
                  ],
                ),
        ),
        Icon(Icons.calendar_month, size: 14, color: colors.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          dateLabel,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  static Map<String, int> _groupByType(List<AttachmentEntity> attachments) {
    final map = <String, int>{};
    for (final a in attachments) {
      final label = _AttachmentPill._labelForExt(a.extension);
      map.update(label, (value) => value + 1, ifAbsent: () => 1);
    }
    return map;
  }
}

class _AttachmentBadge extends StatelessWidget {
  const _AttachmentBadge({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final icon = _AttachmentPill._iconForLabel(label);
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.primary),
          const SizedBox(width: 4),
          Text(
            count > 1 ? '$label ($count)' : label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentStrip extends StatelessWidget {
  const _AttachmentStrip({required this.attachments});

  final List<AttachmentEntity> attachments;

  @override
  Widget build(BuildContext context) {
    final grouped = _AttachmentRow._groupByType(attachments);
    final visible = grouped.entries.toList().take(4).toList();
    final extra = grouped.length - visible.length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in visible)
          _AttachmentPill(label: e.key, count: e.value),
        if (extra > 0) _MorePill(count: extra),
      ],
    );
  }
}

class _AttachmentPill extends StatelessWidget {
  const _AttachmentPill({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final icon = _iconForLabel(label);
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: 6),
          Text(
            count > 1 ? '$label ($count)' : label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  static IconData _iconForLabel(String label) {
    switch (label) {
      case 'Image':
        return Icons.image_outlined;
      case 'PDF':
        return Icons.picture_as_pdf_outlined;
      case 'Audio':
        return Icons.audiotrack_outlined;
      case 'Video':
        return Icons.videocam_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  static String _labelForExt(String ext) {
    final lower = ext.toLowerCase();
    if (_isImage(lower)) return 'Image';
    if (lower == 'pdf') return 'PDF';
    if (lower == 'mp3' || lower == 'wav' || lower == 'm4a') return 'Audio';
    if (lower == 'mp4' || lower == 'mov' || lower == 'avi') return 'Video';
    return 'File';
  }

  static bool _isImage(String ext) =>
      const {'png', 'jpg', 'jpeg', 'webp', 'gif'}.contains(ext);
}

class _MorePill extends StatelessWidget {
  const _MorePill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('+$count more'),
    );
  }
}
