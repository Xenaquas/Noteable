# Digital Memory — Feature Status

> **19 October 2026.** “Implemented” means code exists. “Verified” requires a named runtime check. No completion percentages are invented.

## 1. Status legend

| Status | Meaning |
|---|---|
| Implemented, bounded verification | Working source path; runtime scope is limited to the evidence log |
| Partial / defective | Useful implementation exists but a known gap affects completion |
| Placeholder | Visible setting/action or schema exists without its promised behavior |
| Not implemented | No supporting implementation found in reviewed application code |
| Not verified | Requires hardware, platforms, or scenarios not exercised here |

## 2. Core product matrix

| Feature | Status | Source and behavior | Acceptance still needed |
|---|---|---|---|
| Create/edit notes | Implemented, bounded verification | Quill editor, title/category, note repository | Long notes, interruption during save, DB failure |
| Note preview | Implemented, bounded verification | Separate rich reading screen and media viewers | Large rich documents and unsupported media |
| Autosave | Partial / risk | Two-second debounce; skips empty draft and locked state | Edits during an in-flight save; lifecycle exit; failure feedback |
| Categories | Implemented, bounded verification | Personal, Work, Ideas; stored on notes | User-defined category CRUD is not implemented by empty category files |
| Pinning | Partial | Repository orders pinned first; Home VM applies another global sort | Verify pin remains dominant in all sort modes |
| Grid/list and sort | Implemented, bounded verification | Preference-backed Home VM | Large dataset and pinned ordering |
| Search notes/tasks | Partial / defective | SQL note LIKE, task scan, debounce, filters | Clear-field bug; stale responses; error state and scale |
| Delete note | Partial / defective | Transaction removes note/attachment rows | Undo, linked-record policy, physical media cleanup |
| Undo note deletion | Defective | Nullable-ID copy preserves deleted ID; upsert only updates | F04 regression scenario |
| Attach local files | Partial / risk | File/image/video pickers and local-path rows | Permanent media ownership, missing-file recovery |
| Audio recording/playback | Implemented, not fully verified | FlutterSound recorder, audio/video playback components | Real microphone, permission denial, codecs, interruption |
| Image/PDF/video preview | Implemented, not fully verified | Local viewers and thumbnails | Representative files, large media, external opens |
| Attachment browser | Partial / privacy defect | Cross-note filters and sorting | Locked note and private media access policy |
| Lock individual notes | Partial / privacy defect | List/preview auth plus PIN/biometrics | Bypass entry points, encryption claims, timeout |
| App biometric lock | Partial / risk | Home lifecycle gate and preference | Physical hardware, pushed screens, unavailable biometrics |
| PIN fallback | Partial / unsafe storage | SharedPreferences PIN string | Secure verifier, validation, throttling, recovery |
| Vault collection | Partial | In-memory session, locked collection page/sheet | Lifecycle relock and stale snapshot refresh |

## 3. Productivity matrix

| Feature | Status | Current implementation | Remaining gap |
|---|---|---|---|
| Create/edit tasks | Implemented, bounded verification | Title, description, priority, dates, note link | Save error/busy states; duplicate taps |
| Complete tasks | Partial | Task row toggles | Outstanding reminders are not canceled |
| Task filtering/search | Implemented, bounded verification | Active/done/priority and string filters | Consistency between Home pane and separate TasksScreen |
| Task reordering | Implemented in source | Sort indices and DAO updates | Filtered ordering, transactionality, UI paths |
| Subtasks | Partial / defective | Add, order, complete | Parent save resets completion; empty-list save does not clear |
| Linked task note | Partial | Nullable note ID across database files | Deletion/remap policy and locked metadata visibility |
| Labels | Schema/repository scaffolding | Drift labels and links | No complete user label workflow confirmed |
| Calendar and timeline | Implemented, bounded verification | Today/week, filters, tasks, schedules, note reminders | Multi-day/time-zone/large-text behavior |
| Quick schedule creation | Runtime-verified with fixture | Long-press quick-add persisted Review_schedule after a dated task made the timeline visible | Empty view hides target; main FAB integration |
| New schedule FAB | Placeholder | “Schedule coming soon” snackbar | Connect to actual quick-add |
| Schedule drag/resize | Implemented, not fully verified | Drag/drop and duration writes | Precision and accessible fallback |
| Schedule full edit/delete | Partial / absent UI | Repository supports writes/delete; screen detail focuses on links | Complete form and delete confirmation |
| Conflicts and focus blocks | Implemented heuristics | Local timeline calculations | Realistic conflicts, no free slot, completed tasks |
| Timeline card layout | Runtime defect | One-hour focus block overflows by 16 pixels | F18; constrained heights and large text |
| Recurring tasks/schedules | Placeholder at schema level | `recurrenceRule` stored/preserved | No recurrence engine or user flow found |
| Reminders | Partial / reliability risk | Reminder rows, foreground polling, system scheduling | Permissions, horizon, completion, restart/reboot |
| Snooze | Implemented, not fully verified | Ten-minute reminder insertion | Preserve subtasks/task state, duplicate/cancel rules |
| Notification Center | Partial | Upcoming scheduled items | Error recovery, fired history, locked-note policy |

