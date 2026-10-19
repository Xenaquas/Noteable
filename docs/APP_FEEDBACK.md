# Digital Memory — Application Feedback

> **19 October 2026 · Engineering and Product Design review.** Each finding distinguishes source-confirmed behavior, runtime observation, and remaining verification.

## 1. Overall assessment

The product has a useful combination of rich notes, actionable tasks, and calendar context. Material components, category chips, separate preview/edit screens, and progressive task fields give it a coherent starting point. The highest-impact work is **trust and recoverability**: locked content must remain protected through every entry path, and backups must actually restore the user's data.

The current implementation should be treated as a development prototype pending the release gates below. Version `1.0.0+1` is package metadata, not evidence of release readiness.

## 2. Severity and evidence

| Priority | Meaning |
|---|---|
| P1 — High | Privacy, data loss, or core workflow failure; resolve before release |
| P2 — Medium | Incomplete functionality, misleading behavior, or reliability gap |
| P3 — Low | Polish, consistency, or maintainability improvement |

**Source-confirmed** means the path exists in inspected code. **Runtime-confirmed** means it was reproduced in this review's emulator session. **Risk** means a plausible failure still needing a targeted test. Screenshot observations and walkthrough steps are in [App Workflow](APP_WORKFLOW.md) and [Evidence](EVIDENCE.md).

## 3. Engineering findings

### F01 · P1 · Locked content can bypass authentication

**Evidence:** [`attachments_screen.dart`](../lib/presentation/views/attachments/attachments_screen.dart), around line 114; [`in_app_reminder_host.dart`](../lib/presentation/widgets/in_app_reminder_host.dart), around lines 122 and 422; [`notification_center_screen.dart`](../lib/presentation/views/settings/notification_center_screen.dart), `_openItem`.

The attachment browser passes `skipLockCheck: note.isLocked`, so a locked note explicitly skips the preview's authentication check. Reminder entry points also pass `true`. The attachment view model loads every attachment without excluding locked owners, and attachment tiles expose media independently of note authentication.

**Impact:** A lock in the note list does not protect all paths to the content.

**Runtime confirmation:** Created `Review_note` with `review-attachment.txt`, locked it, received the normal PIN prompt, canceled without authenticating, then opened All → File Manager → attachment. The preview displayed the locked note body without authentication. [Normal prompt](evidence/screenshots/10-lock-authentication.png), [locked card](evidence/screenshots/11-locked-notes.png), [exposed attachment](evidence/screenshots/12-private-attachment-visible.png), [bypassed preview](evidence/screenshots/13-lock-bypass-confirmed.png). The UI hierarchy also retains the visually blurred note title; see [locked-notes.xml](evidence/logs/locked-notes.xml). Actual TalkBack speech was not tested.

**Recommendation:** Centralize authorization and require an authenticated session for locked note preview, editor, media, export, and reminder navigation. Avoid a freely passed boolean bypass.

**Acceptance:** Create a locked note with media. From a fresh locked session, open it from notes, attachments, notifications, search/link pickers, and export. Every path either hides private content or requests authorization. See runtime evidence where available; notification delivery routes remain source-confirmed.

### F02 · P1 · Restore cannot recreate missing note IDs

**Evidence:** [`backup_service.dart`](../lib/core/services/backup_service.dart), `restoreFromBackup`; [`note_repository.dart`](../lib/data/repositories/note_repository.dart), `upsert`.

Export retains each note's ID. Restore supplies that non-null ID to `upsert`, which performs `db.update` and returns the ID without checking whether a row existed. On an empty database, no row is inserted. On a different database, a colliding ID may overwrite unrelated content.

**Recommendation:** Validate a versioned import schema; explicitly insert or merge with a conflict policy, remap references, and transact the operation. Report imported/skipped/failed counts.

**Acceptance:** Export from installation A, restore to empty installation B, and compare every record. Also test ID collisions and rollback on invalid input.

**Runtime confirmation:** Imported the valid [restore probe](evidence/fixtures/restore-probe.zip) with unused ID `999999`. The app showed [Restore successful](evidence/screenshots/30-restore-success-message.png), but [the list](evidence/screenshots/31-restore-note-missing.png) and [database check](evidence/logs/restore-probe-result.json) show zero imported probe records. This reproduced missing-ID failure in the review database; a separate clean-install round-trip remains an acceptance test.

### F03 · P1 · Backup is notes-only and incompatible with single-note restore

**Evidence:** [`backup_service.dart`](../lib/core/services/backup_service.dart), `_encodeNote`, `exportNote`, and JSON list decoding in restore.

Full export contains note JSON only. It omits attachment metadata/bytes, tasks, schedules, reminders, labels, and settings. Single-note export writes an object, while restore expects a JSON array. The separate note share ZIP includes PDF/media but is not the restore format.

