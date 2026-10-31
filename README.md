# Promptly

Promptly is a native macOS teleprompter designed for private, offline use. The
current prototype provides reader window behavior with synthetic text and local
placement preferences. Script editing, persistence, handoff and scrolling
remain planned. The approved Quiet Native Library and reader designs guide
upcoming visual adoption.

See the [roadmap](ROADMAP.md) for implementation scope and remaining milestones.
The [architecture map](Docs/Architecture.md) documents current ownership, planned source destinations, and placement decisions.
The [approved Quiet Native baseline](Docs/QuietNativeDesign.md) records the Library
and reader visuals. The [Library design contract](Docs/LibraryDesign.md) records
its states and interactions; native adoption is planned separately from the
current implementation below.

## Current implementation

Promptly opens a menu-bar reader with fixed synthetic sample text. There is no
Library window, script editor, script store, autosave, Send to
Prompter workflow or manual/automatic scrolling implementation yet.

The reader wraps around the primary display's notch, or sits at the top center on a display without one. Choose **Detach Prompter**, then drag the title or empty header area to move it and resize its edges. Collapse, expand, lock, return to the notch, hide, and focus are available through the reader or menu. Lock prevents movement and resizing; Return to Notch remains available while locked.

Pointer interactions are intended to preserve the presenting app's focus. Choose Focus Prompter for keyboard control, then press Escape to release reader focus. Use macOS keyboard menu-bar navigation to reach Promptly's menu; its displayed keyboard shortcuts are local menu shortcuts, not global shortcuts.

Reader placement preferences use local UserDefaults. No script schema, store
filename, migration plan, editing-session cache or deletion-recovery buffer is
implemented. The [planned persistence requirements](Docs/PersistencePolicy.md)
and [Library acceptance checklist](Docs/ScriptEditingValidation.md) guide
future work rather than describe current storage or passing Library tests.

Script editing, scrolling/playback, appearance settings, import/export and AI
suggestions remain planned. Physical notch/display, full-screen, VoiceOver,
minimum macOS 26.0 and Zoom/Teams/Google Meet capture checks remain open. The
[window validation record](Docs/WindowBehaviorValidation.md) and
[coverage report](Docs/SourceCoverage.md) preserve window-prototype evidence;
they do not establish Library functionality or tests. Capture exclusion is
not guaranteed.

## Planned features

### Approved Library design

