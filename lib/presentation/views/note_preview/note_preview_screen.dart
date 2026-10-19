import 'dart:convert';
import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
// ignore: depend_on_referenced_packages
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive_io.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import '../../../data/local/databases/app_drift_database.dart';
import '../../../domain/entities/attachment_entity.dart';
import '../../../domain/entities/note_entity.dart';
import '../../view_models/di.dart';
import '../note_editor/note_editor_screen.dart';
import '../../widgets/shimmer_skeleton.dart';

class NotePreviewScreen extends ConsumerStatefulWidget {
  const NotePreviewScreen({
    super.key,
    required this.noteId,
    this.heroTag,
    this.skipLockCheck = false,
  });

  final int noteId;
  final String? heroTag;
  final bool skipLockCheck;

  @override
  ConsumerState<NotePreviewScreen> createState() => _NotePreviewScreenState();
}

class _NotePreviewScreenState extends ConsumerState<NotePreviewScreen> {
  bool _loading = true;
  NoteEntity? _note;
  List<AttachmentEntity> _attachments = const [];
  quill.QuillController? _controller;
  final FocusNode _readOnlyFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _controller?.dispose();
    _readOnlyFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(noteRepoProvider);
    final note = await repo.getNote(widget.noteId);

    if (!mounted) return;
    if (note == null) {
      setState(() => _loading = false);
      return;
    }

    if (note.isLocked && !widget.skipLockCheck) {
      final ok = await ref.read(lockServiceProvider).authenticate(
            context: context,
            reason: 'Unlock note to preview',
          );
      if (!ok) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
    }