**Recommendation:** Label the current operation accurately, then implement a full snapshot manifest with version, record counts, media checksums, reference mapping, and validation. Preserve a working recovery path before changing database structure.

**Acceptance:** Restore a fixture containing all supported data types to a clean install; verify files open and references survive. Test both single-note and full export/import formats.

**Runtime confirmation:** Create Backup generated one JSON entry containing one locked synthetic note. The exported ZIP contained no attachment bytes despite an attached file, and no task/schedule data despite both existing. [Export inspection](evidence/logs/backup-inspection.json), [share sheet](evidence/screenshots/29-backup-share.png). The share sheet was canceled; no file was sent externally.

### F04 · P1 · Note deletion Undo retains a deleted ID

**Evidence:** [`home_screen.dart`](../lib/presentation/views/home/home_screen.dart), `_deleteNoteWithUndo`; [`note_entity.dart`](../lib/domain/entities/note_entity.dart), `copyWith`; repository `upsert`.

Undo calls `note.copyWith(id: null)` to create a new record, but `copyWith` uses `id ?? this.id`, preserving the old ID. The update then targets the deleted row. Attachment replacement may create rows with no restored note when foreign keys are disabled.

**Recommendation:** Provide an explicit insert/restore operation that preserves or deliberately remaps IDs. Make note and attachment recovery atomic and coordinate task/schedule/reminder references.

**Acceptance:** Delete a note with an attachment and linked task; press Undo; restart the app and verify note, attachment, and links. This is source-confirmed until the exact runtime flow is exercised.

### F05 · P1 · Attachment paths may not survive cache cleanup

**Evidence:** [`note_editor_screen.dart`](../lib/presentation/views/note_editor/note_editor_screen.dart), `_pickAttachments`, `_draftFromXFile`, camera/gallery handling; attachment rows store the supplied path.

Picker/camera files are referenced directly rather than consistently copied to permanent app-owned storage. Simulated upload progress does not establish durable copying. Some plugin paths may point to cache storage.

**Recommendation:** Copy accepted files into an app-managed media directory, validate the copy before saving metadata, and clean orphan files under a documented policy.

**Acceptance:** Import image/PDF/audio/video, restart, remove temporary picker caches, export, restore, and reopen every attachment. Cache-loss behavior is a risk, not a measured loss in this session.

### F06 · P2 · Subtask editing can lose completion and fail to clear the last item

**Evidence:** [`tasks_vm.dart`](../lib/presentation/view_models/tasks_vm.dart), `saveTask`; [`app_drift_database.dart`](../lib/data/local/databases/app_drift_database.dart), `replaceSubtasks`; task editor maps drafts to title strings.

Saving non-empty subtasks deletes and reinserts them with default incomplete state. Saving an empty list skips replacement entirely, leaving previous rows behind.

**Recommendation:** Preserve subtask IDs/completion and always apply the intended list, including empty. Wrap parent/reminder/subtask writes in a transaction where possible.

**Acceptance:** Complete one subtask, edit only the parent title, and verify completion remains. Remove every subtask and verify none reappear after reopening.

### F07 · P2 · Completing a task does not cancel its reminder

**Evidence:** [`tasks_vm.dart`](../lib/presentation/view_models/tasks_vm.dart), `toggleComplete` and `markTasksComplete`; the notification service's due loop does not reject completed owners.

Completion updates only the task row. Existing reminder rows and scheduled notifications can still fire.

**Recommendation:** Cancel outstanding reminders on completion and define behavior for reopening tasks. Reconcile overdue and missing owners during startup.

**Acceptance:** Schedule a future task reminder, complete the task, background the app, and verify no alert arrives. Test both single and bulk completion.

### F08 · P2 · Notification scheduling has lifecycle and coverage gaps

**Evidence:** [`notification_sync_service.dart`](../lib/core/services/notification_sync_service.dart), `init`, `enterForeground`, `enterBackground`, `reschedulePending`.

Initialization marks itself complete before awaited work finishes. Foreground mode cancels platform requests; background restoration schedules only through seven days. A reminder beyond that window may not be registered if the app is not reopened. Permission denial and past-due scheduling also need recovery tests.

**Recommendation:** Await one initialization future, persist/reconcile scheduling state, define the rolling horizon behavior, and handle exact-alarm denial without losing reminders.

**Acceptance:** Test cold start, permission denial, foreground/background transitions, completion, snooze, process death, reboot, and a reminder more than seven days away.

### F09 · P1 · Privacy controls overstate protection

**Evidence:** [`lock_service.dart`](../lib/core/services/lock_service.dart), lines 35–43; [`home_screen.dart`](../lib/presentation/views/home/home_screen.dart), `_maybeRequireUnlock`; [`locked_vault.dart`](../lib/presentation/views/home/widgets/locked_vault.dart), `VaultSession`.

