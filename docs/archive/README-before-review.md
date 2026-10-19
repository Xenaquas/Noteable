# Digital Memory

Digital Memory is a Flutter notes app for capturing notes, tasks, attachments, reminders, and schedules in one offline-first workspace.

## Current App State

- **Notes:** Rich-text notes with categories, pinned notes, locked notes, searchable plain text, and attachment previews.
- **Tasks:** Prioritized tasks with due dates, reminders, subtasks, completion state, and optional linked notes.
- **Schedule:** Calendar-style agenda that brings schedules, task deadlines, note reminders, linked notes, focus blocks, and conflicts into one view.
- **Reminders:** Local notifications with in-app reminder banners while the app is open and system notifications while it is in the background.
- **Settings:** Theme, language, font, lock, backup, notification center, and notification channel guidance.
- **Privacy:** Local biometric lock support for app access and locked notes.
- **Backup:** Export and restore flows for preserving notes and related content.

## Product Direction

The app should feel minimal, fast, and calm. Notes, tasks, and schedules should work together without making the interface feel dense or heavy. Each screen should show the most useful action first, hide advanced controls until needed, and keep navigation predictable.

See [PLAN.md](PLAN.md) for the simplification plan.

## Getting Started

```bash
flutter pub get
flutter run
```

For static checks:

```bash
flutter analyze
```
