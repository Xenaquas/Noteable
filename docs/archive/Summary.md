# Digital Memory – App Summary

## Architecture & State
- Flutter + Riverpod (StateNotifier, ChangeNotifier) for app settings, home, search.
- Data via sqflite `AppDatabase` with `NoteRepository` emitting change stream; entities for notes and attachments.
- Theming from `AppTheme` with DynamicColor, Google Fonts, canvas/text/highlight overrides; localization delegates for en/es/fr/de/zh/hi.

## Screens & Navigation
- Home (`HomeScreen`): rail/drawer navigation (Notes, Tasks, Schedule, History, Settings, About), grid/list toggle, sort sheet, search action, FAB to editor. Auto-lock on resume using biometrics/timer; locked notes require auth before open.
- Note Editor (`NoteEditorScreen`): create/edit notes with Quill rich text, title/category, lock toggle, attachments picker, save/upsert with attachment replacement.
- Search (`SearchScreen`): debounced search over title/plain text; tap to open editor.
- Settings (`SettingsScreen`): appearance (theme mode, language, font family/size, canvas/text color, highlight swatch), privacy (biometric lock, keep screen on, auto-lock timer), backup/storage (export all notes zip, export single note, restore zip, PDF placeholder), About/licensing.
- About (`AboutScreen`): brand, version, licenses.

## Key Widgets & UI Patterns
- `NoteCard`: title + category chip, preview/lock overlay, pin icon, attachment pills. Grid/list layouts with responsive columns.
- Navigation rail + drawer variants; secondary placeholder panel on wide screens.
- Settings uses segmented buttons, dropdowns, sliders, color dots, bottom sheets (timers/note picker), dialogs (color picker), snackbars for feedback.

## Core Features
- Notes: rich-text stored as delta JSON + plain text, categories (Personal/Work/Ideas), pin/lock flags, timestamps. Attachments (images/audio/video/docs) with typed pills and replace-all save.
- Home behaviors: persisted sort/view prefs; live refresh on repo change; authentication gate on locked notes; biometric auto-lock after background + configurable minutes.
- Appearance: system/light/dark theme, custom canvas/text/highlight colors, Google Font choice and scale applied app-wide.
- Localization: selectable locale from supported set; Material/Cupertino/Quill delegates wired.
- Privacy: biometric lock toggle with device capability check; keep-screen-on via wakelock; auto-lock timer.
- Backup/Restore: export all notes to JSON zipped and shared; export single note via picker; restore notes from selected zip.

## User Story (happy path)
1. I open Home and see my notes grid sorted by last updated; I can switch to list, change sort, or search.
2. Locked notes show a blur; tapping prompts biometric auth before opening.
3. I create/edit a note with rich text, choose category, add attachments, optionally lock it, and save.
4. In Settings, I switch theme (system/light/dark), choose language, set Google Font and size, tweak canvas/text/highlight colors, and keep the screen awake. I enable biometric lock and set an auto-lock timer.
5. I back up all notes (or a specific note) to a zip and can restore from a saved zip. About shows version and licenses.

## File Map (high level)
- `lib/app/app.dart` – MaterialApp with themes/locales and root routing.
- `lib/core/themes/app_theme.dart` – light/dark builders with font/scale/color overrides.
- `lib/presentation/views/home/home_screen.dart` + `view_models/home_vm.dart` – home shell, sorting/view prefs, auth gating.
- `lib/presentation/views/note_editor/note_editor_screen.dart` – editor flow with attachments and locking.
- `lib/presentation/views/search/search_screen.dart` + `view_models/search_vm.dart` – search.
- `lib/presentation/views/settings/settings_screen.dart` + `view_models/app_settings_vm.dart` + `data/sources/settings_local_source.dart` – settings state and persistence.
- `lib/core/services/backup_service.dart` – export/restore helpers.
- `lib/core/services/auth_service.dart` – biometric availability/auth wrapper.
