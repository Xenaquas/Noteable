import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:chewie/chewie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart' as fs;
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../domain/entities/attachment_entity.dart';
import '../../../domain/entities/note_entity.dart';
import '../../view_models/di.dart';
import '../../widgets/canvas_scaffold.dart';
import '../../widgets/shimmer_skeleton.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final int? noteId;
  final String? heroTag;
  const NoteEditorScreen({super.key, this.noteId, this.heroTag});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _titleController = TextEditingController();
  final _editorFocusNode = FocusNode();
  final _editorScrollController = ScrollController();

  late quill.QuillController _quillController;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLocked = false;
  bool _isLoadingAttachments = false;
  bool _dirty = false;
  bool _hydrating = false;
  DateTime? _lastSavedAt;
  Timer? _autoSaveTimer;

  final List<_AttachmentDraft> _attachments = [];
  final List<String> _categories = const ["Personal", "Work", "Ideas"];
  String _selectedCategory = "Personal";
  final ImagePicker _imagePicker = ImagePicker();
  final fs.FlutterSoundRecorder _recorder = fs.FlutterSoundRecorder();
  bool _recorderReady = false;
  bool _isRecording = false;
  final Map<String, String> _thumbnailCache = {};

  NoteEntity? _loadedNote;

  @override
  void initState() {
    super.initState();
    _quillController = quill.QuillController(
      document: quill.Document(),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _quillController.addListener(_handleEdited);
    _titleController.addListener(_handleEdited);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _initRecorder();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    _quillController.dispose();
    _autoSaveTimer?.cancel();
    // ignore: discarded_futures
    _recorder.closeRecorder();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final repo = ref.read(noteRepoProvider);
    _hydrating = true;

    if (widget.noteId == null) {
      _loadedNote = null;
      _titleController.text = '';
      _replaceQuillController(
        quill.QuillController(
          document: quill.Document(),
          selection: const TextSelection.collapsed(offset: 0),
        ),
      );
      setState(() => _isLoading = false);
      _hydrating = false;
      return;
    }

    final note = await repo.getNote(widget.noteId!);
    if (!mounted) return;

    if (note == null) {
      _loadedNote = null;
      setState(() => _isLoading = false);
      _hydrating = false;
      return;
    }

    _loadedNote = note;
    _titleController.text = note.title;
    _selectedCategory = note.category.isNotEmpty ? note.category : "Personal";
    _isLocked = note.isLocked;

    final doc = await _loadDocumentAsync(note.contentJson);
    _replaceQuillController(
      quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      ),
    );
    _dirty = false;
    _hydrating = false;

    if (!mounted) return;

    setState(() => _isLoading = false);

    // Defer attachment loading until after first paint to keep UI responsive.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAttachmentsLazy(note.id!);
    });
  }

  void _handleEdited() {
    if (_hydrating) return;
    if (!_dirty) {
      setState(() => _dirty = true);
    }
    _queueAutoSave();
  }

  void _queueAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () async {
      if (!mounted || _isSaving || _isLocked || !_dirty) return;
      if (_shouldSkipAutoSave()) return;
      await _save(fromAuto: true);
    });
  }

  bool _shouldSkipAutoSave() {
    final hasTitle = _titleController.text.trim().isNotEmpty;
    final hasBody = _quillController.document.toPlainText().trim().isNotEmpty;
    return !hasTitle && !hasBody && _attachments.isEmpty;
  }

  Widget _buildSaveStatus(ColorScheme colors, TextTheme textTheme) {
    String? label;
    Color? bg;
    Color? fg;
    IconData? icon;

    if (_isSaving) {
      label = 'Saving...';
      bg = colors.primaryContainer;
      fg = colors.onPrimaryContainer;
      icon = Icons.autorenew;
    } else if (_dirty) {
      label = 'Unsaved';
      bg = colors.surfaceContainerHighest;
      fg = colors.onSurfaceVariant;
      icon = Icons.info_outline;
    } else if (_lastSavedAt != null) {
      label = 'Saved';
      bg = colors.secondaryContainer;
      fg = colors.onSecondaryContainer;
      icon = Icons.check_circle;
    }

    if (label == null || bg == null || fg == null || icon == null) {
      return const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Container(
        key: ValueKey(label),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _replaceQuillController(quill.QuillController next) {
    _quillController.dispose();
    _quillController = next;
  }

  Future<quill.Document> _loadDocumentAsync(String? contentJson) {
    // Offload JSON parsing to a background isolate to keep the UI thread smooth.
    return compute(_decodeDocument, contentJson);
  }

  static quill.Document _decodeDocument(String? contentJson) {
    try {
      if (contentJson == null || contentJson.trim().isEmpty) {
        return quill.Document();
      }
      final decoded = jsonDecode(contentJson);
      if (decoded is List) {
        return quill.Document.fromJson(decoded);
      }
      return quill.Document();
    } catch (_) {
      return quill.Document();
    }
  }

  Future<void> _loadAttachmentsLazy(int noteId) async {
    setState(() => _isLoadingAttachments = true);
    final repo = ref.read(noteRepoProvider);
    final atts = await repo.listAttachments(noteId);
    if (!mounted) return;
    setState(() {
      _attachments
        ..clear()
        ..addAll(atts.map((a) => _AttachmentDraft.fromEntity(a)));
      _isLoadingAttachments = false;
    });
    for (final draft in _attachments) {
      _warmThumbnail(draft);
    }
  }

  Future<void> _initRecorder() async {
    try {
      await _recorder.openRecorder();
      if (mounted) {
        setState(() => _recorderReady = true);
      }
    } catch (_) {
      if (mounted) setState(() => _recorderReady = false);
    }
  }

  Future<void> _addAttachmentDraft(
    _AttachmentDraft draft, {
    bool simulateUpload = false,
  }) async {
    setState(() {
      _attachments.add(draft);
      _dirty = true;
    });
    if (draft.isVideo) {
      _warmThumbnail(draft);
    }
    if (simulateUpload) {
      _simulateUpload(draft);
    } else {
      setState(() => draft.progress = 1);
    }
    _queueAutoSave();
  }

  void _simulateUpload(_AttachmentDraft draft) {
    draft.progress = max(draft.progress, 0.08);
    draft.uploading = true;
    Timer.periodic(const Duration(milliseconds: 140), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        draft.progress = (draft.progress + 0.2).clamp(0, 1);
        if (draft.progress >= 1) {
          draft.uploading = false;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _warmThumbnail(_AttachmentDraft draft) async {
    if (!draft.isVideo || draft.thumbnailPath != null) return;
    final existing = _thumbnailCache[draft.localPath];
    if (existing != null && File(existing).existsSync()) {
      setState(() => draft.thumbnailPath = existing);
      return;
    }
    if (!File(draft.localPath).existsSync()) return;
    final dir = await getTemporaryDirectory();
    final thumb = await VideoThumbnail.thumbnailFile(
      video: draft.localPath,
      imageFormat: ImageFormat.JPEG,
      maxHeight: 260,
      quality: 55,
      thumbnailPath: dir.path,
    );
    if (thumb != null && mounted) {
      _thumbnailCache[draft.localPath] = thumb;
      setState(() => draft.thumbnailPath = thumb);
    }
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (result == null) return;

    final files = result.files.where((f) => f.path != null).toList();
    if (files.isEmpty) return;

    for (final f in files) {
      final ext = (f.extension ?? '').toLowerCase();
      final draft = _AttachmentDraft(
        localPath: f.path!,
        name: f.name,
        extension: ext,
        type: _AttachmentDraft.inferType(ext),
        sizeBytes: f.size,
        progress: 0,
      );
      await _addAttachmentDraft(draft, simulateUpload: true);
    }
  }

  Future<_AttachmentDraft?> _draftFromXFile(
    XFile file, {
    String? typeOverride,
  }) async {
    try {
      final size = await file.length();
      final ext = file.path.split('.').last.toLowerCase();
      return _AttachmentDraft(
        localPath: file.path,
        name: file.name,
        extension: ext,
        type: typeOverride ?? _AttachmentDraft.inferType(ext),
        sizeBytes: size,
        progress: 0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickImage({bool fromCamera = false}) async {
    final picked = await _imagePicker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 82,
    );
    if (picked == null) return;
    final draft = await _draftFromXFile(picked, typeOverride: 'image');
    if (draft != null) {
      await _addAttachmentDraft(draft, simulateUpload: true);
    }
  }

  Future<void> _pickVideo({bool fromCamera = false}) async {
    final picked = await _imagePicker.pickVideo(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (picked == null) return;
    final draft = await _draftFromXFile(picked, typeOverride: 'video');
    if (draft != null) {
      await _addAttachmentDraft(draft, simulateUpload: true);
    }
  }

  Future<void> _recordAudioFlow() async {
    if (!_recorderReady) {
      await _initRecorder();
    }
    if (!_recorderReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone unavailable')),
        );
      }
      return;
    }

    String? path;
    Duration elapsed = Duration.zero;
    Timer? ticker;
    bool started = false;

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> start() async {
              if (started) return;
              started = true;
              final dir = await getTemporaryDirectory();
              path =
                  '${dir.path}/note-audio-${DateTime.now().millisecondsSinceEpoch}.aac';
              await _recorder.startRecorder(
                toFile: path,
                codec: fs.Codec.aacADTS,
              );
              setSheetState(() => _isRecording = true);
              ticker = Timer.periodic(
                const Duration(seconds: 1),
                (_) => setSheetState(
                  () => elapsed += const Duration(seconds: 1),
                ),
              );
            }

            start();

            Future<void> stop() async {
              await _recorder.stopRecorder();
              ticker?.cancel();
              setSheetState(() => _isRecording = false);
              if (ctx.mounted) Navigator.pop(ctx);
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isRecording ? 'Recording...' : 'Preparing recorder',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _formatDuration(elapsed),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: stop,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop & attach'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await _recorder.stopRecorder();
                      ticker?.cancel();
                      path = null;
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    ticker?.cancel();
    _isRecording = false;

    if (path != null && File(path!).existsSync()) {
      final size = await File(path!).length();
      final name = path!.split(Platform.pathSeparator).last;
      final draft = _AttachmentDraft(
        localPath: path!,
        name: name,
        extension: 'aac',
        type: 'audio',
        sizeBytes: size,
        progress: 0,
      );
      await _addAttachmentDraft(draft, simulateUpload: true);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showAttachmentSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Files'),
              subtitle: const Text('PDF, docs, zips'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAttachments();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Photo from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Video from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Capture photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(fromCamera: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic_none_outlined),
              title: const Text('Record audio'),
              subtitle: Text(_recorderReady ? 'Inline voice memo' : 'Mic not ready'),
              onTap: !_recorderReady && !_isRecording
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _recordAudioFlow();
                    },
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _save({bool fromAuto = false}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final repo = ref.read(noteRepoProvider);
      final deltaJson = jsonEncode(
        _quillController.document.toDelta().toJson(),
      );
      final plain = _quillController.document.toPlainText().trim();
      final now = DateTime.now();

      final draft = (_loadedNote == null)
          ? NoteEntity(
              id: null,
              title: _titleController.text.trim(),
              category: _selectedCategory,
              isLocked: _isLocked,
              isPinned: false,
              contentJson: deltaJson,
              contentPlain: plain,
              updatedAt: now,
              createdAt: now,
            )
          : _loadedNote!.copyWith(
              title: _titleController.text.trim(),
              category: _selectedCategory,
              isLocked: _isLocked,
              isPinned: _loadedNote!.isPinned,
              contentJson: deltaJson,
              contentPlain: plain,
              updatedAt: now,
            );

      final savedId = await repo.upsert(draft);

      await repo.replaceAttachments(
        noteId: savedId,
        attachments: _attachments
            .asMap()
            .entries
            .map(
              (entry) =>
                  entry.value.toEntity(noteId: savedId, sortIndex: entry.key),
            )
            .toList(),
      );

      if (!mounted) return;

      _loadedNote = draft.copyWith(id: savedId);
      setState(() {
        _dirty = false;
        _lastSavedAt = DateTime.now();
      });
      if (!fromAuto) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Saved'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 1200),
            margin: const EdgeInsets.all(12),
          ),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final slivers = _isLoading
        ? const [SliverToBoxAdapter(child: _EditorSkeleton())]
        : <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((c) {
                    final selected = c == _selectedCategory;
                    return ChoiceChip(
                      label: Text(c),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = c),
                    );
                  }).toList(),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Start typing here...',
                    border: UnderlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RepaintBoundary(
                  child: _EditorCard(
                    locked: _isLocked,
                    quillController: _quillController,
                    focusNode: _editorFocusNode,
                    scrollController: _editorScrollController,
                    color: colors.surfaceContainerHighest,
                    overlayColor: colors.surface.withAlpha(80),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Attachments',
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _showAttachmentSourceSheet,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Add'),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoadingAttachments)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Loading attachments...'),
                    ],
                  ),
                ),
              ),
            if (_attachments.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _attachments.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _attachments.removeAt(oldIndex);
                        _attachments.insert(newIndex, item);
                        _dirty = true;
                      });
                      HapticFeedback.selectionClick();
                      _queueAutoSave();
                    },
                    itemBuilder: (context, index) {
                            final a = _attachments[index];
                            return Dismissible(
                              key: ValueKey('att-${a.key}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .errorContainer,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 18),
                                alignment: Alignment.centerRight,
                                child: Icon(
                                  Icons.delete_outline,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                ),
                              ),
                              onDismissed: (_) {
                                setState(() {
                                  _attachments.removeAt(index);
                                  _dirty = true;
                                });
                                HapticFeedback.mediumImpact();
                                _queueAutoSave();
                              },
                              child: _AttachmentTile(
                                key: ValueKey(a.key),
                                draft: a,
                                index: index,
                                onPreview: () => _openAttachmentDraft(a),
                                onLongPress: () => _showAttachmentContext(a, index),
                              ),
                            );
                          },
                        ),
                ),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ];

    final page = CanvasScaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBackButton,
        ),
        title: Text(widget.noteId == null ? 'New Note' : 'Edit Note'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _buildSaveStatus(colors, theme.textTheme),
          ),
          IconButton(
            tooltip: _isLocked ? 'Unlock' : 'Lock',
            icon: Icon(_isLocked ? Icons.lock : Icons.lock_open),
            onPressed: () => setState(() => _isLocked = !_isLocked),
          ),
          IconButton(
            tooltip: 'Save',
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _isSaving ? null : () => _save(fromAuto: false),
          ),
        ],
      ),
      slivers: slivers,
      bottomBar: _isLocked
          ? null
          : _BottomToolbar(
              controller: _quillController,
              onMore: _showMoreToolbar,
              onLink: _addLink,
            ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final ok = await _confirmExit();
        if (!mounted) return;
        if (ok && navigator.canPop()) {
          navigator.pop(false);
        }
      },
      child: page,
    );
  }

  Future<void> _showAttachmentContext(
    _AttachmentDraft draft,
    int index,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Preview'),
              onTap: () {
                Navigator.pop(ctx);
                _openAttachmentDraft(draft);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () async {
                Navigator.pop(ctx);
                final next = await _promptRename(draft.name);
                if (next != null && next.trim().isNotEmpty) {
                  setState(() {
                    _attachments[index] = draft.copyWith(name: next.trim());
                    _dirty = true;
                  });
                  _queueAutoSave();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _attachments.removeAt(index);
                  _dirty = true;
                });
                _queueAutoSave();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptRename(String current) async {
    final controller = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename attachment'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'New name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAttachmentDraft(_AttachmentDraft draft) async {
    if (!File(draft.localPath).existsSync()) return;
    final ext = draft.extension;
    if (_AttachmentTile._isImageExt(ext)) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(draft.name)),
            backgroundColor: Colors.black,
            body: Center(
              child: InteractiveViewer(
                child: Image.file(File(draft.localPath)),
              ),
            ),
          ),
        ),
      );
    } else if (ext == 'pdf') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _PdfAttachmentViewer(path: draft.localPath, title: draft.name),
        ),
      );
    } else if (draft.isVideo) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _VideoPlayerScreen(path: draft.localPath, title: draft.name),
        ),
      );
    } else if (draft.isAudio) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _AudioPlayerScreen(path: draft.localPath, title: draft.name),
        ),
      );
    } else {
      await OpenFile.open(draft.localPath);
    }
  }

  Future<void> _handleBackButton() async {
    final ok = await _confirmExit();
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (ok && navigator.canPop()) {
      navigator.pop(false);
    }
  }

  Future<bool> _confirmExit() async {
    if (_dirty && !_isSaving) {
      final decision = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Discard changes?'),
              content: const Text(
                'You have unsaved edits. Save before leaving?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Discard'),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(ctx, false);
                    await _save();
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ) ??
          false;
      return decision;
    }
    return true;
  }

  Future<void> _addLink() async {
    final selection = _quillController.selection;
    if (selection.isCollapsed) return;

    final url = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Insert link'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'https://example.com'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (url != null && url.isNotEmpty) {
      _quillController.formatSelection(quill.LinkAttribute(url));
    }
  }

  void _showMoreToolbar() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          maxChildSize: 0.9,
          initialChildSize: 0.55,
          builder: (_, controller) {
            return SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  quill.QuillSimpleToolbar(
                    config: const quill.QuillSimpleToolbarConfig(
                      showAlignmentButtons: true,
                      showBackgroundColorButton: true,
                      showColorButton: true,
                      showCodeBlock: true,
                      showDirection: false,
                      showFontFamily: false,
                      showFontSize: true,
                      showInlineCode: true,
                      showIndent: true,
                      showListNumbers: true,
                      showListBullets: true,
                      showQuote: true,
                      multiRowsDisplay: true,
                    ),
                    controller: _quillController,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        const SizedBox(height: 10),
                        Text(
                          'Insert',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _QuickInsertButton(
                              icon: Icons.image_outlined,
                              label: 'Image',
                              onTap: () {
                                Navigator.pop(context);
                                _pickImage();
                              },
                            ),
                            _QuickInsertButton(
                              icon: Icons.videocam_outlined,
                              label: 'Video',
                              onTap: () {
                                Navigator.pop(context);
                                _pickVideo();
                              },
                            ),
                            _QuickInsertButton(
                              icon: Icons.audiotrack_outlined,
                              label: 'Audio',
                              onTap: () {
                                Navigator.pop(context);
                                _recordAudioFlow();
                              },
                            ),
                            _QuickInsertButton(
                              icon: Icons.insert_drive_file_outlined,
                              label: 'File',
                              onTap: () {
                                Navigator.pop(context);
                                _pickAttachments();
                              },
                            ),
                            _QuickInsertButton(
                              icon: Icons.link,
                              label: 'Link',
                              onTap: () {
                                Navigator.pop(context);
                                _addLink();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({
    required this.locked,
    required this.quillController,
    required this.focusNode,
    required this.scrollController,
    required this.color,
    required this.overlayColor,
  });

  final bool locked;
  final quill.QuillController quillController;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final Color color;
  final Color overlayColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      constraints: const BoxConstraints(minHeight: 260),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Stack(
        children: [
          AbsorbPointer(
            absorbing: locked,
            child: quill.QuillEditor.basic(
              focusNode: focusNode,
              controller: quillController,
              scrollController: scrollController,
              config: const quill.QuillEditorConfig(
                padding: EdgeInsets.fromLTRB(12, 4, 12, 16),
                placeholder: 'Start typing...',
                autoFocus: false,
                expands: false,
              ),
            ),
          ),
          if (locked)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: overlayColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        'Locked',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PdfAttachmentViewer extends StatelessWidget {
  const _PdfAttachmentViewer({required this.path, required this.title});

  final String path;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SfPdfViewer.file(File(path)),
    );
  }
}

class _VideoPlayerScreen extends StatefulWidget {
  const _VideoPlayerScreen({required this.path, required this.title});

  final String path;
  final String title;

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late final VideoPlayerController _controller;
  ChewieController? _chewie;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path))
      ..initialize().then((_) {
        _chewie = ChewieController(videoPlayerController: _controller);
        if (mounted) setState(() => _ready = true);
      });
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: _ready && _chewie != null
            ? Chewie(controller: _chewie!)
            : const CircularProgressIndicator(),
      ),
    );
  }
}

