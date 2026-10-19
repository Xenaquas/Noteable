# Digital Memory — Dart and Flutter Code Review

> Review date: **19 October 2026**. All 65 Dart files under lib/ and test/ were inventoried and included in static analysis. There are 10 empty files and one generated Drift file.

## 1. Method and limits

This is a structural and behavior-path review, supported by analyzer output, the existing widget test, and Android runtime evidence. High-risk save, restore, delete, lock, task, reminder, and navigation paths were traced in source. The generated file was assessed through its schema, analyzer, and build rather than a manual line-by-line audit. UI variants and empty placeholders are recorded below. No claim is made that every branch or media/device combination ran.

The immutable baseline inventory records path, nonblank-line count, byte size, and SHA-256: [dart-file-inventory.json](evidence/dart-file-inventory.json). Line counts below are PowerShell nonblank-line counts, not physical source line totals.

## 2. Static analysis

The final analyzer run reports **29 issues: 6 warnings and 23 informational diagnostics, no analyzer errors**. The command exits unsuccessfully because diagnostics remain. Warnings include duplicate ignore comments, a redundant non-null assertion, a null comparison/dead branch, and an unused function. Info diagnostics include deprecated APIs and asynchronous BuildContext use. These are separate from the original third-party Quill compiler failure.

[Full analyzer log](evidence/logs/flutter-analyze-final.txt) · [Test failure](evidence/logs/flutter-test-after-compatibility.txt).

## 3. Every Dart file

