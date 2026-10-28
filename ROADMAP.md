# Promptly roadmap

Draft sequence based on the [planned feature set](README.md#planned-features).
These milestones describe intended outcomes, not release dates. The first
window-behavior prototype now provides a menu-bar reader with synthetic text,
notch anchoring, detachment, collapse, locking, and local placement restoration.
Milestone 1 remains open for physical display, full-screen, VoiceOver, and
sharing-app validation; see the [validation record](Docs/WindowBehaviorValidation.md).
The active and empty-library designs are approved. Their first
implementation belongs to milestone 2; Library code, storage and tests are
not present. Milestones 2 onward remain planned work.

## 1. Window behavior

**Goal:** Prove that Promptly can sit comfortably alongside a presenting app.
Use synthetic sample text so this milestone can stand on its own.

- Open a panel on the main display, anchored around its notch or at the top center
  when there is no notch. Use the primary display configured in macOS rather than
  the screen containing the key window. External-camera targeting is out of scope.
- Detach into a draggable, resizable floating window.
- Collapse and expand, lock and unlock the position, and provide an explicit
  return-to-notch command. Keep these states independent of eventual playback.
- Keep the panel and its controls reachable through resizing, display scaling,
  display disconnection, and changes to a multiple-display arrangement.
  Restore detached placement against an actual screen's visible bounds rather
  than a bounding rectangle that can include gaps between displays.
- Define activation and keyboard focus: reading interactions should not
  unexpectedly steal focus from the presenting app, while controls remain
  accessible by keyboard and VoiceOver.
- Investigate screen-sharing visibility early and record results for each actual
  sharing application and window/display capture method tested. A window-sharing
  flag alone is not evidence of capture exclusion.

**Done when:** The anchored → detached → collapsed → expanded → returned journey
works, position locking has an accessible escape, and placement/focus checks cover
notch and no-notch displays. Document tested screen-sharing combinations and
limitations; universal capture exclusion is not a completion requirement.

Define placement restoration with the main display as the default during this milestone.
Script storage, editing, and scrolling belong to later milestones.

## 2. Scripts and safe local editing

**Goal:** Let users prepare real scripts without losing their work.

**Status:** Design approved; implementation from scratch and validation pending.
There is no existing Library implementation, script store or passing
Library test suite to build on.
The [design contract and retained mockups](Docs/LibraryDesign.md) define the
active and empty target states. The [planned persistence requirements](Docs/PersistencePolicy.md)
and [acceptance checklist](Docs/ScriptEditingValidation.md#approved-design-adoption-pending)
guide the first implementation; design approval is not native validation.

- Create, open, edit, duplicate, pin/unpin, search and delete scripts in a local
  library. Keep management and manual sections in the dedicated Library window.
- Build the quiet Library/editor/Sections layout and inline ⌘↵ Send shortcut.
  Omit redundant toolbar/title labels, editor footer and leading section marker.
- Implement the empty-library, first-script and no-search-match states. Preserve
  editor selection, valid blank scripts and accurate save/sent status.
- Add Pinned grouping, circular row swipe controls and full-swipe actions, with
  context-menu, keyboard and VoiceOver alternatives. Operations target the row's
  ID even when a different script is selected.
- Provide destructive-action recovery only through a 10-second Undo toast,
  pausing during hover/focus. Explicit dismissal or expiry discards that
  operation's recovery snapshot; no session Undo Delete fallback remains.
- Add compact outline navigation, inline naming, add-at-cursor naming and
  metadata-only section removal. Preserve normal native editing undo separately
  from toast-limited destructive recovery, including boundaries affected by text.
- Implement autosave, pending/saving/failure states and safe close/quit behavior.
  Failed or out-of-order saves must preserve newer edits and the last good save.
- Design the initial SwiftData schema for scripts and sections, with the agreed
  `isPinned: Bool = false` script metadata field, an isolated persistence owner,
  bounded queries, revision handling and a compatibility policy.
  No schema version, store filename, cache limits or migration baseline is chosen
  yet. Validate writes/reopen and recovery before distributing durable stores.
- Implement Send to Prompter: save the intended revision, revalidate identity and
  revision before handoff, then close the Library and show the reader without
  automatic movement. Failure, cancellation or newer edits keep the Library
  open and preserve the reader. Further edits reach it only through another Send.
- Keep import/export and optional section suggestions in their later milestones.

**Done when:** The [planned acceptance matrix](Docs/ScriptEditingValidation.md#approved-design-adoption-pending)
passes for empty → create → edit → send and last-delete → empty → Undo journeys,
including final recovery expiry, row actions, pin persistence, native section
editing, keyboard/VoiceOver, appearance and failure recovery. Scripts and sections
survive reopening without silent data loss. Preserve the existing reader-window
behavior. Browser mockup checks alone do not complete this milestone.

## 3. Reader appearance

**Goal:** Make scripts comfortable to read in both panel and floating modes.

- Adjust font family, size, color, alignment, line height, paragraph spacing,
  reading-column width, contrast, and background opacity.
- Support Light, Dark, and system appearance, including accessibility settings.
- Provide a live appearance preview using synthetic sample text, without requiring
  the user to leave settings to judge changes.
- Preserve a logical reading anchor through resizing and styling changes; build
  this foundation before automatic scrolling.
- Evaluate OpenDyslexic as an optional font rather than a required dependency.

**Done when:** Large text and narrow windows remain usable, and changing layout
or appearance keeps the reader at the same logical place in the script.

## 4. Playback and navigation

**Goal:** Deliver the core teleprompter experience.

- Provide smooth automatic scrolling with Slow, Normal, and Fast presets and a
  precise speed slider. Both control the same scroll-speed value; show custom
  values between presets. Choose preset values through usability validation.
- Add an optional, configurable count-in after Play, with skip/cancel controls.
  Sending a script does not start it. Define first-start versus resume behavior
  during this milestone; closing the reader cancels pending count-in work.
- Add play, pause, restart, rewind a few lines, and previous/next section commands.
- Highlight the current line, offer an adjustable reading guide, and resume from
  a clicked paragraph.
- Preserve reading position across pause/resume, reflow, and window changes.
  Keep keyboard playback commands compatible with normal text editing.
- Derive movement from elapsed time and stop updates when idle. Manual scrolling
  takes precedence without automatic movement fighting it or jumping afterward.
- Show estimated reading duration in the Library from language-aware word count
  divided by a displayed, adjustable assumed words-per-minute rate. For example,
  600 words at 150 words per minute is about four minutes. This is approximate
  speaking time, independent of scroll speed; count-in is shown separately.
  Define tokenization, the initial rate, and display rounding, including empty
  scripts, short scripts, and languages without space-separated words.

**Done when:** A synthetic long script can be read end to end, navigation and
pause/resume behave predictably, and closing the reader stops its ongoing work.
Preset and slider changes agree, count-in can be skipped/cancelled without losing
the reading anchor, and the duration estimate explains its rate assumption rather
than claiming to measure the speaker. Space and arrow keys retain normal behavior
while editing, and manual scrolling does not fight playback.

## 5. Import and export

**Goal:** Move scripts into and out of Promptly safely.

- Choose supported formats and define whether each preserves sections and styling.
- Validate imports before committing; preserve existing scripts and unsaved edits.
- Export consistent snapshots, safely handle destination replacement, and review
  the sandbox write access required for user-selected destinations.
- Provide useful failure recovery and cancellation.

**Done when:** Supported files work with an independent reader, and failed or
cancelled file operations preserve both existing scripts and destination files.

## 6. Optional AI section suggestions

**Goal:** Offer an on-device shortcut to the manual section workflow.

- Use Foundation Models when available and explain reported availability states.
- Present suggestions for review; only explicit acceptance commits changes.
- Reject stale results after edits, and handle cancellation, refusal, malformed
  output, and failures without replacing manual sections or script text.

**Done when:** Accepted suggestions apply only to the analyzed script revision,
and manual editing/playback remain useful offline when the model is unavailable.

## Later, separately scoped

- **Voice-following:** On-device speech recognition, explicit permission and
  capture controls, and reliable manual playback fallback.
- **Local MCP interface:** Separate script-scoped read, edit, and playback
  permissions, revocation, and revision-safe edits. Explain that external agents
  may process retrieved text remotely despite the local transport.
- **TipKit:** Contextual onboarding once the core interactions have settled.

## Throughout

Privacy, offline core use, data preservation, native Mac interaction, keyboard
access, and VoiceOver are acceptance criteria for every relevant milestone.
Use synthetic content for tests and screenshots. Validate at the lowest reliable
layer and record hardware, OS, capture-method, and other checks that remain open.
No milestone adds analytics, accounts, cloud sync, or remote inference.
