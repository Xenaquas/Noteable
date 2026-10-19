# Digital Memory — App Workflow and Product Design Audit

> **19 October 2026 · Pixel 6a emulator · Android 15/API 35 · Flutter debug build**
>
> Goal: capture a note, attach context, keep it private, create a task, plan a schedule, adjust settings, recover data, and find information again. This is a combined UX/accessibility-risk audit using current-run screenshots and observed actions. It is not an accessibility certification.

## 1. Walkthrough summary

| Step | User workflow | Health | Proof |
|---|---|---|---|
| 1 | Launch, permissions, Home | **Degraded startup; usable afterward** | 01–04 |
| 2 | Create note, attach file, save, preview | **Working in tested path** | 05–09 |
| 3 | Lock note and access attachments | **Failed privacy boundary** | 10–13 |
| 4 | Create task, priority, subtask, due date | **Partial; basic save works** | 14–18, 22 |
| 5 | View calendar and create schedule | **Partial; main action blocked, alternate works, layout fails** | 19–24 |
| 6 | Settings, appearance, Notification Center | **Partial; appearance works, placeholders remain** | 25–28 |
| 7 | Export backup and restore missing-ID note | **Export limited; restore fails despite success message** | 29–31 |
| 8 | Search and restart | **Search state defective; fixture persistence works** | 32–35 |

All image numbers correspond to the full [Evidence Gallery](EVIDENCE.md), including additional states not repeated below. No old inspiration screenshots were used as current proof.

## 2. Step 1 — Startup, permissions, and Home

1. Launched the freshly built APK through `flutter run`.
2. Observed an Android **Process system isn't responding** dialog over the app and notification prompt. Chose Wait; continued successfully.
3. Allowed notifications and enabled the requested alarms/reminders access in Android Settings.
4. Returned to the All tab dashboard.

| Startup blocker | Stable dashboard |
|---|---|
| ![System ANR dialog during startup](evidence/screenshots/01-startup.png) | ![All tab dashboard](evidence/screenshots/04-home.png) |

**Strengths:** The four tabs are visible, and the dashboard offers file, private-note, task, and recent-note entry points. No account is required.

**UX risks:** Permission requests interrupt the first view before a reminder is created. The dashboard repeats privacy entry points as Secret and Locked notes, while the visible brand is Second Brain and the Android label is `digital_memory`. The File Manager/Secret metric row scrolls horizontally; the partially visible second card needs clear discovery cues.

**Accessibility risks:** The hierarchy provides tab names and indices. Several app-bar icons lack explicit accessible names in the captured hierarchy; TalkBack behavior requires testing. The initial system ANR cannot be attributed solely to app code from this run. Debug skipped-frame logs are not release performance measurements.

**Recommendation:** Explain and request notification permissions at the reminder action, unify branding and private-area labels, and profile startup on a physical device.

## 3. Step 2 — Capture a note with a file and read it

1. Opened Notes → New note.
2. Entered `Review_note` and `Private_review_body`.
3. Added the synthetic 127-byte `review-attachment.txt` from Downloads.
4. Observed the Saved indicator; explicitly saved and returned to the note list.
5. Opened the note in read-only preview with body and attachment visible.

| Editor with saved content | Read-only preview |
|---|---|
| ![Note editor with attachment](evidence/screenshots/07-note-with-attachment.png) | ![Saved note preview](evidence/screenshots/09-note-preview.png) |

**Health:** Creation, basic text input, attachment selection, explicit save, list refresh, and preview worked in this fixture. Autosave displayed Saved before explicit save. This did not test every rich-text format, media codec, or interrupted-save condition.

**Strengths:** Categories, formatting tools, save state, and attachment entry are discoverable. Preview offers an explicit Edit action and communicates read-only mode.

**UX risks:** Large fixed empty areas separate note text and attachments, requiring unnecessary visual travel. A file appears both as a preview card and repeated filename/type below it. The editor's lock action does not explain the security policy. Some screenshots show Android's floating input toolbar; it is an emulator/IME surface, not an app toolbar.

**Accessibility risks:** Placeholder contrast and keyboard/focus behavior need measurement. Picker paths can outlive or lose access to underlying files; a saved visual card is not proof of durable file ownership.

**Recommendation:** Keep the reading/editor separation, simplify duplicate attachment metadata, and make durable media copying part of save acceptance. See F05.

## 4. Step 3 — Lock a note, then try another entry path

1. Edited the note, toggled its lock, and saved.
2. The normal preview path requested PIN setup. Canceled without entering or creating a PIN.
3. The Notes card showed a blurred Locked Note state.
4. Opened All → File Manager. The locked note's attachment and owner title were visible.
5. Tapped the attachment row. The preview displayed **Locked** alongside the full body **without authentication**.

