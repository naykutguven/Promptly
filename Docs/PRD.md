# Promptly — Product Requirements Document

**Version:** 0.2  
**Status:** Feature specification — refined  
**Platform:** macOS 26+  
**Language:** Swift 6.4 with strict Swift concurrency  
**UI:** SwiftUI, Observation, AppKit where necessary  
**Text layout:** Custom Core Text engine  
**Persistence:** UserDefaults / @AppStorage  
**Integrations:** Model Context Protocol (MCP), official Swift SDK

---

# 1. Product Overview

## 1.1 Vision

Promptly is a lightweight, privacy-conscious macOS teleprompter that enables users to read prepared scripts while working in other applications.

It combines a floating reading interface, automatic line-by-line playback, flexible window positioning, and integration with AI agents through MCP.

Promptly is designed primarily for video meetings, interviews, presentations, and AI-assisted workflows.

## 1.2 Product principles

1. **Minimalism:** The prompter should remain visually unobtrusive.
2. **Predictability:** Reading progress, navigation, and playback timing must behave consistently.
3. **Local-first:** Script processing occurs locally without requiring cloud services.
4. **Agent interoperability:** MCP clients and the user interface operate on the same application state.
5. **Privacy:** Script content remains ephemeral, and screen-capture protection claims must be technically verified.
6. **Native experience:** Follow macOS conventions and minimize unnecessary custom UI infrastructure.

## 1.3 Confirmed product decisions

| Decision | Specification |
|---|---|
| Playback | Line-by-line advancement |
| Reading speed | Words per minute (WPM) |
| Hide behavior | Automatically pause active playback |
| MCP line indexing | Visual display lines with mandatory layout revisions for navigation |
| Script persistence | Memory-only |
| MCP settings access | Read and write, with security-sensitive exclusions |
| Window sizing | Compact (default) and Expanded fixed presets |
| Window placement | Attached to the built-in laptop display (default), or Floating |
| Source rendering | Individually rendered SwiftUI Text views |
| Text layout | Custom Core Text engine |
| Preferences persistence | UserDefaults |
| Active scripts | One at a time |

## 1.4 Core domain concepts

**Script:** The original unmodified text supplied by a user or agent.

**Display line:** A visually wrapped segment of the script produced by the layout engine.

**Script revision:** A unique identifier representing a version of the active source script.

**Layout revision:** A unique identifier representing a generated collection of display lines. It changes when the script or a layout-affecting setting changes.

**Current line:** The display line representing the user's reading focus.

**Reading session:** The active script, generated display lines, playback state, and reading position.

---

# PRD-01 — Script Input & Management

**Priority:** P0 — MVP

## Objective

Enable users and agents to load and replace scripts without maintaining separate content pipelines.

## Functional requirements

### F01.1 — Manual script entry

- Users can open the script editor in a separate window from the menu bar.
- A newly opened editor shows the active script, or empty text if no script is loaded.
- The editor accepts pasted or typed plain text.
- Users can review and edit content before loading it.
- Selecting **Load into Prompter** replaces the active script, shows the prompter without starting playback, and closes the editor only after success. Failed or superseded loads leave the draft available.
- Whitespace-only scripts are rejected.

### F01.2 — File import

Use the standard macOS file-opening interface.

MVP formats:
- `.txt`
- `.md`, imported as literal plain text

Requirements:
- Read files locally.
- Support UTF-8.
- Preserve paragraph boundaries.
- Display understandable errors for unreadable or unsupported files.
- Avoid modifying the original file.
- Allow review of imported text before loading it.

### F01.3 — Unified loading behavior

Regardless of whether the text originates from the editor, an imported file, or MCP:

1. Validate the new script.
2. Prepare a new script revision and display-line layout without replacing the current session.
3. Confirm this is still the latest load request.
4. Commit the new source text, revisions, and layout together.
5. Set the current line to index `0`.
6. Set playback to Stopped.
7. Show the prompter without starting playback.
8. Update all connected views and MCP-visible state.

The latest load request wins across UI and MCP. Older results must not replace a newer request, regardless of completion order.

If validation or layout generation fails, the previously valid session remains available.

### F01.4 — Memory-only persistence

Script content and editor drafts exist only in application memory.

The application must not:
- Store scripts in UserDefaults.
- Automatically create persistent script files.
- Restore the previous script after an application restart.
- Persist imported file contents or file paths.
- Include script contents in logs, diagnostics, or analytics.
- Automatically upload scripts to cloud services.

On normal application termination, the active session is discarded.

The MVP does not promise secure memory erasure or protection against operating-system memory snapshots and crash dumps.

### F01.5 — Session lifecycle

- Only one script can be active at a time.
- Hiding the prompter preserves the script.
- Showing the prompter restores the existing session.
- Users can explicitly clear the current script.
- Replacing or clearing the active script does not require confirmation.
- Clearing the script invalidates pending loads so older results cannot restore it.
- Loading a new script invalidates existing line references.
- The app is fully functional without an MCP connection.

### F01.6 — Editor synchronization and draft protection

- Typed, pasted, or imported changes not yet loaded are unfinished editor edits.
- When the active script changes or is cleared, update an open editor automatically only if it has no unfinished edits.
- Otherwise preserve the draft and offer **Use Active Script** to replace it with the current active text.
- Confirm before discarding unfinished edits, including on import, **Use Active Script**, editor close, or application quit. Cancelling preserves the draft.

### F01.7 — Input limits

- Initial script limit: 100,000 user-perceived characters.
- Initial imported-file limit: 1 MB (1,000,000 bytes).
- Enforce the script limit when loading through the UI or MCP.
- Reject oversized input with a clear error. Never truncate text or replace the active session or editor draft on rejection.

## Acceptance criteria

