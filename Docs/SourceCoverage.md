# Source test coverage

Measured on 2026-10-26 for the milestone 1 implementation before the app-entry
move and Quit-menu ownership cleanup. Source links follow the current layout;
the counts below remain the historical measurement, including the former
placement of Quit in `ReaderMenu`.

App source executable-line coverage increased from **95.73%
(672/702)** to **96.58%
(678/702)** after adding seven tests.
The baseline run passed all 29 tests (25 unit/AppKit, 4 UI); the final run passed
all 36 tests (31 unit/AppKit, 5 UI), with no failures or skipped tests.

## Measurement

Both measurements use the active Xcode `Promptly` scheme, Debug configuration,
My Mac destination, Swift 6.4, macOS SDK 27.0, and macOS 27.0.1 on arm64.
Tests were discovered with `GetTestList`, run through Xcode `RunSomeTests`, and
coverage extracted from each returned `.xcresult` with `xccov`.

The totals are Xcode's reported executable-line counts for **Promptly.app**.
Test targets are excluded. Swift compiler-generated closures and macro mapping
contribute to Xcode's counts; these are not physical source-line counts or branch
coverage. `DisplayGeometry.swift` has no executable coverage entry and therefore
no percentage. These measurements do not establish minimum macOS 26.0 support.

| App source file | Before | After | Covered/executable after |
| --- | ---: | ---: | ---: |
| [PromptlyAppDelegate.swift](../Promptly/App/PromptlyAppDelegate.swift) | 66.67% | 80.95% | 17/21 |
| [ReaderWindowLayout.swift](../Promptly/Domain/ReaderWindowLayout.swift) | 99.04% | 100.00% | 104/104 |
| [ReaderWindowState.swift](../Promptly/Domain/ReaderWindowState.swift) | 100.00% | 100.00% | 6/6 |
| [NSScreen+Extensions.swift](../Promptly/Extensions/NSScreen+Extensions.swift) | 93.33% | 93.33% | 14/15 |
| [ReaderDragHandle.swift](../Promptly/Features/Reader/ReaderDragHandle.swift) | 100.00% | 100.00% | 25/25 |
| [ReaderMenu.swift](../Promptly/Features/Reader/ReaderMenu.swift) | 78.12% | 81.25% | 26/32 |
| [ReaderView.swift](../Promptly/Features/Reader/ReaderView.swift) | 100.00% | 100.00% | 227/227 |
| [PromptlyApp.swift](../Promptly/App/PromptlyApp.swift) | 100.00% | 100.00% | 8/8 |
| [ReaderHostingView.swift](../Promptly/Services/Windowing/ReaderHostingView.swift) | 0.00% | 0.00% | 0/2 |
| [ReaderPanel.swift](../Promptly/Services/Windowing/ReaderPanel.swift) | 100.00% | 100.00% | 10/10 |
| [ReaderWindowController.swift](../Promptly/Services/Windowing/ReaderWindowController.swift) | 95.26% | 95.26% | 221/232 |
| [ReaderWindowPreferences.swift](../Promptly/Services/Windowing/ReaderWindowPreferences.swift) | 95.00% | 100.00% | 20/20 |
| **Promptly.app total** | **95.73%** | **96.58%** | **678/702** |

## Tests added

- [ReaderWindowPreferencesTests](../PromptlyTests/Services/Windowing/ReaderWindowPreferencesTests.swift):
  a failed encode reports the typed failure and preserves the last good bytes and
  reopened placement.
- [ReaderWindowControllerTests](../PromptlyTests/Services/Windowing/ReaderWindowControllerTests.swift):
  four tests cover immediate hide/stop flushing the newest moved/resized frame
  before debounce can finish, hide/show preserving detached/collapsed/locked
  state, and an anchored collapsed/locked reader following primary-display
  changes between notch and no-notch snapshots.
- [ReaderWindowLayoutTests](../PromptlyTests/Domain/ReaderWindowLayoutTests.swift):
  invalid full-screen or visible-screen rectangles are excluded from restoration;
  a valid actual display is used even when the saved and primary IDs are invalid,
  and no placement is returned if no usable display remains.
- [ReaderWindowUITests](../PromptlyUITests/ReaderWindowUITests.swift):
  a native status-menu journey detaches, collapses, locks, hides, returns to the
  notch while hidden/locked, expands, unlocks, shows again, and quits gracefully.
  Menu queries are scoped to the status item because the app menu also has a
  Quit command.

Unit fixtures use isolated preferences suites and synthetic display geometry,
clean up panels/observers/tasks, and do not sleep to test debounce behavior. No
production-source or project-setting changes were needed for these additions.

## Remaining gaps and interpretation

- `ReaderHostingView`'s two first-mouse/key-policy hooks did not execute in these
  runs. Direct assertions of their constant return values would not verify real
  first-click or presenting-app focus behavior.
- The app's Launch Services reopen delegate is not exercised. Graceful termination
  is now exercised through the real Quit menu action.
- Controller gaps include the native close delegate, focus capture from another
  app, and defensive nil/error fallbacks. Save failure preservation is tested at
  the preferences boundary; the controller's failed-save presentation path is
  not forced through a fabricated framework failure.
- The menu's failed-preference display branch and NSScreen's missing display-ID
  branch remain uncovered.
- Many SwiftUI body lines execute merely by constructing the view. A 100% view
  percentage does not prove correct layout or accessibility; the existing font,
  drag, keyboard, and resize assertions provide separate behavioral evidence.

Physical display/scaling/disconnection, VoiceOver, cross-app focus, full-screen,
and sharing compatibility remain in the [window validation record](WindowBehaviorValidation.md).
No claim of capture exclusion or complete behavioral coverage follows from these
line percentages.

## Repeating the measurement

Run the current full test list in Xcode with coverage enabled and obtain the
result bundle returned by `RunSomeTests`, then extract the report:

```sh
xcrun xccov view --report --json /path/to/Test-Promptly.xcresult > coverage.json
```

Select the `Promptly.app` target and calculate `coveredLines / executableLines`;
do not average file percentages or include the test targets. The current test
configuration is the local Xcode scheme, not a committed CI configuration.

A separate CLI run using `xcodebuild -enableCodeCoverage YES` passed all 29
baseline tests but failed to collect runtime profile files on this host. Its
report had no counts and is excluded from these figures. The two Xcode-driven
runs above produced valid, nonempty coverage reports. Coverage collection did not
require changes to app permissions or sandbox settings.