class _AudioPlayerScreen extends StatefulWidget {
  const _AudioPlayerScreen({required this.path, required this.title});

  final String path;
  final String title;

  @override
  State<_AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<_AudioPlayerScreen> {
  late final AudioPlayer _player;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _loading = true;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _init();
  }

  Future<void> _init() async {
    await _player.setSourceDeviceFile(widget.path);
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playing = state == PlayerState.playing);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = Duration.zero);
    });
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final total = _duration.inMilliseconds == 0 ? 1 : _duration.inMilliseconds;
    final value = total == 0 ? 0.0 : _position.inMilliseconds / total;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audio preview',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),
            Center(
              child: IconButton(
                iconSize: 62,
                color: colors.primary,
                icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle),
                onPressed: _loading
                    ? null
                    : () async {
                        if (_playing) {
                          await _player.pause();
                        } else {
                          await _player.resume();
                        }
                      },
              ),
            ),
            const SizedBox(height: 12),
            Slider(
              value: value.clamp(0.0, 1.0),
              onChanged: _loading || _duration.inMilliseconds == 0
                  ? null
                  : (v) => _player.seek(
                        Duration(
                          milliseconds:
                              (_duration.inMilliseconds * v).round(),
                        ),
                      ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatTime(_position)),
                Text(_formatTime(_duration)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    super.key,
    required this.draft,
    required this.index,
    this.onPreview,
    this.onLongPress,
  });

  final _AttachmentDraft draft;
  final VoidCallback? onPreview;
  final VoidCallback? onLongPress;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isImage = _AttachmentTile._isImageExt(draft.extension);
    final hasThumb = draft.thumbnailPath != null &&
        draft.thumbnailPath!.isNotEmpty &&
        File(draft.thumbnailPath!).existsSync();
    final icon = _iconForExt(draft.extension);
    final sizeLabel = draft.sizeBytes != null ? _AttachmentDraft.formatSize(draft.sizeBytes!) : null;

    Widget preview;
    if (hasThumb) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(draft.thumbnailPath!),
          width: 60,
          height: 60,
          fit: BoxFit.cover,
        ),
      );
    } else if (isImage && File(draft.localPath).existsSync()) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(draft.localPath),
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          cacheWidth: 180,
        ),
      );
    } else {
      preview = Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: colors.onSurfaceVariant),
      );
    }

    return Material(
      key: key,
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPreview,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              preview,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Chip(
                          label: Text(draft.type.toUpperCase()),
                          visualDensity: const VisualDensity(
                            horizontal: -2,
                            vertical: -2,
                          ),
                        ),
                        if (sizeLabel != null)
                          Chip(
                            label: Text(sizeLabel),
                            visualDensity: const VisualDensity(
                              horizontal: -2,
                              vertical: -2,
                            ),
                          ),
                      ],
                    ),
                    if (draft.progress < 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: draft.progress <= 0 ? null : draft.progress,
                                minHeight: 6,
                                backgroundColor: colors.surfaceVariant,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              draft.uploading
                                  ? 'Uploading ${(draft.progress * 100).clamp(0, 100).toStringAsFixed(0)}%'
                                  : 'Processing…',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      draft.extension.toUpperCase(),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Open',
                onPressed: onPreview,
                icon: const Icon(Icons.open_in_new_outlined),
              ),
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.drag_handle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _isImageExt(String ext) =>
      const {'png', 'jpg', 'jpeg', 'webp', 'gif'}.contains(ext);

  static IconData _iconForExt(String ext) {
    if (_isImageExt(ext)) {
      return Icons.image_outlined;
    }
    if (ext == 'pdf') {
      return Icons.picture_as_pdf_outlined;
    }
    if (ext == 'mp3' || ext == 'wav' || ext == 'm4a' || ext == 'aac') {
      return Icons.audiotrack_outlined;
    }
    if (ext == 'mp4' || ext == 'mov' || ext == 'avi') {
      return Icons.videocam_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }
}

