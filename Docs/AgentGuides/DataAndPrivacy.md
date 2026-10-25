# Data and Privacy

Read for SwiftData, autosave, script files, search, import/export, deletion,
generated sections, or future MCP access. Follow [AGENTS.md](../../AGENTS.md);
read [Concurrency and Playback](ConcurrencyAndPlayback.md) for asynchronous
ownership and [Testing and Validation](TestingAndValidation.md) before verification.

## Local persistence and edits

- The app's `ModelConfiguration` explicitly sets `cloudKitDatabase: .none`.
  Preserve that boundary for every script-store configuration, including tests
  and previews. Capabilities alone never authorize data transfer.
- Give scripts stable IDs and revisions. Persistence writes have one isolated
  owner; pass IDs or immutable snapshots across isolation boundaries.
- Use `@AppStorage` for preferences, not script storage or secrets. Keep script text
  out of logs, diagnostics, and content-derived filenames. Publishing scripts to
  system-wide indexes requires an explicit product/privacy decision.
- Autosave must preserve newer edits, undo/redo behavior, and ordering across
  concurrent saves or windows. Represent pending and failed saves honestly, and
  define how unsaved work survives closing or quitting.
- Store-open, save, migration, and low-storage failures preserve the original
  data for retry or recovery. Never silently reset a store or replace the last
  good script with partial work.
- Before distributing durable stores, define schema versions and migration
  policy. Later schema changes require representative on-disk migration/reopen
  tests that preserve IDs, text, sections, and reading anchors.
- Page or batch large libraries and bound script parsing, search, and in-flight
  saves. Keep indexes rebuildable from source data and update them after edits
  and deletion.

## Files, import, export, and deletion

- Import/export formats are undecided in the README. Define the supported formats
  and compatibility policy when that feature is requested.
- Use user-selected file access and sandbox/security-scoped access where required;
  release access deterministically. Do not assume access to the user's filesystem.
- Current user-selected file access is read-only. Review the write-access
  requirements when implementing export; request only the access that feature needs.
- Validate encoding, size, structure, and section references before applying an
  import. Preserve the current script until replacement commits; never silently
  merge, overwrite, or discard edits.
- Export a consistent snapshot. Stage and validate output before publication,
  preserve an existing destination on failure, and clean temporary files after
  success, failure, and cancellation. Test with an independent reader.
- For work spanning files and SwiftData, define ordering, staging, commit point,
  retry identity, compensation, and repeatable crash cleanup; they are not one
  atomic transaction. Handle actual write/save failures, including low storage.
- Deletion must cover associated metadata, search data, derived suggestions, and
  pending work without allowing a late result to recreate deleted content.

## Generated sections

- Treat model output as untrusted suggestions. Bound input/output and validate
  structure, section ranges, ordering, duplicates, and source ID/revision before
  display or save. Never invent a framework model version.
- User acceptance is the commit boundary. Suggestions must not rewrite script
  text or silently replace manual sections; source edits invalidate stale work.
- Check on-device model availability and explain the reported state. Refusal,
  missing assets, malformed output, cancellation, or failure leaves manual
  editing and the last good script intact. Do not add a remote fallback.

## Future MCP boundary

- MCP is planned, not implemented. Prefer the README's stdio helper with XPC or
  a Unix domain socket; do not introduce a network-facing script API.
- Enforce separate read, create/edit, and playback permissions at the service
  boundary, scoped to explicitly authorized scripts rather than the whole library.
  Define caller authorization and revocation before exposing content or actions.
- Explain that an external agent may process retrieved text remotely even though
  Promptly's transport is local. Treat agent edits as untrusted, revision-checked
  input that must preserve newer user work and support recovery.
