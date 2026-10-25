# Phase A execution evidence

These records belong to the privacy repair on 19 October 2026. The earlier audit evidence remains historical. See [the full report](../../PHASE_A_SECURITY_REVIEW.md) for decisions, the preservation incident and the manual release checklist.

## Final results

| Artifact | Actual result |
|---|---|
| `flutter-test-final.txt` | 30 host tests passed, 2:22 |
| `android-integration-final.txt` | 8 tests passed on the isolated API 35 AVD; build 172.1 s, install 26.7 s, tests 1:35 |
| `analyze-final.txt` | Exit 1; zero errors, four preexisting warnings and 24 informational lints |
| `android-app-build-final.txt` | Normal application debug APK built successfully, 116.5 s; existing Gradle/AGP/Kotlin support warnings remain |
| `android-update-install.txt` | Explicit `adb -s emulator-5560 install -r` succeeded; no automatic uninstall fallback |
| `prompt-revocation-final.txt` | Focused revoked-dialog/root-reauthentication regression passed |
| `android-window-flags.txt` | Android reports `SECURE` on the application window |
| `android-secure-window.png` | Original OS capture is black; capture protection was enabled |
| `document-qa.json` | Nine Word pages rendered through Microsoft Word and visually inspected; three embedded images |
| `changed-files.txt` | Exact file inventory relative to the baseline commit |

## Debugger limitation

The final normal app was launched after an explicit update-only install on the isolated AVD. Two MCP hot-restart requests returned `Service connection disposed`. The attached Flutter consoles reported `Restarted application in 8,303ms` and `Restarted application in 4,080ms`, respectively, followed by `Lost connection to device`. The second attach disabled DDS; the failure recurred. The Android process remained alive and a bounded logcat check did not show a matching fatal exception. This is an unresolved debugger/session limitation, **not a verified clean hot-restart result**. No source changes were made in response and no data-bearing emulator was reinstalled to investigate it. The separately completed integration suite passed.

## Earlier attempts retained

- `android-integration.txt`: first isolated-AVD launch failed with `VmServiceDisappearedException`; no native tests from that attempt count as passed.
- `android-debug-build.txt`: intermediate generated-plugin/build configuration failure; later clean builds passed.
- `flutter-test-before-overlay-fix.txt` and `routes-before-overlay-fix.txt`: reproduced missing-overlay failure in the root PIN field; fixed with `Overlay.wrap` and covered by the final suite.
- `review-regression-red.txt`: reproducing failures before focus/attempt-lifecycle fixes. `review-regression-green.txt` records their focused passes.
- `routes-diagnostic.txt`, `routes-regression.txt` and `analyze-intermediate.txt`: intermediate diagnostics retained for traceability.

The bundled Word renderer could not run because LibreOffice is absent. The existing read-only Microsoft Word export fallback produced the nine-page PDF for raster QA. An intermediate OOXML diagram-paragraph error was corrected before delivery. The title sanitizer passed; all nine final page images were inspected. QA intermediates stay outside the repository.

## Preservation incident and scope

The first `flutter run` on the original emulator automatically uninstalled the existing application after `INSTALL_FAILED_INSUFFICIENT_STORAGE`, removing its data. This was unintended and disclosed. The original database has not been recovered. There is no verified pre-uninstall application-data snapshot from this execution; earlier audit counts/screenshots cannot substitute for it. All later install/test commands target only the newly created disposable AVD `Noteable_Privacy_API35_20261019` at `emulator-5560`.

Application changes contain no database reset, schema rewrite or backup/restore implementation change. `backup_service.dart`, `app_database.dart` and `app_drift_database.dart` match the baseline. Phase B is awaiting explicit approval. Overall P0 release gate remains **FAIL**.

Synthetic PINs and note/file labels in test source and logs are disposable fixtures, never production credentials. Source control and Drive copies of these reports are not backups of application databases or user media.
