# Testing and Validation

Read before tests, builds, running, sanitizers, profiling, or handing off code.
Follow [AGENTS.md](../../AGENTS.md) and the relevant domain guides; the
[PRD](../PRD.md) defines behavior and the [Architecture](../Architecture.md)
§9 names the lowest reliable test layer for each area.

## Project and build workflow

- Use `Promptly.xcodeproj` and scheme `Promptly` (Debug/Release). The app and
  both test targets require macOS 26.0 and build with the Swift 6.4 toolchain in
  Swift 6 language mode; check effective settings per target, since project
  defaults differ. Record the actual compiler and SDK: a newer host does not
  prove macOS 26.0 compatibility.
- After code changes, run `./Scripts/tests.sh build-and-test-unit` (see
  [Test commands](#test-commands)). For other selections, use `xcodebuild
  -project Promptly.xcodeproj -scheme Promptly` with an explicit configuration
  and `-destination 'platform=macOS,arch=arm64'`, through `xcsift` with
  `pipefail` when available. Never use `swift build`/`swift test`.
- In Xcode, compile tests with `BuildProject` and `buildForTesting: true`, then
  use `GetTestList` and `RunSomeTests`. Xcode runs use team signing and lack the
  script's test options, so results can differ.
- Lint with the [Linter commands](#linter-commands): `lint-swift` and
  `lint-swift-format` for Swift, `lint-actions` for workflows, and `lint-shell`
  for shell scripts.
- Documentation-only changes need no build: run `./Scripts/docs.sh lint-links`
  and `git diff --check`. The latter skips untracked files, so check those for
  trailing whitespace too.
- If macro plug-ins fail to launch in a restricted shell, compare with Xcode
  before treating it as a source failure. Do not install tools, clean builds,
  or add CI for an unrelated task.

### Test commands

Like the other scripts, `./Scripts/tests.sh` runs from any working directory and
requires a command. CI runs `build-for-testing`, `test-unit`, `build-release`,
`test-tsan`, and `test-ui` as separate steps, then `summarize`. The UI tests do
not block CI until they pass on the hosted runner.

Commands that run `xcodebuild` require an Apple silicon Mac and use
`platform=macOS,arch=arm64`. Builds use ad-hoc signing, keep App Sandbox, and use
`build/DerivedData`; Thread Sanitizer builds use `build/DerivedData-TSan`, so
they never replace the normal build. Tests run serially, in English (US), with a
120-second limit per test.

Each `xcodebuild` run writes its full log to `build/Tests`. Test commands write a
fresh result bundle and counts there, named `unit-tests`, `ui-tests`, or
`tsan-unit-tests`, and fail when no test passes or any test fails. When `xcsift`
is installed, console output goes through `xcsift -f toon -w`; the log keeps the
full output. On GitHub Actions, errors and warnings are also run annotations.

Coverage is informational: a missing report is a warning, not a failure. Xcode
copies coverage data out of the sandboxed app's container, which macOS refuses
unless the app running `xcodebuild` may access other apps' data; the result
bundle then reports "Failed to download profiles … Operation not permitted".
Agent shells can lack that access.

| Command | Behavior |
|---|---|
| `build-for-testing` | Build the Debug app and both test targets with code coverage |
| `test-unit` | Run the built unit tests with code coverage |
| `test-ui` | Run the built UI tests; they take over the screen |
| `build-and-test-unit` | Build and run the unit tests with code coverage |
| `build-release` | Build the Release app and fail unless it is arm64 only |
| `test-tsan` | Build and run the unit tests with Thread Sanitizer; the first report stops the run |
| `summarize` | Print each test command's latest counts, unit-test coverage, and finish time, also to the GitHub job summary |
| `help` | Show the command list |

`test-unit` and `test-ui` never rebuild. They fail without a test build but do
not detect a stale one, so run `build-for-testing` after changes. `summarize`
keeps a command's last results until that command runs again.

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
version on `PATH`. swift-format comes from the selected Xcode 27.2 and is never
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

## Writing tests

- Use Swift Testing for logic and XCTest/XCUITest for native UI journeys.
  Mirror production paths under `PromptlyTests/` and put journeys in
  `PromptlyUITests/`; test-only extensions go in that target's `Extensions/`.
  Architecture §8.2 lists the current tests.
- Unit tests run in a Debug-only windowless host (`PromptlyMain`) with no
  prompter window or menu-bar extra. Test those through UI tests, which launch
  the app with `--promptly-ui-testing` so it starts normally.
- Keep `XCTestCase` subclasses `nonisolated`, UI test methods `@MainActor`, and
  lifecycle overrides at their base-class isolation.
- Inject clocks, IDs, the layout function, presenters, and the defaults store.
  Settings tests use a uniquely named `UserDefaults` suite, never
  `UserDefaults.standard`. Use synthetic text, and temporary files only for
  import tests; avoid network, shared mutable fixtures, and sleeps. Clean up
  tasks, observers, suites, and files.
- For bugs, add a root-cause regression test when practical. Skip tests that
  only mirror the implementation.

Cover the affected behavior:

- loading: the latest load wins across UI and MCP; failed or superseded loads
  keep the previous session; clearing invalidates pending loads (F01.3, F01.5);
- import and limits: `.txt`/`.md`, the 1 MB import limit, and the script limit
  on load (F01.2, F01.7); editor drafts survive cancelled discards (F01.6);
- layout: reading position after reflow, failure recovery, and Play and
  navigation blocked while recalculating (F02.6–F02.9);
- playback: timing on an injected clock, WPM changes, pause on hide and sleep,
  stale tokens, repeated commands, and teardown (F03.5–F03.11);
- settings: atomic partial updates and validation (PRD-08 §8.8, §8.9);
- MCP: enablement, protected settings, same-user access, draft exclusion,
  revision safety, and disabling mid-request (F07.10–F07.15).

## Mac validation

Compilation and unit tests do not establish runtime behavior. For UI changes,
check on macOS with synthetic scripts and capture synthetic screenshots:

- keyboard-only operation, focus, VoiceOver, Reduce Motion, contrast, long text,
  and Light/Dark in the editor and Settings;
- the prompter's presets, Attached and Floating placement, notch and no-notch
  displays, multiple displays and disconnection, Spaces including full-screen,
  showing without activating Promptly, and reading-position preservation
  (PRD-05);
- screen sharing with the actual sharing apps and capture methods, recorded in
  the [compatibility research](../Research/ScreenSharingCompatibility.md).
  Report observed compatibility, never a guarantee (PRD-06);
- MCP with the Codex and Claude Desktop versions you record (F07.16).

Record checks that need unavailable hardware or OS versions as remaining release
gates.

## Sanitizers and performance

- Run `./Scripts/tests.sh test-tsan` for concurrency changes in layout, the
  session, playback, settings, or MCP. For unsafe-memory work, run the unit
  tests with `xcodebuild test -enableAddressSanitizer YES` and its own
  DerivedData path, such as `build/DerivedData-ASan`. Never combine sanitizers,
  and never treat a passing run as proof of safety.
- Measure an identified regression or budget with the same synthetic workload
  before and after, using Release builds on representative Macs. Report
  hardware, OS, workload, and results. Prioritize scroll smoothness, input
  latency, CPU, memory, and idle energy; stop timers and work when inactive.

## Reporting

- Report exact commands or tools, destinations, results, and skipped checks with
  their implications. Do not claim all tests, CI, thread safety, capture
  exclusion, minimum-OS support, or performance gains without evidence.
- Script builds are ad-hoc signed: they check compilation and sandboxed runs,
  not team signing, notarization, or distribution.
