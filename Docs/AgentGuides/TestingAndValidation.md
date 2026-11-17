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
- CI uses the shared `Promptly` scheme stored in the repository. Its test
  configuration is in the scheme; no standalone `.xctestplan` is stored.
- Run `./Scripts/linters.sh` with one of the commands in
  [Linter commands](#linter-commands). For Swift changes, run `lint-swift` and
  `lint-swift-format`; run `lint-actions` for workflow changes and `lint-shell`
  for shell script changes. swift-format uses the selected Xcode 27.2 toolchain.
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
  including untracked files. Run `./Scripts/docs.sh lint-links` for links and
  `git diff --check` for whitespace in tracked changes. No app build is needed
  when only documentation changes.

### Documentation commands

`./Scripts/docs.sh` is for local validation; CI does not run it. Like the
linter script, it runs from any working directory and requires a command.

| Command | Behavior |
|---|---|
| `install` | Install lychee with Homebrew if it is missing; the version is not pinned |
| `lint-links` | Check relative links, root-relative links, and heading anchors in tracked and untracked, non-ignored Markdown files with lychee in offline mode |
| `help` | Show the command list |

`lint-links` does not check external URLs or links inside code blocks.

### Linter commands

Commands run from any working directory. A command is required; running the
script without one fails with a usage error. There is no aggregate lint command:
run each linter separately. CI runs `install`, then `lint-swift`,
`lint-swift-format`, `lint-actions`, and `lint-shell` as separate steps.
CI caches `.build/quality-tools` under a key derived from the script, so
changing a pin starts a new cache entry. Cached tools must still pass the
installer's version check; a cache miss or failure falls back to downloading.

Checks and linters never install tools, and only `format-swift` changes source
files. The script pins each tool version. Installs download the pinned release,
verify its SHA-256 and reported version, and place it in the ignored
`.build/quality-tools` directory. Installs require an Apple silicon Mac, the only
supported platform. Checks use the repository install first, then a matching
version on `PATH`. swift-format comes from the selected Xcode and is never
installed by the script.

| Command | Tool | Behavior |
|---|---|---|
| `check-swiftlint` | SwiftLint | Check for the pinned SwiftLint version (repository install, then `PATH`) |
| `install-swiftlint` | SwiftLint | Install the pinned, checksum-verified SwiftLint in `.build/quality-tools` |
| `lint-swift` | SwiftLint | Lint Swift sources |
| `check-swift-format` | swift-format | Check for the pinned swift-format version from the selected Xcode |
| `lint-swift-format` | swift-format | Check Swift formatting without changing files |
| `format-swift` | swift-format | Format Swift sources in place |
| `check-actionlint` | actionlint | Check for the pinned actionlint version (repository install, then `PATH`) |
| `install-actionlint` | actionlint | Install the pinned, checksum-verified actionlint in `.build/quality-tools` |
| `lint-actions` | actionlint, ShellCheck | Lint GitHub Actions workflows, including embedded shell blocks |
| `check-shellcheck` | ShellCheck | Check for the pinned ShellCheck version (repository install, then `PATH`) |
| `install-shellcheck` | ShellCheck | Install the pinned, checksum-verified ShellCheck in `.build/quality-tools` |
| `lint-shell` | ShellCheck | Lint tracked and untracked, non-ignored `.sh`, `.bash`, and `.ksh` files |
| `check-tools` | All | Check all four tools, reporting every failure |
| `install` | SwiftLint, actionlint, ShellCheck | Install all three pinned tools, reporting every failure |
| `help` | — | Show the command list |

## Test at the lowest reliable layer

- Prefer Swift Testing for policies, state transitions, anchor mapping, revision
  checks, parsing, and cancellation. Use XCTest/XCUITest for framework/UI behavior
  and metrics where needed.
- Keep `XCTestCase` subclasses `nonisolated` under default `MainActor` isolation;
  annotate UI test methods with `@MainActor`. XCTest initializers and lifecycle
  overrides must retain their base-class isolation; do not weaken app settings.
- Use `PromptlyTests/Extensions/` or `PromptlyUITests/Extensions/` when the owning
  test target needs focused type extensions. Keep these conveniences
  test-only and target-local; create the folder with its first real file.
- Current tests cover window state, layout, preferences, the SwiftUI-owned
  window adapter, native visibility/drag/resize behavior, and
  prompter UI journeys. See the [validation record](../WindowBehaviorValidation.md)
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
  for its first implementation. Preserve the prompter-window prototype's evidence;
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
