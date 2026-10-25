import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../view_models/di.dart';

import '../../../core/services/backup_service.dart';
import '../../../domain/entities/note_entity.dart';
import '../../view_models/app_settings_vm.dart';
import 'notification_center_screen.dart';

const _supportedLocales = [
  Locale('en'),
  Locale('es'),
  Locale('fr'),
  Locale('de'),
  Locale('zh'),
  Locale('hi'),
];

const Map<String, String> _localeLabels = {
  'en': 'English',
  'es': 'Spanish',
  'fr': 'French',
  'de': 'German',
  'zh': 'Chinese',
  'hi': 'Hindi',
};

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _voice = 'Ryan (US)';
  String _autoBackup = 'Off';

  void _showNotificationChannelsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notification channels',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Critical alarms'),
                subtitle: const Text('Sound + vibration'),
                trailing: const Icon(Icons.info_outline),
                onTap: () => _showNotificationSettingsHint(
                  context,
                  title: 'Critical alarms',
                  body:
                      'Open system Settings → Apps → Digital Memory → Notifications to customize critical alarms.',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_none_outlined),
                title: const Text('Standard reminders'),
                subtitle: const Text('Silent alerts'),
                trailing: const Icon(Icons.info_outline),
                onTap: () => _showNotificationSettingsHint(
                  context,
                  title: 'Standard reminders',
                  body:
                      'Open system Settings → Apps → Digital Memory → Notifications to customize standard reminders.',
                ),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => _showNotificationSettingsHint(
                  context,
                  title: 'Notification settings',
                  body:
                      'Open system Settings → Apps → Digital Memory → Notifications.',
                ),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('How to open settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationSettingsHint(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final vm = ref.read(appSettingsProvider.notifier);
    final headline = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: headline),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            sliver: SliverList.list(
              children: [
                _SectionHeader(label: 'App'),
                _GroupCard(
                  children: [
                    _ActionTile(
                      icon: Icons.notifications_outlined,
                      title: 'Notification Center',
                      subtitle: 'Reminders, alerts, and badges',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationCenterScreen(),
                        ),
                      ),
                    ),
                    _ActionTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'Notification Channels',
                      subtitle: 'Critical alarms vs silent reminders',
                      onTap: () => _showNotificationChannelsSheet(context),
                    ),
                    _ActionTile(
                      icon: Icons.language,
                      title: 'Language',
                      trailing: Text(
                        _localeLabels[settings.locale.languageCode] ?? 'System',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      onTap: () => _showLanguageSheet(context, vm, settings),
                    ),
                    _ActionTile(
                      icon: Icons.dark_mode_outlined,
                      title: 'Theme',
                      trailing: Text(
                        _themeLabel(settings.themeMode),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      onTap: () => _showThemeSheet(context, vm, settings),
                    ),
                    _ActionTile(
                      icon: Icons.record_voice_over_outlined,
                      title: 'Voice',
                      trailing: Text(_voice),
                      onTap: () => _showVoiceSheet(context),
                    ),
                    _ActionTile(
                      icon: Icons.font_download_outlined,
                      title: 'Font Family',
                      trailing: Text(settings.fontFamily),
                      onTap: () => _showFontFamilySheet(context, vm, settings),
                    ),
                    _ActionTile(
                      icon: Icons.text_fields,
                      title: 'Font Size',
                      trailing:
                          Text('${(settings.fontSizeScale * 100).round()}%'),
                      onTap: () => _showFontSizeSheet(context, vm, settings),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionHeader(label: 'Privacy & Security'),
                _GroupCard(
                  children: [
                    _SwitchTile(
                      icon: Icons.lock_outline,
                      title: 'App Lock (PIN / device)',
                      value: settings.isBiometricEnabled,
                      onChanged: (enabled) async {
                        final lock = ref.read(lockServiceProvider);
                        final ok = enabled
                            ? await lock.configureAppProtection(context)
                            : await lock.authenticate(context: context, reason: 'Disable app lock');
                        if (ok) await vm.setBiometricEnabled(enabled);
                      },
                    ),
                    _ActionTile(
                      icon: Icons.timer_outlined,
                      title: 'Auto-lock Timer',
                      trailing: Text(settings.autoLockMinutes == 0
                          ? 'Off'
                          : '${settings.autoLockMinutes} min'),
                      onTap: () => _showAutoLockSheet(context, vm, settings),
                    ),
                    _SwitchTile(
                      icon: Icons.phone_android,
                      title: 'Keep Screen On',
                      value: settings.keepScreenOn,
                      onChanged: (v) => vm.setKeepScreenOn(v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionHeader(label: 'Backup & Storage'),
                _GroupCard(
                  children: [
                    _ActionTile(
                      icon: Icons.file_upload_outlined,
                      title: 'Create Backup',
                      subtitle: 'Local ZIP',
                      onTap: () => _handleExportAll(),
                    ),
                    _ActionTile(
                      icon: Icons.note_alt_outlined,
                      title: 'Export Single Note',
                      onTap: () => _handleExportSingleNote(),
                    ),
                    _ActionTile(
                      icon: Icons.file_download_outlined,
                      title: 'Restore from File',
                      onTap: () => _handleRestore(),
                    ),
                    _ActionTile(
                      icon: Icons.backup_outlined,
                      title: 'Auto Backup',
                      trailing: Text(_autoBackup),
                      onTap: () => _showAutoBackupSheet(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionHeader(label: 'About'),
                _GroupCard(
                  children: [
                    _ActionTile(
                      icon: Icons.info_outline,
                      title: 'App Version',
                      trailing: const Text('1.4.0 (142)'),
                    ),
                    _ActionTile(
                      icon: Icons.system_update_alt_outlined,
                      title: 'Check for Updates',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showSnack('You are up to date'),
                    ),
                    _ActionTile(
                      icon: Icons.star_rate_outlined,
                      title: 'Rate on Play Store',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showSnack('Opening store soon'),
                    ),
                    _ActionTile(
                      icon: Icons.favorite_outline,
                      title: 'Made with ?? in Flutter',
                    ),
                    _ActionTile(
                      icon: Icons.article_outlined,
                      title: 'Licenses',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showLicensePage(context: context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor:
                        Theme.of(context).colorScheme.onErrorContainer,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _showSnack('Logged out'),
                  icon: const Icon(Icons.logout),
                  label: const Text('Log Out'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  Locale _resolveLocale(Locale locale) {
    return _supportedLocales.firstWhere(
      (l) => l.languageCode == locale.languageCode,
      orElse: () => const Locale('en'),
    );
  }

  Future<void> _handleExportAll() async {
    try {
      final notes = await ref.read(noteRepoProvider).listNotes();
      if (notes.any((note) => note.isLocked)) {
        _showSnack('Backup with private notes is unavailable until encrypted backup is implemented.');
        return;
      }
      await ref.read(backupServiceProvider).exportAllNotes();
      _showSnack('Export successful');
    } catch (e) {
      _showSnack('Export failed: $e');
    }
  }

  Future<void> _handleRestore() async {
    try {
      await ref.read(backupServiceProvider).restoreFromBackup();
      _showSnack('Restore successful');
    } catch (e) {
      _showSnack('Restore failed: $e');
    }
  }

  Future<void> _handleExportSingleNote() async {
    try {
      final notes = (await ref.read(backupServiceProvider).listNotes())
          .where((note) => !note.isLocked).toList();
      if (!mounted) return;
      if (notes.isEmpty) {
        _showSnack('No notes to export yet.');
        return;
      }
      final picked = await _pickNote(notes);
      if (picked == null) return;
      await ref.read(backupServiceProvider).exportNote(picked);
      _showSnack('Note exported');
    } catch (e) {
      _showSnack('Export failed: $e');
    }
  }

  Future<NoteEntity?> _pickNote(List<NoteEntity> notes) async {
    return showModalBottomSheet<NoteEntity>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final height =
            notes.length > 6 ? 360.0 : (notes.length * 64 + 120).toDouble();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Select a note',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  height: height.clamp(220.0, 420.0).toDouble(),
                  child: ListView.separated(
                    itemCount: notes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final note = notes[i];
                      final title =
                          note.title.isEmpty ? 'Untitled note' : note.title;
                      return ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(note.category),
                        trailing: Text(
                          DateFormat('MMM d').format(note.updatedAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onTap: () => Navigator.pop(context, note),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showLanguageSheet(
    BuildContext context,
    AppSettingsViewModel vm,
    AppSettingsState settings,
  ) async {
    final selected = await showModalBottomSheet<Locale>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RadioSheet<Locale>(
        title: 'Language',
        options: _supportedLocales,
        selected: _resolveLocale(settings.locale),
        labelBuilder: (loc) =>
            _localeLabels[loc.languageCode] ?? loc.languageCode,
      ),
    );
    if (selected != null) vm.setLocale(selected);
  }

  Future<void> _showThemeSheet(
    BuildContext context,
    AppSettingsViewModel vm,
    AppSettingsState settings,
  ) async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RadioSheet<ThemeMode>(
        title: 'Appearance',
        options: const [
          ThemeMode.system,
          ThemeMode.light,
          ThemeMode.dark,
        ],
        selected: settings.themeMode,
        labelBuilder: _themeLabel,
      ),
    );
    if (selected != null) vm.setThemeMode(selected);
  }

  Future<void> _showVoiceSheet(BuildContext context) async {
    final voices = ['Ryan (US)', 'Ava (UK)', 'Mira (IN)', 'Alex (System)'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RadioSheet<String>(
        title: 'Voice',
        options: voices,
        selected: _voice,
        labelBuilder: (s) => s,
      ),
    );
    if (selected != null) {
      setState(() => _voice = selected);
      _showSnack('Voice set to $selected');
    }
  }

  Future<void> _showFontFamilySheet(
    BuildContext context,
    AppSettingsViewModel vm,
    AppSettingsState settings,
  ) async {
    final families = [
      'Inter',
      'Roboto',
      'Open Sans',
      'Lato',
      'Montserrat',
      'Poppins',
      'Merriweather',
    ];
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RadioSheet<String>(
        title: 'Font Family',
        options: families,
        selected: settings.fontFamily,
        labelBuilder: (s) => s,
        subtitleBuilder: (s) => GoogleFonts.getFont(s).fontFamily ?? s,
      ),
    );
    if (selected != null) vm.setFontFamily(selected);
  }

  Future<void> _showFontSizeSheet(
    BuildContext context,
    AppSettingsViewModel vm,
    AppSettingsState settings,
  ) async {
    final double? picked = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        double temp = settings.fontSizeScale;
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 20,
                right: 20,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Font Size',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, temp),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Preview',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Second Brain',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 18 * temp,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: temp,
                    min: 0.8,
                    max: 1.4,
                    divisions: 6,
                    label: '${(temp * 100).round()}%',
                    onChanged: (v) => setState(() => temp = v),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
    if (picked != null) vm.setFontSizeScale(picked);
  }


  Future<void> _showAutoLockSheet(
    BuildContext context,
    AppSettingsViewModel vm,
    AppSettingsState settings,
  ) async {
    final options = [0, 1, 3, 5, 10];
    final selected = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RadioSheet<int>(
        title: 'Auto-lock Timer',
        options: options,
        selected: settings.autoLockMinutes,
        labelBuilder: (m) => m == 0 ? 'Off' : '$m min',
      ),
    );
    if (selected != null) vm.setAutoLockMinutes(selected);
  }

  Future<void> _showAutoBackupSheet(BuildContext context) async {
    final options = ['Off', 'Daily', 'Weekly'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RadioSheet<String>(
        title: 'Auto Backup',
        options: options,
        selected: _autoBackup,
        labelBuilder: (s) => s,
      ),
    );
    if (selected != null) {
      setState(() => _autoBackup = selected);
      _showSnack('Auto backup set to $selected');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                thickness: 0.5,
                color: colors.outlineVariant.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colors.primary.withValues(alpha: 0.12),
              child: Icon(icon, color: colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ],
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.chevron_right, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colors.secondaryContainer,
            child: Icon(icon, color: colors.onSecondaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}


class _RadioSheet<T> extends StatelessWidget {
  const _RadioSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.labelBuilder,
    this.subtitleBuilder,
  });

  final String title;
  final List<T> options;
  final T selected;
  final String Function(T) labelBuilder;
  final String Function(T)? subtitleBuilder;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxHeight,
              maxWidth: constraints.maxWidth,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, selected),
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...options.map(
                    (o) => RadioListTile<T>(
                      value: o,
                      groupValue: selected,
                      onChanged: (v) => Navigator.pop(context, v),
                      title: Text(labelBuilder(o)),
                      subtitle: subtitleBuilder != null
                          ? Text(subtitleBuilder!(o))
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


class BlockPicker extends StatelessWidget {
  const BlockPicker({
    super.key,
    required this.pickerColor,
    required this.onColorChanged,
  });

  final Color pickerColor;
  final ValueChanged<Color> onColorChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _swatches
          .map(
            (c) => GestureDetector(
              onTap: () => onColorChanged(c),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c.toARGB32() == pickerColor.toARGB32()
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade400,
                    width: c.toARGB32() == pickerColor.toARGB32() ? 2 : 1,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

const _swatches = [
  Color(0xFFFFFFFF),
  Color(0xFFF5F5F5),
  Color(0xFFE8ECEF),
  Color(0xFFDCE5F5),
  Color(0xFFC8E6C9),
  Color(0xFFFFECB3),
  Color(0xFFFFCDD2),
  Color(0xFF000000),
  Color(0xFF1F2933),
  Color(0xFF374151),
  Color(0xFF4B5563),
  Color(0xFF6B7280),
];
