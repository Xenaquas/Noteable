# Digital Memory — Review Documentation

> **Application review · 19 October 2026 · Android emulator + Dart/Flutter source**

## Start here

| Read | What it answers |
|---|---|
| [Current Status](CURRENT_STATUS.md) | Does it run, what is blocked, and is it ready to release? |
| [App Feedback](APP_FEEDBACK.md) | Which defects and design issues matter most, and how should fixes be accepted? |
| [App Workflow](APP_WORKFLOW.md) | What does the user do, with screenshots and step-by-step health? |
| [Feature Status](FEATURE_STATUS.md) | Which features are implemented, incomplete, placeholders, or unverified? |
| [Application Architecture](APPLICATION_ARCHITECTURE.md) | How are UI, state, storage, services, and navigation connected? |
| [Dart Code Review](DART_CODE_REVIEW.md) | What was reviewed in each of the 65 Dart files? |
| [Future Scope](FUTURE_SCOPE.md) | What should be done next, with measurable milestones? |
| [Project Context](PROJECT_CONTEXT.md) | What is this app, who is it for, and how did the project arrive here? |
| [Verification Record](VERIFICATION.md) | Which commands ran, which failed, and what compatibility changes were necessary? |
| [Evidence Gallery](EVIDENCE.md) | Where are the exact screenshots, action records, and logs? |
| [GitHub Readiness](GITHUB_READINESS.md) | How should source history, backup, branches, and the first push be handled? |

## Visuals

- [Editable tldraw architecture and workflow](https://www.tldraw.com/f/MJ8ymcLzU-nKT2TWyaEVd).
- [Local exported diagram](diagrams/tldraw-review.png), inspected after saving.
- Diagram sources: [architecture](diagrams/architecture.mmd), [workflow](diagrams/workflow.mmd).
- [Android screenshots](evidence/screenshots/) are embedded in the workflow and evidence reports.

## Evidence rules

| Label | Interpretation |
|---|---|
| Runtime-confirmed | Reached and observed in this review's actual emulator session |
| Source-confirmed | Traced in application source; not necessarily reproduced on device |
| Risk / not verified | Requires a scenario, dataset, device, or platform outside the completed checks |
| Proposed | Future work, not a current feature |

A screenshot proves a visible state. It does not establish all data persistence, security, accessibility, or background-delivery properties. Source references and command logs supplement screenshots where visuals alone cannot prove the conclusion.

## Historical documents

Previous root plans and summary were preserved under [archive](archive/). They are not the current status report. `README.md` remains the only Markdown document at the project root.

## Maintenance

When fixing a finding, reference its F-number, record the test and platform, and update the relevant feature/status row. Keep original review evidence unchanged; put later verification in a dated evidence directory. Commit focused changes so source history can be backtracked meaningfully.