PINs are stored as ordinary preferences text and compared directly. The PIN dialog hints at 4–6 digits but does not enforce that minimum or numeric-only input. App lock turns itself off when biometrics are unavailable. Vault `relock()` has no caller. A UI label of “Off” for zero-minute auto-lock conflicts with the comparison that locks after `Duration.zero`.

**Recommendation:** Implement a shared lock lifecycle, secure verifier storage, validation/throttling, and a deliberate fallback. Verify lock behavior while a pushed editor or preview is open. Do not describe current SQLite or ZIP storage as encrypted.

**Acceptance:** Check invalid PIN lengths, failed attempts, unavailable/enrollment-changed biometrics, timeout, resume, notification launch, and task-switcher exposure.

### F10 · P2 · Database upgrades and reference integrity lack tests

**Evidence:** [`app_drift_database.dart`](../lib/data/local/databases/app_drift_database.dart), version 3 migration; [`app_database.dart`](../lib/data/local/databases/app_database.dart), database creation; no `PRAGMA foreign_keys = ON` configuration.

Fresh creation includes six Drift tables, but upgrade code only explicitly adds two columns. Migration fixtures are needed to establish that old installs receive all required tables. Cross-database note references cannot cascade. Reminder ownership is also not enforced by foreign keys.

**Recommendation:** Test every historical schema and define deletion/remapping behavior for linked records. Enable and test within-database constraints where appropriate.

### F11 · P2 · Schedule entry points disagree

**Evidence:** [`home_screen.dart`](../lib/presentation/views/home/home_screen.dart), `_buildFab` and speed dial; [`schedule_tab.dart`](../lib/presentation/views/schedule/schedule_tab.dart), `_showQuickAddSheet`.

The prominent New schedule action says “Schedule coming soon”, while timeline long press supports persisted quick creation. A user can reasonably conclude the feature does not exist. Repository deletion exists without a visible complete schedule CRUD editor in the inspected screen.

**Runtime confirmation:** [The FAB placeholder](evidence/screenshots/20-schedule-placeholder.png) was reproduced. `_ScheduleDayView` returns an empty-state text when there are no items, hiding the long-press target too. After giving a task a due date, the timeline appeared and [quick-add](evidence/screenshots/23-schedule-quick-add.png) successfully created [Review_schedule](evidence/screenshots/24-schedule-created.png). A new user should not need another dated item to unlock creation.

**Recommendation:** Route New schedule to quick-add, then provide discoverable edit/delete controls. Treat recurrence fields as storage scaffolding until recurrence expansion is implemented.

### F12 · P2 · Test suite is not a working quality gate

**Evidence:** [Initial test log](evidence/logs/flutter-test.txt), [post-compatibility test log](evidence/logs/flutter-test-after-compatibility.txt), [`widget_test.dart`](../test/widget_test.dart).

The initial test cannot compile against the old Quill lock. After compatibility resolution it fails because it builds `SecondBrainApp` without the required preferences override, then expects “All Notes”. Platform services and database access also need controlled test dependencies.

**Recommendation:** Repair the bootstrap fixture; add meaningful tests for backup round-trip, deletion Undo, private entry paths, subtask edits, reminders, and migrations. Do not replace these with only a screenshot smoke test.

### F13 · P2 · Some settings report success without doing the promised work

**Evidence:** [`settings_screen.dart`](../lib/presentation/views/settings/settings_screen.dart), `_showAutoBackupSheet`, `_showVoiceSheet`, version/update/store/logout actions, `_handleRestore`.

Auto Backup and Voice change screen-local variables. There is no backup scheduler or speech behavior behind them. Update checking and logout only show snackbars; there is no account session to log out. The displayed `1.4.0 (142)` disagrees with `pubspec.yaml`. Canceling the restore picker returns normally and can still show “Restore successful”.

**Recommendation:** Remove or mark unfinished controls, source version metadata from the package, and report success only after a completed operation with an explicit result.

### F14 · P2 · Search state can disagree with visible text

**Evidence:** [`search_screen.dart`](../lib/presentation/views/search/search_screen.dart), suffix clear action; [`search_vm.dart`](../lib/presentation/view_models/search_vm.dart), debounce and `searchNow`.

The standalone search field has no controller; clearing the view-model query does not clear the actual input. Overlapping asynchronous searches have no request-generation guard, allowing a stale result to replace newer results. Most task searching scans all task rows in memory.

**Runtime confirmation:** Submitting `Review` from Home opened search results while the destination field showed its placeholder. After typing `Review` there and clearing it, results disappeared while the field still displayed `Review`. [Entry mismatch](evidence/screenshots/33-global-search.png), [clear mismatch](evidence/screenshots/34-search-clear-mismatch.png). The stale-response race remains source-confirmed rather than reproduced.

