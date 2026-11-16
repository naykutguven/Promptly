# Concurrency and Playback

Read for actors and isolation, asynchronous work (script loading, layout
generation, file reading, and MCP requests), stale-result protection, the
reading session and its revisions, playback timing, navigation, manual
scrolling, reading-position preservation, and hide, sleep, and quit handling.
Follow [AGENTS.md](../../AGENTS.md), the [PRD](../PRD.md), and the
[Architecture](../Architecture.md). Read [Data and Privacy](DataAndPrivacy.md)
for load validation and MCP access, and
[Testing and Validation](TestingAndValidation.md) before verification.

## Ownership and isolation

- Preserve the compiler and concurrency baseline in AGENTS.md. Approachable
  Concurrency already enables `InferIsolatedConformances` and
  `NonisolatedNonsendingByDefault`; resolve diagnostics through explicit
  ownership rather than weakening these settings.
- The reading session, settings service, editor model, prompter window model,
  and viewport state are `@MainActor`, and their commits happen there
  (Architecture §6). Do not create a competing owner of session or settings
  state on another actor; move the expensive work off the main actor instead.
- Neither `async` nor `Task {}` leaves `MainActor`. With the current settings, a
  plain `nonisolated async` function runs on the caller's actor. Move CPU-heavy
  or blocking work, such as layout and file reading, into explicit
  `@concurrent` functions with `Sendable` inputs and results (F02.7,
  Architecture §6).
- Pass immutable `Sendable` values across isolation boundaries: source text,
  layout configurations, display lines, and session snapshots. Core Text
  objects stay inside a single layout call (Architecture §4.2).
- Actors serialize state; they do not make blocking calls nonblocking. Isolate
  unavoidable blocking work behind a narrow adapter.
- Avoid detached tasks and unchecked isolation escapes. Any necessary exception
  documents its ownership, synchronization, cancellation, and safe captures.

## Operation identity and stale results

- Every asynchronous operation has an owner, an identity, a cancellation path,
  and an applicability check after each suspension. Cancellation never replaces
  identity and revision checks (Architecture §6).
- Loads: the latest request wins across UI and MCP, whatever the completion
  order. Before committing, recheck the request identity, the layout
  configuration, and the operation phase. Clearing invalidates pending loads
  (F01.3, F01.5).
- Layout: apply only results for the latest requested configuration; cancel or
  discard the rest (F02.7). A discarded layout revision is never observable
  (Architecture §4.2).
- Commit the session as one value in one `MainActor` assignment, so observers and
  snapshots never see a partial state (Architecture §3).
- The session mints opaque, unique script and layout revisions. A line index is
  valid only within its layout revision. Reject stale revisions; never remap a
  stale index onto the current layout (F02.5, F07.12).
- One operation phase (idle, loading, recalculating) gates commands. While a
  layout is pending, Play and navigation, including manual scrolling and MCP
  navigation and Rewind, are unavailable and return typed errors
  (F02.7, F07.11, Architecture §4.1).
- Settings updates are serialized; the last committed update to a property wins.
  Side effects run in the commit's `MainActor` turn, so a layout-affecting
  change pauses playback and enters recalculation before the next command
  (PRD-08 §8.8, Architecture §4.4).
- After an MCP request suspends, recheck enablement and the same-user boundary
  before disclosing or mutating. Disabling MCP invalidates in-flight requests
  (Architecture §4.8).
- Bound task counts, queues, file reads, layout input, in-flight MCP requests,
  transport frames, and responses (Architecture §6). Streams need an explicit
  buffering policy and termination cleanup. Continuations resume exactly once,
  including in callback and cancellation races.
- Remove observers and callbacks symmetrically. Repeated activation must not
  install duplicate handlers or leave tasks running after their owner closes.
  On quit, stop the scheduler and close MCP connections.

## Playback model

- Playback advances one display line at a time; it never scrolls continuously
  at a pixel velocity (PRD-03 §3.1). The session owns the current-line index,
  the four playback states (Stopped, Playing, Paused, Completed), and the active
  line's timing. Loading, recalculation, and scroll transitions are operation
  state, not playback states (PRD §10.1, Architecture §4.1).
- The playback engine inside the session runs at most one scheduler task, built
  on Swift concurrency with an injected monotonic clock. Views own no timers
  (F03.5, PRD §10.3, Architecture §4.3).
- Each cycle: make a line current, publish a scroll request with a fresh
  transition token, and start the line's timer only when the viewport reports
  completion with a token that is still current while Playing. Any superseding
  command invalidates the token, so a late completion never starts playback
  (F03.5, Architecture §4.3).
- Compute a line's duration when its timer starts, from the current WPM, using
  the Domain duration policy (F03.4). Store it in the session's timing state,
  never in display lines. A WPM change applies from the next line and never
  regenerates layout (F03.6).
- Schedule against monotonic deadlines rather than counting timer callbacks,
  so long scripts accumulate no drift. Scroll transitions add to elapsed time
  and never consume reading time (F03.5).
- Pause keeps the current line and its remaining time, and repeated Pause is
  harmless; Play resumes only the remaining time. Play while Playing does
  nothing, and Play from Completed restarts at line 0. Rewind returns to line 0,
  resets timing, sets Stopped, and never starts playback (F03.1–F03.3, F03.10).
- Navigation behaves identically from the UI and MCP: validate the revision and
  index, pause, set the line, request the scroll, and reset that line's timer
  (F03.8, F07.4).
- Manual scrolling: detect user scrolling from a native interaction signal, not
  offset changes. Pause and cancel the pending advance as soon as it starts. The
  settled line becomes current and gets its full duration on the next Play, even
  if it did not change. Programmatic scrolling never pauses (F03.7,
  Architecture §4.5). The detection signal is an open decision
  (Architecture §10).
- Hiding pauses Playing and preserves any other state. Showing never resumes,
  and Play is rejected while hidden (F03.1, F03.9).
- System sleep pauses playback and cancels pending advances while keeping the
  remaining time. Wake never resumes or skips unread lines (F03.11). App
  forwards sleep to the session (Architecture §4.3); the clock choice is an open
  decision (Architecture §10).
- Changing the focus position, text color, or WPM, opening Settings, and
  disconnecting an MCP client do not interrupt playback (F04.3, F07.9, F07.14,
  PRD-08 §8.1).

## Layout and reading position

- Regenerate layout only for the triggers in F02.4. Text color, WPM,
  highlighting, playback state, visibility, and placement do not trigger it.
  Implementation details are in [Line Layout Engine](../LineLayoutEngine.md).
- On regeneration, capture the current line's source position, pause if
  Playing, generate, map to the containing or nearest line, restore the scroll
  position, and leave playback paused. Never jump back to the start (F02.6).
  The anchor is a UTF-16 offset in the current script revision, and mapping is a
  pure Domain policy (Architecture §4.2).
- Keep the previous layout visible with its own stored configuration while a
  new one is computed (F02.7, Architecture §4.2).
- If layout fails, keep the previous layout, text, and position. Revert the
  settings that caused it only where they still hold the failed value, so newer
  updates survive, and stay paused (F02.9, PRD-08 §8.9).
- Keep per-advance work small. A line advance must not trigger layout,
  persistence, or invalidation of unrelated views. When nothing is Playing, no
  scheduler work runs.

Test transitions, reentrancy, stale results, cancellation, teardown, repeated
commands, reflow anchors, and bounded work, using an injected clock and layout
function. Run targeted Thread Sanitizer checks for relevant concurrency changes;
a passing sanitizer does not prove thread safety.
