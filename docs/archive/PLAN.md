# Digital Memory Simplification Plan

## Goal

Make Digital Memory minimal, easy to use, simple to interact with, and reliable. The app should help users capture, find, and act on information without feeling visually heavy.

## Principles

- **Show less by default:** Keep primary screens focused on the next useful action.
- **Progressive detail:** Move secondary controls into bottom sheets, menus, and contextual actions.
- **Consistent patterns:** Reuse the same chips, cards, sheets, empty states, and action layouts across Notes, Tasks, Schedule, and Settings.
- **Fast capture first:** New note, new task, and quick schedule creation should take the fewest possible taps.
- **Reliable feedback:** Every save, reminder, backup, restore, and delete action should give clear success or failure feedback.

## UI Direction

- Use a quiet Material 3 layout with more whitespace, fewer nested cards, and restrained color.
- Keep list items compact and scannable; avoid mixing too many visual styles in one screen.
- Prefer icons, chips, switches, segmented controls, and bottom sheets for familiar interactions.
- Keep the FAB visible or collapsed, but avoid fully hiding primary creation actions.
- Use skeleton loading and lazy previews for attachment-heavy content.

## Screen Plan

### Home and Notes

- Make the default Home view a clean notes surface with search, sort, and view mode available but visually secondary.
- Keep note cards lighter: title, category, short preview, lock/pin state, and compact attachment count.
- Move less-used note actions into overflow menus or long-press actions.
- Keep locked notes visually private without making the layout jump.

### Tasks

- Keep task creation fast with a compact quick-add input.
- Show due date, priority, completion, and linked note only when present.
- Keep advanced fields such as subtasks, reminders, and linked notes inside the task editor sheet.
- Avoid attachments inside tasks; link tasks to notes when richer context is needed.

### Schedule

- Keep Today and Week modes as the main switch.
- Use compact filters for Schedules, Tasks, Notes, Focus, and completed tasks.
- Keep the summary strip short: counts and next upcoming item only.
- Use conflicts and focus blocks as visual hints, not large explanatory panels.
- Keep long-press quick-add and drag-to-resize, but provide fallback edit actions for precision.

### Settings

- Group settings into App, Privacy, Backup, and About.
- Keep notification channel customization clear and platform-aware.
- Move advanced or rarely used settings into sheets instead of expanding the main settings list.

## Reliability Plan

- Run `flutter analyze` before release builds.
- Add focused widget tests for Notes list, Task editor, Schedule filters, and Settings sheets.
- Add repository tests for note/task/schedule/reminder save and fetch flows.
- Keep database migrations small, versioned, and verified after schema changes.
- Ensure notification scheduling handles foreground, background, snooze, cancel, and app restart.

## Near-Term Implementation Steps

1. Clean up the Home screen so it defaults to notes and keeps task/schedule entry points secondary.
2. Replace heavy mixed-content areas with compact sections and clear filters.
3. Convert task editing into a reusable bottom sheet pattern.
4. Add a dedicated schedule editor so quick-add can expand into full editing.
5. Add widget tests for the Schedule filter strip and reminder banner.
6. Review all empty, loading, and error states for concise user feedback.

## Definition of Done

- The main screens are understandable within a few seconds.
- Primary actions are always available and predictable.
- Notes, tasks, schedules, and reminders feel connected without crowding each other.
- The app remains responsive with many notes and attachments.
- Errors are recoverable and visible without interrupting normal use.