## 4. Settings and recovery

| Feature | Status | Evidence / limitation |
|---|---|---|
| Light/dark/system theme | Implemented, bounded verification | AppTheme and persistent preference |
| Dynamic colors | Implemented, device dependent | DynamicColorBuilder |
| Font family/size | Implemented, not fully verified | Google Fonts and 80–140% setting; first-use offline fallback needs test |
| Language choice | Partial | Six framework/editor locales; app strings largely English |
| Canvas/text/highlight overrides | Source support | Stored settings and theme parameters; no claim that every setting has a reachable current control |
| Keep screen on | Implemented, not fully verified | Wakelock preference and plugin |
| Auto-lock timer | Partial / semantic defect | UI “Off” is zero; lifecycle comparison treats zero as immediate |
| Create Backup | Runtime-verified, limited scope | Actual exported ZIP contained one note JSON, no media/tasks/schedules |
| Export Single Note | Partial / restore mismatch | Object JSON versus restore array expectation |
| Restore from File | Runtime-confirmed defect | ID 999999 import reports success but inserts no note; collision/cancel behavior also needs coverage |
| Share PDF | Implemented, not fully verified | Primarily plain content; long/non-Latin/rich content needs coverage |
| Share note + attachments ZIP | Implemented, not fully verified | Different from restorable backup format |
| Auto Backup setting | Placeholder | Screen-local selection; no persistence/scheduler |
| Voice setting | Placeholder | Screen-local selection; no speech behavior |
| Update check | Placeholder | Static “up to date” snackbar |
| Store rating | Placeholder | “Opening store soon” snackbar |
| Logout/account | Placeholder / no backend | Snackbar only; no real account flow |
| App version display | Defective metadata | Settings hardcodes `1.4.0 (142)` while package is `1.0.0+1` |
| License screen | Implemented | Flutter license page; project license decision still needed |

## 5. Platform and project status

| Capability | Status |
|---|---|
| Android debug execution | Built, installed, and ran; 35 screenshots and one cold restart. See [Verification](VERIFICATION.md) |
| Physical Android | Not verified |
| iOS | Not built or run; camera/microphone/Face ID usage descriptions require review |
| Windows/macOS/Linux | Platform projects present; not runtime-verified |
| Web | Not verified; unconditional `dart:io` and native DB imports require an explicit web strategy |
| Release signing | Template debug signing; not production-ready |
| Source version history | No Git repository on arrival; no push performed |
| Cloud sync | Not implemented |
| App-data encryption | Not implemented as a verified encryption layer |
| App data version history/trash | Not implemented as a durable workflow |
| Full automated tests | Absent; existing single widget test fails |

## 6. How to update this report

Change a row to Verified only with a reproducible test or a new screenshot/action record. Add platform/device/version and test data. A schema field, dependency, TODO, old plan, or visible control is not sufficient proof of feature completion.

Related: [Current Status](CURRENT_STATUS.md) · [App Feedback](APP_FEEDBACK.md) · [Future Scope](FUTURE_SCOPE.md).
