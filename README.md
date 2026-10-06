# RepoAdmission Demo

**Watch an approval die.** Sanitize a booby-trapped iOS repository, approve what is left, then pull one upstream edit to a Run Script phase — and see `swift build` flip from ALLOW back to DENY without anyone revoking anything.

[![CI](https://github.com/rajatslakhina/repo-admission-gate-kit-demo/actions/workflows/ci.yml/badge.svg)](https://github.com/rajatslakhina/repo-admission-gate-kit-demo/actions/workflows/ci.yml)

This is the companion app for **[RepoAdmission](https://github.com/rajatslakhina/repo-admission-gate-kit)** — an admission gate that sits in front of a coding agent (as a Claude Code `PreToolUse` hook) and decides whether `git`, `swift` and `xcodebuild` calls may run against an untrusted repository. It is a separate Xcode project that consumes the library as a **remote Swift package**: the requirement is `upToNextMajorVersion` from `2.0.0`, and the exact revision a clone gets is locked by the committed `Package.resolved` — which CI enforces with `-disableAutomaticPackageResolution`, so a build can never silently float to a different commit.

## Why this matters

A cloned iOS repository can make your machine run its code before anyone reads it: `core.fsmonitor` fires on `git status`, a `.gitattributes` filter fires on checkout, build-tool plugins and macros fire on `swift build`, Run Script phases and scheme pre-actions fire on `xcodebuild`. Coding agents run those commands first. The demo makes the gate's three load-bearing ideas visible:

1. **It gates the operation, not the repository.** `ls` is allowed from the start; after sanitizing, `git status` and `git log` are allowed while `git submodule update` stays denied — the console shows a verdict per command, and why.
2. **Sanitizing never touches a tracked file.** It edits only `.git/`, so the working tree an agent will diff stays byte-identical.
3. **Approval binds to content.** The approval is a SHA-256 of the exact executable surface. One upstream byte later, it no longer matches.

## What you see

The app opens on `RedTeamFixture`, an in-memory repository planting **40 execution vectors across five families** (git config, hooks, attributes & submodules, SwiftPM, Xcode project) plus decoys that must not be reported. Nothing in it ever executes; it is only scanned.

The header shows the repository's state; the probe list shows what each of nine agent commands would get. The table names the probes whose verdict changes at each step (the full flow, all nine probes, is asserted by `AdmissionConsoleModelTests` in the library).

| Step | Button | What changes on screen |
|---|---|---|
| 0 | — | Header: **"Quarantined — denied vectors present, nothing approved"**. `git status` DENY (fsmonitor), `git log --oneline -5` DENY (pager / textconv), `ls -la` ALLOW, `git -c core.fsmonitor=… status` DENY (injection), `sh -c "$(curl …)"` ASK |
| 1 | **Sanitize .git/** | Config exec keys, includes and the live hook are removed. `git status`, `git log`, `git diff` → ALLOW. `swift build` / `xcodebuild` still DENY (plugins, macros, script phases need approval). `git submodule update` stays DENY — the poisoned `.gitmodules` is tracked, so it cannot be sanitized. Header still **"Quarantined"** (that one deny remains, nothing approved yet). |
| 2 | **Approve current surface** | Header: **"Admitted for approved operations — 1 denied vector(s) still block what fires them"**. `swift build` and `xcodebuild` → ALLOW. `git submodule update` still DENY: approval never clears a deny. |
| 3 | **Pull an upstream change** | One line is appended to the Lint script phase. Header: **"Re-quarantined — the surface changed after approval"** — `swift build` and `xcodebuild` → DENY with "The previous approval no longer matches: the executable surface changed." The provenance log records `approval … voided`. |
| — | **Reset** | Back to step 0 with a fresh gate. |

Buttons are disabled while an action is running; the model also refuses overlapping actions, so a Pull can never land in the middle of a Sanitize.

The app owns the policy (`DemoApp.policy`): `.strict`, plus one allow-listed package pin — `swift-syntax` at the exact revision the fixture's `Package.resolved` records — to show an allow-list shrinking the approval surface by content (identity + revision), never by name.

## Screenshots

**There are no screenshots, and the app has not been run on a Simulator.** No image in this repository claims to show it. The rest of this page describes what the code does, traced by hand and asserted by tests; it is not a record of watching it run.

## How to run it

1. `git clone https://github.com/rajatslakhina/repo-admission-gate-kit-demo.git`
2. Open `Demo.xcodeproj` in Xcode 16 or later. Xcode resolves `repo-admission-gate-kit` from GitHub at the revision `Package.resolved` records.
3. Select the **Demo** scheme and any iOS 17+ Simulator.
4. Build & Run (⌘R), then press the buttons top to bottom.

## Verification

Exactly what has and has not been verified, as of this release:

- **Launched on an iOS Simulator: no.** On the build day the agent that wrote this was granted access to Xcode and Simulator on the author's Mac, but Xcode access was click-only (no typing), so it could not open or clone this project itself. The author was asked to open `Demo.xcodeproj`; when the agent checked, Xcode's Window menu still listed only an unrelated workspace, which it did not touch. So the run did not happen. "It builds for the Simulator" (below) is a separate, weaker claim.
- **Builds for the iOS Simulator SDK: yes, in CI.** The [Actions workflow](https://github.com/rajatslakhina/repo-admission-gate-kit-demo/actions/workflows/ci.yml) resolves the remote package with `-disableAutomaticPackageResolution`, so it must use the committed `Package.resolved` (library `v2.0.0`, revision `8025133`), prints that file, then runs `xcodebuild build -scheme Demo -destination 'generic/platform=iOS Simulator'` with the same flag. That proves the package resolves from GitHub at the locked revision and the app compiles against it. It does **not** launch the app.
- **The headline flow: tested, not watched.** The view model this app renders (`AdmissionConsoleModel`) is exercised in the library's `AdmissionConsoleModelTests` under the same policy this app ships (`.strict` + the swift-syntax pin): every header state and probe verdict in the table above is asserted there, on Linux and macOS CI.
- **Remote dependency:** `XCRemoteSwiftPackageReference` at `https://github.com/rajatslakhina/repo-admission-gate-kit.git`, `upToNextMajorVersion` from `2.0.0`, locked by the committed `Package.resolved`.

## License

MIT
