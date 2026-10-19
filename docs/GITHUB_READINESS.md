# Digital Memory — GitHub and Version-Control Readiness

> **19 October 2026.** The connected GitHub profile was available. The local project was **not a Git repository** when reviewed. No repository, remote, commit, push, branch, or pull request was created by this review.

## 1. What GitHub will protect

Git records source, configuration, documentation, diagrams, and selected evidence at each commit. It supports comparisons, branches, tags, and recovery of committed versions. A remote copy provides an additional backup of those committed files.

Git does not automatically preserve uncommitted work, ignored files, emulator data, installed app databases, private keys, or note attachments stored outside the repository. Source history and app-data recovery are separate concerns.

## 2. Current readiness

| Item | Status / action |
|---|---|
| Local history | Missing on arrival; initialize when ready to create the baseline |
| GitHub connection | Profile lookup succeeded through the selected GitHub plugin |
| Remote destination | Not supplied or selected |
| Documentation | Root README links to `docs/`; old plans preserved under `docs/archive/` |
| Ignore rules | Root and Android ignore files exist; inspect the actual staged file set |
| Lockfile | Keep `pubspec.lock` for this application; review the compatibility changes |
| Quality gates | Analyzer warnings/info and failing widget test remain; do not mark CI green |
| Build baseline | Review compatibility adjustments in [Verification](VERIFICATION.md) |
| Signing | Release currently uses debug signing; final signing material must stay private |
| License | No top-level project license observed; choose one before public distribution |
| User data | Screenshots use review fixtures; inspect all evidence before public publication |

## 3. Proposed first push

Run from the project directory. The URL below is an explicit placeholder to replace with the actual new repository URL; it is not an existing verified repository.

```powershell
git init -b main
git status --short
git add .
git add -f android/gradlew android/gradlew.bat android/gradle/wrapper/gradle-wrapper.jar
git diff --cached --stat
git diff --cached --check
git status --short
# Inspect the staged files before committing.
git commit -m "Document Digital Memory baseline and application review"
git remote add origin https://github.com/OWNER/REPOSITORY.git
git push -u origin main
```

Create the remote repository with the intended visibility and avoid generating an unrelated starter README if you want to push this existing tree directly. Use a private remote initially if source, screenshots, or sample content have not been cleared for publication.

The commands above are instructions, not actions performed in this review. Authentication, ownership, visibility, and the destination remain decisions for the actual push.

## 4. Files to include

| Include | Why |
|---|---|
| `lib/`, `test/`, platform source and build configuration | Reconstruct and build the app |
| `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml` | Reproduce dependencies and quality configuration |
| Gradle wrapper scripts/JAR/properties | Reproduce Android tooling |
| `README.md`, current `docs/`, sanitized evidence and local diagrams | Reviewable project context and portable proof |
| Generated Drift Dart file, if retaining current checked-in generation policy | Needed by current imports; document regeneration |

## 5. Files to exclude or inspect

| Exclude / inspect | Reason |
|---|---|
| `build/`, `.dart_tool/`, platform build caches | Large generated outputs and machine paths |
| `android/local.properties` | SDK paths specific to this machine; Android ignore rules cover it |
| `.idea/`, `*.iml` | Local IDE state |
| Signing keystores, `key.properties`, credentials, tokens, `.env` secrets | Private configuration |
| App databases, exported user backups, recorded audio, private media | User data, not source history |
| Heap dumps and profiling traces | Can be large and contain sensitive memory |
| Historical inspiration assets | Check attribution and redistribution rights |
| Review logs and screenshots | Inspect for personal paths/content before a public push |

The Android ignore file currently excludes `gradlew`, `gradlew.bat`, and `gradle-wrapper.jar`. The explicit force-add above includes those three existing build bootstrap files, without force-adding SDK paths or signing keys. The current root ignore includes `*.log`; review logs are saved as intentional `.txt` evidence. Do not assume every log should be published. The report does not claim a comprehensive secret scan.

## 6. Everyday workflow

```powershell
git switch -c fix/backup-round-trip
# Make one focused change, then run relevant checks.
flutter analyze
flutter test
git add lib test docs
git diff --cached
git commit -m "Restore notes safely into a clean database"
git push -u origin fix/backup-round-trip
```

Use a pull request to explain the user-visible issue, resulting behavior, and validation. Commit fixes in small units so reverting one issue does not discard unrelated progress. Tag a stable version only after its release gates pass.

## 7. Returning to previous versions

| Goal | Command | Consequence |
|---|---|---|
| Inspect history | `git log --oneline --decorate` | Read-only view of commits |
| Compare revisions | `git diff OLD_COMMIT NEW_COMMIT` | Shows changes |
| Safely undo a published change | `git revert COMMIT_SHA` | Creates a new inverse commit |
| Inspect an old version in a branch | `git switch -c inspect-old COMMIT_SHA` | New branch at the old revision; save current work first |

Avoid rewriting shared history as a routine recovery method. Checking out older source does not migrate an installed app's database backward. Test old builds against copied fixtures or a separate emulator; do not assume data-schema compatibility.

## 8. CI proposal

After repairing the existing test, add a pinned Flutter workflow that runs dependency resolution, formatting checks, static analysis, tests, and an Android debug build. Add repository/migration tests before using CI to approve persistence changes. Keep release signing in appropriate private CI secrets only when release automation is intentionally introduced.

Related: [current status](CURRENT_STATUS.md) · [verification](VERIFICATION.md) · [future scope](FUTURE_SCOPE.md).
