import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../domain/entities/attachment_entity.dart';
import '../../../domain/entities/note_entity.dart';
import '../../view_models/attachments_vm.dart';
import '../note_preview/note_preview_screen.dart';

class AttachmentsScreen extends ConsumerWidget {
  const AttachmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(attachmentsVmProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attachments'),
        actions: [
          PopupMenuButton<AttachmentSort>(
            onSelected: ref.read(attachmentsVmProvider).setSort,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: AttachmentSort.newest,
                child: Text('Newest'),
              ),
              PopupMenuItem(
                value: AttachmentSort.oldest,
                child: Text('Oldest'),
              ),
              PopupMenuItem(
                value: AttachmentSort.nameAz,
                child: Text('Name A-Z'),
              ),
              PopupMenuItem(
                value: AttachmentSort.nameZa,
                child: Text('Name Z-A'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(attachmentsVmProvider).load(),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AttachmentFilter.values
                      .map(
                        (f) => FilterChip(
                          avatar: Icon(
                            _filterIcon(f),
                            size: 16,
                          ),
                          label: Text(_filterLabel(f)),
                          selected: vm.filter == f,
                          onSelected: (_) =>
                              ref.read(attachmentsVmProvider).setFilter(f),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            if (vm.isLoading)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, __) => const _AttachmentSkeleton()
                        .animate(onPlay: (c) => c.repeat())
                        .shimmer(duration: 1200.ms),
                    childCount: 6,
                  ),
                ),
              )
            else if (vm.items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _AttachmentEmpty(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final attachment = vm.items[index];
                      final note = vm.noteFor(attachment.noteId);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: _AttachmentTile(
                          attachment: attachment,
                          note: note,
                          onOpenNote: note == null
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => NotePreviewScreen(
                                        noteId: note.id!,
                                        heroTag: 'attachment-note-${note.id}',
                                        skipLockCheck: note.isLocked,
                                      ),
                                    ),
                                  ),
                        ),
                      );
                    },
                    childCount: vm.items.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      backgroundColor: colors.surface,
    );
  }

  String _filterLabel(AttachmentFilter f) {
    switch (f) {
      case AttachmentFilter.all:
        return 'All';
      case AttachmentFilter.images:
        return 'Images';
      case AttachmentFilter.pdf:
        return 'PDF';
      case AttachmentFilter.audio:
        return 'Audio';
      case AttachmentFilter.video:
        return 'Video';
      case AttachmentFilter.other:
        return 'Other';
    }
  }

  IconData _filterIcon(AttachmentFilter f) {
    switch (f) {
      case AttachmentFilter.all:
        return Icons.apps;
      case AttachmentFilter.images:
        return Icons.image;
      case AttachmentFilter.pdf:
        return Icons.picture_as_pdf;
      case AttachmentFilter.audio:
        return Icons.audiotrack;
      case AttachmentFilter.video:
        return Icons.videocam;
      case AttachmentFilter.other:
        return Icons.insert_drive_file;
    }
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.attachment,
    required this.note,
    this.onOpenNote,
  });

  final AttachmentEntity attachment;
  final NoteEntity? note;
  final VoidCallback? onOpenNote;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = _iconForExt(attachment.extension);
    final file = File(attachment.localPath);
    final isImage = const {'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'}
        .contains(attachment.extension.toLowerCase());
    final isVideo = const {'mp4', 'mov', 'avi', 'mkv', 'webm'}
        .contains(attachment.extension.toLowerCase());
    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpenNote,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 56,
                  height: 56,
                  color: colors.surfaceContainerLow,
                  child: isImage && file.existsSync()
                      ? Image.file(
                          file,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(icon, color: colors.primary),
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              color: colors.primary.withValues(alpha: 0.12),
                            ),
                            Center(
                              child: Icon(
                                isVideo ? Icons.videocam : icon,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      attachment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      note == null ? 'Unknown note' : 'From: ${note!.title.isEmpty ? 'Untitled' : note!.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  attachment.extension.toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForExt(String ext) {
    final lower = ext.toLowerCase();
    if (const {'png', 'jpg', 'jpeg', 'webp', 'gif'}.contains(lower)) {
      return Icons.image;
    }
    if (lower == 'pdf') return Icons.picture_as_pdf;
    if (const {'mp3', 'wav', 'm4a', 'aac', 'flac'}.contains(lower)) {
      return Icons.audiotrack;
    }
    if (const {'mp4', 'mov', 'avi', 'mkv', 'webm'}.contains(lower)) {
      return Icons.videocam;
    }
    return Icons.insert_drive_file;
  }
}

class _AttachmentSkeleton extends StatelessWidget {
  const _AttachmentSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 82,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 120,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 60,
            height: 24,
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentEmpty extends StatelessWidget {
  const _AttachmentEmpty();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insert_drive_file_outlined,
                size: 64, color: colors.primary),
            const SizedBox(height: 12),
            Text(
              'No attachments found',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add files to your notes and they will show up here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