class _QuickInsertButton extends StatelessWidget {
  const _QuickInsertButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _BottomToolbar extends StatelessWidget {
  const _BottomToolbar({
    required this.controller,
    required this.onMore,
    required this.onLink,
  });

  final quill.QuillController controller;
  final VoidCallback onMore;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _ToolbarButton(
              icon: Icons.format_bold,
              tooltip: 'Bold',
              color: color,
              onTap: () => controller.formatSelection(quill.Attribute.bold),
            ),
            _ToolbarButton(
              icon: Icons.format_italic,
              tooltip: 'Italic',
              color: color,
              onTap: () => controller.formatSelection(quill.Attribute.italic),
            ),
            _ToolbarButton(
              icon: Icons.format_underline,
              tooltip: 'Underline',
              color: color,
              onTap: () =>
                  controller.formatSelection(quill.Attribute.underline),
            ),
            _ToolbarButton(
              icon: Icons.format_list_bulleted,
              tooltip: 'List',
              color: color,
              onTap: () {
                final attributes = controller.getSelectionStyle().attributes;
                if (attributes.containsKey(quill.Attribute.ul.key)) {
                  controller.formatSelection(
                    quill.Attribute.clone(quill.Attribute.ul, null),
                  );
                } else {
                  controller.formatSelection(quill.Attribute.ul);
                }
              },
            ),
            _ToolbarButton(
              icon: Icons.link,
              tooltip: 'Link',
              color: color,
              onTap: onLink,
            ),
            _ToolbarButton(
              icon: Icons.more_horiz,
              tooltip: 'More',
              color: color,
              onTap: onMore,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}

class _EditorSkeleton extends StatelessWidget {
  const _EditorSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ShimmerSkeleton(width: 200, height: 28),
          SizedBox(height: 12),
          ShimmerSkeleton(width: 140, height: 18),
          SizedBox(height: 20),
          ShimmerSkeleton(height: 200, borderRadius: 16),
          SizedBox(height: 20),
          ShimmerSkeleton(width: 100, height: 18),
          SizedBox(height: 12),
          ShimmerSkeleton(height: 72, borderRadius: 12),
        ],
      ),
    );
  }
}

