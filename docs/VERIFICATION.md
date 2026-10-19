# Digital Memory — Verification Record

> Review date: **19 October 2026 · Asia/Kolkata**. Commands ran in the project workspace. A failure is retained as a result, not relabeled as a pass.

## 1. Environment

| Component | Observed value |
|---|---|
| Host | Windows, PowerShell |
| Flutter | 3.47.5 stable, framework `6a19cca564` |
| Dart | 3.13.4 |
| Android emulator | `Pixel_6a`, runtime serial `emulator-5554` |
| Android OS | Android 15 / API 35 / x86_64 |
| Screen | 1080 × 2400 physical pixels |
| Java selected by Flutter | Android Studio JBR 21.0.10 |
| Android SDK | Toolchain reports 36.1.0 |
| Doctor caveat | Some Android licenses unaccepted; not automatically accepted during this review |

[Doctor output](evidence/logs/flutter-doctor.txt). The emulator's own status-bar date/time may differ from the review date; screenshots are genuine captures from this run, not edited to match the report.

## 2. Commands and outcomes

| Check | Outcome | Evidence |
|---|---|---|
| `flutter --version`, `flutter devices`, `flutter emulators` | SDK and available emulator identified | Values recorded above |
| `flutter emulators --launch Pixel_6a` | Emulator started and appeared in `adb devices` | Runtime serial and screenshot evidence |
| `flutter pub get` | Succeeded; SDK-driven transitive resolutions changed | [pub-get.txt](evidence/logs/pub-get.txt) |
| `flutter analyze --no-pub` | Failed quality gate: 29 diagnostics, no analyzer errors | [initial analyzer](evidence/logs/flutter-analyze.txt) |
| `flutter test --no-pub --reporter expanded` | Initial compile failure in Quill 11.5.0 | [initial test](evidence/logs/flutter-test.txt) |
| `flutter pub upgrade flutter_quill` | Resolved Quill to 11.6.0 within existing constraint | [upgrade log](evidence/logs/quill-compatibility-upgrade.txt) |
| Existing widget test after Quill resolution | Compiles, fails at missing preferences override and unmet text expectation | [test after compatibility](evidence/logs/flutter-test-after-compatibility.txt) |
| Android run with original build configuration | Failed minimum Gradle check: 8.12 below required 8.14 | [initial Android log](evidence/logs/flutter-run-initial.txt) |
| Gradle download attempts from Java wrapper | Failed with connection refused | [first download failure](evidence/logs/flutter-run.txt), [direct-host attempt](evidence/logs/flutter-run-verified.txt) |
| Cached Gradle 9.1.0 diagnostic attempt | Failed: old `video_thumbnail` plugin calls removed `jcenter()` | [diagnostic build](evidence/logs/flutter-run-cached-gradle.txt) |
| Final analyzer after dependency resolution | Still 29 diagnostics: 6 warnings, 23 info | [final analyzer](evidence/logs/flutter-analyze-final.txt) |
| Final Android build and walkthrough | See the final recorded result below and [Evidence](EVIDENCE.md) | [final run log](evidence/logs/flutter-run-final.txt) |

The analyzer scans application/test Dart under the project configuration; it is not a substitute for compiling every dependency or running platform code.

## 3. Compatibility adjustments made during review

| File | Change | Reason |
|---|---|---|
| `pubspec.lock` | Flutter SDK transitive resolution changes, plus Quill 11.5.0 → 11.6.0 | Old Quill lacks `TextInputClient.onFocusReceived` required by this Flutter SDK |
| `android/settings.gradle.kts` | AGP 8.9.1 → 8.11.1; Kotlin 2.1.0 → 2.2.20 | Meet installed Flutter's minimum Android dependency checks |
| `android/gradle/wrapper/gradle-wrapper.properties` | Gradle 8.12 → 8.14 bin distribution; official SHA-256 pinned | Meet minimum; retain Gradle 8 compatibility with the existing thumbnail plugin |
| `android/gradle.properties` | Flutter added `android.builtInKotlin=false` and `android.newDsl=false` | Automatic Flutter project migration |
| `analysis_options.yaml` | Flutter added build/platform directory exclusions | Automatic Flutter project migration |

`pubspec.yaml` was not intentionally edited. Its declared Dart lower bound is older than the SDK required by the newly resolved Quill; use the tested Flutter version for this baseline and reconcile the declared minimum before release. No application Dart source or existing test was edited for the audit. The [baseline inventory](evidence/dart-file-inventory.json) and [final hashes](evidence/dart-file-final-hashes.json) allow verification of that claim.

