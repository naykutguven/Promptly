# Promptly

Promptly is a native macOS teleprompter designed for private, offline use. This README describes the planned feature set and technical direction.

See the [draft roadmap](ROADMAP.md) for the proposed implementation sequence, starting with window behavior.

## Planned features

### Privacy and offline operation

- **Privacy:** All processing performed by Promptly stays on device. Scripts, preferences, and settings are stored locally.
- **Offline operation:** Core features require no network connection. Apple-managed speech and Apple Intelligence model assets may require downloads or updates; script and speech processing stays on device.

### Script preparation

- **Preparation window:** Keep script management, editing, file import/export, manual sections, and optional section suggestions in a dedicated window, separate from the reader.
- **Script management:** Support autosave, undo/redo, duplication, search, and import/export. Supported file formats will be defined later.
- **Sections:** Allow users to mark section boundaries for navigation.
- **Optional AI section suggestions:** Use Foundation Models to suggest script sections. When the on-device model is unavailable, explain its availability status and provide setup guidance where applicable. Manual section editing remains available.
- **Send to Prompter:** Save the latest edits and hand off a stable script revision before closing the preparation window. Failed or cancelled handoffs keep the window open and edits intact. Open the reader paused; Play is a separate action. Reopening preparation restores the selected script, and further edits reach the reader only through another explicit send.
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
- **SwiftUI:** Application interface, script editor, controls, and settings.
- **AppKit:** Floating panel, window positioning, focus behavior, and display integration.
- **SwiftData:** Local persistence for scripts and section metadata, with CloudKit synchronization disabled.
- **@AppStorage:** Local user preferences and settings.
- **Foundation Models:** Optional section suggestions using the on-device `SystemLanguageModel`.
- **Speech framework — future:** On-device speech recognition for voice-following.
- **TipKit — later:** Contextual onboarding and feature discovery.

## Implementation notes

- **Preparation handoff:** Revalidate the script identity and revision before committing a send. Newer edits or a failed save must not be discarded by closing preparation or replacing the active reader. Sending does not implicitly restart an already loaded script.
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
