import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Digital Memory',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            _item(context, Icons.note_rounded, 'Notes', '/', selected: true),
            _item(context, Icons.check_circle_outline, 'Tasks', '/'),
            _item(context, Icons.calendar_month, 'Schedule', '/'),
            _item(context, Icons.history, 'History', '/'),
            const Divider(),
            _item(context, Icons.settings, 'Settings', '/settings'),
            _item(context, Icons.info_outline, 'About', '/'),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String title,
    String route, {
    bool selected = false,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: selected,
      onTap: () {
        Navigator.pop(context);
        if (route != '/') context.go(route);
        if (route == '/') context.go('/');
      },
    );
  }
}