| Normal authentication gate | Alternative path exposes locked content |
|---|---|
| ![PIN request on normal locked note path](evidence/screenshots/10-lock-authentication.png) | ![Locked note body exposed through attachments](evidence/screenshots/13-lock-bypass-confirmed.png) |

**Health:** Failed. This is a reproduced privacy defect, not only a source concern. The path did not use an authenticated vault session.

**Strength:** The normal preview path has a gate and the list visually redacts content.

**UX/security risk:** The user sees a lock badge while the body is readable through another route. File Manager also reveals metadata before authorization. The captured UI hierarchy retains the visually blurred note title, so visual blur alone does not establish assistive-technology privacy.

**Recommendation:** Fix F01/F09 before describing the feature as private storage. Apply one access policy to all entry paths, including notifications, exports, links, media, and accessibility semantics. No PIN or biometric credential was configured during this review.

## 5. Step 4 — Create a task and inspect its detail flow

1. Opened New task from the dashboard.
2. Entered a synthetic task; its saved title is `Review_tas` in the evidence.
3. Opened More, selected High priority, and added `Verify_docs` as a subtask.
4. Saved, opened Tasks, and expanded/collapsed the row.
5. Swiped the row to expose Edit, set its due date to Today, and saved. The task later appeared in the schedule summary and focus planning.

| Advanced task details | Saved task collection |
|---|---|
| ![Task editor with priority and subtask](evidence/screenshots/15-task-details.png) | ![Saved task list](evidence/screenshots/16-tasks-saved.png) |

**Health:** Basic creation, priority, subtask persistence, swipe-to-edit, and due-date persistence worked. Subtask completion/reset, deleting the final subtask, parent completion, linked-note behavior, and reminders remain source-reviewed rather than fully exercised. The attempted subtask tap in image 18 collapsed the parent row; it is **not** proof of subtask completion.

**Strengths:** The basic form stays short until More is opened. Common date presets and priority chips are familiar.

**UX risks:** New task is repeated in the header and FAB. Editing relies on a swipe action that is not obvious from the resting row. The top save check has no explicit tooltip in source. Custom row/checkbox semantics deserve direct screen-reader testing.

**Recommendation:** Keep progressive disclosure, add an obvious edit/details action, and fix F06/F07 before relying on task edits or reminder completion.

## 6. Step 5 — Calendar, schedule creation, and timeline layout

1. Opened Schedule with no dated items. Today/Week views showed No agenda for this day.
2. Tapped New schedule: received **Schedule coming soon**.
3. Source tracing showed empty-state rendering also removes the timeline long-press creation target.
4. Added a Today due date to the existing task. The timeline and generated focus block became visible.
5. Long-pressed an empty timeline slot, entered `Review_schedule`, and created a 30-minute event at 8:15 AM.
6. Observed the schedule count change to 1 and the event appear.
7. A one-hour focus card displayed a **16-pixel bottom RenderFlex overflow**.

| Main creation action | Alternate creation succeeds, with layout defect |
|---|---|
| ![New schedule placeholder message](evidence/screenshots/20-schedule-placeholder.png) | ![Created event and focus overflow](evidence/screenshots/24-schedule-created.png) |

**Health:** Partial. The secondary quick-add flow works after a dated item makes the timeline available. The primary creation action is blocked, and the timeline has a confirmed layout defect.

**Strengths:** The schedule combines tasks, events, and focus suggestions; counts update after creation.

**UX risks:** Summary cards, five filter chips, and calendar consume most of the visible height before the timeline begins. Today/Week changes date navigation behavior but both use a week calendar strip, which can obscure the difference. The essential first-event flow depends on a hidden gesture. The focus card offers a past 9 AM slot even though the current time is after 5 PM; future-only focus scheduling needs a product decision and tests.

**Accessibility risks:** Long press, drag, and resize need form/button equivalents. The pale Focus chip and crowded block text need contrast/reflow checks. The overflow is confirmed at the normal app font setting; large-text resilience is not established.

**Recommendation:** Connect New schedule to quick-add, keep an empty timeline or visible creation control, and fix block layout at constrained heights. See F11/F18.

## 7. Step 6 — Settings, notifications, and dark theme

1. Opened Settings through the overflow menu.
2. Opened Notification Center; observed its empty scheduled-reminder state.
3. Changed Theme from System to Dark. The app updated immediately.
4. Scrolled to Backup & Storage and About.
5. Observed version `1.4.0 (142)`, which disagrees with the installed/package `1.0.0+1`, and malformed Made with ?? copy.

