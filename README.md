# Promptly

Promptly is a native macOS teleprompter designed for private, offline use. This README describes the planned feature set and technical direction.

## Planned features

### Privacy and offline operation

- **Privacy:** All processing performed by Promptly stays on device. Scripts, preferences, and settings are stored locally.
- **Offline operation:** Core features require no network connection. Apple-managed speech and Apple Intelligence model assets may require downloads or updates; script and speech processing stays on device.

### Script preparation

- **Script management:** Support autosave, undo/redo, duplication, search, and import/export. Supported file formats will be defined later.
- **Sections:** Allow users to mark section boundaries for navigation.
- **Optional AI section suggestions:** Use Foundation Models to suggest script sections. When the on-device model is unavailable, explain its availability status and provide setup guidance where applicable. Manual section editing remains available.

### Reading and playback

- **Text styling:** Support font family, size, color, and alignment. Evaluate OpenDyslexic as an optional font.
- **Readability:** Provide adjustable line height, paragraph spacing, reading-column width, text contrast, and background opacity.
- **Appearance:** Support Light Mode, Dark Mode, and following the system appearance.
- **Playback controls:** Play, pause, restart, rewind a few lines, and move to the previous or next section.
- **Scrolling:** Provide smooth automatic scrolling with adjustable speed.
- **Reading position:** Highlight the current line, provide an adjustable reading guide, and allow playback to resume from a clicked paragraph. Preserve the reading position when resizing the window or changing text styling.

### Window behavior

- **Window placement:** Default to a panel anchored around the notch, with the option to detach it into a draggable, resizable floating window.
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

- **Model availability:** Check on-device model availability before offering AI section suggestions. macOS manages Apple Intelligence model downloads. An unavailable model may also indicate that Apple Intelligence is disabled or unsupported; show guidance appropriate to the reported state.
- **MCP transport:** Prefer a stdio MCP helper that communicates with Promptly through XPC or a Unix domain socket, without a network-facing API. The detailed interface will be specified later.
- **Agent privacy boundary:** Local transport does not guarantee that an external agent processes retrieved scripts locally. Make that distinction clear when granting script-reading access.

## References

- [Apple: Foundation Models availability](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)
- [Apple: Speech model assets](https://developer.apple.com/documentation/speech/assetinventory)
- [Apple: Window-sharing limitations](https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum/none)
- [MCP: Transports](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports)
