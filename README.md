# Digital Memory

**A Flutter workspace for rich notes, tasks, attachments, and personal schedules.**

Capture ideas, connect tasks to notes, and review commitments in a local calendar. Core data is stored on the device. The project is a **development prototype with known privacy and recovery defects**; read the review before relying on locks or backups.

## Application review

The **19 October 2026** review includes all 65 Dart files, static analysis, the existing test, Android emulator execution, screenshots, diagrams, and release readiness.

| Report | Purpose |
|---|---|
| [Documentation index](docs/INDEX.md) | Navigate the complete review |
| [Current status](docs/CURRENT_STATUS.md) | Run outcome and release blockers |
| [Architecture](docs/APPLICATION_ARCHITECTURE.md) | Layers, state, storage, and services |
| [App workflow](docs/APP_WORKFLOW.md) | Screenshots and step-by-step review |
| [App feedback](docs/APP_FEEDBACK.md) | Prioritized findings and acceptance checks |
| [Feature status](docs/FEATURE_STATUS.md) | Implemented, partial, placeholder, and unverified features |
| [Dart code review](docs/DART_CODE_REVIEW.md) | Every application/test Dart file |
| [Future scope](docs/FUTURE_SCOPE.md) | Ordered milestones |
| [Project context](docs/PROJECT_CONTEXT.md) | Product intent and structure |
| [Verification](docs/VERIFICATION.md) | Commands, failures, and compatibility changes |
| [Evidence](docs/EVIDENCE.md) | Screenshots and raw logs |
| [GitHub readiness](docs/GITHUB_READINESS.md) | First push, history, and source backup |

## Current capabilities

### Screens from the Android review

| Saved note preview | Dashboard after cold restart |
|---|---|
| <img src="docs/evidence/screenshots/09-note-preview.png" width="280" alt="Note preview with synthetic attachment"> | <img src="docs/evidence/screenshots/35-cold-start-persistence.png" width="280" alt="Dark dashboard after restart"> |

These are current debug-build captures using synthetic review content. See [Workflow](docs/APP_WORKFLOW.md) for defects and evidence limits.

- Rich text notes with categories, reading/editing modes, autosave, pin and lock flags.
- Local image, audio, video, PDF, and file attachment paths and viewers.
- Tasks with priority, due dates, reminders, subtasks, and linked notes.
- Daily/weekly schedule views combining events, deadlines, and note reminders.
- Material 3 themes, dynamic colors, font preferences, and partial localization.
- Local notification integration and note JSON ZIP export.

**Known limitations:** private-content entry paths can bypass locks; backups omit most app data and restore is defective; task/subtask/reminder integrity needs fixes. Some settings and schedule entry points are placeholders. See the [feature matrix](docs/FEATURE_STATUS.md).

## Run on Android

The review used **Flutter 3.47.5 stable / Dart 3.13.4**, Android Studio JBR 21, and a Pixel 6a emulator on Android 15/API 35. The resolved lockfile requires Dart ≥3.12 and Flutter ≥3.44; use the tested version to reproduce this baseline. Android tooling is Gradle 8.14, AGP 8.11.1, and Kotlin 2.2.20.

```powershell
flutter doctor -v
flutter pub get
flutter emulators
flutter emulators --launch Pixel_6a
flutter devices
flutter run -d emulator-5554
```

Replace emulator/device IDs with those listed on your machine. Install required SDK components and handle applicable Android licenses through your normal setup process. Keep local SDK paths and signing keys out of Git.

The original dependency/build setup failed on this SDK. The review updated the lockfile and Android toolchain configuration; [Verification](docs/VERIFICATION.md) records the exact changes and download workaround.

## Quality checks

```powershell
flutter analyze
flutter test
```

Review result: **29 analyzer issues — 6 warnings, 23 informational diagnostics**. The sole widget test fails because its bootstrap omits required dependencies. These gates are not passing.

After intentional Drift schema edits, regenerate output:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

Generation does not replace migration tests. This review did not regenerate or manually edit schema output.

## Technology and storage

| Area | Implementation |
|---|---|
| UI | Flutter, Material 3, Flutter Quill |
| State | Riverpod, ChangeNotifier, StateNotifier, Notifier |
| Notes | Sqflite: second_brain.db |
| Productivity | Drift: second_brain_drift.db |
| Preferences | SharedPreferences |
| Media | Local filesystem paths and platform plugins |
| Alerts | Local notifications and foreground reminders |

The active app uses Navigator and tabs. A separate GoRouter builder is not wired into the live MaterialApp. iOS, web, and desktop folders exist but were not runtime-verified.

## Project layout

```text
lib/app/           App shell and navigation definitions
lib/core/          Themes, constants, application services
lib/domain/        Entities and note repository contract
lib/data/          Databases, models, repositories, settings
lib/presentation/  Screens, widgets, and view models
test/              Existing widget test
docs/              Reports, screenshots, diagrams, logs, archived plans
```

Only this README remains as a root Markdown document. Previous plans are preserved in docs/archive/.

## Diagrams

[Editable tldraw architecture and workflow board](https://www.tldraw.com/f/MJ8ymcLzU-nKT2TWyaEVd). The [local diagram folder](docs/diagrams/) contains an inspected PNG export and Mermaid sources.

## Version control and backups

There was no Git repository on arrival. No GitHub repository or push was created. Follow [GitHub Readiness](docs/GITHUB_READINESS.md) to establish a baseline and inspect staged content. Git preserves committed source; app databases and personal attachments need a separate verified backup.

No top-level project license was found. Choose a license and review dependency/asset redistribution requirements before public distribution.