- Users can load scripts through both manual entry and file import.
- MCP-provided scripts use identical loading behavior.
- New scripts reset the reading position and playback.
- Successful loads through UI or MCP show the prompter without starting playback.
- Application restart begins without an active script.
- Settings persist independently of the active script.
- Invalid imports never destroy an existing valid session.
- The editor opens separately with the active script and closes only after a successful editor-initiated load.
- Incoming scripts preserve unfinished editor edits; discarding those edits requires confirmation.
- Oversized input is rejected without truncation through every entry point.
- Older load results cannot overwrite the latest load request.

## Out of scope

PDF/DOCX import, rich-text editing, script history, cloud synchronization, multiple scripts, autosave, and persistent script libraries.

---

# PRD-02 — Text Layout & Line Engine

**Priority:** P0 — MVP

## Objective

Produce deterministic display lines that fit the prompter's configured width, while preserving the relationship between rendered lines and the original source text.

## Functional requirements

### F02.1 — Core Text layout engine

A dedicated Core Text engine calculates line breaks using:

- Source text
- Available text width
- Font family
- Font weight
- Font size
- Relevant shaping and typography attributes

The layout engine must not depend on SwiftUI view instances.

Keep `kCTTypesetterOptionAllowUnboundedLayout` at its default, `false`. Bidirectional processing is already supported; this option permits otherwise excessively expensive layout. Reconsider enabling it only if representative long or bidirectional scripts within the input limits demonstrate a need, after measuring resource use. See Apple's [unbounded-layout option](https://developer.apple.com/documentation/coretext/kcttypesetteroptionallowunboundedlayout) and [bidirectional behavior](https://developer.apple.com/documentation/coretext/kcttypesetteroptionforcedembeddinglevel).

### F02.2 — Display-line model

Each display line contains:

| Field | Description |
|---|---|
| `id` | Line identity assigned once during layout generation |
| `text` | Text represented by the line |
| `sourceRange` | Range within the original script |
| `layoutRevision` | Revision that produced the line |

The model conforms to `Identifiable`. Each ID remains stable within its layout. Zero-based line indexes are derived from array positions, including in MCP responses.

The source range is the authoritative connection between a display line and the original script.

Internal Core Text range handling must account for UTF-16 indexing and Unicode grapheme boundaries.

### F02.3 — Rendering

- Render each display line as an independent SwiftUI `Text` view.
- Present lines vertically within a `ScrollView`.
- Use stable line identities within a layout revision.
- Ensure each line fits the available reading width.
- Preset widths and supported font sizes must provide sufficient reading width.
- Avoid unintended second-line wrapping.
- Use efficient/lazy view construction when needed.
- Keep line and paragraph spacing fixed for the MVP.

The layout and rendering systems must use compatible font measurements.

### F02.4 — Layout invalidation

Regenerate the display-line layout when any of these change:

- Active script
- Compact/Expanded size preset
- Font family
- Font weight
- Font size
- Effective text container width
- Any rendering attribute that changes glyph shaping or line width

Do not regenerate lines for:
- Text color
- WPM
- Current-line highlighting
- Playback state
- Window visibility
- Placement changes that do not alter reading width
- Visual effects that do not affect text geometry

### F02.5 — Layout revisions

Every successful layout regeneration creates a new unique layout revision.

Line indexes are valid only within that revision.

For example:

- Layout revision A contains 42 lines.
- A font size change generates revision B containing 58 lines.
- A request referencing line 30 of revision A is considered stale, even if revision B also contains line 30.

This prevents agents from accidentally navigating to the wrong text after layout changes.

### F02.6 — Preserve reading position

When layout regeneration occurs:

1. Capture the current line's source-text position.
2. Pause playback if it is active.
3. Generate the new layout.
4. Find the new line containing or nearest to the saved source position.
5. Update the current line index.
6. Restore the corresponding visual scroll position.
7. Leave playback paused.

The user must not unexpectedly return to the beginning.

### F02.7 — Asynchronous generation and loading state

