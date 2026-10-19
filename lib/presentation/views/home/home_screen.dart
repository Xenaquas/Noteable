import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
// ignore: depend_on_referenced_packages
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:sticky_headers/sticky_headers.dart';

import '../../../core/services/auth_service.dart';
import '../../../data/local/databases/app_drift_database.dart';
import '../../../domain/entities/attachment_entity.dart';
import '../../../domain/entities/note_entity.dart';
import '../../view_models/di.dart';
import '../../view_models/app_settings_vm.dart';
import '../../view_models/home_vm.dart';
import '../../widgets/note_card.dart';
import '../attachments/attachments_screen.dart';
import '../note_editor/note_editor_screen.dart';
import '../note_preview/note_preview_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../tasks/tasks_screen.dart';
import '../tasks/task_editor_screen.dart';
import '../schedule/schedule_tab.dart';
import '../../view_models/tasks_vm.dart';
import '../../widgets/smooth_refresh_indicator.dart';
import '../home/locked_notes_page.dart';
import 'widgets/dashboard_metrics.dart';
import 'widgets/locked_vault.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _destinations = [
    _NavDestination(
      icon: Icons.note_alt_outlined,
      label: 'Notes',
      route: '/notes',
    ),
    _NavDestination(icon: Icons.task_alt, label: 'Tasks', route: '/tasks'),
    _NavDestination(
      icon: Icons.calendar_month,
      label: 'Schedule',
      route: '/schedule',
    ),
    _NavDestination(icon: Icons.history, label: 'History', route: '/history'),
    _NavDestination(
      icon: Icons.settings_outlined,
      label: 'Settings',
      route: '/settings',
    ),
    _NavDestination(icon: Icons.info_outline, label: 'About', route: '/about'),
  ];

  DateTime? _lastBackgrounded;
  bool _lockDialogOpen = false;
  final ValueNotifier<bool> _fabVisible = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _dialOpen = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _dialController = ValueNotifier<bool>(false);
  final VaultSession _vaultSession = VaultSession();
  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final safeIndex = widget.initialTabIndex.clamp(0, 3);
    _tabController =
        TabController(length: 4, vsync: this, initialIndex: safeIndex);
    _tabController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(homeVmProvider).init();
      await _maybeRequireUnlock(force: true);
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fabVisible.dispose();
    _dialOpen.dispose();
    _dialController.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _vaultSession.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(homeVmProvider).loadNotes();
      _maybeRequireUnlock();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _lastBackgrounded = DateTime.now();
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<void> _openEditor({int? id, String? heroTag}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(noteId: id, heroTag: heroTag),
      ),
    );
    if (changed == true && mounted) {
      await ref.read(homeVmProvider).loadNotes();
    }
  }

  Future<void> _openTaskEditor({Task? task}) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => TaskEditorScreen(task: task)));
    if (mounted) {
      await ref.read(tasksVmProvider).load();
    }
  }

  void _handleNav(String route) {
    if (route == '/notes') return;
    if (route == '/settings') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
      return;
    } else if (route == '/tasks') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const TasksScreen()));
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Destination coming soon')));
  }

  void _showSortSheet(HomeViewModel vm) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Text(
                'Sort by',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...SortOption.values.map(
                (o) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    vm.sortOption == o
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: vm.sortOption == o
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(_sortLabel(o)),
                  onTap: () {
                    vm.setSort(o);
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _maybeRequireUnlock({bool force = false}) async {
    final settings = ref.read(appSettingsProvider);
    if (!settings.isBiometricEnabled || !mounted) return;

    final now = DateTime.now();
    final shouldLock =
        force ||
        _lastBackgrounded == null ||
        now.difference(_lastBackgrounded!) >=
            Duration(minutes: settings.autoLockMinutes);

    if (!shouldLock || _lockDialogOpen) return;
    _lockDialogOpen = true;

    final auth = ref.read(authServiceProvider);
    final available = await auth.isBiometricAvailable;
    if (!available) {
      _lockDialogOpen = false;
      if (mounted) {
        await ref.read(appSettingsProvider.notifier).setBiometricEnabled(false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric lock turned off (unavailable).'),
          ),
        );
      }
      return;
    }
    if (!mounted) {
      _lockDialogOpen = false;
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String? error;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Unlock required'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Authenticate to continue.'),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final ok = await auth.authenticate(
                      reason: 'Unlock Digital Memory',
                    );
                    if (!mounted) return;
                    if (ok) {
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      return;
                    }
                    setState(() => error = 'Authentication failed. Try again.');
                  },
                  child: const Text('Unlock'),
                ),
              ],
            );
          },
        );
      },
    );

    _lockDialogOpen = false;
    _lastBackgrounded = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(homeVmProvider);
    final colors = Theme.of(context).colorScheme;
    final greeting = _greeting();

    ref.listen(homeVmProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading notes: ${next.error}'),
            backgroundColor: colors.error,
          ),
        );
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final showRail = constraints.maxWidth >= 900;
        final showSecondary = constraints.maxWidth >= 1280;

        final notesPane = _NotesPane(
          vm: vm,
          viewMode: vm.viewMode,
          onRefresh: () => ref.read(homeVmProvider).loadNotes(),
          onOpenEditor: _openEditor,
          onScrollDirectionChanged: (isUp) => _fabVisible.value = isUp,
          greeting: greeting,
        );

        final tasksPane = _TasksPane(
          onOpenTaskEditor: _openTaskEditor,
          onOpenNote: _openEditor,
        );

        final allPane = _AllPane(
          notesVm: vm,
          greeting: greeting,
          onOpenNote: _openEditor,
          onOpenTaskEditor: _openTaskEditor,
          onShowTasks: () => _tabController.animateTo(2),
          onShowNotes: () => _tabController.animateTo(1),
          vaultSession: _vaultSession,
        );

        final tabbedContent = TabBarView(
          controller: _tabController,
          children: [
            allPane,
            notesPane,
            tasksPane,
            const ScheduleTab(),
          ],
        );

        final shell = Row(
          children: [
            if (showRail)
              _NavigationRailShell(
                destinations: _destinations,
                onSelect: _handleNav,
              ),
            Expanded(flex: showSecondary ? 8 : 12, child: tabbedContent),
            if (showSecondary) ...[
              const VerticalDivider(width: 1, thickness: 1),
              const Expanded(flex: 7, child: _SecondaryPlaceholder()),
            ],
          ],
        );

        final body = ValueListenableBuilder<bool>(
          valueListenable: _dialOpen,
          builder: (context, dialOpen, _) {
            final showOverlay =
                dialOpen && _tabController.index == 0;
            return Stack(
              children: [
                SafeArea(child: shell),
                if (showOverlay)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _dialController.value = false,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );

        final fab = _buildFab(colors);

        return Scaffold(
          backgroundColor: colors.surface,
          drawer: showRail
              ? null
              : _AppDrawer(destinations: _destinations, onSelect: _handleNav),
          appBar: AppBar(
            centerTitle: false,
            leading: showRail
                ? null
                : Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
            title: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _isSearching
                  ? Padding(
                      key: const ValueKey('search-field'),
                      padding: const EdgeInsets.only(right: 12),
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _searchFocus,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search notes and tasks...',
                          filled: true,
                          fillColor: colors.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(Icons.search),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 12,
                          ),
                        ),
                        onSubmitted: (value) {
                          setState(() => _isSearching = false);
                          ref.read(searchVmProvider).onQueryChanged(value);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SearchScreen(),
                            ),
                          );
                        },
                      ),
                    )
                  : Text(
                      'Second Brain',
                      key: const ValueKey('title'),
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
            ),
            actions: [
              if (_isSearching)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchCtrl.clear();
                    });
                  },
                )
              else ...[
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() => _isSearching = true);
                    _searchFocus.requestFocus();
                  },
                ),
                // Enhanced toggle button with animation
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return RotationTransition(
                      turns: Tween<double>(
                        begin: 0.0,
                        end: 1.0,
                      ).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: IconButton(
                    key: ValueKey<ViewMode>(vm.viewMode),
                    icon: Icon(
                      vm.viewMode == ViewMode.grid
                          ? Icons.view_agenda_outlined
                          : Icons.grid_view,
                    ),
                    tooltip: vm.viewMode == ViewMode.grid
                        ? 'Switch to List view'
                        : 'Switch to Grid view',
                    onPressed: () async {
                      await ref.read(homeVmProvider).toggleViewMode();
                    },
                  ),
                ),
                PopupMenuButton<String>(
                  position: PopupMenuPosition.under,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (v) {
                    switch (v) {
                      case 'backup':
                        _handleNav('/settings');
                        return;
                      case 'settings':
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                        break;
                      case 'sort':
                        _showSortSheet(vm);
                        break;
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'backup',
                      child: Text('Backup / Export'),
                    ),
                    PopupMenuItem(value: 'sort', child: Text('Sort')),
                    PopupMenuItem(value: 'settings', child: Text('Settings')),
                  ],
                ),
              ],
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: false,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Notes'),
                Tab(text: 'Tasks'),
                Tab(text: 'Schedule'),
              ],
            ),
          ),
          floatingActionButton: ValueListenableBuilder<bool>(
            valueListenable: _fabVisible,
            builder: (context, visible, child) {
              return AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                offset: visible ? Offset.zero : const Offset(0, 0.4),
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: visible ? 1 : 0,
                  child: child,
                ),
              );
            },
            child: fab,
          ),
          body: body,
        );
      },
    );
  }

  Widget _buildFab(ColorScheme colors) {
    switch (_tabController.index) {
      case 1:
        return FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('New note'),
        );
      case 2:
        return FloatingActionButton.extended(
          onPressed: () => _openTaskEditor(),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('New task'),
        );
      case 3:
        return FloatingActionButton.extended(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Schedule coming soon')),
          ),
          icon: const Icon(Icons.schedule_outlined),
          label: const Text('New schedule'),
        );
      default:
        return SpeedDial(
          icon: Icons.add,
          activeIcon: Icons.close,
          foregroundColor: Colors.white,
          backgroundColor: colors.primary,
          renderOverlay: false,
          spacing: 8,
          spaceBetweenChildren: 10,
          openCloseDial: _dialController,
          onOpen: () {
            FocusScope.of(context).unfocus();
            _dialOpen.value = true;
          },
          onClose: () => _dialOpen.value = false,
          children: [
            SpeedDialChild(
              child: const Icon(Icons.note_add_outlined),
              backgroundColor: colors.secondaryContainer,
              foregroundColor: colors.onSecondaryContainer,
              label: 'New note',
              onTap: () => _openEditor(),
            ),
            SpeedDialChild(
              child: const Icon(Icons.check_circle_outline),
              backgroundColor: colors.tertiaryContainer,
              foregroundColor: colors.onTertiaryContainer,
              label: 'New task',
              onTap: () {
                _tabController.animateTo(2);
                _openTaskEditor();
              },
            ),
            SpeedDialChild(
              child: const Icon(Icons.schedule_outlined),
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              label: 'New schedule',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Schedule coming soon')),
              ),
            ),
            SpeedDialChild(
              child: const Icon(Icons.settings_outlined),
              backgroundColor: colors.surfaceContainerHighest,
              foregroundColor: colors.onSurface,
              label: 'Settings',
              onTap: () => _handleNav('/settings'),
            ),
          ],
        );
    }
  }

  String _sortLabel(SortOption o) {
    switch (o) {
      case SortOption.updated:
        return 'Last updated';
      case SortOption.created:
        return 'Created date';
      case SortOption.title:
        return 'Title';
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    String timeGreeting;
    if (hour >= 5 && hour < 12) {
      timeGreeting = 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      timeGreeting = 'Good afternoon';
    } else if (hour >= 17 && hour < 22) {
      timeGreeting = 'Good evening';
    } else {
      timeGreeting = 'Good night';
    }
    return '$timeGreeting, explorer';
  }
}

