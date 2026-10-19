# Digital Memory — Project Context

> Review baseline: **19 October 2026 · Asia/Kolkata**. This document describes the inspected implementation. Earlier plans are historical proposals, not proof of completion.

## 1. Product purpose

Digital Memory is a personal knowledge and productivity application: capture rich notes and media, turn intentions into tasks, and view commitments in a calendar. The intended experience is fast, calm, and primarily local. The repository also uses the older name **Second Brain** in classes, database filenames, and some visible copy.

| Dimension | Observed context |
|---|---|
| Package | `digital_memory` |
| Declared version | `1.0.0+1` in `pubspec.yaml` |
| Primary reviewed target | Android emulator; other platform folders are scaffolding until separately verified |
| Language and UI | Dart, Flutter, Material 3 |
| State | Riverpod 3 with legacy ChangeNotifier/StateNotifier and newer Notifier APIs |
| Persistence | Sqflite notes database, separate Drift productivity database, preferences, local files |
| Backend | No account server or cloud synchronization implemented in reviewed app code |
| Source control on arrival | No `.git` repository in this project |
| Tests on arrival | One widget test; no repository or integration test suite |
| Design direction | Minimal capture and retrieval, progressive detail, consistent sheets and cards |

## 2. Core user jobs

1. Capture an idea with a title, rich text, category, and optional media.
2. Find and read an existing note without entering an editor.
3. Create a task with priority, a deadline, subtasks, and related note context.
4. Review deadlines and time blocks on a daily or weekly schedule.
5. Receive a reminder and act on it.
6. Keep selected content private and preserve personal data through backup.

The last two jobs need the most reliability work. A visible lock or successful backup toast does not establish secure access control or recoverability.

## 3. Project map

```text
digital_memory/
├── README.md                 Entry point and run instructions
├── docs/                     Current review, evidence, diagrams, historical plans
├── lib/
│   ├── main.dart             Preference initialization and ProviderScope
│   ├── app/                  MaterialApp; separate unused GoRouter builder
│   ├── core/                 Themes, constants, authentication, locks, backups, notifications
│   ├── domain/               Note/attachment entities and note repository contract
│   ├── data/                 SQLite models, databases, repositories, settings source
│   └── presentation/         View models, screens, shared widgets
├── test/                     Existing widget smoke test
├── android/                  Reviewed Android build configuration
└── ios, web, windows,
    macos, linux/             Platform projects, not a support guarantee
```

## 4. Design and implementation context

- Material 3 themes use Android dynamic colors where available and Google Fonts.
- Notes default to list mode in `HomeViewModel`; the home shell itself initially selects the combined dashboard.
- The four main tabs are All, Notes, Tasks, and Schedule; All is the Home dashboard. Drawer and wide-screen rail entries expose additional destinations with inconsistent completeness.
- Localized framework/editor delegates exist for English, Spanish, French, German, Chinese, and Hindi. Most application strings remain English literals.
- Media is referenced through local paths. Picker and camera paths are not consistently copied into permanent app-managed storage.
- Tasks and schedules reference notes by integer ID across two independent databases.

## 5. Review boundaries

The review includes the application Dart inventory, static analysis, the existing test, Android build/startup attempts, current-run screenshots, and source tracing of key workflows. Generated Drift code was treated as generated output and checked through analysis and schema inspection. An inventory row is not a claim that every possible behavior was exercised.

No production account, cloud backend, release distribution, physical biometric hardware, or third-party media library was assumed. See [verification](VERIFICATION.md) for exactly what ran and [evidence](EVIDENCE.md) for captured states.

## 6. Historical material

| Archive | Meaning |
|---|---|
| [Original README](archive/README-before-review.md) | Previous broad feature description |
| [Simplification plan](archive/PLAN.md) | Desired visual and interaction direction |
| [Earlier next steps](archive/Next_Step.md) | Prior critique; references old screenshots not used as current evidence |
| [Earlier summary](archive/Summary.md) | Previous implementation summary, possibly stale |
| [Original app blueprint](archive/App_plan.md) | Preserved former `App_plan.txt`; aspirational scope |

Current findings take precedence when old descriptions disagree. The archive was moved rather than deleted so that the project's reasoning remains available for future Git history.

## 7. Decision record

| Decision | Reason |
|---|---|
| Keep only README among root Markdown documents | Requested documentation layout |
| Put reports, images, and logs under `docs/` | Relative links remain portable when pushed to GitHub |
| Preserve original failures | The review must distinguish initial state from compatibility adjustments |
| Record product defects instead of silently refactoring | Requested scope is review and documentation |
| Defer GitHub push | User described a forthcoming push; no repository destination or publication request was supplied |

Related: [architecture](APPLICATION_ARCHITECTURE.md) · [workflow](APP_WORKFLOW.md) · [feature status](FEATURE_STATUS.md) · [GitHub readiness](GITHUB_READINESS.md).