    final attachments = await repo.listAttachments(note.id!);
    final doc = await _decodeDocument(note.contentJson);
    final controller = quill.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );

    if (!mounted) return;
    setState(() {
      _note = note;
      _attachments = attachments;
      _controller?.dispose();
      _controller = controller;
      _loading = false;
    });
  }

  Future<quill.Document> _decodeDocument(String? json) async {
    return compute(_decodeDoc, json);
  }

  static quill.Document _decodeDoc(String? json) {
    try {
      if (json == null || json.isEmpty) {
        return quill.Document();
      }
      return quill.Document.fromJson(jsonDecode(json));
    } catch (_) {
      return quill.Document()..insert(0, '');
    }
  }

  Future<void> _share() async {
    if (_note == null) return;
    await _shareOptions();
  }

  Future<void> _print() async {
    if (_note == null) return;
    await Printing.layoutPdf(
      onLayout: (format) async {
        final doc = pw.Document();
        doc.addPage(
          pw.Page(
            build: (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(_note!.title,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    )),
                pw.SizedBox(height: 12),
                pw.Text(_note!.contentPlain),
              ],
            ),
          ),
        );
        return doc.save();
      },
    );
  }

  Future<void> _openEditor() async {
    if (_note == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          noteId: _note!.id,
          heroTag: widget.heroTag,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _load();
    }
  }

  Future<void> _setReminder() async {
    final note = _note;
    if (note == null || note.id == null) return;
    final fireAt = await _pickReminderDateTime();
    if (fireAt == null) return;
    if (fireAt.isBefore(DateTime.now())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder time must be in the future.')),
      );
      return;
    }
    await _cancelNoteReminders(note.id!);
    final reminderId = await ref.read(reminderRepoProvider).insert(
          ownerType: 'note',
          ownerId: note.id!,
          fireAtUtc: fireAt.toUtc(),
        );
    await ref.read(notificationSyncServiceProvider).scheduleReminder(
          Reminder(
            id: reminderId,
            ownerType: 'note',
            ownerId: note.id!,
            fireAt: fireAt.toUtc(),
            status: kReminderScheduled,
            notificationId: null,
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
          title: 'Note reminder',
          body: "Note '${_noteTitle(note)}' is due now!",
        );
    if (!mounted) return;
    final label =
        '${fireAt.month}/${fireAt.day} ${TimeOfDay.fromDateTime(fireAt).format(context)}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reminder set for $label.')),
    );
  }

  Future<DateTime?> _pickReminderDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (date == null) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _cancelNoteReminders(int noteId) async {
    final reminders = await ref
        .read(reminderRepoProvider)
        .forOwner(ownerType: 'note', ownerId: noteId);
    for (final r in reminders) {
      final idInt = int.tryParse(r.notificationId ?? '') ?? r.id;
      await ref.read(notificationSyncServiceProvider).cancelReminder(idInt);
      await ref.read(reminderRepoProvider).delete(r.id);
    }
  }

  String _noteTitle(NoteEntity note) {
    final title = note.title.trim();
    return title.isEmpty ? 'Untitled note' : title;
  }

  Future<void> _shareOptions() async {
    if (_note == null) return;
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
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Share as PDF (content only)'),
              onTap: () async {
                Navigator.pop(ctx);
                final file = await _buildPdf();
                if (file != null) {
                  // ignore: deprecated_member_use
                  await Share.shareXFiles([XFile(file.path)], subject: _note!.title);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Share with attachments (ZIP)'),
              onTap: () async {
                Navigator.pop(ctx);
                final file = await _buildZip();
                if (file != null) {
                  // ignore: deprecated_member_use
                  await Share.shareXFiles([XFile(file.path)], subject: _note!.title);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<File?> _buildPdf() async {
    if (_note == null) return null;
    final pdf = pw.Document();
    final text = _note!.contentPlain.trim().isEmpty
        ? 'No content'
        : _note!.contentPlain.trim();
    final updatedLabel =
        '${_note!.updatedAt.year}-${_note!.updatedAt.month.toString().padLeft(2, '0')}-${_note!.updatedAt.day.toString().padLeft(2, '0')}';
    pdf.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              _note!.title.isEmpty ? 'Untitled note' : _note!.title,
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text('Category: ${_note!.category}'),
            pw.Text('Updated: $updatedLabel'),
            pw.SizedBox(height: 16),
            pw.Text(text),
          ],
        ),
      ),
    );
    final dir = await getTemporaryDirectory();
    final nameSafe =
        (_note!.title.isEmpty ? 'note' : _note!.title).replaceAll(RegExp(r'[^a-zA-Z0-9-_ ]'), '_');
    final file = File('${dir.path}/$nameSafe.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<File?> _buildZip() async {
    if (_note == null) return null;
    final pdfFile = await _buildPdf();
    if (pdfFile == null) return null;
    final archive = Archive();
    archive.addFile(
      ArchiveFile(
        pdfFile.uri.pathSegments.last,
        pdfFile.lengthSync(),
        pdfFile.readAsBytesSync(),
      ),
    );

    for (final a in _attachments) {
      if (a.localPath.isEmpty || !File(a.localPath).existsSync()) continue;
      final data = File(a.localPath).readAsBytesSync();
      archive.addFile(ArchiveFile(a.name, data.length, data));
    }

    final bytes = ZipEncoder().encode(archive);
    if (bytes == null) return null;
    final dir = await getTemporaryDirectory();
    final nameSafe =
        (_note!.title.isEmpty ? 'note' : _note!.title).replaceAll(RegExp(r'[^a-zA-Z0-9-_ ]'), '_');
    final zipFile = File('${dir.path}/$nameSafe-${DateTime.now().millisecondsSinceEpoch}.zip')
      ..writeAsBytesSync(bytes);
    return zipFile;
  }

  void _openAttachment(AttachmentEntity a) {
    final path = a.localPath;
    if (path.isEmpty || !File(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found')),
      );
      return;
    }
    final ext = a.extension.toLowerCase();
    if (_isImage(ext)) {
      _openImage(path, tag: 'att-${a.id}');
      return;
    }
    if (ext == 'pdf') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _PdfViewerScreen(path: path, title: a.name),
        ),
      );
      return;
    }
    if (_isVideo(ext)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _VideoPlayerPage(path: path, title: a.name),
        ),
      );
      return;
    }
    if (_isAudio(ext)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _AudioPlayerPage(path: path, title: a.name),
        ),
      );
      return;
    }
    OpenFile.open(path);
  }

  void _openImage(String path, {String? tag}) {
    showGeneralDialog(
      context: context,
      barrierLabel: 'image',
      barrierDismissible: true,
      pageBuilder: (_, __, ___) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: Colors.black.withValues(alpha: 0.85),
            alignment: Alignment.center,
            child: Hero(
              tag: tag ?? path,
              child: InteractiveViewer(
                child: Image.file(File(path)),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Note preview'),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: _note == null || _loading ? null : _share,
          ),
          IconButton(
            tooltip: 'Print',
            icon: const Icon(Icons.print_outlined),
            onPressed: _note == null || _loading ? null : _print,
          ),
          IconButton(
            tooltip: 'Set reminder',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: _note == null || _loading ? null : _setReminder,
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _note == null || _loading ? null : _openEditor,
          ),
        ],
      ),
      floatingActionButton: _note == null || _loading
          ? null
          : FloatingActionButton(
              onPressed: _openEditor,
              tooltip: 'Edit note',
              child: const Icon(Icons.edit),
            ),
      body: SafeArea(
        child: _loading
            ? const _PreviewSkeleton()
            : _note == null
                ? const Center(child: Text('Note not found'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.heroTag != null)
                          Hero(
                            tag: widget.heroTag!,
                            flightShuttleBuilder: (_, animation, __, ___, ____) {
                              return FadeTransition(
                                opacity: animation.drive(
                                  CurveTween(curve: Curves.easeInOut),
                                ),
                                child: const SizedBox.expand(),
                              );
                            },
                            child: _PreviewShell(
                              note: _note!,
                              attachments: _attachments,
                              controller: _controller!,
                              onAttachmentTap: _openAttachment,
                              focusNode: _readOnlyFocus,
                              scrollController: _scrollController,
                            ),
                          )
                        else
                          _PreviewShell(
                            note: _note!,
                            attachments: _attachments,
                            controller: _controller!,
                            onAttachmentTap: _openAttachment,
                            focusNode: _readOnlyFocus,
                            scrollController: _scrollController,
                          ),
                        if (_attachments.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _AttachmentPreviewList(
                            attachments: _attachments,
                            onOpen: _openAttachment,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          'Read-only mode. Tap Edit to modify this note.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  static bool _isImage(String ext) =>
      const {'png', 'jpg', 'jpeg', 'webp', 'gif'}.contains(ext);
  static bool _isVideo(String ext) =>
      const {'mp4', 'mov', 'avi', 'mkv'}.contains(ext);
  static bool _isAudio(String ext) =>
      const {'mp3', 'wav', 'm4a', 'aac'}.contains(ext);
}

class _ThumbCache {
  _ThumbCache._();

  static final Map<String, Future<Uint8List?>> _cache = {};

  static Future<Uint8List?> get(String path) {
    return _cache.putIfAbsent(path, () async {
      if (!File(path).existsSync()) return null;
      return VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 160,
        quality: 55,
      );
    });
  }
}

class _PreviewShell extends StatelessWidget {
  const _PreviewShell({
    required this.note,
    required this.attachments,
    required this.controller,
    required this.onAttachmentTap,
    required this.focusNode,
    required this.scrollController,
  });

  final NoteEntity note;
  final List<AttachmentEntity> attachments;
  final quill.QuillController controller;
  final void Function(AttachmentEntity) onAttachmentTap;
  final FocusNode focusNode;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dateLabel = '${note.updatedAt.year}-${note.updatedAt.month.toString().padLeft(2, '0')}-${note.updatedAt.day.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  note.title.isEmpty ? 'Untitled' : note.title,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  note.category,
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.lock_outline,
                  size: 16,
                  color: note.isLocked ? colors.primary : colors.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                note.isLocked ? 'Locked' : 'Unlocked',
                style: textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Icon(Icons.schedule, size: 16, color: colors.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                dateLabel,
                style: textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (attachments.isNotEmpty) ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: attachments
                  .map(
                    (a) => ActionChip(
                      label: Text(_attachmentLabel(a)),
                      avatar: Icon(_attachmentIcon(a),
                          size: 18, color: colors.primary),
                      onPressed: () => onAttachmentTap(a),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
          ],
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: AbsorbPointer(
                child: quill.QuillEditor.basic(
                  focusNode: focusNode,
                  controller: controller,
                  scrollController: scrollController,
                  config: const quill.QuillEditorConfig(
                    padding: EdgeInsets.zero,
                    autoFocus: false,
                    expands: false,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _attachmentIcon(AttachmentEntity a) {
    final ext = a.extension.toLowerCase();
    if (const {'png', 'jpg', 'jpeg', 'webp', 'gif'}.contains(ext)) {
      return Icons.image_outlined;
    }
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    if (ext == 'mp3' || ext == 'wav' || ext == 'm4a') return Icons.audiotrack;
    if (ext == 'mp4' || ext == 'mov' || ext == 'avi') return Icons.videocam;
    return Icons.insert_drive_file_outlined;
  }

  String _attachmentLabel(AttachmentEntity a) {
    final ext = a.extension.toLowerCase();
    if (const {'png', 'jpg', 'jpeg', 'webp', 'gif'}.contains(ext)) {
      return 'Image';
    }
    if (ext == 'pdf') return 'PDF';
    if (ext == 'mp3' || ext == 'wav' || ext == 'm4a') return 'Audio';
    if (ext == 'mp4' || ext == 'mov' || ext == 'avi') return 'Video';
    return 'File';
  }
}

class _PdfViewerScreen extends StatelessWidget {
  const _PdfViewerScreen({required this.path, required this.title});

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

class _VideoPlayerPage extends StatefulWidget {
  const _VideoPlayerPage({required this.path, required this.title});

  final String path;
  final String title;

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
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

class _AudioPlayerPage extends StatelessWidget {
  const _AudioPlayerPage({required this.path, required this.title});

  final String path;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _AudioPreview(path: path, title: title),
      ),
    );
  }
}

class _AttachmentPreviewList extends StatelessWidget {
  const _AttachmentPreviewList({
    required this.attachments,
    required this.onOpen,
  });

  final List<AttachmentEntity> attachments;
  final void Function(AttachmentEntity) onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attachments',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Column(
          children: attachments
              .map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AttachmentCard(
                      entity: a,
                      colors: colors,
                      onOpen: onOpen,
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.entity,
    required this.colors,
    required this.onOpen,
  });

  final AttachmentEntity entity;
  final ColorScheme colors;
  final void Function(AttachmentEntity) onOpen;

  @override
  Widget build(BuildContext context) {
    final ext = entity.extension.toLowerCase();
    final isImage = const {'png', 'jpg', 'jpeg', 'gif', 'webp'}.contains(ext);
    final isVideo = const {'mp4', 'mov', 'avi'}.contains(ext);
    final isAudio = const {'mp3', 'wav', 'm4a'}.contains(ext);
    final isPdf = ext == 'pdf';

    Widget preview;
    if (isImage && File(entity.localPath).existsSync()) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(entity.localPath),
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    } else if (isVideo && File(entity.localPath).existsSync()) {
      preview = FutureBuilder<Uint8List?>(
        future: _ThumbCache.get(entity.localPath),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const AspectRatio(
              aspectRatio: 16 / 9,
              child: ShimmerSkeleton(),
            );
          }
          return Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  snap.data!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(12),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
              ),
            ],
          );
        },
      );
    } else if (isAudio) {
      preview = _AudioPreview(path: entity.localPath, title: entity.name);
    } else {
      preview = Container(
        height: 72,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              isPdf
                  ? Icons.picture_as_pdf_outlined
                  : isVideo
                      ? Icons.videocam_outlined
                      : isImage
                          ? Icons.image_outlined
                          : isAudio
                              ? Icons.audiotrack_outlined
                              : Icons.insert_drive_file_outlined,
              color: colors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entity.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      );
    }

    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onOpen(entity),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: preview,
              ),
              const SizedBox(height: 10),
              Text(
                entity.name,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                ext.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioPreview extends StatefulWidget {
  const _AudioPreview({required this.path, required this.title});

  final String path;
  final String title;

  @override
  State<_AudioPreview> createState() => _AudioPreviewState();
}

class _AudioPreviewState extends State<_AudioPreview> {
  late final AudioPlayer _player;
  bool _ready = false;
  bool _playing = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

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
      if (mounted) {
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }
    });
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _playing ? Icons.pause_circle : Icons.play_circle,
                  size: 34,
                  color: colors.primary,
                ),
                onPressed: !_ready
                    ? null
                    : () async {
                        if (_playing) {
                          await _player.pause();
                        } else {
                          await _player.resume();
                        }
                      },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: _duration.inMilliseconds == 0
                      ? 0.0
                      : (_position.inMilliseconds / _duration.inMilliseconds)
                          .clamp(0.0, 1.0)
                          .toDouble(),
                  onChanged: !_ready || _duration.inMilliseconds == 0
                      ? null
                      : (v) => _player.seek(
                            Duration(
                              milliseconds:
                                  (_duration.inMilliseconds * v).round(),
                            ),
                          ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewSkeleton extends StatelessWidget {
  const _PreviewSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerSkeleton(width: 160, height: 18),
          const SizedBox(height: 10),
          const ShimmerSkeleton(width: 80, height: 14),
          const SizedBox(height: 18),
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerSkeleton(width: 120, height: 16),
                const SizedBox(height: 8),
                const ShimmerSkeleton(width: 200, height: 14),
                const SizedBox(height: 16),
                const ShimmerSkeleton(height: 80),
                const Spacer(),
                const ShimmerSkeleton(width: 140, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