The Quiet Native active-script and empty-library designs are approved, with native
implementation from scratch and validation pending in
[milestone 2](ROADMAP.md#2-scripts-and-safe-local-editing).
The [design contract](Docs/LibraryDesign.md) retains both synthetic mockups
and defines the target behavior:

- **Quiet workspace:** Library sidebar, plain-text editor, compact editable
  Sections inspector, and one Send to Prompter button displaying ⌘↵. Remove
  redundant toolbar/title labels and the Plain text/repeated Send footer.
- **Library actions:** Pinned above Recently used; circular swipe actions for
  Duplicate/Delete and Pin/Unpin, full-swipe actions, and accessible contextual
  alternatives. Deletion offers recovery through a dismissible, 10-second Undo
  toast; closing or expiring it discards that operation's recovery snapshot.
- **Section navigation:** Single-click to jump, double-click to rename inline,
  keyboard navigation, add-at-cursor naming, and metadata-only removal with
  Undo. The current section uses a highlight without an extra leading marker.
- **Empty and first-script states:** A focused Create a Script · ⌘N action,
  hidden Sections and disabled Send without a document, then title focus and a
  valid blank editor on creation. No-match search offers Clear Search while
  preserving the open editor. There is no retained session recovery after toast
  dismissal or timeout; unrelated native editing undo remains separate.

The Library feature and script storage are not implemented. The first
implementation must include these approved states and interactions, with safe
save/send, section anchoring, local privacy and data-preservation behavior.

### Privacy and offline operation

- **Privacy:** All processing performed by Promptly stays on device. Scripts, preferences, and settings are stored locally.
- **Offline operation:** Core features require no network connection. Apple-managed speech and Apple Intelligence model assets may require downloads or updates; script and speech processing stays on device.

### Library

- **Library window:** Keep script management, editing, file import/export, manual sections, and optional section suggestions in a dedicated window, separate from the reader. **Show Library** opens or returns to this workspace.
- **Script management:** Support autosave, undo/redo, duplication, search, and the approved pinned-library workflow. File import/export remains a separate milestone; supported formats will be defined later.
- **Sections:** Named paragraph-start boundaries are stored separately from script text. They move with edits; consuming a whole paragraph removes its boundary, and joining marked paragraphs keeps the earlier boundary. Native undo restores text and affected boundaries together.
- **Optional AI section suggestions:** Use Foundation Models to suggest script sections. When the on-device model is unavailable, explain its availability status and provide setup guidance where applicable. Manual section editing remains available.
- **Send to Prompter:** Save the latest edits and hand off a stable script revision before closing the Library window. Failed or cancelled handoffs keep the window open and edits intact. Open the reader paused; Play is a separate action. Reopening the Library restores the selected script, and further edits reach the reader only through another explicit send.
- **Estimated reading duration:** Show approximate speaking time from script length and a displayed, adjustable assumed reading rate in words per minute. Label the assumption clearly; this is an estimate, not measured speech or automatic scrolling time. Keep count-in time separate.

### Reading and playback

- **Text styling:** Support font family, size, color, and alignment. Evaluate OpenDyslexic as an optional font.
- **Readability:** Provide adjustable line height, paragraph spacing, reading-column width, text contrast, and background opacity.
- **Appearance:** Support Light Mode, Dark Mode, and following the system appearance.
- **Live preview:** Preview appearance changes immediately using synthetic sample text.
- **Playback controls:** Play, pause, restart, rewind a few lines, and move to the previous or next section.
- **Count-in:** Offer an optional, configurable countdown after Play and before scrolling starts, with a way to skip or cancel it.
- **Scrolling:** Provide smooth automatic scrolling with Slow, Normal, and Fast pace presets plus a slider for precise adjustment. Presets and the slider control the same scroll-speed value; intermediate values are shown as custom.
- **Reading position:** Highlight the current line, provide an adjustable reading guide, and allow playback to resume from a clicked paragraph. Preserve the reading position when resizing the window or changing text styling.

### Window behavior

- **Window placement:** Focus on the main display, anchoring the panel around its notch or at the top center when there is no notch. Allow detaching into a draggable, resizable floating window. External-camera targeting is outside the planned workflow.
- **Window controls:** Support collapsing, position locking, and an explicit command to return the panel to its notch position.
- **Screen-sharing visibility:** Aim to keep the teleprompter hidden during screen sharing. Compatibility will be tested during development and may depend on the sharing application and capture method.

### Future capabilities

- **Voice-following — future:** Optionally synchronize scrolling with the speaker's progress through the script using on-device speech recognition.
- **MCP integration — future:** Provide a local agent interface with separate permissions for reading scripts, creating or editing scripts, and controlling playback. Scope access to explicitly authorized scripts; do not grant access to the entire script library by default.

## Tech stack

- **Minimum deployment target:** macOS 26.0.
- **Swift:** Swift 6.4 toolchain, strict concurrency checking, Approachable Concurrency enabled, and `MainActor` as the default isolation.
- **SwiftUI:** Current reader interface and controls; Library and settings UI are planned.
- **AppKit:** Current floating panel, window positioning, focus and display integration; native text editing and undo are planned.
- **SwiftData — planned:** Local script, section and pin storage with CloudKit disabled. The initial schema and compatibility policy are not implemented.
- **UserDefaults:** Current reader placement preferences; `@AppStorage` bindings for future preference UI are planned.
- **Foundation Models — planned:** Optional section suggestions using the on-device `SystemLanguageModel`.
- **Speech framework — future:** On-device speech recognition for voice-following.
- **TipKit — later:** Contextual onboarding and feature discovery.

## Implementation notes

- **Library handoff — planned:** Revalidate the script identity and revision before committing a send. Newer edits or a failed save must not be discarded by closing the Library or replacing the active reader. Sending must not implicitly restart an already loaded script.
- **Duration estimate:** Calculate approximate minutes as language-aware word count divided by the assumed words per minute. For example, 600 words at 150 words per minute is about four minutes. Define tokenization and the initial rate during implementation; account for languages without space-separated words and explain that pauses and delivery vary. This assumption is separate from the scroll-speed control.
- **Display placement:** The main display means the primary display configured in macOS, not whichever display contains the key window. Restore detached placement against actual visible screen bounds, including display disconnection; a bounding rectangle around multiple screens may contain gaps.
- **Playback timing:** Derive motion from elapsed time, give manual scrolling precedence, and stop playback updates when idle or the reader closes. Keep logical reading anchors independent of pixel offsets.
- **Model availability:** Check on-device model availability before offering AI section suggestions. macOS manages Apple Intelligence model downloads. An unavailable model may also indicate that Apple Intelligence is disabled or unsupported; show guidance appropriate to the reported state.
- **MCP transport:** Prefer a stdio MCP helper that communicates with Promptly through XPC or a Unix domain socket, without a network-facing API. The detailed interface will be specified later.
- **Agent privacy boundary:** Local transport does not guarantee that an external agent processes retrieved scripts locally. Make that distinction clear when granting script-reading access.

## References

- [Apple: Foundation Models availability](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)
- [Apple: Speech model assets](https://developer.apple.com/documentation/speech/assetinventory)
- [Apple: Window-sharing limitations](https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum/none)
- [MCP: Transports](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports)
