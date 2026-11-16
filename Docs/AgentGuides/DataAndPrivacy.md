# Data and Privacy

Read for script entry, file import, loading and clearing the active script,
editor drafts, input limits, memory-only scripts, preferences and their
persistence, logging and diagnostics, and MCP access scope and enablement.
Follow [AGENTS.md](../../AGENTS.md); the [PRD](../PRD.md) defines behavior and
the [Architecture](../Architecture.md) defines ownership. Read
[Concurrency and Playback](ConcurrencyAndPlayback.md) for asynchronous loading
and [Testing and Validation](TestingAndValidation.md) before verification.

## Scripts stay in memory

- The active script, editor drafts, display lines, revisions, reading position,
  and playback state exist only in memory (F01.4, Architecture §7). Restarting
  starts with no script; normal termination discards the session.
- Never write script or draft text to UserDefaults, `@AppStorage`,
  `@SceneStorage`, files, caches, or any other store. Avoid native features
  that keep text implicitly, such as document-based scenes with autosave and
  versions, restoration of editor contents, and Spotlight, Handoff, or other
  `NSUserActivity` publishing.
- Do not claim secure erasure or protection from memory snapshots and crash
  dumps; the MVP does not promise either (F01.4).
- Keep script text, imported file paths, and values derived from script text out
  of logs, diagnostics, analytics, identifiers, accessibility identifiers, and
  filenames. `Logger` privacy redaction is not an exemption. Log counts,
  revisions, and error categories instead.
- Revisions are opaque and unique. Generate them randomly or from counters,
  never by hashing content (Architecture §4.1, §7).
- Use synthetic text in tests, previews, screenshots, fixtures, and issue
  evidence.

## Loading, replacing, and clearing

- Every source (the editor, an import reviewed in the editor, and MCP) uses the
  same load operation on the reading session (F01.3, F07.1). Do not add a
  second path that commits text differently.
- Validate before preparing anything: reject whitespace-only text (F01.1) and
  text over 100,000 user-perceived characters (F01.7). Rejection never truncates
  and never changes the active session or the editor draft.
- The latest load request wins across UI and MCP, regardless of completion
  order. Clearing the script invalidates pending loads (F01.3, F01.5).
- A failed or superseded load keeps the previous valid session and leaves the
  draft available (F01.1, F01.3).
- Replacing or clearing the active script needs no confirmation (F01.5).

## Editor drafts

- The editor model owns the draft, its edit revision, and the unfinished-edit
  flag. The draft is the only sanctioned copy of script text outside the
  session, and it never reaches the session, MCP, or logs until the user
  chooses **Load into Prompter** (F01.6, F07.15, Architecture §3, §4.6).
- When the active script changes or is cleared, update an open editor only if
  it has no unfinished edits; otherwise keep the draft and offer **Use Active
  Script** (F01.6).
- Confirm before discarding unfinished edits on import, **Use Active Script**,
  editor close, and application quit. Cancelling keeps the draft (F01.6).
- After a successful load from the editor, close it only if the draft has not
  changed since submission (F01.1, Architecture §4.6).

## File import

- Use the standard macOS open panel. Accept only `.txt` and `.md`; read `.md` as
  literal plain text without parsing or rendering Markdown (F01.2).
- The app is sandboxed with read-only access to user-selected files. Do not
  request write access, and never modify the original file (F01.2). Balance
  security-scoped access deterministically, including on failure and
  cancellation.
- Read files in `Services/Files/` off the main actor (Architecture §4.6, §6).
  Enforce the 1,000,000-byte file limit on import, without reading an unbounded
  file into memory (F01.7). Decode UTF-8 strictly; do not substitute
  replacement characters for invalid bytes. Preserve paragraph boundaries.
- A file within the byte limit opens in the editor even when its text exceeds
  the 100,000-character script limit, so the user can shorten it. The editor
  indicates when its text is over the limit, and loading enforces it (F01.7).
