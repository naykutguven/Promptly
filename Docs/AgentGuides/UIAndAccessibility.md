# UI and Accessibility

Read for SwiftUI and AppKit integration, the menu bar, the prompter, editor, and
Settings windows, size presets, placement and displays, current-line
presentation, app activation and keyboard focus, accessibility, Reduced Motion,
error and confirmation presentation, and screen-capture disclosure. Follow
[AGENTS.md](../../AGENTS.md), the [PRD](../PRD.md), the
[Architecture](../Architecture.md), and the macOS Human Interface Guidelines.
Read [Concurrency and Playback](ConcurrencyAndPlayback.md) for scrolling and
playback timing, and [Testing and Validation](TestingAndValidation.md) before
verification.

## Native UI research checklist

Before choosing a framework integration or workaround:

- Identify the observable need. Window visibility, stacking level, Spaces
  participation, app activation, keyboard focus, and playback state are separate
  capabilities; establish which ones the requirement actually needs.
- Check what the native scene or control already manages, including frame
  restoration and user or system settings. Add custom behavior only for a
  requirement those defaults do not meet.
- Confirm whether a placement API affects initial creation, restoration, or an
  open window. Distinguish view coordinates from screen coordinates.
- Prefer content-driven sizing and native interaction modifiers over manual
  geometry or event handling. When AppKit is necessary, find the smallest native
  operation and define its owner, lifetime, and MainActor boundary.
- Check availability against the macOS 26 deployment target, using the installed
  SDK declarations when signatures matter.
- Use a small isolated probe when documentation leaves runtime behavior unclear.
  Report separately what compilation, automation, physical interaction, and
  different OS or display configurations establish.

## Structure and state

- Feature windows, AppKit adapters, presentation state, focus, and feature-only
  geometry live in `Features/<Feature>/`. Scenes, app-wide commands, and
  cross-window routing live in `App/` (Architecture §2, §8).
- Views observe the reading session and settings service and send intents to
  them. They keep no copy of the active script, layout, current line, playback
  state, or editable settings (Architecture §3).
- Features do not call each other. For example, the editor never opens the
  prompter; the load operation reveals it through a capability App injects
  (Architecture §2).
- Keep presentation state on `MainActor`. Model mutually exclusive presentation
  with enums. Show useful empty, loading, error, and retry states without
  unexplained indefinite spinners.
- Enable controls from the session's command predicates, so the UI and MCP never
  disagree about what is allowed (Architecture §4.1, §4.5).

## Menu bar and windows

- Promptly is menu-bar-only, with no Dock icon, even while the editor or
  Settings is open (F05.6). It has three windows: the prompter, the script
  editor, and Settings (Architecture §1).
- The menu bar toggles prompter visibility, opens the editor, and can switch
  placement (F01.1, F05.4, F05.5).
- Show the prompter at launch, with an empty state when no script is loaded
  (F05.5).
- Showing the prompter (from the menu bar, or after a UI or MCP load) and using
  its controls or drag region must not activate Promptly; the app the user is
  working in keeps keyboard focus. Opening the editor or Settings activates
  Promptly normally (F05.6).
- How the prompter avoids activation is an open decision, likely an AppKit
  non-activating panel hosting the SwiftUI view (Architecture §10). The
  prototype calls `NSApp.activate()` when showing the prompter; that is a known
  deviation, not a pattern to copy.

## Prompter window

- Offer the Compact and Expanded presets with fixed reading areas and no
  freeform resizing (F05.1). Reading width comes from the preset, so placement
  does not change it (Architecture §4.2).
- Attached placement targets the built-in display, even when an external display
  is primary. Anchor it top-center relative to the notch when one exists, fall
  back on displays without one, and keep essential text and controls out of
  inaccessible hardware regions (F05.2). Never hard-code screen geometry.
- Floating placement moves only by a designated drag region; dragging must not
  scroll the text (F05.3, F05.4).
- Within a launch, detaching returns the window to its last floating position,
  which the window model keeps in memory. With none available, after relaunching
  while Attached or after Restore All Defaults, use a default floating position
  (F05.3, PRD-08 §8.6).
- Promptly stores no window coordinates; macOS restores the frame across
  launches. Verify native restoration for the borderless prompter on macOS 26
  before relying on it (F05.3).
- Placement and preset changes from the window, menu bar, Settings, or MCP go
  through the settings service; the window model applies them (F05.4,
  Architecture §5).
- Validate restored frames, relocate a window whose display disappears, and
  recompute attached geometry after display changes, without losing the reading
  position (F05.7).
- Use a minimal borderless presentation on a solid black background, above
  ordinary windows where supported.
  While attached, stay on the built-in display across its Spaces without
  appearing on external displays. Verify Spaces and full-screen behavior on
  macOS 26 before claiming it (F05.6).