- Layout calculations must run off the main actor using an `@concurrent` async entry point, as defined by [Swift's concurrency specification](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md).
- Results must be concurrency-safe.
- Obsolete calculations must be cancelled or discarded.
- Only results corresponding to the latest requested configuration may be applied.
- SwiftUI-observed session state is updated on the main actor.
- Keep the previous layout visible with its matching rendering configuration while recalculating.
- Pause playback and disable Play and navigation, including manual scrolling and MCP navigation, until the new layout is ready or failure recovery completes.
- Show a small progress indicator only for noticeable delays. Do not replace the previous layout with skeletons or shimmer animations.

### F02.8 — Text edge cases

The engine must support or explicitly handle:

- Empty paragraphs
- Consecutive newlines
- Long unbroken words and URLs, wrapping between characters when needed without splitting composed characters or emoji sequences
- Emoji and composed characters
- Unicode whitespace
- Bidirectional text
- Font fallback
- Scripts with thousands of words

Each preserved blank line occupies a normal line-height row, counts toward the display-line total, and is navigable. Preserve consecutive blank lines. Blank-line playback uses the minimum line duration defined in PRD-03.

### F02.9 — Layout failure

- Preserve the previous valid layout, source text, and reading position, and expose the failure.
- If a settings change caused the failure, restore the affected settings to their previous working values without overwriting newer settings updates.
- Leave playback paused after recovery.
- Failed script replacements follow the loading rules in PRD-01.

## Acceptance criteria

- Display lines fit the available width.
- No source content is unintentionally lost or duplicated.
- Font changes produce correct new layouts.
- Current reading position survives layout regeneration.
- Old revisions are rejected by MCP navigation.
- Rapid settings changes cannot apply stale layout results.
- Text rendering agrees with the layout engine's calculated boundaries.
- Long words and URLs wrap without losing text or splitting composed characters.
- Blank lines are included in line counts and navigation.
- Recalculation preserves the previous display and blocks Play/navigation through UI and MCP.
- Failed settings-triggered layout changes restore the previous working layout and affected settings without undoing newer updates.

## Out of scope

Rich-text styling, paragraph annotations, inline images, manual line overrides, and per-word text animations.

---

# PRD-03 — Playback & Navigation

**Priority:** P0 — MVP

## Objective

Provide automatic line-by-line reading at a configurable WPM, with predictable manual interruption and navigation.

## 3.1 Playback model

**Confirmed:** Playback advances one display line at a time.

The application does not continuously scroll at a fixed pixel velocity.

Instead:

1. A display line becomes current.
2. Scroll it into its configured focus position using a brief animation.
3. Once scrolling finishes, start the line's calculated reading duration.
4. Keep the line stationary for that duration.
5. Advance to the next line and repeat, or complete playback after the final line.

The reading session owns the current-line index. The scroll view only represents that position visually.

Scrolling time is additional to the WPM-based reading duration. Total playback time includes both reading and scroll transitions. Respect Reduced Motion when presenting transitions.

## 3.2 Playback states

| State | Meaning |
|---|---|
| Stopped | Session initialized or rewound |
| Playing | Automatic line advancement is active |
| Paused | Playback interrupted, position retained |
| Completed | Final line finished its reading duration |

## Functional requirements

### F03.1 — Play

- Starts playback from the current line.
- Resumes from a paused position.
- If playback has completed, starts again from the beginning.
- Does nothing if playback is already active.
- Play is unavailable while the prompter is hidden. Disable UI Play controls and reject MCP Play with a structured window-hidden error; do not show the prompter automatically.

The first line must remain visible for its calculated reading duration before advancing.

### F03.2 — Pause

- Immediately suspends automatic advancement.
- Preserves the current line.
- Preserves the remaining reading time for that line; Play continues that remaining time.
- Does not change the scroll position.
- Repeated Pause commands are safe and idempotent.

### F03.3 — Rewind

- Stops automatic playback.
- Sets the current-line index to `0`.
- Resets line timing.
- Scrolls to the first line.
- Sets state to Stopped.

Rewind must not automatically restart playback.

### F03.4 — Reading speed

**Confirmed:** WPM is the only MVP playback-speed model.

Confirmed defaults:
- Default: 150 WPM
- Initial supported range: 60–300 WPM
- User-adjustable in Settings

Line reading duration is based on the amount of text within that display line.

Calculate each line's reading duration as:

`lineDuration = max(0.6 seconds, wordCount × 60 / WPM)`

Example at 150 WPM:
- 5 words → 2 seconds
- 10 words → 4 seconds
- 15 words → 6 seconds

A minimum duration prevents short lines from advancing too quickly.

The minimum duration is 0.6 seconds. Each blank line receives this minimum duration, including consecutive blank lines.

Word counting must use appropriate Unicode-aware tokenization rather than assuming that all languages separate words using ASCII spaces.

Count words independently within each display line, including word fragments produced by character wrapping.

### F03.5 — Playback timing engine

Playback uses monotonic elapsed time.

The playback engine calculates duration when a line's reading timer starts, using the current WPM. The reading session stores the active line's calculated duration and remaining reading time in playback state. Do not store playback durations in the display-line model. Pausing and resuming retain the captured duration; a WPM change does not recalculate the current line.

Requirements:
- Avoid assuming timer callbacks are perfectly accurate.
- Avoid accumulating unintended timer drift over long scripts; scroll transitions remain additional elapsed time.
- Ensure a single active playback scheduler.
- Cancel or invalidate previous scheduled advances when playback is paused, reset, or replaced.
- Ensure navigation commands supersede pending timer events.
- Start each reading timer only after its scroll transition finishes. Interrupted or obsolete transition completions must not start playback.

A Swift concurrency-based scheduling mechanism is preferred over a view-owned repeating timer.

### F03.6 — WPM changes during playback

Changing WPM must not reset the script or reading position.

**Confirmed MVP behavior:**
- The new speed takes effect from the next display line.
- The current line finishes according to its existing timing.
- The new speed is persisted immediately.

This avoids unexpectedly shortening or extending the current line while the user is reading it.

### F03.7 — Manual scrolling

**Confirmed:** Manual scrolling pauses playback.

Requirements:
- Detect user-initiated scrolling.
- Pause playback as soon as user interaction starts.
- Cancel pending automatic advancement.
- Allow the user to scroll normally.
- Update the current line according to the final reading focus.
- Reset timing so the selected line receives its full reading duration when Play is next pressed, even if scrolling settles on the same line.
- Do not resume playback automatically.

The current line should follow the nearest line to the configured focus anchor. It may update during user scrolling, but the settled position becomes authoritative when scrolling ends.

Programmatic scrolling must not trigger manual-scroll interruption.

### F03.8 — Direct navigation

Navigating to a specified line:

1. Validates the layout revision.
2. Validates the line index.
3. Pauses playback.
4. Sets the requested line as current.
5. Scrolls the line into its configured focus position.
6. Resets the line's reading timer.

Navigation must behave identically whether initiated through the UI or MCP.

### F03.9 — Automatic pause on hide

**Confirmed:** Hiding the prompter pauses playback.

- If playback is Playing, hiding changes the state to Paused.
- If playback is already Paused, Stopped, or Completed, that state is preserved.
- The current line remains unchanged.
- Showing the window does not automatically resume playback.
- Users must explicitly press Play or invoke the MCP Play command.

This behavior applies to all ordinary Promptly hide actions, including the window control and menu-bar toggle.

It does not imply that the app can detect every third-party screen-sharing state.

### F03.10 — Completion behavior

- The last line remains current for its calculated duration.
- Playback then transitions to Completed.
- No automatic looping occurs.
- Pressing Play from Completed restarts at the first line.

### F03.11 — System sleep

- If playback is active when the Mac goes to sleep, pause it and cancel pending automatic advances.
- Preserve the current line and its remaining reading time.
- Playback paused by system sleep remains paused after wake until Play is explicitly requested with the prompter visible.
- Do not advance through unread lines to catch up with time spent asleep.

## Acceptance criteria

- Playback progresses line by line at the configured WPM.
- Short and blank lines receive at least 0.6 seconds of reading time; blank lines receive exactly the minimum.
- Play/Pause/Rewind behave consistently.
- Pause/resume continues the current line's remaining reading time.
- Manual scrolling immediately interrupts playback.
- Play after manual scrolling gives the selected line its full reading duration.
- Programmatic scrolling never falsely triggers a pause.
- Hiding the window pauses playback.
- Play while hidden is disabled in the UI and rejected through MCP without showing the prompter.
- Reopening the window does not resume playback.
- System sleep preserves position and remaining time; wake never resumes playback or skips unread lines.
- Playback reaches Completed only after the final line's reading duration.
- Reading timers start after scrolling finishes, so animation does not consume reading time.
- Each display line is timed independently using its own word count and the minimum duration.
- Changing WPM does not regenerate the layout.
- Repeated rapid control actions do not create overlapping playback schedules.

## Out of scope

Continuous scrolling, speech synchronization, microphone tracking, per-word playback, automatic looping, and fixed duration-per-line mode.

---

# PRD-04 — Current Line Highlighting

**Priority:** P0 — MVP

## Objective

Make the current reading position immediately identifiable without visually overwhelming the script.

## Functional requirements

### F04.1 — Current line

Exactly one display line is designated as current when a nonempty layout exists.

Its identity is determined by the reading session, not individual view state.

### F04.2 — Highlight presentation

Confirmed MVP presentation:
- Current line at full opacity (`1.0`).
- Surrounding lines at fixed opacity, initially `0.6`. Tune this value during implementation for readability; no user-adjustable dimming in the MVP.
- No changes to font size or line height.
- No background rectangle.
- Strong enough contrast to remain readable.
- A blank current line has no special marker or decoration; retain its normal blank row.

Highlight styling must not affect text layout.

### F04.3 — Highlight position

Users can select:

- Top
- Center
- Bottom

The current line is automatically aligned to the chosen reading position.

The default position is Center. Changing position preserves the current line, playback state, and timing; active playback continues without layout regeneration.

Adequate leading and trailing scroll space must exist for the first and last lines.

### F04.4 — Synchronization

Highlighting updates when:
- Playback advances.
- Users scroll manually.
- A line is selected directly.
- MCP navigates to another line.
- The layout is regenerated.
- Playback is rewound.

### F04.5 — Reduced motion

System accessibility preferences must be respected.

Where Reduce Motion is enabled, transitions should become immediate or use restrained alternatives.

## Acceptance criteria

- A current line containing text is visually distinct; a blank current line has no special mark.
- Top, Center, and Bottom placement remain consistent.
- Reading focus defaults to Center.
- Changing focus position preserves the current line and playback timing without pausing active playback.
- Highlight transitions do not cause text reflow.
- Rapid navigation does not produce competing highlights.
- Manual scrolling and MCP navigation update the same highlighted line.

## Out of scope

User-adjustable dimming, word-level highlights, karaoke effects, multiple highlighted lines, and animated text transformations.

---

# PRD-05 — Window & Notch Management

**Priority:** P0 — MVP

## Objective

Provide a small, nonintrusive prompter window that users can attach near the camera or position freely.

## Functional requirements

### F05.1 — Fixed size presets

The prompter supports:

**Compact**
- Initial usable reading area: **480 × 160 pt** (width × height).
- Smaller reading area.
- Shorter visual lines.
- Designed for minimal obstruction.

**Expanded**
- Initial usable reading area: **640 × 280 pt** (width × height).
- Larger reading area.
- Longer visual lines.
- Provides additional reading context.

These dimensions exclude padding and controls, which add to the overall window size. Tune the initial dimensions during implementation for readability across supported fonts and sizes.

Default preset: Compact. Restore the saved preset on subsequent launches.

Neither preset supports freeform resizing.

Switching between presets triggers layout regeneration if the text width changes, preserving the source reading position and pausing active playback.

### F05.2 — Attached placement

Attached mode:
- Is the default placement for new installations; restore the saved placement on subsequent launches.
- Targets the built-in laptop display, even when an external monitor is configured as the primary display in macOS.
- Positions the prompter relative to the notch region when available.
- Uses top-center anchoring.
- Accounts for display geometry.
- Provides a fallback for displays without a notch.
- Avoids rendering essential text or controls underneath inaccessible hardware regions.

### F05.3 — Floating placement

Floating mode:
- Allows free movement using a designated drag region.
- Does not enable freeform resizing.
- Remembers the last valid floating position through window preferences.
- Prevents a restored window from becoming permanently inaccessible.

### F05.4 — Attach/detach behavior

- Users can switch placement from Settings, the menu bar, or the window.
- Attaching/detaching preserves script and current line.
- Position changes should animate smoothly where practical.
- The window must not accidentally initiate text scrolling during dragging.

### F05.5 — Show/hide

- Show the prompter on application launch, with an empty state when no script is loaded.
- A successful script load through UI or MCP reveals a hidden prompter without starting playback. The newly loaded session is Stopped, as defined in PRD-01.
- The window can be hidden using an in-window control.
- The menu bar can toggle visibility.
- Hiding pauses active playback.
- The reading session remains in memory.
- Reopening restores the same reading position.
- Reopening does not resume automatic playback.

### F05.6 — Window behavior

The window should:
- Use a minimal, borderless presentation.
- Remain above ordinary application windows where supported.
- Minimize unexpected application activation.
- While attached in an extended desktop, remain on the built-in laptop display across that display's Spaces, without duplicating the prompter onto external displays.
- Support eligible full-screen Spaces on the built-in display, subject to native compatibility validation.
- Run as a menu-bar-only application with no Dock icon, including when the editor or Settings window is open.

Apple's [window collection behaviors](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct) provide native Spaces and full-screen participation. Verify actual behavior on macOS 26 and multiple-display configurations before claiming compatibility; documentation alone is not runtime evidence.

### F05.7 — Multiple displays

- Validate restored window positions.
- Relocate the window when its previous display disappears.
- Recalculate attached positioning after display geometry changes.
- Preserve reading progress during display changes.

## Acceptance criteria

- Compact and Expanded modes are fixed-size.
- New installations default to Compact and Attached on the built-in laptop display.
- Launch shows an empty prompter when no script is loaded.
- Successful UI and MCP loads reveal the prompter without starting playback.
- Switching presets preserves the reading position.
- Attached and Floating placements work independently.
- The attached prompter follows the built-in display's Spaces without appearing on external displays in an extended desktop.
- Full-screen Spaces compatibility is verified and documented for tested configurations.
- The application has no Dock icon.
- Window hiding always pauses active playback.
- Closing and reopening the window does not destroy the reading session.
- Display changes do not strand the window offscreen.

## Out of scope

Arbitrary resizing, multiple teleprompter windows, custom window dimensions, and automatic eye-tracking-based positioning.

---

# PRD-06 — Screen-Sharing Privacy

**Priority:** P0 — MVP compatibility testing and disclosure

## Objective

Determine how reliably Promptly can avoid appearing in third-party screen captures and clearly communicate supported behavior.

The MVP may ship with documented limitations. Capture exclusion is not a release requirement for every application or capture mode; test and document observed behavior.

## Technical constraint

macOS does not expose a documented universal mechanism allowing a conventional third-party application to force all other capture applications to exclude its window.

Legacy `NSWindow.sharingType = .none` must not be treated as reliable protection.

An app that initiates capture may choose to exclude particular windows, but Promptly cannot generally impose this choice on unrelated capture applications.

## Functional requirements

### F06.1 — Compatibility research

Test screen-sharing visibility in:
- Zoom
- Microsoft Teams
- Google Meet
- macOS screenshot and screen-recording tools
- ScreenCaptureKit-based applications

Evaluate:
- Entire display sharing
- Individual window sharing
- Different display configurations
- Different app versions
- Relevant macOS versions

### F06.2 — Compatibility documentation

Maintain the compatibility matrix in a separate [technical research document](Research/ScreenSharingCompatibility.md), identifying:
- Tested application and version
- macOS version
- Capture mode
- Display configuration
- Observed Promptly visibility
- Known limitations
- Reproduction procedure

### F06.3 — Privacy communication

- Do not advertise universal invisibility.
- Describe tested capabilities accurately.
- Clearly disclose capture limitations in the app and documentation, including cases that are unsupported or untested.
- Keep detailed test results in the separate technical research document.
- Keep screen-capture privacy separate from ordinary window hide/show functionality.

## Acceptance criteria

- A reproducible test matrix is maintained in the separate technical research document.
- Privacy claims match observed behavior.
- Capture limitations and untested cases are clearly disclosed in the app and documentation.
- Users are not given misleading invisibility guarantees.
- Documented capture limitations do not block MVP release.

## Out of scope

DRM, universal capture prevention, interception of other applications' capture pipelines, and protection from external cameras.

---

# PRD-07 — MCP Integration

**Priority:** P0 — MVP

## Objective

Allow authorized MCP clients to manage scripts, inspect display lines, navigate playback, and read or update application preferences.

## 7.1 Integration architecture

Promptly acts as an MCP server.

External MCP-compatible clients connect to Promptly and invoke registered tools.

The MCP layer is an adapter around the same application services used by the user interface.

It must not maintain its own script, playback state, layout collection, or settings database.

## 7.2 MCP tools

### Script and playback tools

| Tool | Purpose |
|---|---|
| `promptly_set_text` | Replace active script |
| `promptly_get_lines` | Retrieve visual display lines |
| `promptly_get_current_line` | Read current line and playback state |
| `promptly_go_to_line` | Navigate to a specified visual line |
| `promptly_play` | Start or resume playback |
| `promptly_pause` | Pause playback |
| `promptly_rewind` | Stop and return to first line |
| `promptly_get_state` | Retrieve lightweight session/window state |

### Settings tools

**Confirmed:** MCP clients can read and write user preferences.

| Tool | Purpose |
|---|---|
| `promptly_get_settings` | Retrieve current configurable preferences |
| `promptly_update_settings` | Apply validated preference changes |

Total: **10 MVP MCP tools**.

## 7.3 Script tools

### F07.1 — `promptly_set_text`

Input:
- `text`: String

Behavior:
- Uses the shared PRD-01 loading rules, including the script limit, draft protection, and latest-request-wins ordering.
- Replaces the current source text.
- Generates new script and layout revisions.
- Resets playback to Stopped and shows the prompter without starting playback.
- Returns the resulting session metadata.

Output:
- Script revision
- Layout revision
- Display-line count
- Playback state

### F07.2 — `promptly_get_lines`

Inputs:
- `start_index`: Integer, optional
- `limit`: Integer, optional
- `layout_revision`: String, optional

Output:
- Layout revision
- Total line count
- Ordered line records
- Source ranges
- Pagination metadata

Line indexing is zero-based and derived from array positions; it is not stored in the display-line model. Blank lines are included in counts and pagination.

A revision may be omitted when obtaining a fresh snapshot. If provided, it must match the active layout.

Requests for previous revisions must return a structured stale-revision error rather than silently using current indexes.

### F07.3 — `promptly_get_current_line`

Returns:
- Current line index
- Current line text
- Source range
- Layout revision
- Playback state
- Total line count

If no script is loaded, the response explicitly represents the empty-session state.

### F07.4 — `promptly_go_to_line`

Inputs:
- `line_index`: Integer
- `layout_revision`: String, required

Behavior:
1. Validate revision.
2. Validate index.
3. Pause playback.
4. Set the requested line as current.
5. Update the scroll position.
6. Reset the line's playback timer.

An outdated revision must never be interpreted as a valid request against the current layout.

### F07.5 — Playback tools

`promptly_play`, `promptly_pause`, and `promptly_rewind` invoke the exact same operations used by the UI.

Play while hidden returns a structured window-hidden error and does not show the prompter.

Each successful command returns the resulting playback state and current line.

### F07.6 — `promptly_get_state`

Returns:
- Script loaded status
- Script revision
- Layout revision
- Playback state
- Current line index
- Total line count
- Window visibility
- Window size preset
- Placement mode

The response does not include the entire script.

## 7.4 Settings tools

### F07.7 — `promptly_get_settings`

Returns the current configurable preferences.

Categories:
- Window and layout
- Typography
- Playback
- Highlight positioning
- Appearance, when available

Example response structure:

```json
{
  "window": {
    "size": "compact",
    "placement": "attached"
  },
  "typography": {
    "font_family": "System",
    "font_weight": "regular",
    "font_size": 24,
    "alignment": "center",
    "text_color": "#FFFFFF"
  },
  "playback": {
    "words_per_minute": 150
  },
  "highlight": {
    "position": "center"
  }
}
```

Values above are illustrative defaults, not final UI-design decisions.

### F07.8 — `promptly_update_settings`

Allows an agent to modify supported preferences.

Example request:

```json
{
  "changes": {
    "window": {
      "size": "expanded",
      "placement": "floating"
    },
    "typography": {
      "font_size": 28
    },
    "playback": {
      "words_per_minute": 170
    }
  }
}
```

Requirements:
- Support partial updates to individual properties, including nested properties; omitted properties remain unchanged.
- Validate all supplied values against the current settings before applying changes.
- Reject unknown or unsupported keys.
- Reject out-of-range values.
- Apply updates atomically.
- Apply and persist changes through the same settings service used by the UI.
- Return the resulting preferences.

If any requested change is invalid, the entire update fails without partially modifying preferences.

### F07.9 — Settings side effects

Agent-initiated settings changes must behave exactly like user-initiated changes.

Settings updates pause active playback only when layout regeneration is required. After regeneration, playback remains paused until Play is explicitly requested.

Examples:

**Changing WPM**
- Updates playback speed.
- Does not regenerate display lines.
- Applies to the next line if playback is active.

**Changing font size**
- Pauses playback if active.
- Regenerates display lines.
- Changes the layout revision.
- Preserves the source reading position.

**Changing window size**
- Updates the window preset.
- Regenerates display lines when necessary.
- Preserves the source reading position.

**Changing text color**
- Immediately updates rendering.
- Does not change the layout revision.
- Does not interrupt playback.

**Changing reading focus position**
- Realigns the current line to Top, Center, or Bottom.
- Preserves the current line, playback state, and timing without regenerating display lines.

**Changing placement**
- Repositions the prompter.
- Does not alter layout or playback unless the effective reading width changes.

### F07.10 — MCP settings permissions

**Confirmed:** Agents have read/write access to supported application preferences.

However, security-sensitive integration controls remain user-only in the MVP.

Agents may modify:
- Window size and placement
- Font family and weight
- Font size
- Text alignment and color
- WPM
- Highlight position
- Supported appearance preferences

Agents may not modify:
- Whether MCP integration is enabled
- Client authorization or permissions
- Security/privacy acknowledgments
- Network exposure
- Application-wide destructive reset operations

This prevents an agent from changing its own security boundary.

## 7.5 Concurrency and consistency

### F07.11 — Serialized mutations

All mutations must pass through shared application services.

Potentially conflicting operations must be coordinated.

Examples:
- MCP navigation while the user changes font size.
- Agent-initiated settings updates while playback advances.
- Multiple clients attempting to replace a script.
- User rewinding while an agent requests direct navigation.

The final state must correspond to an explicit, well-defined sequence of operations.

While layout generation is pending, MCP Play and navigation commands, including Rewind, return a structured layout-in-progress error.

### F07.12 — Revision safety

MCP navigation uses visual indexes scoped to a layout revision.

An agent workflow should:

1. Retrieve lines and revision.
2. Select a target index.
3. Navigate using both index and revision.
4. Refresh the layout if the revision has changed.

Do not silently remap a stale MCP line index based on the current layout.

### F07.13 — Transport

The MVP supports local MCP integration.

Preferred architecture to investigate:
- A lightweight MCP helper using a supported local transport.
- Controlled IPC to the running macOS application.
- No remotely accessible listener by default.

Transport choice must be validated against the official Swift MCP SDK, client compatibility, sandboxing, and packaging requirements.

Local transport does not guarantee that an external MCP client processes retrieved script text on device. Clients with authorized script-reading access can retrieve text regardless of screen-sharing visibility and may process it remotely. Screen-capture exclusion must not be presented as restricting that access.

### F07.14 — Connection behavior

- Users can enable or disable MCP integration.
- Disconnecting a client does not stop playback.
- Reconnecting does not reload the script.
- MCP tools reflect the current user-visible state.
- An unavailable application returns a clear connection error.

## Acceptance criteria

- An MCP client can discover all 10 supported tools.
- Agents can load, read, navigate, and play scripts.
- Agents can retrieve and update supported preferences.
- Settings changes are reflected in SwiftUI and persisted.
- Layout-affecting agent updates generate new revisions.
- Old line revisions are rejected.
- Invalid multi-setting updates are atomic and leave preferences unchanged.
- MCP does not create a second state owner.
- Disabling MCP blocks further agent access.
- Promptly remains usable without an agent.

## Out of scope

Remote MCP access, agent-generated scripts inside Promptly, incremental text patches, per-client settings profiles, and unrestricted access to security configuration.

---

# PRD-08 — Settings & Preferences

**Priority:** P0 — MVP

## Objective

Provide centralized, persistent, immediately applicable preferences shared across the UI and authorized MCP clients.

## 8.1 Settings navigation

The Settings window uses a native macOS sidebar with the following tabs:

1. General
2. Window & Layout
3. Typography
4. Playback
5. Integrations
6. About

An Appearance tab may be introduced when advanced transitions become available.

Opening or closing Settings preserves playback state and reading position; it does not pause active playback or resume paused playback.

## 8.2 General

MVP settings:
- Restore default preferences
- Basic application behavior settings, if required

Future:
- Launch at login
- Global keyboard shortcut customization

Destructive reset actions must require user confirmation and are not available through MCP in the MVP.

## 8.3 Window & Layout

### Window size

Options:
- Compact
- Expanded

Default: Compact. Persist the selected preset.

### Placement

Options:
- Attached
- Floating

Default: Attached to the built-in laptop display. Persist placement mode and a valid last floating position.

### Reading focus

Options:
- Top
- Center
- Bottom

Default: Center.

Changing focus position updates the scroll target for the same current line without regenerating the display-line collection. Preserve playback state and timing; active playback continues.

## 8.4 Typography

### Font family

- Select from compatible installed fonts.
- Provide a readable system-font default.
- Handle unavailable fonts using a deterministic fallback.

### Font weight

- Regular
- Medium
- Semibold
- Bold

### Font size

- Adjustable within a validated range.
- Provide a usable default.
- Changes trigger layout regeneration.

### Alignment

- Leading
- Center
- Trailing

Alignment changes should not regenerate the layout when the usable line width and shaping remain unchanged.

### Text color

- Native color selection.
- Restore default.
- Immediately update visible text.

Colors should use a stable, explicitly defined persistence format suitable for MCP serialization.

## 8.5 Playback

### Reading speed

**Confirmed:** WPM only.

- Default: 150 WPM
- Initial range: 60–300 WPM
- Persist the selected value
- Apply changes from the next display line during active playback

### Manual scrolling behavior

Fixed MVP behavior:
- Manual scrolling pauses playback.
- Automatic resumption is disabled.

No user setting is needed for this behavior.

### Hide behavior

Fixed MVP behavior:
- Hiding the window pauses playback.
- Showing the window never automatically resumes playback.
- Play is unavailable while the prompter is hidden.

No user setting is needed for this behavior.

## 8.6 Integrations

MCP settings:
- Enable/disable integration
- Current integration status
- Client setup instructions
- Available tools
- Documentation link

Integration permissions are controlled through the UI, not writable through MCP.

## 8.7 About

Display:
- Application name
- Version
- Build number
- Project information
- Privacy information
- Licenses and acknowledgments

## 8.8 Persistence requirements

- Store preferences in UserDefaults.
- Use `@AppStorage` where suitable for simple UI-bound values.
- Use a shared settings service for all UI and MCP mutations.
- Ensure UI and MCP updates pass through the same validation rules.
- Use Observation to propagate changes.
- Persist only preferences and necessary window coordinates, never script content.

## 8.9 Settings update behavior

- UI and MCP submit only the properties being changed, rather than replacing settings from an older snapshot.
- The shared settings service serializes updates and preserves all unspecified properties, including siblings within nested groups.
- If valid updates modify the same property, the last update committed by the service wins. Client timestamps and asynchronous completion order do not determine precedence.
- Settings updates through UI or MCP pause active playback only when layout regeneration is required. WPM, text color, and reading focus changes preserve playback state. After regeneration, playback remains paused until Play is explicitly requested.

## 8.10 Settings change atomicity

A multi-field update must be validated before any change is committed.

The settings service must:
1. Merge the specified properties into the current settings and validate the entire proposed update before committing.
2. Determine affected subsystems.
3. Commit the new preference state.
4. Publish the change.
5. Trigger necessary layout/window/playback side effects.

Discard obsolete layout results. If a settings-triggered layout recalculation fails, preserve the previous valid layout and reading position, restore the affected settings to their previous working values, and expose the failure. Recovery must not overwrite newer settings updates. Leave playback paused.

## Acceptance criteria

- Preferences survive app restarts.
- Scripts do not survive app restarts.
- UI and MCP reflect identical settings values.
- Agent updates appear immediately in Settings.
- UI updates appear immediately through MCP.
- Opening or closing Settings preserves playback state and reading position.
- WPM, text color, and reading focus changes do not pause active playback through either UI or MCP.
- Layout-affecting settings preserve reading position.
- Invalid updates are rejected without partial persistence.
- Updates to different properties are preserved; updates to the same property follow service commit order.
- Resetting preferences does not delete the active script.
- MCP clients cannot alter protected integration/security settings.

## Out of scope

Cloud settings sync, settings profiles, per-script preferences, remote administration, and import/export of settings.

---

# PRD-09 — Advanced Visual Transitions

**Priority:** P2 — Post-MVP

## Objective

Introduce optional visual effects that improve reading focus without compromising clarity or playback synchronization.

## Potential transition modes

- None
- Opacity
- Subtle scale
- Blur

## Functional requirements

- Effects apply to current-line transitions.
- Effects must not change line geometry.
- Effects must be independently configurable.
- Rapid navigation cancels obsolete animations.
- Accessibility preferences take precedence.
- Transition changes must not regenerate the text layout.
- Once implemented, supported transition preferences may be read and changed through MCP.

## Acceptance criteria

- No text reflow is caused by transitions.
- Transitions can be fully disabled.
- Rapid Play/Pause/Navigation actions remain stable.
- Reduced Motion is respected.
- Playback and highlighted-line state remain synchronized.

## Out of scope

Character-level animation, 3D transformations, custom animation editors, and animated backgrounds.

---

# 10. Shared Architecture Requirements

## 10.1 Single reading-session authority

The reading session owns:
- Active script
- Script revision
- Display lines
- Layout revision
- Current-line index
- Playback state
- Playback timing information, including the active line's calculated duration and remaining reading time

SwiftUI views consume this state rather than maintaining independent copies.

## 10.2 Service responsibilities

**Reading Session Controller**
- Script loading
- Current-line navigation
- Session lifecycle
- Playback state coordination

**Text Layout Engine**
- Core Text segmentation
- Layout generation
- Source-range mapping
- Revision production

**Playback Engine**
- Calculate WPM-based duration when each line's reading timer starts
- Monotonic scheduling
- Pause/resume/rewind timing
- Playback completion

**Window Controller**
- Visibility
- Placement
- Size presets
- Display geometry
- Window-level behavior

**Settings Service**
- Validation
- Persistence
- Observation updates
- Serialized partial updates
- Side-effect coordination

**MCP Bridge**
- Tool registration
- Input validation
- Connection lifecycle
- Request/response mapping
- Security restrictions

## 10.3 Concurrency requirements

- Enable strict concurrency checking.
- Keep UI/AppKit state on the main actor.
- Serialize mutable session operations.
- Use concurrency-safe values across actor boundaries.
- Cancel or discard outdated layout calculations.
- Ensure only one playback scheduler is active.
- Coordinate MCP mutations and user commands.
- Avoid view-owned playback timers.

## 10.4 Error handling

Errors must be explicit and recoverable where possible.

Examples:
- No script loaded
- Invalid line index
- Stale layout revision
- Invalid preference value
- Layout generation in progress
- Prompter window hidden
- File import failure
- Layout generation failure
- MCP integration unavailable

Errors must not leave playback or settings in inconsistent intermediate states.

## 10.5 Accessibility

- Keyboard-accessible controls
- Appropriate accessibility labels
- Reduced Motion support
- Readable typography and contrast
- Predictable focus behavior
- No reliance on color alone to convey reading position

## 10.6 Privacy

- No automatic script persistence
- No mandatory accounts or cloud services
- No script content in diagnostic logs
- User-controlled MCP availability
- Protected security-sensitive settings
- Accurate documentation of screen-capture limitations

---

# 11. Implementation Roadmap

## Phase 0 — Capture compatibility research

Investigate capture visibility across supported sharing applications.

**Deliverable:** A separate technical compatibility matrix and clear disclosure of tested behavior and limitations. Capture exclusion failures do not block release when accurately documented and disclosed.

## Phase 1 — Script and layout foundation

Implement:
- Manual script input
- Source script model
- Core Text layout engine
- Display-line models
- Layout revisions
- SwiftUI rendering

**Deliverable:** A static but fully functional teleprompter reading view.

## Phase 2 — Playback

Implement:
- Line-by-line advancement
- WPM timing
- Play/Pause/Rewind
- Manual scroll interruption
- Current-line tracking
- Focus positioning
- Automatic pause on hide

**Deliverable:** Complete standalone reading experience.

## Phase 3 — Window and preferences

Implement:
- Compact and Expanded sizes
- Attached and Floating placement
- Window visibility
- Menu-bar integration
- Settings UI
- UserDefaults persistence

**Deliverable:** Native, configurable menu-bar application.

## Phase 4 — MCP

Implement:
- Local MCP transport
- Script tools
- Playback tools
- Revision-aware navigation
- Settings read/write
- Shared state integration
- Validation and mutation ordering

**Deliverable:** Agent-controllable teleprompter with consistent application state.

## Phase 5 — Stabilization and polish

Implement:
- Performance optimization
- Accessibility improvements
- Capture compatibility verification
- Animation polish
- Documentation and packaging

**Deliverable:** Public-release candidate with documented and clearly disclosed capture limitations.

---

# 12. MVP Acceptance Checklist

The MVP is functionally complete when:

- [ ] Users can paste or import scripts.
- [ ] Core Text generates accurate display lines.
- [ ] Compact and Expanded modes work.
- [ ] The prompter supports Attached and Floating placement.
- [ ] Playback advances line by line.
- [ ] Reading duration is determined by WPM.
- [ ] Play, Pause, and Rewind are reliable.
- [ ] Manual scrolling pauses playback.
- [ ] Hiding the window pauses playback.
- [ ] Showing the window preserves the position without resuming.
- [ ] Current-line highlighting remains synchronized.
- [ ] Top, Center, and Bottom focus positioning work.
- [ ] Typography preferences can be customized.
- [ ] User preferences persist across launches.
- [ ] Scripts do not persist across launches.
- [ ] MCP clients can read and replace scripts.
- [ ] MCP clients can read lines and navigate using layout revisions.
- [ ] MCP clients can control playback.
- [ ] MCP clients can read and modify supported preferences.
- [ ] UI and MCP updates remain synchronized.
- [ ] Invalid or stale MCP requests are rejected safely.
- [ ] Screen-sharing behavior has been tested and documented, with limitations clearly disclosed in the app and documentation.
- [ ] The app functions without an internet connection.

---

# 13. Future Considerations

Potential post-MVP features:

- Continuous scrolling as an alternative to line-by-line playback
- Speech-following and microphone-based synchronization
- Word-by-word highlighting
- Advanced text transitions
- PDF and DOCX import
- Script libraries and saved sessions
- Incremental script updates through MCP
- MCP state-change notifications and subscriptions
- Additional keyboard shortcuts
- Per-client MCP permissions
- Custom window presets
- Reading statistics
- Script editing during playback

These features should remain out of scope until the core reading experience and agent interoperability are stable.
