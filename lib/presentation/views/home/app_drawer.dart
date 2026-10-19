import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const _DrawerHeader(),
            const Divider(height: 0),
            _DrawerItem(
              icon: Icons.note_outlined,
              title: 'Notes',
              onTap: () => context.go('/'),
            ),
            _DrawerItem(
              icon: Icons.check_circle_outline,
              title: 'Task',
              onTap: () {
                // TODO: later route: /tasks
              },
            ),
            _DrawerItem(
              icon: Icons.calendar_today_outlined,
              title: 'Schedule',
              onTap: () {
                // TODO: later route: /schedule
              },
            ),
            _DrawerItem(
              icon: Icons.history,
              title: 'History',
              onTap: () {
                // TODO: later route: /history
              },
            ),
            const Divider(height: 0),
            _DrawerItem(
              icon: Icons.settings_outlined,
              title: 'Settings',
              onTap: () => context.push('/settings'),
            ),
            _DrawerItem(
              icon: Icons.info_outline,
              title: 'About',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Second Brain',
                  applicationVersion: '1.0.0',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [cs.primary, cs.primaryContainer],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 40),
          const SizedBox(height: 12),
          Text(
            'Digital Memory',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your notes, not your chaos.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }
}