| Settings in light theme | Settings after Dark selection |
|---|---|
| ![Light settings](evidence/screenshots/25-settings.png) | ![Dark settings](evidence/screenshots/27-settings-dark.png) |

**Health:** Appearance selection works and persists across restart. The Notification Center screen loads, but no delivery scenario was tested; its empty state is not proof that foreground/background alerts work.

**Strengths:** Settings have clear groups and use familiar rows, switches, and sheets.

**UX risks:** Voice, Auto Backup, update checks, store rating, and logout imply completed behavior that source does not implement. The lower settings screen shows duplicated chevrons on some rows and a dark-theme logout button whose label is visually difficult or impossible to discern in the capture.

**Recommendation:** Remove or label unfinished settings, fix version/copy and button contrast, and verify notification delivery separately. See F13/F17.

## 8. Step 7 — Export and verify recovery

1. Chose Create Backup. The Android share sheet offered a generated ZIP; canceled without choosing a recipient or external destination.
2. Inspected that actual ZIP: one JSON file, one locked note, no attachment bytes, no task/schedule data.
3. Created a controlled, valid notes-array ZIP containing `Restore_probe` with unused ID `999999`.
4. Imported that fixture through Restore from File.
5. The app displayed Restore successful. The list still contained only the original locked note.
6. A database snapshot query confirmed `restore_probe_count: 0`.

| Claimed restore success | Resulting collection without the imported note |
|---|---|
| ![Restore successful toast](evidence/screenshots/30-restore-success-message.png) | ![Imported note missing](evidence/screenshots/31-restore-note-missing.png) |

**Health:** Failed recovery. The tested missing-ID import did not insert the note. This test used the review database with an existing synthetic note; it was not a separate fresh-install round-trip.

**Evidence beyond screenshots:** [ZIP inspection](evidence/logs/backup-inspection.json), [restore fixture](evidence/fixtures/restore-probe.zip), [database result](evidence/logs/restore-probe-result.json).

**UX risk:** A success message without validated record counts creates false confidence. Backup scope and share-ZIP scope are different and need explicit labels. Export also included the locked note without an authentication step.

**Recommendation:** Fix F02/F03 and report verified imported counts before presenting restore as successful. Do not use this ZIP as the sole recovery copy of important data.

## 9. Step 8 — Search and cold restart

1. Entered `Review` in Home's search field and submitted.
2. Global search returned the task and excluded the locked note, but its field showed the placeholder rather than the submitted query.
3. Typed `Review` in the destination field, then pressed its clear action. Results disappeared while visible text remained `Review`.
4. Force-stopped and relaunched the installed app.
5. The stable dashboard returned in Dark mode. Database checks confirmed 1 note, 1 attachment row, 1 task, 1 subtask, and 1 schedule; no reminder had been created.

| Search after Clear | Stable dashboard after cold restart |
|---|---|
| ![Visible query remains after clearing state](evidence/screenshots/34-search-clear-mismatch.png) | ![Data and dark theme survive cold restart](evidence/screenshots/35-cold-start-persistence.png) |

**Health:** Partial. Basic task search and locked-note exclusion worked; query/field synchronization failed. Fixture persistence across one process restart worked. See [persistence counts](evidence/logs/cold-start-persistence.json).

**Recommendation:** Bind the field to the same query state, initialize it on navigation, and test Clear and stale asynchronous responses. One restart does not establish migration, cache-loss, reboot, or backup safety.

## 10. Evidence limits and follow-up checks

| Not verified | Why it matters |
|---|---|
| TalkBack, keyboard focus, measured contrast, large text, reduced motion | Screenshots and UI hierarchies are insufficient for compliance |
| Physical biometrics, camera, microphone, representative media codecs | Emulator and text attachment cover only a narrow path |
| Scheduled notification delivery, snooze, reboot, Doze, permission denial | Notification Center empty state is not a delivery test |
| Full rich text/PDF printing, very long documents, non-Latin output | Requires document fixtures and output inspection |
| Undo, subtask completion/reset, schema upgrades, collision recovery | Source-confirmed defects need focused regression tests |
| Release/profile performance and other operating systems | Debug emulator behavior is not production performance/support evidence |

The installed app is left running with synthetic review data. The Flutter debug connection ended intentionally when the app process was force-stopped for the persistence check.

Related: [findings](APP_FEEDBACK.md) · [feature matrix](FEATURE_STATUS.md) · [architecture diagram](APPLICATION_ARCHITECTURE.md) · [verification](VERIFICATION.md).
