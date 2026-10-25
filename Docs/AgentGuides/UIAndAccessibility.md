# UI and Accessibility

Read for SwiftUI/AppKit, presentation, windows, focus, styling, permissions,
localization, or accessibility. Follow [AGENTS.md](../../AGENTS.md) and native
macOS Human Interface Guidelines. Read [Concurrency and Playback](ConcurrencyAndPlayback.md)
for scrolling and [Testing and Validation](TestingAndValidation.md) before verification.

## Native Mac interaction

- Use native controls, menus, toolbars, text editing, search, and settings before
  custom replicas. Views render state and send intents to injected capabilities.
- Keep presentation state on `MainActor`. Use enums for mutually exclusive
  workflows; provide useful empty, loading, unavailable, error, retry, and
  cancellation states without unexplained indefinite spinners.
- Preserve expected text selection, undo/redo, copy/paste, and keyboard shortcuts.
  Playback commands must not interfere with editor typing or standard shortcuts.
- Make primary flows work with keyboard and VoiceOver. Provide menu commands,
  discoverable shortcuts, logical tab order, and alternatives to custom gestures.
- Keep script font, spacing, width, alignment, contrast, and background opacity
  adjustable without losing the logical reading position.

## Panels, displays, and focus

- Support the planned notch-anchored panel and detached, draggable, resizable
  window without hard-coded screen geometry. Handle Macs without a notch,
  multiple displays, scaling, and changing display arrangements.
- Account for visible screen bounds and safe areas. Keep controls reachable after
  resizing, disconnecting a display, or restoring saved placement; provide the
  explicit return-to-notch command from the README.
- Define activation and keyboard-focus behavior deliberately. Reading controls
  should not unexpectedly steal focus from the user's presenting application;
  script editing must still support normal keyboard access.
- Distinguish collapsed, position-locked, and playback states. Position locking
  must not trap users or hide the way to unlock or reposition the panel.
- Validate screen-sharing visibility with actual applications and capture paths.
  Do not promise universal exclusion or treat it as a security boundary. Avoid
  changing accessibility exposure merely to try to hide a window from capture.

## Accessibility and appearance

- Provide accurate VoiceOver labels, values, actions, grouping, and focus order.
  Expose playback state and the reading position semantically without announcing
  every frame or continuously moving accessibility focus.
- Respect user text-size and accessibility settings; avoid clipped labels and
  fixed layouts. Test large script text, long controls, and narrow windows.
- Support Light, Dark, system appearance, Increased Contrast, Reduce Transparency,
  Reduce Motion, and Differentiate Without Color. Use semantic colors and give
  non-color cues for the reading guide, highlighted line, and state changes.
- Keep scrolling an explicit user-controlled reading aid. Honor Reduce Motion
  for decorative effects and transitions; keep pause and manual navigation easy
  to reach and avoid unexpected movement.
- Localize user-facing text with grammar-safe resources and locale-aware
  formatting. Test long translations and right-to-left text where supported.

## Permissions and private content

- Request microphone or Speech access only when future voice-following is
  explicitly enabled. Explain why, show active capture clearly, and provide a
  useful manual fallback after denial or unavailability.
- Present AI section suggestions for review; explain unavailable on-device models
  without blocking manual section editing or exposing private diagnostic detail.
- Explain destructive actions and prefer honest undo/recovery where supported.
  Errors state what happened, whether edits are safe, and the next useful action.
- Use synthetic scripts in previews, screenshots, and UI tests. Accessibility IDs
  are stable semantic tokens, never script text. Future agent consent must explain
  scope, separate capabilities, revocation, and possible external processing.

Verify window placement/focus, keyboard flows, VoiceOver, appearance/contrast,
reduced effects, reflow position, and applicable permission/error states on macOS.
Keep frequent playback updates local to the views that need them, and stop
view-lifetime work when inactive.