class _AttachmentDraft {
  final String key;
  final String localPath;
  final String extension;
  final String type;
  final int? sizeBytes;
  double progress;
  bool uploading;
  String name;
  String? thumbnailPath;

  _AttachmentDraft({
    required this.localPath,
    required this.name,
    required this.extension,
    required this.type,
    this.sizeBytes,
    this.progress = 1,
    this.uploading = false,
    this.thumbnailPath,
    String? keyOverride,
  }) : key =
            keyOverride ?? '${DateTime.now().microsecondsSinceEpoch}_${name.hashCode}';

  static _AttachmentDraft fromEntity(AttachmentEntity e) => _AttachmentDraft(
        localPath: e.localPath,
        name: e.name,
        extension: e.extension.toLowerCase(),
        type: e.type,
        sizeBytes: (() {
          try {
            return File(e.localPath).lengthSync();
          } catch (_) {
            return null;
          }
        })(),
        progress: 1,
      );

  _AttachmentDraft copyWith({
    String? name,
    double? progress,
    bool? uploading,
    String? thumbnailPath,
    int? sizeBytes,
  }) =>
      _AttachmentDraft(
        localPath: localPath,
        name: name ?? this.name,
        extension: extension,
        type: type,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        progress: progress ?? this.progress,
        uploading: uploading ?? this.uploading,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        keyOverride: key,
      );

  AttachmentEntity toEntity({required int noteId, required int sortIndex}) =>
      AttachmentEntity(
        id: null,
        noteId: noteId,
        name: name,
        localPath: localPath,
        extension: extension,
        type: type,
        sortIndex: sortIndex,
        mime: null,
      );

  static String inferType(String ext) {
    if (_AttachmentTile._isImageExt(ext)) {
      return 'image';
    }
    if (ext == 'pdf') {
      return 'pdf';
    }
    if (ext == 'mp3' || ext == 'wav' || ext == 'm4a' || ext == 'aac') {
      return 'audio';
    }
    if (_videoExts.contains(ext)) {
      return 'video';
    }
    return 'file';
  }

  bool get isVideo => _videoExts.contains(extension) || type == 'video';
  bool get isAudio =>
      type == 'audio' || const {'mp3', 'wav', 'm4a', 'aac'}.contains(extension);

  static const Set<String> _videoExts = {'mp4', 'mov', 'avi', 'mkv'};

  static String formatSize(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    if (bytes < kb) return '$bytes B';
    if (bytes < mb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    return '${(bytes / mb).toStringAsFixed(1)} MB';
  }
}
