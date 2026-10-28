# Testing and Validation

Read before tests, builds, running, sanitizers, profiling, or handing off code.
Follow [AGENTS.md](../../AGENTS.md) and the relevant domain guides.

## Project and build workflow

- Use `Promptly.xcodeproj`, scheme `Promptly`, and Debug/Release configurations.
  The app and both test targets have a macOS 26.0 minimum. Verify effective
  settings per target/configuration; project defaults may differ from overrides.
- Check the Swift 6.4 toolchain and Swift 6 language mode against the baseline
  in AGENTS.md. Record the actual compiler and macOS SDK/runtime; a newer host
  alone does not prove macOS 26.0 compatibility.
- Xcode exposes a `Promptly` scheme and test plan, but no `.xcscheme` or
  `.xctestplan` files are stored in the repository. Persist shared configuration
  before relying on it for CI. No CI, linter, or formatter is configured.
- Prefer Xcode tooling for the open workspace. Use `BuildProject` with
  `buildForTesting: true` to compile test targets; an app-only build misses test
  compilation failures. Discover tests with `GetTestList`, then use `RunSomeTests`
  for the relevant selection.
- Shell app builds/tests use `xcodebuild -project Promptly.xcodeproj -scheme Promptly`
  with an explicit configuration and `-destination 'platform=macOS'`. Use `xcsift`
  when available, preserving the build's exit status with `pipefail`; otherwise
  keep the unfiltered result. Build/test the app through its Xcode project, not
  `swift build`/`swift test`; use macOS destinations.
- If a restricted CLI environment prevents compiler macro plug-ins from launching,
  check the logs and compare with Xcode before treating it as a source failure.
  Do not install tools, clean builds, or add CI merely for an unrelated task.
- Documentation-only changes need consistency, local-link, and whitespace checks,
  including untracked files; run `git diff --check` for tracked changes. No app
  build is needed when only documentation changes.

## Test at the lowest reliable layer

- Prefer Swift Testing for policies, state transitions, anchor mapping, revision
  checks, parsing, and cancellation. Use XCTest/XCUITest for framework/UI behavior
  and metrics where needed.
- Keep `XCTestCase` subclasses `nonisolated` under default `MainActor` isolation;
  annotate UI test methods with `@MainActor`. XCTest initializers and lifecycle
  overrides must retain their base-class isolation; do not weaken app settings.
- Current tests cover window state, layout, preferences, AppKit behavior, and
  reader UI journeys. See the [validation record](../WindowBehaviorValidation.md)
  and [coverage report](../SourceCoverage.md) for evidence and remaining gaps;
  they do not establish coverage of planned script editing or playback.
- Use isolated in-memory stores for suitable logic tests and unique temporary
  on-disk stores for persistence, migration, reopen, and file-transaction tests.
- Inject time, IDs, file roots, and capability clients where determinism matters.
  Use synthetic scripts, no real network, no shared mutable fixtures or arbitrary
  sleeps. Clean up tasks, observers, files, and stores after each test.
- For bugs, add a root-cause regression test when practical. Avoid tests that
  merely mirror an implementation or add no useful failure signal.

Cover the affected behavior, especially:

- save ordering, undo/redo, unsaved edits, migration/reopen, and low-storage recovery;
- import validation, export readability, cancellation, and safe replacement;
- stale results after edits/deletion, reentrancy, repeated commands, and teardown;
- reading anchors after reflow, styling, resize, section changes, and script edits;
- long scripts, large libraries, bounded work, and unavailable models/permissions;
- future MCP capability enforcement, script scope, revocation, and edit conflicts.

## UI and Mac validation

- The [approved Library design](../LibraryDesign.md) has a separate
  [planned acceptance matrix](../ScriptEditingValidation.md#approved-design-adoption-pending)
  for its first implementation. Preserve the reader-window prototype's evidence;
  there is no implemented Library baseline or passing Library test suite.
  Browser mockup checks and design approval do not establish native gesture,
  keyboard, VoiceOver, persistence or handoff behavior.
- Inspect affected UI on macOS with synthetic scripts, including keyboard-only
  operation, VoiceOver, focus, text editing, and undo/redo.
- Exercise notch/no-notch placement, detached windows, resizing, multiple displays,
  display disconnection, scaling, and restoration when relevant.
- Check Light/Dark, contrast, reduced effects, long/localized text, and reading
  position preservation. Capture synthetic screenshots for UI changes.
- Screen-sharing claims require tests with the actual sharing applications and
  window/display capture methods. Report observed compatibility, not a guarantee.
- On-device Foundation Models and future Speech features need real-Mac checks
  for supported/unsupported configurations, asset availability, offline behavior,
  permissions, and resource cleanup. Record unavailable hardware/OS checks as
  remaining release gates.

## Concurrency, performance, and reporting

- Run targeted Thread Sanitizer checks for relevant actor/callback/persistence
  changes; Address Sanitizer for unsafe-memory work. Run them separately and
  never treat a passing sanitizer as proof of safety.
- Measure an identified regression or budget with the same synthetic workload
  before/after. Use Release builds on representative Macs and report hardware,
  OS, workload, and results. Prioritize scroll smoothness, input latency, CPU,
  memory, and idle energy; stop timers and work when inactive.
- Documentation needs consistency/link/whitespace checks; logic changes need
  targeted tests and a build; persistence/concurrency needs integration/failure
  coverage; UI/window changes need Mac interaction and accessibility checks.
- Report exact commands/tools, destinations, results, and skipped checks with
  their implications. Do not claim all tests, CI, thread safety, capture exclusion,
  minimum-OS support, or performance gains without corresponding evidence.
- Unsigned builds check compilation, not signing, notarization, or runtime sandbox
  entitlements.