- Today the window model attaches to the `NSWindow` SwiftUI creates without
  replacing its delegate or lifecycle (Architecture §4.5). Change the hosting
  window only within the non-activating-prompter task. Either way, visibility is
  native window state; the window model observes it and reports it to the
  session, and adds no second visibility owner (Architecture §3, §4.5).
- Hiding from the in-window control or the menu bar pauses active playback.
  Showing never resumes it. Disable Play while the prompter is hidden (F03.1,
  F03.9, F05.5).
- The prototype's lock control and freeform sizing are not MVP behavior
  (Architecture §8.2). Do not extend them.

## Reading view

- Render each display line as its own SwiftUI `Text` in a `ScrollView`, with
  identities that are stable within a layout revision. Render from the layout's
  stored configuration, not live settings, so text matches the engine's line
  breaks. Line and paragraph spacing are fixed (F02.3, Architecture §4.2).
- While a new layout is computed, keep the previous layout visible. Show a small
  progress indicator only after a noticeable delay; do not use skeletons or
  shimmer (F02.7).
- Show the current line at full opacity and surrounding lines at a fixed reduced
  opacity, without changing font size, line height, or adding a background.
  A blank current line gets no marker. Emphasis never changes layout (F04.2).
- Align the current line to the Top, Center, or Bottom focus position, with
  enough leading and trailing space for the first and last lines. Changing the
  position neither pauses playback nor regenerates layout (F04.3).
- Text color is a preference that applies immediately without relayout
  (PRD-08 §8.2, F07.9).
- Keep frequent playback updates local to the views that need them. Advancing a
  line must not invalidate the whole list.

## Editor and Settings

- The editor is a separate plain-text window opened from the menu bar. Keep
  native text selection, undo and redo, copy and paste, and standard shortcuts
  (F01.1). Draft rules are in [Data and Privacy](DataAndPrivacy.md).
- Import uses the standard open panel and puts the result in the editor for
  review (F01.2). The editor indicates when its text exceeds the script limit,
  which blocks loading until the text is shortened (F01.7).
- Settings uses a native sidebar modeled on macOS 27 System Settings, while
  still supporting macOS 26. Its sections are Prompter (with Layout and Text
  groups), Playback, Integrations, and About. **Restore All Defaults…** sits at
  the bottom of the sidebar, apart from navigation (PRD-08 §8.1, §8.6).
- Settings shows exactly the preferences PRD-08 defines; add no others, such as
  appearance options, without a requirement.
- Settings controls submit partial updates, and agent changes appear
  immediately. Opening or closing Settings does not pause or resume playback
  (PRD-08 §8.1, §8.8).
- Use native color selection with a way to restore the default color
  (PRD-08 §8.2).
- Enabling MCP in Integrations presents the access-scope and external-processing
  disclosure (F07.15, PRD-08 §8.4).

## Confirmations and errors

- Confirm only where the PRD requires it: discarding unfinished editor edits
  (F01.6) and Restore All Defaults (PRD-08 §8.6). Replacing or clearing the
  active script needs no confirmation (F01.5).
- Errors say what happened, whether the session and draft are intact, and the
  next useful step. Cover the PRD's error cases, such as no script loaded,
  layout in progress, window hidden, import failure, and layout failure
  (PRD §10.4).

## Accessibility and motion

- Make every control keyboard-accessible with accurate labels, logical focus
  order, and predictable focus behavior (PRD §10.5). Disabled controls must not
  trap initial focus.
- Keyboard shortcuts, including global hotkeys, are post-MVP (PRD §13). Add no
  global hotkeys or custom shortcuts; native text-editing and window shortcuts
  stay available.
- Expose the current line and playback state to VoiceOver without announcing
  every advance or continually moving accessibility focus. Do not rely on color
  alone to show the reading position (PRD §10.5).
- Respect Reduce Motion: make transitions immediate or restrained. The viewport
  completes scroll transitions immediately under Reduce Motion (F04.5,
  Architecture §4.5).
- Use readable typography and contrast (PRD §10.5). Use native controls and
  semantic colors in the editor and Settings so they follow system appearance
  and accessibility display settings.
- Accessibility identifiers are stable semantic tokens, never script text. Use
  synthetic text in previews, screenshots, and UI tests.
- User interface localization is post-MVP (PRD §13); add no translations.
  Script text still needs the Unicode and bidirectional handling in F02.8.

## Screen-capture disclosure

- Never claim universal invisibility. macOS has no documented way for an app to
  force other capture apps to exclude its window, and
  `NSWindow.sharingType = .none` is not reliable protection (PRD-06).
- Record observed behavior in the
  [compatibility research](../Research/ScreenSharingCompatibility.md), and
  disclose tested behavior plus unsupported or untested cases in the app and
  documentation (F06.2, F06.3).
- Keep capture privacy separate from hide and show. Do not change accessibility
  exposure to try to hide the window from capture.

Verify window placement, presets, display changes, Spaces, focus, keyboard
flows, VoiceOver, Reduced Motion, and reading-position preservation on macOS.
