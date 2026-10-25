import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/attachment_entity.dart';
import '../../../domain/entities/note_entity.dart';
import '../../../core/services/note_authorization.dart';
import '../../view_models/home_vm.dart';
import '../../widgets/note_card.dart';
import '../note_preview/note_preview_screen.dart';
import '../../view_models/di.dart';
import 'widgets/locked_vault.dart';

class LockedNotesPage extends ConsumerStatefulWidget {
  const LockedNotesPage({
    super.key,
    required this.notes,
    required this.attachmentsFor,
    required this.vaultSession,
  });

  final List<NoteEntity> notes;
  final List<AttachmentEntity> Function(int?) attachmentsFor;
  final VaultSession vaultSession;

  @override
  ConsumerState<LockedNotesPage> createState() => _LockedNotesPageState();
}

class _LockedNotesPageState extends ConsumerState<LockedNotesPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  SortOption _sort = SortOption.updated;
  bool _showPinnedOnly = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<NoteEntity> _filtered() {
    var list = [...widget.notes];
    if (_showPinnedOnly) {
      list = list.where((n) => n.isPinned).toList();
    }
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (n) =>
                n.title.toLowerCase().contains(q) ||
                n.contentPlain.toLowerCase().contains(q),
          )
          .toList();
    }
    list.sort((a, b) {
      switch (_sort) {
        case SortOption.updated:
          return b.updatedAt.compareTo(a.updatedAt);
        case SortOption.created:
          return b.createdAt.compareTo(a.createdAt);
        case SortOption.title:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = _filtered();

    if (!widget.vaultSession.unlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchCtrl,
          focusNode: _searchFocus,
          decoration: InputDecoration(
            hintText: 'Search locked notes...',
            filled: true,
            fillColor: colors.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchCtrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {});
                    },
                  ),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          ),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          IconButton(
            tooltip: _showPinnedOnly ? 'Show all' : 'Only pinned',
            icon: Icon(
              _showPinnedOnly ? Icons.push_pin : Icons.push_pin_outlined,
            ),
            onPressed: () => setState(() => _showPinnedOnly = !_showPinnedOnly),
          ),
          PopupMenuButton<SortOption>(
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: SortOption.updated,
                child: Text('Last updated'),
              ),
              PopupMenuItem(
                value: SortOption.created,
                child: Text('Created date'),
              ),
              PopupMenuItem(
                value: SortOption.title,
                child: Text('Title'),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Locked notes',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    '${items.length} items',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
          if (items.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _LockedEmpty(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
              sliver: SliverList.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final note = items[index];
                  final attachments = widget.attachmentsFor(note.id);
                  final heroTag =
                      note.id == null ? null : 'locked-note-${note.id}';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: OpenContainerWrapper(
                      note: note,
                      attachments: attachments,
                      heroTag: heroTag,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class OpenContainerWrapper extends ConsumerWidget {
  const OpenContainerWrapper({
    super.key,
    required this.note,
    required this.attachments,
    required this.heroTag,
  });

  final NoteEntity note;
  final List<AttachmentEntity> attachments;
  final String? heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgPath = _firstImagePath(attachments);
    return NoteCard(
      note: note,
      category: note.category,
      updatedAt: note.updatedAt,
      attachments: attachments,
      heroTag: heroTag,
      backgroundImagePath: bgPath,
      isList: true,
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NotePreviewScreen(
              noteId: note.id!,
              heroTag: heroTag,
            ),
          ),
        );
      },
      onLongPress: () async {
        final repo = ref.read(noteRepoProvider);
        if (!await ref.read(lockServiceProvider).authorizeNote(context: context,
            noteId: note.id!, operation: NoteOperation.edit)) {
          return;
        }
        final updated = note.copyWith(isPinned: !note.isPinned);
        await repo.upsert(updated);
        await ref.read(homeVmProvider).loadNotes();
      },
    )
        .animate()
        .fadeIn(duration: 220.ms)
        .move(begin: const Offset(0, 8), duration: 240.ms);
  }
}

class _LockedEmpty extends StatelessWidget {
  const _LockedEmpty();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 48, color: colors.onSurfaceVariant),
          const SizedBox(height: 8),
          const Text('No locked notes found.'),
        ],
      ),
    );
  }
}

String? _firstImagePath(List<AttachmentEntity> attachments) {
  for (final a in attachments) {
    final ext = a.extension.toLowerCase();
    if (const {'png', 'jpg', 'jpeg', 'webp', 'gif'}.contains(ext)) {
      return a.localPath;
    }
  }
  return null;
}
