# Window behavior validation

This is the acceptance and compatibility record for [roadmap milestone 1](../ROADMAP.md#1-window-behavior).
Use only synthetic sample text in tests, recordings, screenshots, and reports.
Pending checks are release gates, not evidence that a configuration works.

## Accepted behavior

- Promptly is a menu-bar app. Its menu provides a recovery path to show and focus
  the reader, expand it, unlock its position, return it to the notch, and quit.
- The anchored reader visually merges with and wraps around the primary display's
  notch; text and controls stay below the camera housing. Without a notch, it is
  centered at the top of the usable display area. The primary display is the one
  configured in macOS, not the display containing the key window.
- The reader is intended to remain visible across Spaces and over full-screen
  presenting apps. Routine pointer interactions preserve the presenting app's
  focus; keyboard access uses an explicit focus action.
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
| Local pointer focus | Partial | TextEdit's empty synthetic document retained its focused text field after a reader control click; does not establish compatibility with presenting apps |
| Physical notch and no-notch placement | Pending | MacBook Pro and external display |
| Scaling, arrangement, and disconnection | Pending | Record display configuration before and after |
| Keyboard and VoiceOver | Partial | UI test covers menu recovery, explicit Focus, Space activation, Tab to Lock, and Escape release. Physical keyboard menu-bar navigation and VoiceOver remain pending |
| Minimum macOS 26.0 runtime | Pending | Requires that runtime |
| Sharing applications | Not tested | Matrix below |

The native journey test uses mouse events to drag the detached header and resize
the lower edge, then collapses, locks, expands, and returns while locked. It keeps
an attachment containing only the synthetic anchored reader. The keyboard test
recovers a hidden reader through the menu-bar item, focuses Collapse, activates it
with Space, tabs to Lock, and confirms Space no longer changes the control after
Escape. These do not replace physical accessibility or presenting-app checks.

App/menu ownership cleanup on 2026-10-26 moved `PromptlyApp.swift` into `App/`
and moved the final divider and Quit command from `ReaderMenu` into the app's
`MenuBarExtra` composition. Xcode `BuildProject(buildForTesting: true)` succeeded,
and `RunSomeTests` passed
`ReaderWindowUITests/testMenuRecoversLockedCollapsedReaderAndQuits()` (1 passed,
0 failed or skipped) using the Promptly scheme on My Mac, macOS 27.0.1. The
existing journey verifies menu recovery and graceful Quit after the ownership
change. The full suite and coverage measurement were not repeated for this
cleanup; the coverage figures above describe the earlier source layout.

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

## Manual window journey

For each check, record Pass, Fail, or Not tested with a short observation.

1. Launch with no saved window preferences. Confirm one reader on the configured
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
5. Focus a presenting app and click reader text and controls. Verify routine
   interactions do not unexpectedly divert keyboard input. Use Focus Prompter
   and reach every control by keyboard; press Escape and confirm the
   presenting app is usable again. Repeat with VoiceOver enabled.
6. Change Spaces, enter and leave a presenting app's full-screen Space, and
   exercise Stage Manager if used. Confirm the reader stays reachable without
   activating Promptly unexpectedly or covering essential presenting controls.
7. Place the detached reader on each display, quit, and relaunch. Repeat while
   collapsed and locked. Check restored mode, size, state, and reachable controls.
8. While detached on the external display, disconnect it. Reconnect, change the
   primary display, rearrange displays with negative origins and gaps, and change
   scaling. Repeat with the reader locked and collapsed. Verify the reader fits
   an actual screen and Return to Notch targets the current primary display.
9. Hide and show the reader through its menu, repeat the journey, quit, and
   relaunch. Check for duplicate panels, stale menu states, or lost recovery
   commands. Confirm quitting ends the app.
10. Check Light and Dark appearance, Increased Contrast, Reduce Transparency,
    Reduce Motion, and keyboard focus indicators. Ensure state labels remain
    legible without relying on color and controls do not clip at narrow sizes.

## Screen-sharing compatibility

Capture exclusion is a compatibility goal, not a security boundary. Apple
describes [`NSWindow.SharingType.none`](https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum/none)
as a legacy value and advises against using it to hide captured content. Setting
a window-sharing flag does not establish that the reader is absent from a stream.
Do not change accessibility exposure to influence capture.

Test with synthetic text and inspect the **remote participant's received image**
or a receiver-side recording. A presenter's local preview alone is insufficient.
Record desktop-client versus browser use, app/browser versions, the precise
capture choice, and display selected. Browser tab sharing is a separate capture
path and must not be reported as an application-window test.

| Sharing app | Capture method | Result | App/browser version, macOS, build, and evidence |
| --- | --- | --- | --- |
| Zoom | Entire display containing the reader | Not tested | — |
| Zoom | Presenting application window | Not tested | — |
| Microsoft Teams | Entire display containing the reader | Not tested | — |
| Microsoft Teams | Presenting application window | Not tested | — |
| Google Meet | Entire display containing the reader | Not tested | — |
| Google Meet | Presenting application window | Not tested | — |

For every capture row, exercise anchored, detached, collapsed, and expanded
states, including reader movement over the shared presenting window and a
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