Original Android settings and wrapper files are preserved as [settings before](evidence/logs/android-settings-before.txt) and [wrapper before](evidence/logs/gradle-wrapper-before.txt). There was no Git history available for a full pre-review diff.

### Why Quill changed

The compiler explicitly reported the missing text-input method. The upstream [Flutter Quill changelog](https://github.com/singerdmx/flutter-quill/blob/master/CHANGELOG.md) documents its implementation beginning in 11.5.1 for Flutter 3.44+. The existing caret constraint permitted 11.6.0. The subsequent test compiled far enough to expose the independent bootstrap test failure.

### Gradle distribution verification

The wrapper's Java downloader could not reach the redirected distribution. The same official distribution was downloaded using Python, compared with the publisher's checksum, and extracted into the wrapper cache. Final wrapper URL:

```text
https://downloads.gradle.org/distributions/gradle-8.14-bin.zip
SHA256: 61ad310d3c7d3e5da131b76bbf22b5a4c0786e9d892dae8c1658d4b484de3caa
```

The final wrapper pins that checksum. This is an environment-specific download workaround, not a dependency-validation bypass. Gradle/AGP/Kotlin remain below Flutter's future-warning targets; plan a coordinated later migration after updating incompatible plugins.

## 4. Existing test failure

`main.dart` provides SharedPreferences through an override. `test/widget_test.dart` directly constructs `SecondBrainApp` under a default `ProviderScope`, causing `sharedPreferencesProvider` to throw `UnimplementedError`. The “All Notes” expectation then fails because the app never builds successfully.

Repair the fixture with controlled preferences, database, notification, and platform dependencies before relying on this test. This review preserves the failing test rather than changing the quality baseline to appear healthy.

## 5. Runtime evidence and limits

Screenshots and action results are indexed in [Evidence](EVIDENCE.md), with user-facing interpretation in [App Workflow](APP_WORKFLOW.md). Only actually captured states are treated as runtime proof. Source-confirmed findings are not automatically promoted to reproduced bugs.

Not covered by this review: release-mode performance benchmarks, physical biometrics/microphone/camera, reboot/Doze notification reliability, large data migrations, complete accessibility testing, iOS/desktop/web execution, signed release distribution, or comprehensive security testing.

## 6. Final recorded Android result

**Build and launch succeeded.** The fresh debug APK was built in 548.5 seconds, installed in 6.5 seconds, and ran on `emulator-5554`. The resulting APK was 105,730,740 bytes. A Dart VM service was available during the walkthrough.

**Observed startup caveat:** Android displayed a Process system isn't responding dialog; Wait allowed review to continue. The log records skipped frames. This is retained as observed emulator startup trouble, without attributing it solely to app code or treating debug timing as a release benchmark.

**Completed runtime checks:** note creation/autosave indicator/explicit save, text attachment and preview, normal lock prompt plus alternative-path bypass, task/priority/subtask save and due-date edit, schedule FAB placeholder plus successful timeline quick-add, Notification Center empty state, dark theme, actual ZIP generation/inspection, missing-ID restore failure, search query/clear mismatch, and one cold restart with database count verification. The gallery contains 35 inspected PNGs.

**Runtime failure:** `A RenderFlex overflowed by 16 pixels on the bottom`, with the error-causing Column at `schedule_tab.dart:1714`. It is visible in screenshots 22 and 24. Other source-confirmed findings remain open even when not reproduced.

**Final app state:** Intentionally force-stopped and relaunched the installed app to test persistence; the debug tool's Lost connection to device at that moment is expected, not a spontaneous crash. The emulator app remains running in Dark mode with synthetic review fixtures: 1 note, 1 attachment row, 1 task, 1 subtask, 1 schedule, and 0 reminders. [Persistence result](evidence/logs/cold-start-persistence.json).

No release build, production push, or GitHub repository was created. See [Current Status](CURRENT_STATUS.md) for the release verdict.

## 7. Documentation acceptance

The [validation utility](evidence/validate_review.py) checked the root README plus all 12 current Markdown reports: **373 local links, zero broken targets; 65 unchanged Dart files; 35 PNG hashes verified; README.md is the only root Markdown file**. [Validation result](evidence/logs/documentation-validation.json). Historical archived prose is preserved separately and is not presented as current verification.

The tldraw diagram PNG was opened after local export. Each final screenshot was opened and accepted for the state described in the gallery. The gallery keeps explicit caveats for the startup blocker, Android input toolbar, and collapsed task observation. Final counts and links can be rechecked with:

```powershell
python docs/evidence/validate_review.py
```