**Recommendation:** Control and clear the field, ignore stale requests, handle errors, and index/paginate after measuring realistic data.

### F15 · P2 · Language selection is only partial localization

**Evidence:** [`app.dart`](../lib/app/app.dart), delegates/locales; English string literals across presentation views.

Framework and editor translations are wired, but app-owned copy is not backed by an application localization catalog. Selecting Hindi or French does not establish full product translation.

**Recommendation:** Add application ARB resources, cover plural/date strings, and verify every supported locale with long text and assistive technology.

### F16 · P3 · Inactive alternatives and large screens increase maintenance cost

**Evidence:** Unused GoRouter builder, multiple drawers, alternative theme/filter/editor view models, ten zero-byte Dart files; [file inventory](DART_CODE_REVIEW.md).

**Recommendation:** Keep one live navigation/theme/editor path, remove empty scaffolding after confirming imports, and extract responsibilities around proven workflows. Avoid a broad rewrite before safety tests exist.

### F17 · P2 · Android release configuration is still a template

**Evidence:** [`android/app/build.gradle.kts`](../android/app/build.gradle.kts), example application ID and debug signing in release; app label in manifest; SDK/build compatibility logs.

**Recommendation:** Choose final identity, release signing, icons, version source, reproducible SDK/toolchain, and CI. Confirm iOS usage descriptions before claiming camera/microphone/Face ID support there. A debug emulator build does not validate release distribution.

### F18 · P2 · Timeline focus cards overflow their allocated height

**Runtime-confirmed evidence:** [Task timeline](evidence/screenshots/22-schedule-with-task.png), [schedule plus focus](evidence/screenshots/24-schedule-created.png), and [Flutter runtime log](evidence/logs/flutter-run-final.txt). Flutter displayed **BOTTOM OVERFLOWED BY 16 PIXELS** in a one-hour focus card at the review device's normal text setting. The app remained usable, but the card's time text escaped its layout. The console identifies `schedule_tab.dart:1714`.

**Source:** [`schedule_tab.dart`](../lib/presentation/views/schedule/schedule_tab.dart), `_TimelineBlock` and `_BlockContent`.

**Recommendation:** Fit content to the actual block constraints, prioritize title/time, and provide a details view for content that cannot fit. Do not merely hide the debug overflow stripe.

**Acceptance:** Render 15/30/60/120-minute items and focus blocks at standard and large text sizes with no layout exception, clipping of essential information, or overlap.

## 4. Product Design review

The audit uses current emulator screenshots, saved and inspected before inclusion. The walkthrough and screenshot-specific findings are documented in [App Workflow](APP_WORKFLOW.md). Earlier inspiration images and historical screenshots were not treated as runtime evidence.

### Strengths

- Notes, task context, and schedules share a consistent Material visual foundation.
- A separate note preview supports reading without accidental editing.
- Categories, priority, and due-date presets reduce repetitive input.
- Advanced task fields are progressively revealed under More.
- Local storage avoids requiring account setup for core capture.

### Priority design opportunities

| Opportunity | User consequence | Recommended outcome |
|---|---|---|
| Creation actions must work everywhere | A visible New schedule placeholder blocks discovery | One consistent schedule creation flow |
| Distinguish backup from sharing | Users may assume PDF/media ZIPs are restorable snapshots | Explicit format, contents, destination, and recovery instructions |
| Explain privacy accurately | A locked badge suggests stronger protection than current implementation | Clear policy plus enforced private entry paths |
| Eliminate nonfunctional settings | Success snackbars undermine trust | Completed settings or visibly unavailable controls |
| Reduce competing navigation paths | Tabs, rail, drawer, and duplicate task pages can diverge | Consistent destinations and labels |
| Make failures recoverable | Persistence/plugin errors can leave loading or false success states | Retry, cancellation, and explicit success/failure counts |

## 5. Accessibility target and limits

Target screen-reader names for every icon action, 48 logical-pixel touch areas, readable contrast, and layouts that remain usable with large text. The task editor save icon has no explicit tooltip. Repeated motion/shimmer should respect reduced-motion preferences. Custom checkbox/gesture controls and timeline long press need assistive-technology alternatives.

These are **risks requiring verification**, not a WCAG conformance verdict. Screenshots cannot prove semantics, TalkBack order, keyboard focus, measured contrast, motor accessibility, or reduced-motion behavior. Physical device and large-text testing remain release gates.

## 6. Suggested order of work

1. F01/F09 private access policy, F02/F03 recovery, F04 Undo, F05 durable media.
2. F06/F07 task integrity and F08 reminder lifecycle; F10 migrations.
3. F11/F13 honest and connected workflows; F12 reliable test gate.
4. F14/F15 search and localization; F16/F17 maintainability and release packaging.

See [Future Scope](FUTURE_SCOPE.md) for measurable milestones rather than a feature wish list.