| File | Nonblank lines | Role | Review note |
|---|---:|---|---|
| [lib/main.dart](../lib/main.dart) | 15 | Bootstrap | Preferences override is required for real startup and tests. |
| [lib/app/app.dart](../lib/app/app.dart) | 73 | App shell | MaterialApp, dynamic themes, framework/editor delegates, and reminder host; notification init is unawaited from build. F08/F15. |
| [lib/app/router.dart](../lib/app/router.dart) | 30 | Alternative navigation | GoRouter is defined but not installed in the active MaterialApp; not proof of working deep links. F16. |
| [lib/core/constants/app_constants.dart](../lib/core/constants/app_constants.dart) | 23 | Constants | Second Brain branding differs from Digital Memory; version is duplicated. F13/F17. |
| [lib/core/constants/database_constants.dart](../lib/core/constants/database_constants.dart) | 0 | Empty placeholder | No implementation; remove or clearly track as planned work. |
| [lib/core/services/auth_service.dart](../lib/core/services/auth_service.dart) | 36 | Biometric adapter | Availability/auth errors become false; verify enrollment changes and fallback. F09. |
| [lib/core/services/backup_service.dart](../lib/core/services/backup_service.dart) | 112 | Backup/import | Notes-only export; object/list mismatch; non-null ID update cannot restore missing rows. F02/F03. |
| [lib/core/services/lock_service.dart](../lib/core/services/lock_service.dart) | 160 | Private access | Plain preferences PIN, insufficient input validation and no throttling. F09. |
| [lib/core/services/notification_sync_service.dart](../lib/core/services/notification_sync_service.dart) | 230 | Notification lifecycle | Early initialized flag, foreground polling, seven-day background horizon. F07/F08. |
| [lib/core/themes/app_theme.dart](../lib/core/themes/app_theme.dart) | 150 | Active theming | Material 3, dynamic colors, Google Fonts and font scale; first-use font download should be tested offline. |
| [lib/core/themes/theme_controller.dart](../lib/core/themes/theme_controller.dart) | 61 | Alternative theming | Separate FlexColorScheme state is not the active AppTheme path; consolidate deliberately. F16. |
| [lib/data/local/databases/app_database.dart](../lib/data/local/databases/app_database.dart) | 48 | Sqflite schema | Notes/attachments version 1; no onUpgrade or explicit FK enable; private rows are ordinary SQLite. F09/F10. |
| [lib/data/local/databases/app_drift_database.dart](../lib/data/local/databases/app_drift_database.dart) | 319 | Drift schema/DAOs | Version 3, six tables, sequential subtasks/order writes; upgrade and FK tests needed. F06/F10. |
| [lib/data/local/databases/app_drift_database.g.dart](../lib/data/local/databases/app_drift_database.g.dart) | 4386 | Generated Drift | Generated mapping/SQL output; checked through analyzer and schema context, not manually edited. Regenerate from source schema. |
| [lib/data/local/databases/note_dao.dart](../lib/data/local/databases/note_dao.dart) | 0 | Empty placeholder | No implementation; remove or clearly track as planned work. |
| [lib/data/local/preferences/app_preferences.dart](../lib/data/local/preferences/app_preferences.dart) | 0 | Empty placeholder | No implementation; remove or clearly track as planned work. |
| [lib/data/models/attachment_model.dart](../lib/data/models/attachment_model.dart) | 27 | Row mapping | Maps stored path/type/name/order; durability belongs to media ownership policy. F05. |
| [lib/data/models/category_model.dart](../lib/data/models/category_model.dart) | 0 | Empty placeholder | No implementation; remove or clearly track as planned work. |
| [lib/data/models/note_model.dart](../lib/data/models/note_model.dart) | 33 | Row mapping | Maps flags, timestamps, rich/plain text; no schema-validation test exists. |
| [lib/data/repositories/category_repository.dart](../lib/data/repositories/category_repository.dart) | 0 | Empty placeholder | No implementation; remove or clearly track as planned work. |
| [lib/data/repositories/file_repository.dart](../lib/data/repositories/file_repository.dart) | 0 | Empty placeholder | No implementation; remove or clearly track as planned work. |
| [lib/data/repositories/note_repository.dart](../lib/data/repositories/note_repository.dart) | 214 | Repository | See path: domain file defines contract; data implementation has broadcast changes, batched attachments, update-only existing-ID upsert. F02/F04/F10. |
| [lib/data/repositories/reminder_repository.dart](../lib/data/repositories/reminder_repository.dart) | 47 | Reminder persistence | Owner and date filters; no relational owner enforcement; caller coordinates cancellation. F07/F08/F10. |
| [lib/data/repositories/schedule_repository.dart](../lib/data/repositories/schedule_repository.dart) | 43 | Schedule persistence | UTC fields and nullable end; date overlap and incomplete CRUD UI need tests. F11. |
| [lib/data/repositories/task_repository.dart](../lib/data/repositories/task_repository.dart) | 67 | Task persistence | Exposes Drift Task records; delegates ordering and subtask replacement. F06/F10. |
| [lib/data/sources/settings_local_source.dart](../lib/data/sources/settings_local_source.dart) | 63 | Preference persistence | ThemeMode indexing trusts stored integer; locale/font/colors/lock preferences persisted; defensive decode tests desirable. |
| [lib/domain/entities/attachment_entity.dart](../lib/domain/entities/attachment_entity.dart) | 41 | Domain data | Immutable metadata; copyWith cannot explicitly clear nullable ID/mime with null; define clearing semantics if used. |
| [lib/domain/entities/note_entity.dart](../lib/domain/entities/note_entity.dart) | 45 | Domain data | copyWith(id:null) retains old ID, breaking Undo insert intent. F04. |
| [lib/domain/repositories/note_repository.dart](../lib/domain/repositories/note_repository.dart) | 21 | Repository | See path: domain file defines contract; data implementation has broadcast changes, batched attachments, update-only existing-ID upsert. F02/F04/F10. |
| [lib/presentation/views/about/about_screen.dart](../lib/presentation/views/about/about_screen.dart) | 47 | About UI | Second Brain and hardcoded version; actual build version must have one source. F13/F17. |
| [lib/presentation/views/attachments/attachments_screen.dart](../lib/presentation/views/attachments/attachments_screen.dart) | 376 | Media browser | All-note attachment visibility and skipLockCheck bypass; previews expose private assets. F01/F05. |
| [lib/presentation/views/home/app_drawer.dart](../lib/presentation/views/home/app_drawer.dart) | 122 | Navigation variant | Multiple same-named drawers coexist; standalone variants use GoRouter, active Home uses its own drawer. F11/F16. |
| [lib/presentation/views/home/home_screen.dart](../lib/presentation/views/home/home_screen.dart) | 2963 | Main orchestration | Dashboard/tabs, lifecycle lock, export, delete/Undo, private entry paths, task rendering; split after tests. F04/F09/F11/F16. |
| [lib/presentation/views/home/locked_notes_page.dart](../lib/presentation/views/home/locked_notes_page.dart) | 255 | Private collection | Consumes a snapshot and shared VaultSession; verify relock and refresh after edits. F09. |
| [lib/presentation/views/home/widgets/dashboard_metrics.dart](../lib/presentation/views/home/widgets/dashboard_metrics.dart) | 241 | Dashboard UI | Metrics, horizontal/wrap layout, loading skeleton; analyzer deprecation warning; large text not verified. |
| [lib/presentation/views/home/widgets/locked_vault.dart](../lib/presentation/views/home/widgets/locked_vault.dart) | 315 | Private session/sheet | Boolean session lacks lifecycle relock caller; sheet max size .9 cannot reach .95 full-page threshold. F09/F16. |
| [lib/presentation/views/note_editor/note_editor_screen.dart](../lib/presentation/views/note_editor/note_editor_screen.dart) | 1758 | Rich note editor | Autosave, Quill, attachments, recorder, exports, lock flag; direct local paths and large responsibilities. F01/F05/F16. |
| [lib/presentation/views/note_preview/note_preview_screen.dart](../lib/presentation/views/note_preview/note_preview_screen.dart) | 1042 | Reading/media | Authenticates unless bypass flag; isolate decode and rich preview; some PDF exports use single page/plain text. F01/F16. |
| [lib/presentation/views/schedule/schedule_tab.dart](../lib/presentation/views/schedule/schedule_tab.dart) | 2095 | Calendar/timeline | Week loading, quick-add, drop/resize, conflicts/focus; direct repositories; no recurrence engine/full CRUD editor. F10/F11. |
| [lib/presentation/views/search/search_screen.dart](../lib/presentation/views/search/search_screen.dart) | 263 | Search UI | Standalone field is uncontrolled, clear only resets VM; filter chips and mixed note/task results. F14. |
| [lib/presentation/views/settings/notification_center_screen.dart](../lib/presentation/views/settings/notification_center_screen.dart) | 270 | Reminder list | Upcoming scheduled rows only; note route bypasses auth; no explicit FutureBuilder error presentation. F01/F08. |
| [lib/presentation/views/settings/settings_screen.dart](../lib/presentation/views/settings/settings_screen.dart) | 923 | Settings UI | Real appearance/preferences coexist with voice/auto-backup/update/logout placeholders and wrong version. F09/F13/F15. |
| [lib/presentation/views/tasks/subtask_draft.dart](../lib/presentation/views/tasks/subtask_draft.dart) | 10 | Editor draft | Draft title/completed values exist, but save passes titles only. F06. |
| [lib/presentation/views/tasks/task_editor_screen.dart](../lib/presentation/views/tasks/task_editor_screen.dart) | 978 | Task editing | Title validation, presets, More, linked notes, subtasks; completed flags dropped on save, no save tooltip/busy guard. F06. |
| [lib/presentation/views/tasks/tasks_screen.dart](../lib/presentation/views/tasks/tasks_screen.dart) | 784 | Task collection | Dedicated task list/agenda duplicates Home task presentation; filters, completion, swipe delete. F07/F16. |
| [lib/presentation/view_models/app_settings_vm.dart](../lib/presentation/view_models/app_settings_vm.dart) | 138 | Settings state | Legacy StateNotifier, prefs persistence, wakelock; async errors and malformed prefs need tests. |
| [lib/presentation/view_models/attachments_vm.dart](../lib/presentation/view_models/attachments_vm.dart) | 122 | Media state | Loads all attachments and notes; no locked-owner exclusion before display. F01. |
| [lib/presentation/view_models/auth_view_model.dart](../lib/presentation/view_models/auth_view_model.dart) | 0 | Empty placeholder | No implementation; remove or clearly track as planned work. |
| [lib/presentation/view_models/category_view_model.dart](../lib/presentation/view_models/category_view_model.dart) | 0 | Empty placeholder | No implementation; remove or clearly track as planned work. |
| [lib/presentation/view_models/di.dart](../lib/presentation/view_models/di.dart) | 42 | Dependency wiring | Default prefs provider throws; two DB providers and concrete services; disposal registration missing. F08/F12/F16. |
| [lib/presentation/view_models/home_vm.dart](../lib/presentation/view_models/home_vm.dart) | 152 | Notes collection state | Preference-backed sort/view and batched attachment loads; resorting replaces repository pin-first ordering. |
| [lib/presentation/view_models/note_editor_vm.dart](../lib/presentation/view_models/note_editor_vm.dart) | 127 | Alternative editor state | Not wired to current screen; duplicate logic and controller disposal missing. F16. |
| [lib/presentation/view_models/note_view_model.dart](../lib/presentation/view_models/note_view_model.dart) | 20 | Alternative note filters | Category/query Notifier; confirm live callers before consolidation. F16. |
| [lib/presentation/view_models/notes_stream_provider.dart](../lib/presentation/view_models/notes_stream_provider.dart) | 19 | Future providers | Named stream file uses FutureProvider; filters loaded notes, no repository-change subscription here. F16. |
| [lib/presentation/view_models/search_vm.dart](../lib/presentation/view_models/search_vm.dart) | 91 | Search state | 320ms debounce, all-task scan, no stale-response protection or try/finally recovery. F14. |
| [lib/presentation/view_models/tasks_vm.dart](../lib/presentation/view_models/tasks_vm.dart) | 254 | Task orchestration | Subtask reset/empty-list issue; complete does not cancel reminders; parent/reminder writes not atomic. F06/F07/F08. |
| [lib/presentation/widgets/app_drawer.dart](../lib/presentation/widgets/app_drawer.dart) | 49 | Navigation variant | Multiple same-named drawers coexist; standalone variants use GoRouter, active Home uses its own drawer. F11/F16. |
| [lib/presentation/widgets/attachment_preview.dart](../lib/presentation/widgets/attachment_preview.dart) | 0 | Empty placeholder | No implementation; remove or clearly track as planned work. |
| [lib/presentation/widgets/canvas_scaffold.dart](../lib/presentation/widgets/canvas_scaffold.dart) | 42 | Editor scaffold | Shared slivers and keyboard-aware bottom toolbar; verify keyboard resize/large text on Android. |
| [lib/presentation/widgets/category_chip.dart](../lib/presentation/widgets/category_chip.dart) | 0 | Empty placeholder | No implementation; remove or clearly track as planned work. |
| [lib/presentation/widgets/in_app_reminder_host.dart](../lib/presentation/widgets/in_app_reminder_host.dart) | 410 | Foreground reminders/navigation | Lifecycle bridge, banners, snooze, private-note bypass, task save reuse. F01/F07/F08. |
| [lib/presentation/widgets/note_card.dart](../lib/presentation/widgets/note_card.dart) | 508 | Notes presentation | Grid/list cards, locked blur, media pills; visual redaction alone is not authorization. F01/F09. |
| [lib/presentation/widgets/shimmer_skeleton.dart](../lib/presentation/widgets/shimmer_skeleton.dart) | 59 | Loading UI | Repeating animation controller disposed; reduced-motion adaptation not explicit. |
| [lib/presentation/widgets/smooth_refresh_indicator.dart](../lib/presentation/widgets/smooth_refresh_indicator.dart) | 27 | Refresh UI | Shared Material pull-to-refresh wrapper; local refresh must not imply cloud sync. |
| [test/widget_test.dart](../test/widget_test.dart) | 16 | Widget test | Fails: missing sharedPreferencesProvider override, then All Notes expectation; see stored logs. F12. |

## 4. Recommended focused tests

| Area | Meaningful regression case |
|---|---|
| Repository import | Existing ID missing in target database must insert or report failure |
| Undo | Delete note with media, undo, restart, verify note and references |
| Privacy | Locked note reached from attachments and reminders still authenticates |
| Task edits | Completed subtask survives parent edit; clearing final subtask persists |
| Reminders | Completion cancels alerts; long-horizon and permission-denied behavior |
| Schema upgrades | Version 1/2 fixtures upgrade to version 3 with all required tables |
| Search | Clear changes field and results; old async response cannot replace new query |
| Preferences | Malformed/out-of-range stored settings recover safely |

## 5. Build-only adjustments

Compatibility work was limited to dependency resolution and Android tooling so the requested emulator review could run. No application Dart implementation or existing test was edited. Exact changes and failed attempts are listed in [Verification](VERIFICATION.md). Findings remain open unless explicitly marked otherwise.

Related: [architecture](APPLICATION_ARCHITECTURE.md) · [prioritized feedback](APP_FEEDBACK.md) · [feature matrix](FEATURE_STATUS.md).

