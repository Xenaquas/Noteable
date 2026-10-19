# Digital Memory — Future Scope and Roadmap

> Proposed work after the 19 October 2026 review. These items are **not implemented promises**. Priorities follow observed privacy, data integrity, and workflow gaps.

## 1. Product direction

Keep the core product focused on a local personal workspace: capture, retrieve, act, and recover. Reliability should precede new integrations or AI features. Notes, tasks, and schedules should share context without requiring the user to manage three unrelated systems.

## 2. Milestones

| Milestone | Scope | Exit criteria | Dependencies |
|---|---|---|---|
| M0 · Reproducible baseline | SDK/toolchain policy, lockfile, build instructions, repair test fixture, resolve analyzer warnings | Clean checkout resolves; Android debug builds; existing smoke test passes; CI reports analyzer/test status | Git repository and pinned toolchain |
| M1 · Protect and recover | Shared private access policy, PIN handling, full backup/restore, Undo, durable attachments | Fresh-install restore round-trip succeeds; all locked entry paths gated; delete/Undo survives restart; cache cleanup does not lose media | Test fixtures before persistence changes |
| M2 · Reliable productivity | Subtask identity/completion, reminder cancellation/reconciliation, migrations, linked-note deletion policy | Task editing preserves subtasks; completed tasks do not alert; upgrades from each historical schema pass | M0, M1 |
| M3 · Finish existing workflows | Working New schedule action, edit/delete schedule, honest settings, consistent navigation, clear error feedback | Every visible primary action has a working completion or explicit unavailable state; no false success on cancel | M2 |
| M4 · Inclusive and measured UX | Application translations, TalkBack labels/order, large text, contrast, reduced motion, profile-mode measurements | Documented accessibility matrix and performance results on emulator plus physical Android | Stable workflows |
| M5 · Release preparation | Branding, final app ID, release signing, privacy statement, dependency license review, store assets | Signed release build installed and tested; release checklist complete; recovery instructions published | M1–M4 |

No calendar dates or effort estimates are assigned without delivery capacity and acceptance of scope. These are ordered milestones, not commitments.

## 3. Acceptance scenarios

### Recovery and data safety

- Full backup includes notes, attachments, tasks, subtasks, schedules, reminders, labels, preferences, and a versioned manifest.
- Import supports empty installation, existing records, collisions, malformed archives, missing media, and rollback.
- Note IDs are deliberately preserved or remapped with all references updated.
- The app tells the user exactly what was imported and what failed.
- Deletion policy covers linked tasks/schedules and associated reminder/file cleanup.

### Private content

- Every preview, editor, attachment, export, notification, and linked-note path applies one authorization policy.
- Vault session expires at the documented timeout and relocks on the intended lifecycle events.
- PIN setup validates length and numeric content; failed attempts are throttled.
- Ordinary local storage is not marketed as encrypted unless encryption and key recovery are implemented and verified.
- Background/task-switcher previews follow the chosen privacy policy.

### Tasks and reminders

- Editing a task title does not reset completed subtasks.
- Removing the final subtask is durable.
- Completing/deleting a task cancels relevant reminders; reopening has a defined policy.
- Foreground alerts, background notifications, snooze, permissions, reboot, and cold launch all have tests.
- Reminder horizons and overdue reminders are handled explicitly.

### Schedule

- New schedule uses the same creation logic as timeline quick-add.
- Title, dates, duration, all-day state, and location have validation and edit/delete affordances.
- Drag/resize has accessible button or form alternatives.
- Multi-day and all-day events work across time zones and daylight-saving boundaries.
- Recurrence is advertised only after an occurrence engine, editing rules, and cancellation semantics exist.

## 4. Architectural work worth doing

| Improvement | Reason | Keep it bounded |
|---|---|---|
| One locked-content policy | Current boolean bypasses are unsafe | Start with one shared authorization API and entry-path tests |
| Versioned backup schema | Current ZIP variants are inconsistent | Define a manifest and import result; avoid a general sync engine |
| Owned media storage | Picker paths may expire | Copy on import with checksums and clear cleanup rules |
| Transactional task edits | Parent/subtask/reminder writes can diverge | Add transactions and preserve IDs |
| Extract screen orchestration | Large views mix responsibilities | Extract the tested persistence/export logic first |
| One navigation system | Router and drawer variants drift | Keep current routes working while removing inactive alternatives |
| Search scaling | Full collections are loaded | Measure before introducing FTS/paging |

Database consolidation is an option, not a prerequisite for every fix. A merge should happen only with tested migrations and a recovery plan.

## 5. Later opportunities

| Opportunity | User value | Prerequisite / boundary |
|---|---|---|
| Recurring tasks and schedules | Reduce repeated entry | Occurrence model, time-zone policy, edit-series behavior |
| Version history / trash | Recover accidental edits and deletion | Stable IDs and storage retention policy |
| Full-text and attachment search | Faster retrieval at scale | Indexed metadata and supported document extraction |
| Optional encrypted sync | Multi-device access | Account, encryption/key recovery, conflict model, offline reconciliation |
| Calendar integration | Avoid duplicate planning | Explicit provider permissions, mapping, conflict handling |
| Widgets and quick capture | Lower capture friction | Stable capture API and background/platform testing |
| Voice transcription | Searchable spoken ideas | Clear privacy/processing choice; current Voice selector is a placeholder |
| AI summaries or retrieval | Help connect existing notes | Explicit data boundaries, measurable quality, cost and consent model |

## 6. What to avoid expanding yet

Do not add a second cloud backend, multiple state-management libraries, or a generalized plugin system to solve current reliability problems. Do not use GitHub as the app's private-user-data backup mechanism. Git history protects source revisions; the app needs its own verified data backup.

## 7. Readiness dashboard

Use concrete gates rather than an invented percentage:

- [ ] Fresh checkout builds with the documented SDK.
- [ ] Analyzer and meaningful tests pass.
- [ ] Backup restores to a clean installation.
- [ ] Locked-content entry-path matrix passes.
- [ ] Undo, subtasks, and reminders preserve user intent.
- [ ] Database upgrades are fixture-tested.
- [ ] Primary schedule and settings actions are complete.
- [ ] TalkBack, large text, and physical device testing are recorded.
- [ ] Signed release build and publication metadata are reviewed.

Related: [findings](APP_FEEDBACK.md) · [feature status](FEATURE_STATUS.md) · [GitHub plan](GITHUB_READINESS.md).
