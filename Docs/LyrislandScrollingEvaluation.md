# Lyrisland scrolling evaluation

Reviewed on 2026-11-05 against Lyrisland
[`c8e11ad4121feca0ca81c29068f4848e5948f6e2` (v0.7.2)](https://github.com/EurFelux/Lyrisland/tree/c8e11ad4121feca0ca81c29068f4848e5948f6e2).
Links below pin that revision rather than a changing branch.

This is source and framework research for [roadmap milestones 3–4](../ROADMAP.md#3-prompter-appearance).
It does not implement scrolling, approve another visual direction, or change
Promptly's privacy, persistence, window ownership, or concurrency contracts.
The current prompter still displays synthetic text; playback remains planned.

## Recommendation

Lyrisland is a useful reference for separating playback timing from semantic
highlight updates, isolating small views, and managing a finite animation
sequence. Its lyric view moves between timestamped rows; its marquee pans a
single line horizontally. Neither supplies Promptly's continuous vertical
playback, wrapped-text reading anchors, or manual-scroll policy.

Start the eventual viewport investigation with native SwiftUI scrolling APIs.
Keep a feature-owned AppKit adapter conditional on a reproduced gap. No runtime
evidence from this review establishes that SwiftUI cannot meet the requirements
or that AppKit would perform better. Independent reviews of the wider project
and native scrolling alternatives support this starting point.

## Window sizing, font changes, and current-line synchronization

Follow-up checked on 2026-11-06; the main branch still resolves to the reviewed
revision. The sizing/settings paths across the source tree show that the main
lyric island has preset, programmatically changed sizes and a base-font-size
setting. It does not expose free edge/corner resizing or a font-family picker.

### How the window changes size

The [panel's style mask](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Window/DynamicIslandPanel.swift#L15-L19)
contains borderless/nonactivating options, without resizable. Its custom mouse
handling supports movement and tapping to cycle state. The [Settings and lyrics
picker windows](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/App/AppDelegate.swift#L314-L385)
are separately created with the resizable option.

[IslandContentView](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Views/IslandContentView.swift#L41-L80)
requests panel sizing on appearance, screen-parameter changes, attachment
changes, compact/expanded/full state changes, artwork changes, and dual-line
changes. [Its sizing function](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Views/IslandContentView.swift#L290-L378)
uses those inputs and notch geometry. Standard widths are 220 points compact,
450/380 expanded, and 540/400 full, depending on artwork; notch-hugging compact
width derives from the notch and its side areas. Font size is absent from this
calculation.

[animateResize](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Window/DynamicIslandPanel.swift#L115-L140)
animates the new frame over 0.35 seconds, preserving screen-top center while
attached or the existing top-left while detached. The hosting view is
[constrained to its container's edges](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Window/DynamicIslandPanel.swift#L31-L53),
so the layout receives the new available space. Switching island state also
switches among different SwiftUI view branches.

### How font changes reach the text

The [Appearance slider](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Views/SettingsView.swift#L117-L183)
sets a base size of 12–24 points in one-point steps, defaulting/resetting to 16.
The update path is:

1. The slider writes rootFontSize through AppStorage/UserDefaults.
2. [AppState's defaults observer](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/App/AppState.swift#L77-L96)
   copies the value into its published rootFontSize property on the main run loop.
3. [IslandContentView injects the value into the environment](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Views/IslandContentView.swift#L30-L39).
4. Child views recompute system fonts using [a multiplier times that base size](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Utils/RemScaling.swift#L18-L23).
   For example, the active full-list lyric uses 0.9375 times the base: 15 points
   at the default setting and 22.5 at the maximum.

The app does not explicitly call resizePanel when only rootFontSize changes.
It supplies new fonts to SwiftUI within its designed geometry. In expanded
mode, [lyric rows have fixed 20-point heights](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Views/ExpandedIslandView.swift#L47-L74).
This is not evidence that all font sizes fit. Native hosting constraints can
also react to changed content measurements: Apple documents the default
[NSHostingView sizing behavior](https://developer.apple.com/documentation/swiftui/nshostingview/sizingoptions).
Exact clipping, alignment, and framework-driven size adjustments require a run;
no native result is asserted here.

### Why the lyric identity survives a layout change

[SyncedLyrics.lineIndex](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Lyrics/Models/SyncedLyrics.swift#L17-L31)
finds the last timestamp at or before playback position plus the user's timing
offset. The [sync engine](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Spotify/PlaybackSyncEngine.swift#L102-L153)
updates that index during playback and publishes it only when it changes.
Neither window size nor font size enters this calculation. Rebuilding a lyric
view does not replace the shared playback engine.

The three presentations consume the same timestamp-selected identity:

- [Compact](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Views/CompactLyricsView.swift#L13-L46)
  displays the current lyric, optionally with the next lyric underneath.
- [Expanded](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Views/ExpandedIslandView.swift#L38-L82)
  displays a context slice of up to five timestamped lyrics.
- [Full](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Views/FullIslandView.swift#L37-L42)
  passes the index to LyricsScrollView, which explicitly centers it only on
  appearance or a changed index. Entering full mode mounts that view and thus
  requests initial centering. Font-only or size-only changes in an existing
  full view have no explicit centering handler. While paused, the next
  timestamp transition cannot supply another centering request.

These presentations keep individual lyrics on single visual rows, using
horizontal panning for the active row's overflow and truncation for surrounding
rows. Dual-line mode means two timestamped lyrics. There is no wrapped-line
mapping to recalculate after resizing. Retaining the highlighted lyric's ID is
separate from keeping that row centered in the viewport.

For the marquee, a changed container width resets its local offset/phase; if
that changes the task identity, the phase task restarts. A font-only change
does not explicitly refresh the cached natural text width or reset the phase.
Reentering a mode or advancing to a newly mounted lyric can remeasure it, but
that does not establish correct behavior for the surviving view. The marquee
also has no remaining-playback-time input, so a restarted pan does not account
for time already spent in the lyric. See the detailed component review below.

The useful Promptly lesson is to retain a logical content identity independently
of layout. Promptly additionally needs a location within wrapped script content
and an explicit policy to restore that location at the guide after reflow.
Lyrisland's timing-selected rows do not demonstrate that latter requirement.

## LyricsScrollView.swift

[Source, lines 13–50](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Views/LyricsScrollView.swift#L13-L50):
a vertical `ScrollView`, `LazyVStack`, and identified lyric rows sit inside
`ScrollViewReader`. Appearance positions the current row immediately; a changed
line index requests a centered scroll with a 0.3-second ease-in-out animation.
Line duration comes from adjacent lyric timestamps.

This is a useful small example of explicit navigation to a content identity.
Promptly's previous/next section and clicked-paragraph navigation may use the
same native capability. Automatic playback needs a separate motion policy:
fixed-duration recentering at each line boundary produces intermittent movement
and varying velocity, rather than a continuous user-selected pace.

Important differences for Promptly:

- **Content identity:** Lyrisland's [line IDs are array indices](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Lyrics/Models/SyncedLyrics.swift#L3-L8).
  That fits an immutable parsed track. Promptly needs an anchor into a particular
  sent script revision, independent of wrapped line numbers and pixel offsets.
  Paragraph identity alone may be too coarse within a long wrapped paragraph.
- **Manual interaction:** The index-change handler has no user-interaction gate;
  it can request another automatic scroll while the user is navigating manually.
  Promptly must explicitly arbitrate manual input and playback.
- **Reflow:** This view requests scrolling on appearance and index changes.
  It does not explicitly reconcile the reading anchor after font, spacing,
  viewport, or content changes. Native behavior may help, but this code alone
  does not establish preservation of the same reading location.
- **Stable layout and readability:** [Current and inactive rows use different
  font sizes, with truncation, blur, scaling, and dimming on inactive text](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Views/LyricsScrollView.swift#L65-L108).
  Promptly needs readable wrapped script text and its approved Quiet Native
  treatment. Prefer a highlight/guide that preserves text metrics; validate
  contrast and non-color cues rather than adopting the lyric effects.
- **Guide placement:** Fixed 40-point top/bottom spacers are not a general way
  to align the first and last text with an adjustable reading guide in a
  resizable viewport. Derive any required scrollable padding from that geometry.

The [comment claiming roughly two row changes per index shift](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Views/LyricsScrollView.swift#L54-L63)
should not become a performance assumption. Each row receives the exact
`distance` from the current index; moving to the adjacent index changes that
stored input for every materialized row, even when its resulting blur stays the same.
`Equatable` cannot make unequal inputs equal. Actual body evaluations and lazy
layout costs require measurement. Apple documents the equality-based behavior
of [equatable()](https://developer.apple.com/documentation/swiftui/view/equatable()).
For Promptly, keep frequent position updates local to the viewport and pass
only the semantic state a row actually needs.

## MarqueeText.swift

[Source, lines 18–92](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Views/MarqueeText.swift#L18-L92):
the view measures available width and unwrapped text width, computes overflow,
and offsets a clipped text overlay. Edge gradients indicate hidden content.
Text that fits remains static. A four-phase enum runs the initial delay, linear
pan, final delay, and optional repeat through a view-associated task.

Useful techniques are explicit phases, overflow-driven activation, points per
second as a pace unit, and cancellation checks after suspension. SwiftUI's
[task modifier](https://developer.apple.com/documentation/swiftui/view/task(id:name:priority:file:line:_:))
cancels/recreates work when its identity changes and can cancel it when the view
disappears. That is a helpful lifetime mechanism, but view disappearance must
not be assumed to equal native window hide/close or playback pause.

Limitations visible in this implementation:

- **Incomplete measurement updates:** [Text width is assigned on appearance
  and text changes](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Views/MarqueeText.swift#L61-L81),
  without observing changes to the measured text geometry. A font-only change
  in a fixed container has no corresponding width refresh. Observe the actual
  measured size; Apple's [onGeometryChange](https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:))
  provides a native option. The 50-millisecond sleep in the idle phase is not a
  layout-readiness contract.
- **Incomplete restart inputs:** The task is keyed only by animation phase.
  Enabling scrolling after the idle task has finished does not itself restart
  it. Lyrisland's [DualLineRow forces recreation when its current state changes](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Views/CompactLyricsView.swift#L109-L123)
  to handle this case. Speed and duration changes also lack an explicit restart
  or rebase policy. A reusable component needs deliberate input/lifetime rules.
- **No playback pause linkage:** The marquee has no playback-state input. An
  already-running pan is independent of Spotify pausing. Promptly's script
  viewport must obey its single session's pause and lifecycle commands.
- **Timing is specific to lyrics:** [Duration uses the full lyric interval
  minus the initial delay and a buffer](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Views/MarqueeText.swift#L35-L45).
  It does not receive remaining time when entering midway through a line.
  Short intervals fall back to distance divided by speed, which need not finish
  before the line changes. This is unsuitable as Promptly's playback clock.
- **Accessibility and direction need validation:** There is explicit RTL pan
  handling, but [language identification determines direction](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Utils/TextDirection.swift).
  That is not a complete mixed-direction paragraph-layout solution. Neither
  scrolling file explicitly handles Reduce Motion. Test VoiceOver exposure of
  the measured/overlaid text and mixed scripts before adopting the pattern.
  Apple's [Reduce Motion environment value](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion)
  supports reducing decorative movement; explicit prompter playback remains
  a user-controlled reading aid with accessible pause/manual navigation.

A horizontal marquee could be evaluated separately if a future compact title
requires it. It is not needed for wrapped script reading, and no new title
behavior is selected here.

## Other useful parts of the project

| Area | Lesson for Promptly | Boundary |
| --- | --- | --- |
| [PlaybackSyncEngine](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Spotify/PlaybackSyncEngine.swift#L18-L28) | Keep interpolated position separate from the published current-line identity; publish semantic changes only when needed. | Despite its opening comment, the actual driver is a [30 Hz Timer](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Spotify/PlaybackSyncEngine.swift#L103-L131), using Date-based interpolation. The declared CVDisplayLink is unused. This is not evidence of display-synchronized continuous scrolling. |
| [Paused content replacement](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Spotify/PlaybackSyncEngine.swift#L134-L153) and [regression tests](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Tests/PlaybackSyncEngineTests.swift#L15-L52) | Recompute the current unit when content changes even while the clock is stopped. | Promptly must additionally reconcile the sent script identity, revision, and logical anchor. |
| [SyncedLyrics lookup](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Lyrics/Models/SyncedLyrics.swift#L16-L31) | Binary search is useful when locating the active unit in ordered boundaries. | Ordered lyric timestamps are not script reading positions; use an appropriate layout index only if needed. |
| [IslandPlacement](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Window/IslandPlacement.swift), [PanelPlacement](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Window/PanelPlacement.swift), and their tests | Pure geometry policies make display edge cases testable. | Promptly already separates geometry. Lyrisland's [custom nonactivating NSPanel and hosting/drag infrastructure](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Window/DynamicIslandPanel.swift#L4-L56) does not justify replacing Promptly's SwiftUI Window. |

The wider project also supplies cautionary examples. [Lyrics loading](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Lyrics/LyricsManager.swift#L74-L114)
assigns results after suspension without checking the still-current request
identity; overlapping requests can admit an older result. Promptly's revision
and cancellation rules remain necessary. Its [icon playback controls](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/Sources/Views/PlaybackControlsView.swift#L9-L25) do not
establish keyboard or VoiceOver behavior through source inspection alone.

The [project configuration](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/project.yml)
targets macOS 14 and Swift 5.10, includes KeyboardShortcuts, disables App Sandbox,
and enables Apple Events and network-client entitlements. Remote lyric providers
and track-detail logging serve a different product. Promptly's offline script
path, sandbox, private diagnostics, and Swift 6 concurrency baseline remain the
applicable contracts.

The repository declares [GPLv3](https://github.com/EurFelux/Lyrisland/blob/c8e11ad4121feca0ca81c29068f4848e5948f6e2/LICENSE).
Direct code adoption requires a separate license-compatibility decision. This
review adds analysis and links, without vendoring source or adding a dependency.

## Native alternatives for the future viewport

The following availability was checked against official Apple documentation
and installed Xcode 27.2 / macOS 27.2 SDK declarations. All listed APIs are
available at Promptly's macOS 26.0 minimum; that is a declaration check, not
runtime validation on macOS 26.0.

Declaration evidence uses the SDK under
`/Applications/Xcode_27.2.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk`:

- SwiftUI's `arm64e-apple-macos.swiftinterface`: lines 1993–1994, 11465–11467,
  15922–15923, 18124–18131, 25584–25585, 29493–29494, and 29587–29588.
- SwiftUICore's `arm64e-apple-macos.swiftinterface`: lines 729–735, 766–777,
  and 799–806 for ScrollPosition and its methods/properties.
- AppKit's `Headers/NSView.h`: lines 655–662 for view display links.

| Candidate | macOS availability | Purpose |
| --- | --- | --- |
| [ScrollViewReader](https://developer.apple.com/documentation/swiftui/scrollviewreader) | 11.0+ | Small option for explicit jumps to identified paragraphs/sections. |
| [ScrollPosition](https://developer.apple.com/documentation/swiftui/scrollposition) and [scrollPosition binding](https://developer.apple.com/documentation/swiftui/view/scrollposition(_:anchor:)) | 15.0+ | One native owner supporting IDs, edges, and point/axis scroll commands. The x/y read properties specifically require 26.0. |
| [scrollTargetLayout](https://developer.apple.com/documentation/swiftui/view/scrolltargetlayout(isenabled:)) | 14.0+ | Declare paragraph targets, including offscreen lazy items, without requiring snapping. |
| [onScrollGeometryChange](https://developer.apple.com/documentation/swiftui/view/onscrollgeometrychange(for:of:action:)) | 15.0+ | Observe actual offsets, sizes, and insets; derive small values instead of broadcasting every frame. |
| [onScrollPhaseChange](https://developer.apple.com/documentation/swiftui/view/onscrollphasechange(_:)) | 15.0+ | Distinguish interaction/deceleration from idle/programmatic animation for manual-input policy. Validate each Mac input path. |
| [defaultScrollAnchor by role](https://developer.apple.com/documentation/swiftui/view/defaultscrollanchor(_:for:)) | 15.0+ | Separate initial position, size-change, and undersized-content alignment policies. |
| [TimelineView animation schedule](https://developer.apple.com/documentation/swiftui/timelineschedule/animation(minimuminterval:paused:)) | 12.0+ | A pausable scheduling candidate; delivery cadence is not the playback clock. |
| [NSView displayLink](https://developer.apple.com/documentation/appkit/nsview/displaylink(target:selector:)) | 14.0+ | A narrow display-linked scheduling option if the native probe demonstrates the need. It follows the containing display and stops callbacks when hidden/off-display. |

Apple documents that identity-based ScrollPosition targets are kept visible
where possible across resizing/reordering. Point-based positions do not maintain
an exact offset across content-size changes. Neither promise establishes
preservation of the current wrapped line inside a long paragraph. Keep a logical
content anchor independent of layout, resolve it after reflow, and rebase motion.

Use an injected monotonic elapsed-time source and a base position/speed, rather
than adding a fixed distance per callback. Apple's [ContinuousClock](https://developer.apple.com/documentation/swift/continuousclock)
is one available clock; it includes system sleep, so resumption needs deliberate
rebasing to avoid a jump. Scheduling, elapsed-time calculation, and visibility
policy are separate responsibilities. Speed changes, manual navigation,
pause/resume, and reflow also require rebasing.

Apple's [Beyond scroll views sample and presentation](https://developer.apple.com/videos/play/wwdc2023/10159/)
demonstrates target layouts and ID bindings. It also discusses the usability
cost of hidden scroll indicators (09:10–09:58), and why scroll transitions avoid
font changes that alter content size (13:24–13:38). Use that native behavior as
the baseline before reproducing Lyrisland's visual effects.

Only a failing minimal native example would justify evaluating NSScrollView
scroll ownership. Source-range/layout mapping and text interaction require
separate evidence of a gap. Scrolling
alone does not require replacing text rendering, the SwiftUI Window, or its
existing geometry adapter. Follow the [architecture ownership map](Architecture.md):
viewport/layout integration belongs to Features/Prompter, shared content anchors
to Domain, and the authoritative non-UI playback session to Services.

## Evidence still required

No Lyrisland build, native interaction, VoiceOver check, or performance profile
was performed. The implementation findings above are static observations;
native alternatives are documented capabilities and recommendations to test.
This review does not establish accessibility, smoothness, energy use,
minimum-OS runtime compatibility, or screen-sharing exclusion.

For milestones 3–4, use a minimal native probe with synthetic content to verify:

1. A long script, very long wrapped paragraphs, blank paragraphs, large text,
   mixed-direction text, and unbroken tokens remain readable and navigable.
2. The same logical text stays at the reading guide across resize, font/spacing/
   column changes, and display changes, including first/last content bounds.
3. Continuous motion follows elapsed time at multiple speeds; pause/resume,
   speed changes, jumps, and click-to-resume do not introduce position jumps.
4. Mouse wheel, trackpad, keyboard, scroller, and accessibility navigation take
   precedence; programmatic movement is not mistaken for manual input.
5. Close cancels pending work; pause stops playback updates. Define hide/collapse
   and system-suspension behavior explicitly, and ensure reopening cannot apply
   stale motion. Keep the existing independent window states.
6. Keyboard/VoiceOver, contrast, Reduce Motion, and the guide/highlight work
   without announcing every frame or making surrounding text unreadable.
7. Measure actual offset, responsiveness, smoothness, CPU, and idle energy on a
   representative Mac before selecting a scheduler or claiming a performance
   benefit. Keep frequent work local; no persistence or full-script processing
   on each update.

These are future implementation checks, not passing tests or permission to skip
the earlier script/editing and appearance milestones.
