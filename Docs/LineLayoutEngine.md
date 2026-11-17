# Line layout engine

`LineLayoutEngine` (`Promptly/Services/Prompter/LineLayoutEngine.swift`) turns
script text into display lines, returned as `PrompterLine` values
(`Promptly/Domain/Prompter/PrompterLine.swift`). Only the standalone
demonstration under `Promptly/Features/Prompter/Viewport/` uses it. The main
prompter, settings, and playback are not connected to it.
[Architecture](Architecture.md) §4.2 defines how the reading session will use
the engine.

## Interface

`LineLayoutEngine.layout(text:font:width:)` accepts an unchanged String,
a SwiftUI `Font.Resolved`, and a finite positive reading width in points. It
returns an array of `PrompterLine` values with only:

- `sourceRange`: UTF-16 coordinates in that exact input String, including any
  hard-break delimiter consumed by the line.
- `text`: the corresponding substring with only its terminal hard break removed.
  Spaces and tabs are preserved.

The PRD's line `id` and `layoutRevision` fields (F02.2) are not engine output
yet. The reading session will mint a layout revision for each request, and
generation will stamp each line with an identity and that revision
([Architecture](Architecture.md) §4.2).

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
They bound this calculation; they do not replace the product limits in F01.7.
Core Text's protection against unreasonably expensive layout remains enabled
through its [nullable creation API](https://developer.apple.com/documentation/coretext/cttypesettercreatewithattributedstringandoptions(_:_:)).

## Execution and integration boundary

The stateless engine uses `@concurrent` to leave the caller's actor under the
project's concurrency settings. Each calculation creates, uses and releases its
native layout objects without an intervening await, returning only Sendable
value models. Apple distinguishes shareable fonts from operation-owned layout
objects in the [Core Text threading guidance](https://developer.apple.com/documentation/CoreText).
Cancellation is checked before native creation, between lines and before return;
an individual native call cannot be interrupted.

The reading session will own layout requests ([Architecture](Architecture.md)
§4.1–§4.2). It coalesces layout-affecting settings changes, including the size
preset that defines the reading width, cancels obsolete work, and checks its
request identity plus script and layout revisions before committing. It
restores the latest source anchor, including navigation performed while layout
was running. The viewport only renders committed layouts. Environment,
Observation, and UserDefaults stay outside the calculation. Color-only highlight
changes do not require reflow.

## Design rationale

Core Text's [contextual line breaking](https://developer.apple.com/documentation/coretext/cttypesettersuggestlinebreak(_:_:_:))
gives every line a direct range in the original string, which reading anchors
and MCP line records need. A single wrapped SwiftUI `Text` with `TextRenderer`
provides line geometry and highlighting, but its documented layout indices are
opaque and do not map to offsets in the original string.

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
changes text color only and exposes the selected accessibility trait. Native
buttons support selecting a row and Previous/Next/Restart. The native scroll
view tracks the visible row by source-start identity.
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
interacting or decelerating, as reported by `onScrollPhaseChange`. Scroll
identity callbacks from programmatic restoration do not update the source
anchor.

Previews prepare both sample layouts through the real engine with
[PreviewModifier.makeSharedContext](https://developer.apple.com/documentation/swiftui/previewmodifier/makesharedcontext())
and pass them in through a preview-only environment value, so a static snapshot
never captures the loading state. The regular view keeps its cancellable task.
No hand-written line fixtures or sleeps are involved.

The typeface control is a
[segmented Picker](https://developer.apple.com/documentation/swiftui/pickerstyle/segmented).
A pop-up Picker crashes live Previews with Xcode 27.2 on macOS 27.2, inside
AppKit's menu presentation and independent of the engine. Recheck that before
switching back.

## Validation status

`PromptlyTests/Services/Prompter/LineLayoutEngineTests` covers empty and
whitespace-only input, hard breaks and blank lines (including atomic CRLF and a
trailing break), spaces and tabs, Unicode and grapheme boundaries, long words,
width and font-size reflow, invalid widths and limits, UTF-16 input and line
limits, widths narrower than one cluster, and cancellation. The demo model has
no automated tests.

For concurrency changes, also run the unit tests, which include this suite, with
Thread Sanitizer. A clean run is not proof of thread safety.

```sh
./Scripts/tests.sh test-tsan
```

Not yet validated:

- Agreement between Core Text breaks and SwiftUI row rendering. Rows lay out
  again in SwiftUI, and matching fonts alone does not establish matching
  paragraph direction, tabs, whitespace, or discretionary-hyphen rendering. The
  engine inserts no discretionary hyphenation.
- Physical scrolling input (mouse, trackpad, keyboard, accessibility actions)
  and VoiceOver.
- Long-script responsiveness, CPU, and energy use. No performance claim is made.
- Runtime behavior on macOS 26.0.