- Report unreadable, unsupported, oversized, and invalid-encoding files with
  understandable errors that leave the draft and session unchanged (F01.2,
  PRD §10.4).
- An import result replaces the editor draft for review, after any discard
  confirmation. It never goes straight to the session (Architecture §4.6).
- Do not keep the file path after reading. Do not create security-scoped
  bookmarks or recent-document entries for imported files, because both
  persist paths (F01.4).

## Preferences

- Persist preferences in UserDefaults through the settings service, the only
  owner of preferences, defaults, validation, and coding (PRD-08 §8.7,
  Architecture §4.4).
- All UI and MCP changes go through one mutation entry point that takes a
  partial update and its origin. It merges, validates the whole result, commits
  atomically, persists, and publishes. Invalid updates change nothing; the last
  committed update to a property wins (PRD-08 §8.8–§8.9, F07.8).
- Agent-origin updates cannot change protected settings: MCP enablement,
  authorization policy, security or privacy acknowledgments, network exposure,
  or Restore All Defaults (F07.10).
- `@AppStorage` is for view-local UI state, such as the selected Settings
  section. It must not write a shared preference around the service
  (Architecture §4.4).
- Use stable, explicit stored formats. Text color must serialize the same way
  for storage and MCP (PRD-08 §8.2). Read stored values through the same
  validation; an unavailable font uses the deterministic fallback (PRD-08 §8.2).
- Changing a stored key or format affects persistence compatibility; ask before
  doing it (AGENTS.md §7).
- Persist only preferences. Promptly stores no window coordinates: macOS
  restores the prompter frame across launches, and the window model keeps the
  last floating position in memory for detaching within a launch (F05.3,
  PRD-08 §8.2, §8.7).
- Restore All Defaults resets every preference, discards the remembered floating
  position, and disables MCP. It keeps the active script, drafts, and reading
  position (PRD-08 §8.6).
- The preferences are exactly those PRD-08 defines. Do not add others, such as
  appearance options, without a requirement. Settings import and export, cloud
  sync, profiles, and per-script preferences are out of scope (PRD-08).

## MCP access boundary

- MCP is disabled by default. Only the user enables or disables it, in
  Settings (F07.10, F07.14, PRD-08 §8.4).
- Transport is local `stdio` with no network listener. Any helper-to-app
  communication is secured and enforces the same macOS user boundary (F07.13).
  The process layout and IPC mechanism are undecided; see the
  [MCP SDK evaluation](../Research/MCPSwiftSDKEvaluation.md). Add no dependency,
  target, or entitlement before that decision (Architecture §4.8).
- Enforce enablement and the same-user boundary inside the app, at the service
  boundary. Recheck both after every suspension before disclosing content or
  mutating state. Disabling MCP invalidates in-flight requests (F07.15,
  Architecture §4.8).
- While enabled, any same-user local client may use all ten MVP tools without
  per-client approval. Script access covers the active script and later
  replacements. Unfinished editor drafts are never exposed (F07.15).
- The MCP bridge owns no script, layout, playback, or preference state. It calls
  session and settings operations with the agent origin and applies the same
  validation, limits, and load path as the UI (PRD-07 §7.1, F07.11).
  `promptly_get_state` never returns the script text (F07.6).
- When the user enables MCP, explain the access scope and that clients may
  process retrieved text remotely even though transport is local. Do not
  present screen-capture exclusion as limiting MCP access (F07.13, F07.15).
- Per-client permissions, remote access, and incremental text patches are out of
  scope (PRD-07).

## Privacy claims

- Never claim universal screen-sharing invisibility. Report only verified
  capture behavior and disclose unsupported or untested cases (PRD-06). See
  [UI and Accessibility](UIAndAccessibility.md) for the window side and the
  [compatibility research](../Research/ScreenSharingCompatibility.md) for
  evidence.
- Add no accounts, analytics, cloud services, or automatic uploads (F01.4,
  PRD §10.6).
