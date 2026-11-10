# Prompter line-layout engine

Implemented on 2026-11-06 as a standalone component under
`Promptly/Features/Prompter/Viewport/`. A separate demonstration view integrates
the engine with SwiftUI rows and local controls. The main prompter, app settings,
playback, and persistence are not connected to it. The existing TextRenderer
LinePrompter experiment remains separate.

## Interface

`PrompterLineLayoutEngine.layout(text:font:width:)` accepts an unchanged String,
a SwiftUI `Font.Resolved`, and a finite positive reading width in points. It
returns an array of `PrompterLine` values with only:

- `sourceRange`: UTF-16 coordinates in that exact input String, including any
  hard-break delimiter consumed by the line.
- `text`: the corresponding substring with only its terminal hard break removed.
  Spaces and tabs are preserved.

Array indices identify rows within one layout. They are not durable reading
positions. A caller keeps its script identity/revision and source offset,
then finds the new row containing that source position after reflow. The engine
does not own that anchor or apply results to a view.

Resolve the chosen font using SwiftUI's font resolution context at the caller.
The resolved value carries the selected font's family, size and traits into
Core Text, without a second family/weight mapping. SwiftUI supports both
[Font.Resolved.ctFont](https://developer.apple.com/documentation/swiftui/font/resolved/ctfont)
on macOS 26.0 and [Font(ctFont)](https://developer.apple.com/documentation/swiftui/font/init(_:))
for a row renderer. Vertical row/paragraph spacing and alignment are viewport
presentation; the engine returns no y offsets, heights or baselines.

## Source and failure behavior

- Empty input returns no rows.
- LF, CR, CRLF, vertical tab, form feed, NEL, line separator and paragraph
  separator are treated as hard breaks. CRLF stays atomic.
- Consecutive hard breaks preserve empty rows. A final hard break adds an empty
  row with a zero-length range at the end of the source.
- Consumed ranges cover the original source in order, without inserting new
  breaks or normalizing whitespace. Source offsets use UTF-16 units, not Swift
  Character counts, glyph indices, or word counts.
- Normal contextual wrapping uses Core Text. A cluster-break fallback handles
  long unbroken text. Breaks are additionally kept at composed-character
  boundaries; no surrogate, combining sequence or emoji sequence is split to
  force progress.
- A width too narrow for an indivisible cluster fails with `widthTooNarrow`.
  The engine does not shrink text or silently truncate it. Fit checks use
  typographic advance excluding consumed trailing whitespace; they do not
  promise that glyph ink or whitespace stays inside the width.
- Invalid width, invalid font, invalid limits, input/line limits and native
  typesetting failure use typed `Failure` cases. Cancellation throws
  `CancellationError`. A caller should retain its last good layout on failure.

Default technical limits are 1,000,000 UTF-16 units and 100,000 output rows,
including a final empty row. Both limits are injectable at engine initialization.
They bound this calculation; they do not establish script-store or file-format
compatibility limits. Core Text's protection against unreasonably expensive
layout remains enabled through its [nullable creation API](https://developer.apple.com/documentation/coretext/cttypesettercreatewithattributedstringandoptions(_:_:)).

## Execution and integration boundary

The stateless engine uses `@concurrent` to leave the caller's actor under the
project's concurrency settings. Each calculation creates, uses and releases its
native layout objects without an intervening await, returning only Sendable
value models. Apple distinguishes shareable fonts from operation-owned layout
objects in the [Core Text threading guidance](https://developer.apple.com/documentation/CoreText).
Cancellation is checked before native creation, between lines and before return;
an individual native call cannot be interrupted.

A future viewport owner should coalesce settings/width changes, cancel obsolete
work, and check its request generation plus script identity/revision before
committing. It restores the latest source anchor, including navigation performed
while layout was running. Environment/Observation and UserDefaults are separate
from the calculation. Color-only highlight changes do not require reflow.

## Standalone demonstration

[PrompterLineLayoutDemoView.swift](../Promptly/Features/Prompter/Viewport/PrompterLineLayoutDemoView.swift)
can be instantiated with `PrompterLineLayoutDemoView(text: syntheticText)`.
Its two named previews use a synthetic sample at wide and narrow window sizes.
The controls change system/serif/monospaced design, bold weight, text size and
preferred reading width. Actual width is fitted to the window and shown in the
footer alongside the selected line and exact source offset. These controls are
local state and do not write the user's preferences.

Rows use the engine's text and resolved font. A blank row displays a nonbreaking
space to retain a line box, with a Blank line accessibility label. Selection
changes text color only, as requested, and exposes the selected accessibility
trait. Native buttons support selecting a row and Previous/Next/Restart.
The native scroll view tracks the visible row by source-start identity.
[ScrollViewProxy.scrollTo](https://developer.apple.com/documentation/swiftui/scrollviewproxy/scrollto(_:anchor:))
aligns explicit navigation and restored rows to the viewport top; bottom padding
allows the final row to reach that same position.

The demo's observable model keeps legal idle/loading/ready/failure states and
retains the last good layout on cancellation or error. Request generation and
cancellation checks reject late completions. Reflow preserves the precise
source offset; explicit navigation changes it to a current row's start.
Results use navigation performed during the pending calculation. A successful
source replacement resets the anchor; a failed replacement retains both the
previous source and its anchor.

Manual interaction invalidates pending results synchronously, before SwiftUI's
view-task cancellation can arrive. Reflow is deferred while the user is
interacting/decelerating. Scroll identity callbacks from programmatic
restoration do not update the source anchor. Actual native input/callback order
still requires physical interaction validation; the model tests do not prove
every mouse, trackpad, keyboard or accessibility scrolling path.

The preview tool currently supports static snapshots for this destination and
captures an ordinary asynchronous demo before its layout completes. Native
[PreviewModifier.makeSharedContext](https://developer.apple.com/documentation/swiftui/previewmodifier/makesharedcontext())
prepares both sample layouts through the actual engine before capture. A
preview-only optional environment value supplies the prepared result, while
the regular view continues using its cancellable task. This avoids hand-written
line fixtures or sleeps. Preview preparation is available at the deployment
target; no newer runtime-only API is required.

## Native choice and remaining validation

The standalone String/font/width-to-row interface uses Core Text's
[contextual line breaking](https://developer.apple.com/documentation/coretext/cttypesettersuggestlinebreak(_:_:_:)).
The earlier independent alternatives review also considered one wrapped SwiftUI
Text with TextRenderer. TextRenderer already
provides geometry/highlighting in the experiment; its documented opaque layout
indices do not directly specify offsets into original strings. Core Text gives
the requested engine a direct source-range calculation without adopting another
window or text-view owner.

The results describe Core Text's layout. Displaying substrings in independent
SwiftUI Text rows performs another layout pass. Matching fonts alone does not
establish matching paragraph direction, tabs, whitespace or discretionary hyphen
rendering. The engine preserves source and does not insert discretionary
hyphenation. SwiftUI row parity, accessibility, visual fit, long-script
responsiveness, CPU/energy, and minimum macOS 26.0 runtime behavior still need
native integration validation. No performance improvement is claimed.

## Validation record

On 2026-11-06, using Xcode 27.2, Swift 6.4.2, macOS SDK/runtime 27.2 and the
arm64 My Mac destination:

- Xcode `BuildProject(buildForTesting: true)` passed, compiling the app and both
  test targets with the existing Swift 6/concurrency settings.
- `RunSomeTests` for `PrompterLineLayoutEngineTests` passed the initial 35 cases,
  and a subsequent run passed the added whitespace-only narrow-width cases.
- The final complete suite passed all 40 cases across 17 test methods under
  Thread Sanitizer using the command below: source coverage, hard breaks/blank
  lines, whitespace, Unicode boundaries, width/font reflow, bounds and
  cancellation. No sanitizer diagnostics were reported; this is not proof of
  thread safety. The first sanitizer build reported an ignored duplicate
  `@executable_path` rpath; the final incremental run reported no warnings.

```sh
set -o pipefail
xcodebuild -project Promptly.xcodeproj -scheme Promptly -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/Promptly-LineLayout-TSan \
  -enableThreadSanitizer YES \
  -only-testing:PromptlyTests/PrompterLineLayoutEngineTests test \
  2>&1 | xcsift -f toon -w
```

The restricted shell initially prevented compiler macro plug-ins and local
signing; the approved retry outside that sandbox passed. Source/docs whitespace
and local-link checks passed. The repository-wide diff check still reports an
unrelated pre-existing extra EOF blank line in PrompterWindowBridge.swift.
No UI journey, visual parity, Release performance or macOS 26.0 runtime check
was performed for this standalone component.

The demonstration was subsequently validated on the same toolchain/destination:

- App and both test targets build with the demo/model included.
- All 14 cases across 13 demo model tests passed, including exact-anchor reflow
  round trips, navigation during a pending layout, old success/failure rejection,
  synchronous invalidation, cancellation, last-good recovery and preview reuse.
- The focused demo model suite also passed with Thread Sanitizer enabled.
- Both named previews rendered successfully through the native macOS preview
  tool and were visually inspected: wide/dark and narrow/light with Increased
  Contrast. The initial loading-only snapshot was corrected with native async
  preview preparation. These snapshots establish those rendered states, not
  physical input, VoiceOver, all typography parity or scrolling performance.

### Picker Preview crash follow-up

Opening the original typeface pop-up crashed the live Preview on macOS 27.2
with Xcode 27.2. Four local crash reports showed the same main-thread
`EXC_BREAKPOINT` in AppKit while creating an `NSPopupMenuWindow`, through
`NSWindow.setContentView` and SwiftUI's menu-presentation bridge. This happened
before selection; no engine or demo-model frames appeared in the crashing stack.
The reports and nearby app logs did not provide the assertion message.

The user reproduced the crash in a temporary Preview containing only a native
three-option Picker with Int tags and local State. The same minimal control
opened and selected Serif in a separate ordinary native window through
accessibility actions, including with matching sandbox, hardened-runtime,
read-only selected-file and debug entitlements. Temporary diagnostic apps used
ad-hoc signing, rather than the project's development identity. These
observations isolate the failure from the demo's
font resolution, engine, and prepared preview data; they do not establish the
underlying AppKit assertion or compatibility on other OS versions.

The demo now uses a native
[segmented Picker](https://developer.apple.com/documentation/swiftui/pickerstyle/segmented),
which Apple recommends for two to five options. This avoids popup presentation
for its three designs without introducing a custom control or native bridge.
The Picker retains its semantic Typeface label while hiding the visual label
to fit the narrow demonstration window. The engine and source-anchor behavior
are unchanged. This is a local workaround, not a general restriction on macOS
pop-up controls.

An isolated ordinary window compiled from the four actual engine/demo source
files also passed accessibility-action checks: Next moved the source offset to
35; System → Serif → Monospaced → System changed the line count from
30 → 33 → 44 → 30 while retaining offset 35 and selecting its containing row.
The native accessibility tree retained the Typeface group label and the three
selected/unselected options. Both named previews rendered after the style change,
including the 430-point narrow view, and the app plus both test targets built.
The temporary isolation Preview was removed. These checks do not establish
physical input or VoiceOver behavior for the replacement control in the live
Preview; canvas click/keyboard automation failed with `noWindowsAvailable`.
