import 'package:go_router/go_router.dart';

import '../presentation/views/home/home_screen.dart';
import '../presentation/views/note_editor/note_editor_screen.dart';
import '../presentation/views/search/search_screen.dart';
import '../presentation/views/settings/settings_screen.dart';

GoRouter buildRouter() {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (_, __) => const SearchScreen(),
      ),
      GoRoute(
        path: '/editor/:id',
        builder: (_, state) {
          final id = int.parse(state.pathParameters['id']!);
          return NoteEditorScreen(noteId: id);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
    ],
  );
}
