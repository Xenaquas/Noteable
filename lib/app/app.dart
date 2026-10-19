import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/themes/app_theme.dart';
import '../presentation/view_models/di.dart';
import '../presentation/view_models/app_settings_vm.dart';
import '../presentation/views/home/home_screen.dart';
import '../presentation/widgets/in_app_reminder_host.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>();

class SecondBrainApp extends StatelessWidget {
  const SecondBrainApp({super.key});

  @override
  Widget build(BuildContext context) => const App();
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    // Initialize notification sync once (idempotent).
    ref.read(notificationSyncServiceProvider).init();

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp(
          title: 'Digital Memory',
          debugShowCheckedModeBanner: false,
          navigatorKey: _rootNavigatorKey,
          themeMode: settings.themeMode,
          theme: AppTheme.light(
            fontFamily: settings.fontFamily,
            fontSizeScale: settings.fontSizeScale,
            canvasColor: settings.canvasColor,
            textColor: settings.textColor,
            highlightColor: settings.highlightColor,
            colorScheme: lightDynamic,
          ),
          darkTheme: AppTheme.dark(
            fontFamily: settings.fontFamily,
            fontSizeScale: settings.fontSizeScale,
            canvasColor: settings.canvasColor,
            textColor: settings.textColor,
            highlightColor: settings.highlightColor,
            colorScheme: darkDynamic,
          ),

          // Fixes MissingFlutterQuillLocalizationException
          localizationsDelegates: const [
            FlutterQuillLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('es'),
            Locale('fr'),
            Locale('de'),
            Locale('zh'),
            Locale('hi'),
          ],
          locale: settings.locale,
          builder: (context, child) => InAppReminderHost(
            navigatorKey: _rootNavigatorKey,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}
