# Window behavior validation

This is the acceptance and compatibility record for [roadmap milestone 1](../ROADMAP.md#1-window-behavior).
Use only synthetic sample text in tests, recordings, screenshots, and reports.
Pending checks are release gates, not evidence that a configuration works.

The feature was renamed from Reader to Prompter on 2026-11-04.
Historical test identifiers, commands and type names below retain
their original spelling; current source and tests use Prompter names.

## Accepted behavior

- Promptly is a menu-bar app. Its menu provides a recovery path to show
  the prompter, expand it, unlock its position, return it to the notch, and quit.
- The anchored prompter visually merges with and wraps around the primary display's
  notch; text and controls stay below the camera housing. Without a notch, it is
  centered at the top of the usable display area. The primary display is the one
  configured in macOS, not the display containing the key window.
- The prompter is intended to remain visible across Spaces and over full-screen
  presenting apps. Normal native prompter-window activation is allowed as of
  2026-11-03; keyboard access uses the menu-bar commands.
- Detaching enables dragging and resizing. Collapse preserves placement mode and
  expanded size, leaving a compact strip with usable controls. Lock prevents
  movement and resizing while keeping controls available. Return to Notch is an
  explicit placement override even when locked.
- Relaunch restores mode, size, collapse, and lock state. Detached placement is
  fitted to one actual connected display's visible bounds; an invalid or missing
  placement falls back to the primary display. A rectangle spanning gaps between
  displays is not a valid restoration area.
- This milestone uses static synthetic text. Window preferences are local; script
  editing, durable script storage, and automatic scrolling are later milestones.

The implementation persists only window preferences in UserDefaults. Startup no
longer opens the starter SwiftData store; existing stores are not deleted. The
milestone adds no network or microphone permissions.

## Evidence and remaining checks

Automated geometry tests can establish placement policy for supplied display
rectangles, including negative origins, gaps, changed bounds, and disconnected
display IDs. They cannot establish physical notch alignment, AppKit focus,
VoiceOver usability, full-screen behavior, or capture exclusion. Record those
separately with the actual hardware, OS, app build, and observed result.

As of 2026-10-26, the user's available validation setup is a MacBook Pro with a
notch and an external display. Its physical display and sharing checks below are
pending. Record the Mac model, external display model, arrangement, scaling, and
macOS version when testing. A newer macOS host does not establish compatibility
with the minimum macOS 26.0 release.

| Check | Result | Evidence / environment |
| --- | --- | --- |
| Debug app and both test targets compile | Passed | Xcode `BuildProject(buildForTesting: true)`, Promptly scheme, My Mac; Swift 6.4, macOS SDK 27.0, host macOS 27.0.1 |
| Release app compilation | Passed | Unsigned CLI build below; no compiler warnings. Does not validate signing or notarization |
| Placement, state, preferences, and AppKit tests | Passed: 31 | Xcode `GetTestList` then `RunSomeTests`, all `PromptlyTests` on My Mac |
| Native window, drag, resize, and menu/keyboard journeys | Passed: 5 | All five `ReaderWindowUITests` passed in the full 36-test coverage run on MacBook Pro (Mac16,8), macOS 27.0.1. An earlier missed initial Detach click remains recorded in the resize follow-up below |
| App source line coverage before app/menu ownership cleanup | 96.58% (678/702) | Increased from 95.73% after seven tests; see the [source coverage report](SourceCoverage.md) for historical per-file results and limitations |
| Controller lifecycle under Thread Sanitizer | Passed: 7 | Targeted CLI command below; no sanitizer findings; linker reported a duplicate `@executable_path` rpath warning |
| Local pointer focus | Partial | TextEdit's empty synthetic document retained its focused text field after a prompter control click; does not establish compatibility with presenting apps |
| Physical notch and no-notch placement | Pending | MacBook Pro and external display |
| Scaling, arrangement, and disconnection | Pending | Record display configuration before and after |
| Keyboard and VoiceOver | Partial | The historical direct-focus keyboard journey was removed on 2026-11-03. Physical keyboard menu-bar navigation and VoiceOver remain pending |
| Minimum macOS 26.0 runtime | Pending | Requires that runtime |
| Sharing applications | Not tested | Matrix below |

The native journey test uses mouse events to drag the detached header and resize
the lower edge, then collapses, locks, expands, and returns while locked. It keeps
an attachment containing only the synthetic anchored prompter. The former keyboard
test recovered a hidden prompter through the menu-bar item, focused Collapse,
activated it with Space, tabbed to Lock, and confirmed Space no longer changed the
control after Escape. This historical journey predates removal of direct prompter
focus on 2026-11-03. These checks do not replace physical accessibility or
presenting-app checks.

App/menu ownership cleanup on 2026-10-26 moved `PromptlyApp.swift` into `App/`
and moved the final divider and Quit command from `ReaderMenu` into the app's
`MenuBarExtra` composition. Xcode `BuildProject(buildForTesting: true)` succeeded,
and `RunSomeTests` passed
`ReaderWindowUITests/testMenuRecoversLockedCollapsedReaderAndQuits()` (1 passed,
0 failed or skipped) using the Promptly scheme on My Mac, macOS 27.0.1. The
existing journey verifies menu recovery and graceful Quit after the ownership
change. The full suite and coverage measurement were not repeated for this
cleanup; the coverage figures above describe the earlier source layout.

Prompter-window ownership refactor on 2026-10-31 separated the observable
`ReaderWindowController` from the native `ReaderPanelController`. The former owns
state, placement policy, preference recovery and saving; the latter owns panel
configuration, focus, display observation and window-delegate callbacks. The
app delegate composes both. Preference keys/payloads, geometry calculations and
prompter visuals are unchanged. All new state and callbacks remain on `MainActor`.

Validation used the Promptly scheme on My Mac (arm64), Swift 6.4.2, macOS SDK
27.2 and host macOS 27.2. Effective settings for all three targets retained the
macOS 26.0 deployment target and configured Swift/concurrency baseline.

| Refactor check | Result | Evidence / limitation |
| --- | --- | --- |
| Debug app and both test targets | Passed | Xcode `BuildProject(buildForTesting: true)`; no compiler warnings |
| Release app | Passed | Unsigned CLI build below; no warnings. The restricted-shell attempt could not launch compiler macro plug-ins; the same command passed outside that shell sandbox |
| Unit and AppKit tests | Passed: 40 | Xcode `GetTestList` then `RunSomeTests`; 16 coordinator tests use a fake panel, and four adapter tests exercise native geometry feedback, resize/collapse/lock, display-observer restart, and close/save routing |
| Five prompter UI journeys | Not run | The runner failed to initialize with “Timed out while enabling automation mode.” An isolated retry stalled and was stopped; keyboard/mouse journeys remain unverified for this refactor |
| Targeted Thread Sanitizer run | No runtime result | Instrumented targets compiled with a duplicate `@executable_path` rpath linker warning, but the test manager reported a 120-second control-session timeout and produced no test results. The stalled run was stopped |

```sh
set -o pipefail
xcodebuild -project Promptly.xcodeproj -scheme Promptly -configuration Release \
  -destination 'platform=macOS' -derivedDataPath /private/tmp/Promptly-Window-Modularity-Release \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | xcsift -f toon -w
xcodebuild -project Promptly.xcodeproj -scheme Promptly -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /private/tmp/Promptly-Window-Modularity-TSan \
  -enableThreadSanitizer YES -enableCodeCoverage NO -parallel-testing-enabled NO \
  -only-testing:PromptlyTests/ReaderWindowControllerTests \
  -only-testing:PromptlyTests/ReaderPanelControllerTests test 2>&1 | xcsift -f toon -w
```

Coverage was not remeasured. These checks do not establish minimum-OS, physical
display, cross-app focus, VoiceOver, full-screen or capture compatibility, and
there is no passing sanitizer claim for this refactor. The earlier evidence and
open release gates remain separate.

Source-layout migration on 2026-11-01 moved 12 app files and five unit/AppKit test
files into the feature, domain and preference folders recorded in the
[architecture map](Architecture.md). All 24 Swift files and both tracked Xcode
project files retained their original bytes; preference keys, payloads,
concurrency settings and runtime behavior are unchanged.

Validation used the Promptly scheme, Debug configuration and My Mac (arm64),
Swift 6.4.2, macOS SDK 27.2 and host macOS 27.2. Xcode
`BuildProject(buildForTesting: true)` built the app and both test targets.
`GetTestList` discovered all 45 tests at their current paths, and `RunSomeTests`
passed all 40 unit/AppKit tests and all five prompter UI journeys, with no failures,
skips or unrun tests. File-integrity, local documentation-link and whitespace
checks also passed. Release, sanitizers and coverage were not repeated for this
file relocation. The physical-display, minimum-OS, cross-app focus, VoiceOver,
full-screen and capture checks remain separate release gates.

Drag verification on 2026-10-26 reproduced a dead area in the header: only the
small title text originally accepted dragging. The regression failed before the
fix. The drag target now covers the title and empty leading header area at full
header height, excluding the control buttons, with a grab cursor when detached
and unlocked. The new UI test repeats drags while expanded and collapsed, checks
that locking blocks movement, and verifies dragging resumes after unlocking and
expanding. All three UI tests passed after the fix. This explains a reproducible
missed drag; it does not establish that every reported missed attempt had this
cause. First-drag behavior with presenting apps remains part of the manual focus
checks below.

Resize verification on 2026-10-26 reproduced an unintended compact layout that
changed the sample from 28 to 20 points and removed a line in smaller windows.
That behavior is removed: the fixed-size sample now reflows and clips to the
available viewport, preserving its content and font. User-adjustable typography
remains in roadmap milestone 3. The new resize regression failed before the fix
and passed afterward, checking text height at unchanged width and sample content
across both height and width reductions. The drag and keyboard tests also passed
in that run. The original window journey missed its initial Detach click once
and passed on an immediate isolated retry; the cause of that missed click is not
established, so presenting-app and first-click checks remain open.

CLI validation used `pipefail` and xcsift, with the project's configured concurrency
checks preserved:

```sh
set -o pipefail
xcodebuild -project Promptly.xcodeproj -scheme Promptly -configuration Release \
  -destination 'platform=macOS' -derivedDataPath /private/tmp/Promptly-Window-Release \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | xcsift -f toon -w
xcodebuild -project Promptly.xcodeproj -scheme Promptly -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /private/tmp/Promptly-Window-TSan \
  -enableThreadSanitizer YES -parallel-testing-enabled NO \
  -only-testing:PromptlyTests/ReaderWindowControllerTests test 2>&1 | xcsift -f toon -w
```

The restricted shell initially prevented Apple's macro plug-in server from
launching; the Release build passed outside that shell sandbox. Sanitizer passing
is evidence for these lifecycle tests, not proof of thread safety. Window state
and native callbacks remain owned by MainActor.

## Focus flow removal — 2026-11-03

Removed Focus Prompter and its ⌥⌘F menu shortcut, programmatic app activation,
control-focus requests, custom Space handling, and Escape-based focus release.
Show Prompter still reveals the prompter; keyboard commands remain in the native
menu-bar menu. The existing panel now always rejects key-window status rather
than switching into an explicit keyboard mode. Apple documents that
[`canBecomeKey == false`](https://developer.apple.com/documentation/appkit/nswindow/canbecomekey)
rejects attempts to make a window key; the existing
[`becomesKeyOnlyIfNeeded`](https://developer.apple.com/documentation/appkit/nspanel/becomeskeyonlyifneeded)
policy is retained. No replacement window infrastructure was needed.

Validation used the Promptly scheme, Debug configuration and My Mac (arm64),
Swift 6.4.2, macOS SDK 27.2 and host macOS 27.2. Xcode
`BuildProject(buildForTesting: true)` compiled the app and both test targets.
`GetTestList` discovered 44 tests after removing the obsolete focus-request test.
`RunSomeTests` selected 19 controller/AppKit tests and all five prompter UI
journeys: 23 passed, and the resize test failed because its first automated drag
reduced the height by 39 points against a strict greater-than-40-point threshold.
An immediate isolated rerun passed without changes; the cause of the initial
drag discrepancy remains unresolved. The updated menu-recovery journey passed,
checking that Focus Prompter is absent and that Show, Collapse and Lock remain
usable by pointer.

Preference payloads, privacy permissions and concurrency settings are unchanged.
Release, sanitizers and coverage were not repeated. Physical keyboard menu-bar
navigation, presenting-app focus, VoiceOver, minimum macOS 26.0, display and
capture checks remain open; automated clicks do not establish physical-input
focus behavior.

## SwiftUI prompter scene — 2026-11-03

The prompter now uses SwiftUI `Window`, with a real `WindowVisibilityToggle` in
its header and native `openWindow`/`dismissWindow` status-menu actions. The user
approved normal native window activation. The custom panel, hosting view,
native drag view and window delegate were removed. The model remains outside
the window; a narrow adapter preserves live geometry/display policy without
creating or ordering windows. The [implementation notes](SwiftUIPrompterWindow.md)
record the independent alternatives review, retained native gaps, and the minimal
visibility-toggle host-context reproduction. Earlier panel/focus evidence above
is historical and does not establish the current SwiftUI behavior.

Validation used the Promptly scheme, Debug configuration and My Mac (arm64),
Swift 6.4.2, macOS SDK 27.2 and host macOS 27.2. Xcode
`BuildProject(buildForTesting: true)` compiled the app and both test targets.
`GetTestList` then `RunSomeTests` passed all **47 tests**: 41 unit/AppKit tests
and six native prompter UI journeys, with no failures, skips or unrun tests.

The UI journeys cover the native header toggle and menu dismissal independently,
reopening the same detached/collapsed/locked state and frame, hidden Return to
Notch, graceful Quit, collapse/expansion, locked resizing and native header
dragging. A new check compares initial prompter placement and notch-height inset
against the configured primary display. The synthetic prompter screenshot remains
attached to the window journey. Native drag testing uses larger pointer travel
and directional bounds because its recognizer consumes initial pointer travel.
Unit checks cover old-window notification/late-detach filtering, unchanged native
delegate identity, close-save/reopen, corrupt-preference protection and fitted
constraints on synthetic displays smaller than the preferred minimum size.

The unsigned Release app compiled with no reported warnings. A separate targeted
Thread Sanitizer run passed all **21** controller/adapter tests with no sanitizer
findings; the linker reported the existing duplicate `@executable_path` rpath
warning. Sanitizer success is not proof of thread safety. Commands used:

```sh
set -o pipefail
xcodebuild -project Promptly.xcodeproj -scheme Promptly -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/Promptly-SwiftUIWindow-Release \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | xcsift -f toon -w
xcodebuild -project Promptly.xcodeproj -scheme Promptly -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/Promptly-SwiftUIWindow-TSan \
  -enableThreadSanitizer YES -enableCodeCoverage NO -parallel-testing-enabled NO \
  -only-testing:PromptlyTests/ReaderWindowControllerTests \
  -only-testing:PromptlyTests/ReaderWindowAdapterTests test 2>&1 | xcsift -f toon -w
```

Preference keys/payloads, project settings, privacy permissions and the Swift
concurrency baseline are unchanged. Coverage was not remeasured. Physical
keyboard/VoiceOver, notch seams, additional displays/scaling/disconnection,
full-screen presenting apps, minimum macOS 26.0 and actual capture paths remain
release gates. No universal capture-exclusion claim follows from this migration.

## Prompter feature rename — 2026-11-04

Renamed the feature folder, Swift types, app composition properties and test
suites from Reader to Prompter. Current product documentation and design-context
source paths use the new name. Historical validation identifiers, remote draft
names and dated approval artifacts retain their original references.

The SwiftUI scene ID remains `reader`, and preferences still use
`reader.windowPlacement.v1` with the same Codable fields. Accessibility IDs and
their UI-test selectors now use `prompter.*`. A comparison against the working
tree before the rename verified that all 23 Swift files retain their logic;
project configuration, assets and approval JSON are unchanged.

Validation used the Promptly scheme, Debug configuration and My Mac (arm64),
Swift 6.4.2, macOS SDK 27.2 and host macOS 27.2. Xcode
`BuildProject(buildForTesting: true)` built the app and both test targets.
`GetTestList` followed by `RunSomeTests` passed all 41 `PromptlyTests`, with no
failures, skips or unrun selected tests. Local Markdown links, JSON and whitespace
checks passed. Build logs contain the metadata-extraction warning for targets
without an AppIntents.framework dependency; no App Intents work was added.

The six current UI journeys were compiled but not run. The pre-existing working
tree renders a placeholder Circle in `PromptlyApp` and comments out the menu-bar
composition and header Hide control; those in-progress changes were preserved.
Release, sanitizers, coverage, physical-display, accessibility and capture checks
were not repeated for this naming change.

## Manual window journey

For each check, record Pass, Fail, or Not tested with a short observation.

1. Launch with no saved window preferences. Confirm one prompter on the configured
   primary display, a reachable menu-bar item, and no Dock icon. Repeat with an
   ordinary window focused on the other display.
2. On the MacBook Pro, inspect the notch seam, rounded edges, camera clearance,
   menu-bar interaction, and control reachability. Make the external no-notch
   display primary and verify its top-center placement.
3. Run anchored → detached → collapsed → expanded → returned. Drag and resize
   while detached, including the minimum size. Confirm expansion restores size
   and keeps controls visible.
4. Lock both expanded and collapsed states. Attempt dragging and resizing; then
   use Unlock and Return to Notch from the panel and the menu. Verify the escape
   commands remain usable and return works while locked.
5. Focus a presenting app and click prompter text and controls. Verify normal
   native activation and first-click behavior, with no explicit focus mode. Use macOS keyboard
   menu-bar navigation to reach Promptly's prompter commands, including Show and
   Hide, and confirm the presenting app remains usable. Repeat with VoiceOver enabled.
6. Change Spaces, enter and leave a presenting app's full-screen Space, and
   exercise Stage Manager if used. Confirm the prompter stays reachable without
   activating Promptly unexpectedly or covering essential presenting controls.
7. Place the detached prompter on each display, quit, and relaunch. Repeat while
   collapsed and locked. Check restored mode, size, state, and reachable controls.
8. While detached on the external display, disconnect it. Reconnect, change the
   primary display, rearrange displays with negative origins and gaps, and change
   scaling. Repeat with the prompter locked and collapsed. Verify the prompter fits
   an actual screen and Return to Notch targets the current primary display.
9. Hide and show the prompter through its menu, repeat the journey, quit, and
   relaunch. Check for duplicate panels, stale menu states, or lost recovery
   commands. Confirm quitting ends the app.
10. Check Light and Dark appearance, Increased Contrast, Reduce Transparency,
    Reduce Motion, and keyboard focus indicators. Ensure state labels remain
    legible without relying on color and controls do not clip at narrow sizes.

## Screen-sharing compatibility

Capture exclusion is a compatibility goal, not a security boundary. Apple
describes [`NSWindow.SharingType.none`](https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum/none)
as a legacy value and advises against using it to hide captured content. Setting
a window-sharing flag does not establish that the prompter is absent from a stream.
Do not change accessibility exposure to influence capture.

Test with synthetic text and inspect the **remote participant's received image**
or a receiver-side recording. A presenter's local preview alone is insufficient.
Record desktop-client versus browser use, app/browser versions, the precise
capture choice, and display selected. Browser tab sharing is a separate capture
path and must not be reported as an application-window test.

| Sharing app | Capture method | Result | App/browser version, macOS, build, and evidence |
| --- | --- | --- | --- |
| Zoom | Entire display containing the prompter | Not tested | — |
| Zoom | Presenting application window | Not tested | — |
| Microsoft Teams | Entire display containing the prompter | Not tested | — |
| Microsoft Teams | Presenting application window | Not tested | — |
| Google Meet | Entire display containing the prompter | Not tested | — |
| Google Meet | Presenting application window | Not tested | — |

For every capture row, exercise anchored, detached, collapsed, and expanded
states, including prompter movement over the shared presenting window and a
full-screen presentation where supported. Report visible, absent, intermittent,
or blocked, including any flicker, state-specific result, or picker exclusion.
Record permission denials and unsupported capture choices as such. If testing
Meet tab sharing, add a separate row naming the browser and tab-sharing method.

Result template:

```text
Date / Promptly build:
Mac / macOS / display arrangement and scaling:
Sharing app and version / browser and version, if applicable:
Capture method and selected display, window, or tab:
Reader states and full-screen/Space transitions exercised:
Receiver-side observation and synthetic evidence:
Result / limitations / retest needed:
```