class _NotesPane extends ConsumerWidget {
  const _NotesPane({
    required this.vm,
    required this.viewMode,
    required this.onRefresh,
    required this.onOpenEditor,
    required this.onScrollDirectionChanged,
    required this.greeting,
  });

  final HomeViewModel vm;
  final ViewMode viewMode;
  final Future<void> Function() onRefresh;
  final void Function({int? id, String? heroTag}) onOpenEditor;
  final void Function(bool isScrollingUp) onScrollDirectionChanged;
  final String greeting;

  String attachmentsDigest(
    List<NoteEntity> notes,
    List<AttachmentEntity> Function(int?) provider,
  ) {
    final buffer = StringBuffer();
    for (final n in notes) {
      buffer.write('${n.id}-${provider(n.id).length};');
    }
    return buffer.toString();
  }

  int _crossAxisCount(double width) {
    if (viewMode == ViewMode.list) return 1;
    if (width >= 1200) return 4;
    if (width >= 900) return 3;
    if (width >= 600) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    double? lastOffset;

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = _crossAxisCount(constraints.maxWidth);

        final contentKey = ValueKey(
          '${viewMode.name}-${vm.notes.length}-${vm.isLoading}-'
          '${attachmentsDigest(vm.notes, vm.attachmentsFor)}',
        );

        final scrollable = SmoothRefreshIndicator(
          edgeOffset: 8,
          onRefresh: onRefresh,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              final currentOffset = notification.metrics.pixels;
              if (lastOffset != null) {
                final delta = currentOffset - lastOffset!;
                if (delta.abs() > 6) {
                  onScrollDirectionChanged(delta < 0);
                }
              }
              lastOffset = currentOffset;
              return false;
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: _GreetingHeader(greeting: greeting),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                if (vm.isLoading)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverMasonryGrid.count(
                      crossAxisCount: count,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      itemBuilder: (_, __) => const _NoteSkeleton()
                          .animate(onPlay: (c) => c.repeat())
                          .shimmer(duration: 1200.ms),
                      childCount: 6,
                    ),
                  )
                else if (vm.notes.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(),
                  )
                else
                  (viewMode == ViewMode.grid
                      ? _ContentListBuilder.masonry(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          crossAxisCount: count,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          itemCount: vm.notes.length,
                          itemBuilder: (context, i) =>
                              _buildNoteItem(context, i, ref, isGrid: true),
                        )
                      : _ContentListBuilder.list(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: vm.notes.length,
                          itemBuilder: (context, i) =>
                              _buildNoteItem(context, i, ref, isGrid: false),
                        )),
              ],
            ),
          ),
        );

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 0.02),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(key: contentKey, child: scrollable),
        );
      },
    );
  }

  Widget _buildNoteItem(
    BuildContext context,
    int i,
    WidgetRef ref, {
    required bool isGrid,
  }) {
    final note = vm.notes[i];
    final heroTag = note.id == null ? null : 'note-${note.id}';
    final attachments = vm.attachmentsFor(note.id);
    final bgPath = _firstImagePath(attachments);

    Widget card = isGrid
        ? OpenContainer(
            transitionType: ContainerTransitionType.fadeThrough,
            closedElevation: 0,
            openElevation: 0,
            closedColor: Colors.transparent,
            openColor: Theme.of(context).canvasColor,
            closedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            openBuilder: (_, __) => NotePreviewScreen(
              noteId: note.id!,
              heroTag: heroTag,
              skipLockCheck: note.isLocked,
            ),
            closedBuilder: (context, open) => NoteCard(
              note: note,
              category: note.category,
              updatedAt: note.updatedAt,
              attachments: attachments,
              isList: false,
              heroTag: heroTag,
              backgroundImagePath: bgPath,
              onTap: () async {
                if (note.isLocked) {
                  final ok = await ref
                      .read(lockServiceProvider)
                      .authenticate(
                        context: context,
                        reason: 'Unlock note to view content',
                      );
                  if (!ok) return;
                }
                open();
              },
              onLongPress: () => _showNoteMenu(context, note, heroTag, ref),
            ),
          )
        : Padding(
            padding: EdgeInsets.only(bottom: i == vm.notes.length - 1 ? 0 : 12),
            child: OpenContainer(
              transitionType: ContainerTransitionType.fadeThrough,
              closedElevation: 0,
              openElevation: 0,
              closedColor: Colors.transparent,
              openColor: Theme.of(context).canvasColor,
              closedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              openBuilder: (_, __) => NotePreviewScreen(
                noteId: note.id!,
                heroTag: heroTag,
                skipLockCheck: note.isLocked,
              ),
              closedBuilder: (context, open) => NoteCard(
                note: note,
                category: note.category,
                updatedAt: note.updatedAt,
                attachments: attachments,
                isList: true,
                heroTag: heroTag,
                backgroundImagePath: bgPath,
                onTap: () async {
                  if (note.isLocked) {
                    final ok = await ref
                        .read(lockServiceProvider)
                        .authenticate(
                          context: context,
                          reason: 'Unlock note to view content',
                        );
                    if (!ok) return;
                  }
                  open();
                },
                onLongPress: () => _showNoteMenu(context, note, heroTag, ref),
              ),
            ),
          );

    if (note.id != null) {
      card = Dismissible(
        key: ValueKey('note-${note.id}'),
        direction: DismissDirection.endToStart,
        background: _dismissBackground(context),
        confirmDismiss: (_) => _confirmDelete(context),
        onDismissed: (_) =>
            _deleteNoteWithUndo(context, note, attachments, ref),
        child: card,
      );
    }

    return card;
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

  Widget _dismissBackground(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(Icons.delete_forever, color: colors.onErrorContainer),
    );
  }

  Future<void> _togglePin(NoteEntity note, WidgetRef ref) async {
    final repo = ref.read(noteRepoProvider);
    await repo.upsert(note.copyWith(isPinned: !note.isPinned));
    await ref.read(homeVmProvider).loadNotes();
  }

  Future<void> _toggleLock(
    BuildContext context,
    NoteEntity note,
    WidgetRef ref,
  ) async {
    final ok = await ref
        .read(lockServiceProvider)
        .authenticate(
          context: context,
          reason: note.isLocked ? 'Unlock this note' : 'Lock this note',
        );
    if (!ok) return;
    final repo = ref.read(noteRepoProvider);
    await repo.upsert(note.copyWith(isLocked: !note.isLocked));
    await ref.read(homeVmProvider).loadNotes();
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete note?'),
            content: const Text('This will remove the note and attachments.'),
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

  Future<void> _deleteNoteWithUndo(
    BuildContext context,
    NoteEntity note,
    List<AttachmentEntity> attachments,
    WidgetRef ref,
  ) async {
    if (note.id == null) return;
    final repo = ref.read(noteRepoProvider);
    final safeAttachments = attachments.isNotEmpty
        ? attachments
        : await repo.listAttachments(note.id!);
    await repo.deleteNote(note.id!);
    if (!context.mounted) return;
    await ref.read(homeVmProvider).loadNotes();
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Note deleted'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            final restored = note.copyWith(
              id: null,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            final newId = await repo.upsert(restored);
            await repo.replaceAttachments(
              noteId: newId,
              attachments: safeAttachments
                  .asMap()
                  .entries
                  .map(
                    (entry) => entry.value.copyWith(
                      id: null,
                      noteId: newId,
                      sortIndex: entry.key,
                    ),
                  )
                  .toList(),
            );
            if (context.mounted) {
              await ref.read(homeVmProvider).loadNotes();
            }
          },
        ),
      ),
    );
  }

  Future<void> _shareNoteOptions(
    BuildContext context,
    NoteEntity note,
    WidgetRef ref,
  ) async {
    final repo = ref.read(noteRepoProvider);
    final attachments = note.id != null
        ? await repo.listAttachments(note.id!)
        : <AttachmentEntity>[];
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('Share note as PDF (content only)'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _shareNoteAsPdf(note, attachments);
                },
              ),
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('Share note + attachments as ZIP'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _shareNoteAsZip(note, attachments);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<File> _buildNotePdf(NoteEntity note) async {
    final pdf = pw.Document();
    final text = note.contentPlain.trim().isEmpty
        ? 'No content'
        : note.contentPlain.trim();
    final updatedLabel =
        '${note.updatedAt.year}-${note.updatedAt.month.toString().padLeft(2, '0')}-${note.updatedAt.day.toString().padLeft(2, '0')}';
    pdf.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              note.title.isEmpty ? 'Untitled note' : note.title,
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text('Category: ${note.category}'),
            pw.Text('Updated: $updatedLabel'),
            pw.SizedBox(height: 16),
            pw.Text(text),
          ],
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final nameSafe = (note.title.isEmpty ? 'note' : note.title).replaceAll(
      RegExp(r'[^a-zA-Z0-9-_ ]'),
      '_',
    );
    final file = File('${dir.path}/$nameSafe.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<void> _shareNoteAsPdf(
    NoteEntity note,
    List<AttachmentEntity> attachments,
  ) async {
    final pdfFile = await _buildNotePdf(note);
    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [XFile(pdfFile.path, name: pdfFile.uri.pathSegments.last)],
      subject: note.title.isEmpty ? 'Shared note' : note.title,
      text: note.contentPlain,
    );
  }

  Future<void> _shareNoteAsZip(
    NoteEntity note,
    List<AttachmentEntity> attachments,
  ) async {
    final archive = Archive();
    final pdfFile = await _buildNotePdf(note);
    archive.addFile(
      ArchiveFile(
        pdfFile.uri.pathSegments.last,
        pdfFile.lengthSync(),
        pdfFile.readAsBytesSync(),
      ),
    );

    for (final a in attachments) {
      if (a.localPath.isEmpty || !File(a.localPath).existsSync()) continue;
      final data = File(a.localPath).readAsBytesSync();
      archive.addFile(ArchiveFile(a.name, data.length, data));
    }

    final bytes = ZipEncoder().encode(archive);
    final dir = await getTemporaryDirectory();
    final nameSafe = (note.title.isEmpty ? 'note' : note.title).replaceAll(
      RegExp(r'[^a-zA-Z0-9-_ ]'),
      '_',
    );
    final zipPath =
        '${dir.path}/$nameSafe-${DateTime.now().millisecondsSinceEpoch}.zip';
    final zipFile = File(zipPath)..writeAsBytesSync(bytes);

    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [XFile(zipFile.path, name: '$nameSafe.zip')],
      subject: note.title.isEmpty ? 'Shared note' : note.title,
      text: 'Attachments included (${attachments.length}).',
    );
  }

  Future<void> _showNoteMenu(
    BuildContext context,
    NoteEntity note,
    String? heroTag,
    WidgetRef ref,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                ),
                title: Text(note.isPinned ? 'Unpin' : 'Pin'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _togglePin(note, ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share / Print'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _shareNoteOptions(context, note, ref);
                },
              ),
              ListTile(
                leading: Icon(
                  note.isLocked ? Icons.lock_open : Icons.lock_outline,
                ),
                title: Text(note.isLocked ? 'Unlock' : 'Lock'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _toggleLock(context, note, ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirmed = await _confirmDelete(context);
                  if (!context.mounted || !confirmed) return;
                  final repo = ref.read(noteRepoProvider);
                  final attachments = await repo.listAttachments(note.id!);
                  if (!context.mounted) return;
                  await _deleteNoteWithUndo(context, note, attachments, ref);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// Rest of the widget classes remain the same...


class _AllPane extends ConsumerStatefulWidget {
  const _AllPane({
    required this.notesVm,
    required this.greeting,
    required this.onOpenNote,
    required this.onOpenTaskEditor,
    required this.onShowTasks,
    required this.onShowNotes,
    required this.vaultSession,
  });

  final HomeViewModel notesVm;
  final String greeting;
  final void Function({int? id, String? heroTag}) onOpenNote;
  final Future<void> Function({Task? task}) onOpenTaskEditor;
  final VoidCallback onShowTasks;
  final VoidCallback onShowNotes;
  final VaultSession vaultSession;

  @override
  ConsumerState<_AllPane> createState() => _AllPaneState();
}

class _AllPaneState extends ConsumerState<_AllPane> {
  double _collapseProgress = 0;

  int _crossAxisCount(double width) {
    if (width >= 1200) return 4;
    if (width >= 900) return 3;
    if (width >= 620) return 2;
    return 1;
  }

  int _dueRank(DateTime? dueAt) {
    if (dueAt == null) return 4;
    final local = dueAt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(local.year, local.month, local.day);
    final diff = target.difference(today).inDays;
    if (diff < 0) return 0;
    if (diff == 0) return 1;
    if (diff == 1) return 2;
    return 3;
  }

  List<Task> _focusNowTasks(List<Task> tasks, FocusSort sort) {
    final now = DateTime.now();
    final soon = now.add(const Duration(days: 3));
    final filtered = tasks.where(
      (t) =>
          !t.isCompleted &&
          (t.priority == kPriorityHigh ||
              (t.dueAt != null && t.dueAt!.toLocal().isBefore(soon))),
    );

    final sorted = filtered.toList()
      ..sort((a, b) {
        switch (sort) {
          case FocusSort.priority:
            final dueCompare = _dueRank(a.dueAt).compareTo(_dueRank(b.dueAt));
            if (dueCompare != 0) return dueCompare;
            final priority = a.priority.compareTo(b.priority);
            if (priority != 0) return priority;
            return b.updatedAt.compareTo(a.updatedAt);
          case FocusSort.due:
            final dueCompare = _dueRank(a.dueAt).compareTo(_dueRank(b.dueAt));
            if (dueCompare != 0) return dueCompare;
            final aDue = a.dueAt?.toLocal();
            final bDue = b.dueAt?.toLocal();
            if (aDue != null && bDue != null) {
              return aDue.compareTo(bDue);
            }
            return a.priority.compareTo(b.priority);
          case FocusSort.updated:
            return b.updatedAt.compareTo(a.updatedAt);
        }
      });

    return sorted.take(6).toList();
  }

  int _attachmentTotal(HomeViewModel vm) {
    var total = 0;
    for (final n in vm.notes) {
      total += vm.attachmentsFor(n.id).length;
    }
    return total;
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

  DateTime _noteRecency(NoteEntity note) {
    return note.updatedAt.isAfter(note.createdAt)
        ? note.updatedAt
        : note.createdAt;
  }

  List<NoteEntity> _recentNotes(List<NoteEntity> notes) {
    final sorted = [...notes]
      ..sort((a, b) => _noteRecency(b).compareTo(_noteRecency(a)));
    return sorted.take(4).toList();
  }

  void _handleScroll(double offset) {
    final next = (offset / 120).clamp(0.0, 1.0);
    if ((next - _collapseProgress).abs() > 0.02) {
      setState(() => _collapseProgress = next);
    }
  }

  Future<void> _openVault(
    BuildContext context,
    List<NoteEntity> lockedNotes,
  ) async {
    if (lockedNotes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No locked notes yet.')),
      );
      return;
    }
    final lockService = ref.read(lockServiceProvider);
    final ok = await widget.vaultSession.ensureUnlocked(
      context,
      lockService,
      reason: 'Authenticate to view private notes',
    );
    if (!ok || !mounted) return;
    if (!context.mounted) return;
    await showLockedNotesSheet(
      context: context,
      vaultSession: widget.vaultSession,
      notes: lockedNotes,
      attachmentsFor: widget.notesVm.attachmentsFor,
      onOpenFullPage: () => _pushLockedPage(lockedNotes),
    );
  }

  Future<void> _openAttachments(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AttachmentsScreen()));
  }

  void _pushLockedPage(List<NoteEntity> lockedNotes) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LockedNotesPage(
          notes: lockedNotes,
          attachmentsFor: widget.notesVm.attachmentsFor,
          vaultSession: widget.vaultSession,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tasksVm = ref.watch(tasksVmProvider);
    final notesVm = widget.notesVm;
    final viewMode = notesVm.viewMode;

    return LayoutBuilder(
      builder: (context, constraints) {
        final gridCount = _crossAxisCount(constraints.maxWidth);
        final allTasks = tasksVm.allTasks;
        final focusTasks = _focusNowTasks(allTasks, tasksVm.focusSort);
        final recentNotes = _recentNotes(notesVm.notes);
        final lockedNotes = notesVm.notes.where((n) => n.isLocked).toList();
        final attachmentsTotal = _attachmentTotal(notesVm);
        final useWrapMetrics = constraints.maxWidth >= 900;
        final metricsLoading =
            (notesVm.isLoading && notesVm.notes.isEmpty) ||
                (tasksVm.isLoading && tasksVm.allTasks.isEmpty);

        return SmoothRefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.read(homeVmProvider).loadNotes(),
              ref.read(tasksVmProvider).load(),
            ]);
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification) {
                _handleScroll(notification.metrics.pixels);
              }
              return false;
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: _GreetingHeader(greeting: widget.greeting),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: DashboardMetrics(
                      metrics: [
                        DashboardMetricData(
                          label: 'File Manager',
                          value: '$attachmentsTotal',
                          subtitle: 'Media files',
                          icon: Icons.insert_drive_file_outlined,
                          color: colors.tertiary,
                          onTap: () => _openAttachments(context),
                        ),
                        DashboardMetricData(
                          label: 'Secret',
                          value: lockedNotes.isEmpty
                              ? 'Setup'
                              : '${lockedNotes.length}',
                          subtitle: lockedNotes.isEmpty
                              ? 'Tap to lock notes'
                              : 'Private notes',
                          icon: Icons.lock_outline_rounded,
                          color: colors.secondaryContainer,
                          onTap: () => _openVault(context, lockedNotes),
                        ),
                      ],
                      useWrap: useWrapMetrics,
                      condensed: _collapseProgress > 0.05,
                      isLoading: metricsLoading,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: AnimatedBuilder(
                      animation: widget.vaultSession,
                      builder: (context, _) => LockedNotesQuickCard(
                        lockedCount: lockedNotes.length,
                        unlocked: widget.vaultSession.unlocked,
                        onTap: () => _openVault(context, lockedNotes),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Focus now',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Do these first.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Mark all done',
                              onPressed: focusTasks.isEmpty
                                  ? null
                                  : () async {
                                      try {
                                        await ref
                                            .read(tasksVmProvider)
                                            .markTasksComplete(focusTasks);
                                      } catch (_) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Could not complete all focus tasks.',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                              icon: const Icon(Icons.done_all),
                            ),
                            PopupMenuButton<FocusSort>(
                              tooltip: 'Sort focus tasks',
                              onSelected: ref.read(tasksVmProvider).setFocusSort,
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: FocusSort.priority,
                                  child: Text('Priority first'),
                                ),
                                PopupMenuItem(
                                  value: FocusSort.due,
                                  child: Text('Due date'),
                                ),
                                PopupMenuItem(
                                  value: FocusSort.updated,
                                  child: Text('Recently updated'),
                                ),
                              ],
                              icon: const Icon(Icons.sort),
                            ),
                            TextButton(
                              onPressed: widget.onShowTasks,
                              child: const Text('Open tasks'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (tasksVm.isLoading)
                  const _FocusListSkeleton()
                else if (focusTasks.isEmpty)
                  SliverToBoxAdapter(
                    child: _FocusEmpty(
                      onAddTask: () => widget.onOpenTaskEditor(),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 230,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final task = focusTasks[index];
                          return SizedBox(
                            width: 320,
                            child: _FocusCard(
                              task: task,
                              onOpen: () => widget.onOpenTaskEditor(task: task),
                              onToggle: () async {
                                HapticFeedback.lightImpact();
                                final ok = await ref
                                    .read(tasksVmProvider)
                                    .toggleCompleteSafe(task);
                                if (!ok && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Could not update task. Please try again.',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemCount: focusTasks.length,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent notes',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        TextButton(
                          onPressed: widget.onShowNotes,
                          child: const Text('View all'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (notesVm.isLoading && recentNotes.isEmpty)
                  _ContentListBuilder.masonry(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    crossAxisCount: gridCount,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    itemCount: 6,
                    itemBuilder: (_, __) => const _NoteSkeleton()
                        .animate(onPlay: (c) => c.repeat())
                        .shimmer(duration: 1200.ms),
                  )
                else if (recentNotes.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: Column(
                        children: [
                          const _EmptyState(),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => widget.onOpenNote(),
                            icon: const Icon(Icons.note_add_outlined),
                            label: const Text('Create your first note'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  (viewMode == ViewMode.grid
                      ? _ContentListBuilder.masonry(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          crossAxisCount: gridCount,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          itemCount: recentNotes.length,
                          itemBuilder: (context, index) {
                            final note = recentNotes[index];
                            final attachments = notesVm.attachmentsFor(note.id);
                            final heroTag = note.id == null
                                ? null
                                : 'dash-note-${note.id}';
                            final bgPath = _firstImagePath(attachments);
                            return OpenContainer(
                              transitionType: ContainerTransitionType.fadeThrough,
                              closedElevation: 0,
                              openElevation: 0,
                              closedColor: Colors.transparent,
                              openColor: Theme.of(context).canvasColor,
                              closedShape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              openBuilder: (_, __) => NotePreviewScreen(
                                noteId: note.id!,
                                heroTag: heroTag,
                                skipLockCheck: note.isLocked,
                              ),
                              closedBuilder: (context, open) => NoteCard(
                                note: note,
                                category: note.category,
                                updatedAt: note.updatedAt,
                                attachments: attachments,
                                heroTag: heroTag,
                                backgroundImagePath: bgPath,
                                onTap: () async {
                                  if (note.isLocked) {
                                    final ok = await ref
                                        .read(lockServiceProvider)
                                        .authenticate(
                                          context: context,
                                          reason: 'Unlock note to view content',
                                        );
                                    if (!ok) return;
                                  }
                                  open();
                                },
                                onLongPress: () => widget.onOpenNote(
                                  id: note.id,
                                  heroTag: heroTag,
                                ),
                              ),
                            );
                          },
                        )
                      : _ContentListBuilder.list(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                          itemCount: recentNotes.length,
                          itemBuilder: (context, index) {
                            final note = recentNotes[index];
                            final attachments = notesVm.attachmentsFor(note.id);
                            final heroTag = note.id == null
                                ? null
                                : 'dash-note-${note.id}';
                            final bgPath = _firstImagePath(attachments);
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 6,
                              ),
                              child: OpenContainer(
                                transitionType:
                                    ContainerTransitionType.fadeThrough,
                                closedElevation: 0,
                                openElevation: 0,
                                closedColor: Colors.transparent,
                                openColor: Theme.of(context).canvasColor,
                                closedShape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                openBuilder: (_, __) => NotePreviewScreen(
                                  noteId: note.id!,
                                  heroTag: heroTag,
                                  skipLockCheck: note.isLocked,
                                ),
                                closedBuilder: (context, open) => NoteCard(
                                  note: note,
                                  category: note.category,
                                  updatedAt: note.updatedAt,
                                  attachments: attachments,
                                  heroTag: heroTag,
                                  backgroundImagePath: bgPath,
                                  isList: true,
                                  onTap: () async {
                                    if (note.isLocked) {
                                      final ok = await ref
                                          .read(lockServiceProvider)
                                          .authenticate(
                                            context: context,
                                            reason: 'Unlock note to view content',
                                          );
                                      if (!ok) return;
                                    }
                                    open();
                                  },
                                  onLongPress: () => widget.onOpenNote(
                                    id: note.id,
                                    heroTag: heroTag,
                                  ),
                                ),
                              ),
                            );
                          },
                        )),
              ],
            ),
          ),
        );
      },
    );
  }
}


class _FocusCard extends StatelessWidget {
  const _FocusCard({
    required this.task,
    required this.onToggle,
    required this.onOpen,
  });

  final Task task;
  final Future<void> Function() onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final due = task.dueAt?.toLocal();
    final dueLabel = due == null ? 'No date' : _friendlyDate(context, due);
    final priorityColor = _priorityColor(task.priority, colors);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.surfaceContainerHighest, colors.surface],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.flash_on, size: 14, color: priorityColor),
                        const SizedBox(width: 6),
                        Text(
                          'Priority',
                          style: theme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: priorityColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: task.isCompleted ? 'Mark active' : 'Mark done',
                    onPressed: () async => await onToggle(),
                    icon: Icon(
                      task.isCompleted
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      color: task.isCompleted
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (task.description?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(
                  task.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dueLabel,
                    style: theme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  priorityPill(task.priority, colors),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusEmpty extends StatelessWidget {
  const _FocusEmpty({required this.onAddTask});

  final VoidCallback onAddTask;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Container(
        height: 150,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bolt, color: colors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No focus tasks',
                    style: theme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Add a high-priority task.',
                    style: theme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: FilledButton.icon(
                onPressed: onAddTask,
                icon: const Icon(Icons.add),
                label: const Text('New task'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusListSkeleton extends StatelessWidget {
  const _FocusListSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _ContentListBuilder.list(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
      itemCount: 3,
      itemBuilder: (_, __) => Container(
        height: 82,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(width: 10),
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
      ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms),
    );
  }
}

class _TasksPane extends ConsumerStatefulWidget {
  const _TasksPane({required this.onOpenTaskEditor, required this.onOpenNote});

  final Future<void> Function({Task? task}) onOpenTaskEditor;
  final void Function({int? id, String? heroTag}) onOpenNote;

  @override
  ConsumerState<_TasksPane> createState() => _TasksPaneState();
}

class _TasksPaneState extends ConsumerState<_TasksPane> {
  final Set<int> _expandedTaskIds = {};
  bool _showCompleted = false;

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(tasksVmProvider);
    final showCompleted = _showCompleted || vm.filter == TaskFilter.done;
    final visibleTasks = showCompleted
        ? vm.tasks
        : vm.tasks.where((t) => !t.isCompleted).toList();
    final groups = _buildTaskGroups(visibleTasks);

    return SmoothRefreshIndicator(
      onRefresh: () => ref.read(tasksVmProvider).load(),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tasks',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => widget.onOpenTaskEditor(),
                    icon: const Icon(Icons.add),
                    label: const Text('New task'),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterChip(
                    context,
                    'All',
                    vm.filter == TaskFilter.all,
                    () => ref.read(tasksVmProvider).setFilter(TaskFilter.all),
                  ),
                  _filterChip(
                    context,
                    'Pending',
                    vm.filter == TaskFilter.active,
                    () =>
                        ref.read(tasksVmProvider).setFilter(TaskFilter.active),
                  ),
                  _filterChip(
                    context,
                    'Done',
                    vm.filter == TaskFilter.done,
                    () => ref.read(tasksVmProvider).setFilter(TaskFilter.done),
                  ),
                  _filterChip(
                    context,
                    'Priority',
                    vm.filter == TaskFilter.priority,
                    () => ref
                        .read(tasksVmProvider)
                        .setFilter(TaskFilter.priority),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
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
            ),
          ),
          SliverToBoxAdapter(child: const SizedBox(height: 8)),
          if (vm.isLoading)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList.builder(
                itemCount: 6,
                itemBuilder: (_, __) => const _TaskSkeleton(),
              ),
            )
          else if (visibleTasks.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyTasks(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final group = groups[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: StickyHeader(
                        header: _TaskSectionHeader(
                          label: group.label,
                          color: group.color,
                        ),
                        content: Column(
                          children: [
                            for (final task in group.tasks)
                              _TaskRow(
                                key: ValueKey('task-${task.id}'),
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
                                  final confirmed =
                                      await _confirmDelete(context);
                                  if (!confirmed) {
                                    return;
                                  }
                                  HapticFeedback.heavyImpact();
                                  await ref
                                      .read(tasksVmProvider)
                                      .delete(task);
                                },
                                onEdit: () =>
                                    widget.onOpenTaskEditor(task: task),
                                onOpenLinkedNote: task.noteId == null
                                    ? null
                                    : () => widget.onOpenNote(id: task.noteId),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: groups.length,
                ),
              ),
            ),
        ],
      ),
    );
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

  List<_TaskGroup> _buildTaskGroups(List<Task> tasks) {
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
      _TaskGroup(label: 'Overdue', color: Colors.red, tasks: overdue),
      _TaskGroup(label: 'Today', color: Colors.blue, tasks: todayTasks),
      _TaskGroup(label: 'Upcoming', color: Colors.grey, tasks: upcoming),
    ];
    return groups.where((g) => g.tasks.isNotEmpty).toList();
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

  ChoiceChip _filterChip(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _TaskSkeleton extends StatelessWidget {
  const _TaskSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 60,
                height: 12,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 12,
            width: 140,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms);
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

class _TaskSectionHeader extends StatelessWidget {
  const _TaskSectionHeader({
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

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    super.key,
    required this.task,
    required this.subtasks,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    required this.onToggleExpanded,
    required this.isExpanded,
    this.onOpenLinkedNote,
  });

  final Task task;
  final List<TaskSubtask> subtasks;
  final Future<void> Function() onToggle;
  final Future<void> Function() onDelete;
  final VoidCallback onEdit;
  final VoidCallback onToggleExpanded;
  final bool isExpanded;
  final VoidCallback? onOpenLinkedNote;

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
                    onChanged: () => onToggle(),
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
                  if (onOpenLinkedNote != null) ...[
                    const SizedBox(width: 8),
                    InkResponse(
                      onTap: onOpenLinkedNote,
                      radius: 16,
                      child: const Icon(Icons.link,
                          size: 16, color: Colors.blue),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ).animate().fadeIn(duration: 250.ms),
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.greeting});

  final String greeting;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ready to capture ideas?',
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ContentListType { list, masonry }

class _ContentListBuilder extends StatelessWidget {
  const _ContentListBuilder.list({
    required this.itemCount,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
  }) : type = _ContentListType.list,
       crossAxisCount = null,
       mainAxisSpacing = 0,
       crossAxisSpacing = 0,
       staggerDelay = const Duration(milliseconds: 40);

  const _ContentListBuilder.masonry({
    required this.itemCount,
    required this.itemBuilder,
    required this.crossAxisCount,
    this.padding = EdgeInsets.zero,
    this.mainAxisSpacing = 12,
    this.crossAxisSpacing = 12,
  }) : type = _ContentListType.masonry,
       staggerDelay = const Duration(milliseconds: 40);

  final _ContentListType type;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;
  final int? crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final Duration staggerDelay;

  @override
  Widget build(BuildContext context) {
    Widget wrap(int index) => _animated(itemBuilder(context, index), index);

    final sliver = switch (type) {
      _ContentListType.list => SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => wrap(index),
          childCount: itemCount,
        ),
      ),
      _ContentListType.masonry => SliverMasonryGrid.count(
        crossAxisCount: crossAxisCount ?? 2,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childCount: itemCount,
        itemBuilder: (context, index) => wrap(index),
      ),
    };

    return SliverPadding(padding: padding, sliver: sliver);
  }

  Widget _animated(Widget child, int index) {
    final delayMs = staggerDelay.inMilliseconds * (index > 200 ? 200 : index);
    final delay = Duration(milliseconds: delayMs);
    return child
        .animate(delay: delay)
        .fadeIn(duration: 260.ms, curve: Curves.easeOut)
        .slideY(
          begin: 0.06,
          end: 0,
          duration: 260.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _NoteSkeleton extends StatelessWidget {
  const _NoteSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 16,
            width: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 14,
            width: 70,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            fit: FlexFit.loose,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_add_outlined,
            size: 72,
            color: color.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            'No notes yet',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create your first note with the + button and it will appear here automatically.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.checklist_rtl,
            size: 72,
            color: color.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            'No tasks yet',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add a task to start organizing your day.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NavigationRailShell extends StatelessWidget {
  const _NavigationRailShell({
    required this.destinations,
    required this.onSelect,
  });

  final List<_NavDestination> destinations;
  final void Function(String route) onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return NavigationRail(
      extended: false,
      labelType: NavigationRailLabelType.all,
      selectedIndex: 0,
      onDestinationSelected: (i) => onSelect(destinations[i].route),
      leading: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Column(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colors.primary.withValues(alpha: 0.1),
              child: Icon(Icons.dashboard_customize, color: colors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              'Second Brain',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      destinations: destinations
          .map(
            (d) => NavigationRailDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.icon, color: colors.primary),
              label: Text(d.label),
            ),
          )
          .toList(),
    );
  }
}

class _SecondaryPlaceholder extends StatelessWidget {
  const _SecondaryPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.table_rows_rounded, size: 40, color: colors.primary),
              const SizedBox(height: 12),
              Text(
                'Editor / preview space',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'On larger screens, this panel will host the editor/preview.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.destinations, required this.onSelect});

  final List<_NavDestination> destinations;
  final void Function(String route) onSelect;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DrawerBranding(),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: destinations
                    .map(
                      (d) => ListTile(
                        leading: Icon(d.icon),
                        title: Text(d.label),
                        selected: d.route == '/notes',
                        onTap: () {
                          Navigator.pop(context);
                          onSelect(d.route);
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerBranding extends StatelessWidget {
  const _DrawerBranding();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: colors.primary.withValues(alpha: 0.12),
            child: Icon(Icons.dashboard_customize, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Second Brain',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'Offline-first',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;
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
  if (diff == -1) return 'Yesterday, $time';
  if (diff.abs() <= 7) {
    final weekday = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ][target.weekday - 1];
    return '$weekday, $time';
  }
  return '${target.year}/${target.month}/${target.day}, $time';
}
