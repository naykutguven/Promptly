# UI and Accessibility

Read for SwiftUI/AppKit, presentation, windows, focus, styling, permissions,
localization, or accessibility. Follow [AGENTS.md](../../AGENTS.md) and native
macOS Human Interface Guidelines. Read [Concurrency and Playback](ConcurrencyAndPlayback.md)
for scrolling and [Testing and Validation](TestingAndValidation.md) before verification.

Use the [approved Quiet Native baseline](../QuietNativeDesign.md) for Library and
prompter styling. It includes SF Symbols, accent-colored filled pins, system-font
section digits and smaller prompter glyphs with accessible targets. Native adoption
and validation remain pending.

## Native UI research checklist

For the framework decisions covered by AGENTS.md, check these distinctions before
choosing an integration:

- Identify the observable user need. Window visibility, stacking level, app
  activation, keyboard focus, and ongoing playback are separate capabilities;
  establish which ones the requirement actually needs.
- Check what the native scene or control already manages, including restoration
  and user/system settings. Add custom persistence only for a requirement those
  defaults do not satisfy.
- Confirm whether a placement API affects initial creation, restoration, zooming,
  or an already-open window. Distinguish view-layout coordinates from desktop
  coordinates, and passing geometry or intents from applying native geometry.
- Evaluate content-driven sizing and native interaction modifiers before manual
  geometry or event handling. If integration remains necessary, identify the
  smallest native operation and its ownership, lifetime, and MainActor boundary.
- Use a small isolated probe when documentation leaves material runtime behavior
  uncertain. Report separately what compilation, automation, physical interaction,
  and different OS/display configurations establish. A probe that fails outside
  the feature is evidence to investigate that broader failure boundary.

Keep comparisons and evidence proportional to the decision. When revising this
workflow, check that it would catch custom code duplicating native defaults,
unsupported minimum-OS assumptions, and limitation claims without researched
alternatives. These checks assess the instructions; they do not validate app UI.

## Native Mac interaction

- Keep feature windows/panels, delegates, hosting, focus, native editor/scroll
  adapters and layout policy in `Features/<Feature>/`. These are UI even when
  implemented in AppKit. App-wide scenes/coordination belong in `App/`; non-UI
  preference codecs, storage and processing belong in `Services/`. Follow the
  [architecture map](../Architecture.md), its current source snapshot and completed
  migration record; planned destinations are created with their roadmap work.
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

## Approved Library design

Use the [approved active and empty states](../LibraryDesign.md) for
Library UI work. The first native implementation is planned in roadmap
milestone 2; no Library implementation or native validation is present.

- Keep swipe actions available through row context menus, keyboard and VoiceOver.
  Actions target the row's ID, not whichever script happens to be selected.
- Select the title after Create. Keep section rows stable for double-click
  naming, distinguish outline focus from the highlighted current section, and
  scope Return/Space/arrow handling to the outline. Preserve editor typing,
  composition and native undo.
- Derive empty-library, no-match and blank-script presentations from their actual
  states. Loading and store failures must not appear as an empty library.
- Keep shortcut glyphs readable and expose their meaning accessibly. Disabled
  controls must not trap initial keyboard focus. Respect semantic colors,
  contrast and reduced effects when matching the mockups.
- Keep Undo reachable during its 10-second toast window, pausing the timer during
  hover/focus and announcing feedback once. Explicit dismissal or expiry ends
  that operation's recovery and discards its snapshot; no recovery command
  remains afterward. Preserve unrelated native editing undo. Persistent save
  failures retain their recovery UI and do not use this transient timer.

## Panels, displays, and focus

- Preserve the notch-anchored and detached, draggable, resizable SwiftUI
  prompter window without hard-coded screen geometry. Handle Macs without a notch,
  multiple displays, scaling, and changing display arrangements.
- Account for visible screen bounds and safe areas. Keep controls reachable after
  resizing, disconnecting a display, or restoring saved placement; provide the
  explicit return-to-notch command from the README.
- Define activation and keyboard-focus behavior deliberately. Normal native
  window activation is allowed for the prompter (2026-11-03); do not reintroduce
  the removed Focus Prompter mode. Script editing must support normal keyboard
  access. SwiftUI owns prompter visibility; observe its window without replacing
  its delegate or adding a second presentation owner.
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
