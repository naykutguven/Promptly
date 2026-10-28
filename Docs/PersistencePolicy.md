# Planned script persistence policy

**Status:** The Library feature and script persistence are not implemented. The
current prototype uses synthetic reader text and local window-placement preferences.
This document specifies requirements for the first implementation in
[roadmap milestone 2](../ROADMAP.md#2-scripts-and-safe-local-editing); it does not
record an existing script store, schema or passing persistence tests.

## Initial storage design

Define the initial durable schema, payload formats, private store location and
compatibility policy before distributing script stores. Include the
[approved Library design](LibraryDesign.md), including pin metadata, in
that initial design. No script-schema version, script-store filename, repository
executor or cache/buffer limits are selected by this document.

- Keep scripts, sections, pins and sent-copy data on device. Explicitly disable
  CloudKit in every script-store configuration, including tests and previews.
  Do not introduce a remote service, system-wide text index or content-derived
  filename.
- Give scripts stable IDs and revisions. Use one explicit, isolated persistence
  owner and exchange immutable values or IDs across isolation boundaries, never
  live SwiftData records or contexts.
- Define revision-checked writes and commit boundaries so stale saves cannot
  overwrite newer work or recreate a deleted script. Keep UI and native editing
  state on `MainActor`; expensive storage work needs an isolated owner.
- Preserve intentionally empty text and separately stored paragraph-start
  section metadata. Native editing and its coupled anchor changes must support
  coherent text undo/redo.
- Choose and test explicit bounds for text, names, sections, library queries,
  in-flight saves and retained editing state. Keep title/body search app-local,
  bounded and rebuildable from source data.
- Include the agreed `isPinned: Bool = false` script metadata field. Define
  deterministic ordering across pinned/recent groups, bounded pagination/search
  and metadata revision handling. Pin writes must not
  overwrite newer text or sections, replace a sent copy, or falsely label its
  content as changed. A duplicate starts unpinned.

Once a durable format has been introduced, later changes need versioned,
explicit migrations and representative on-disk migration/reopen tests. Preserve
IDs, revisions, text, sections, pins and sent-copy data. A renamed store file,
preference flag or atomic-write claim does not establish successful migration.
Never delete or recreate a failed store to recover from incompatibility.

## Pin metadata decision

**Agreed on 2026-10-28; implementation remains planned.** Persist
`isPinned: Bool = false` directly in the script storage model as library metadata.
No separate pin model, relationship or preference map is needed. Expose the
Boolean in immutable library summaries so grouping does not require loading
script text.

New and duplicated scripts start unpinned. A pin-only change must not alter the
script's title, text or sections, mutate the reader's sent copy, or mark content
as needing resending. Revision and query details must respect that distinction.

Include this field in the first script schema. No migration step is needed for
the as-yet-unimplemented initial schema; later durable-format changes still
follow the compatibility requirements above.

## Drafts, saves and sent copies

Implement separate ownership for the working draft, successfully saved library
revision and exact last-sent snapshot. Autosave must preserve newer edits and
represent pending, saving, saved and failed states honestly. Script switching,
duplication, deletion, normal close and quit must not silently discard unsaved
work. Define failure recovery before allowing those transitions.

An explicit Send must save and revalidate the intended script identity and
revision before committing a stable reader copy. Later library edits and pin
changes must not mutate that copy. Whether and how sent copies persist across
relaunch, including startup behavior and compatibility, remains an implementation
decision. If durable restoration is introduced, test it independently from newer
library edits; a sent copy is not full version history or a reading-position
checkpoint.

Deleting the source of a sent copy must clear the matching active reader copy.
If a stored sent copy is introduced, define an all-or-nothing deletion boundary
for that data too. A failed deletion must not publish partial state or allow a
late save to recreate deleted content. Undo during the recovery window restores
the library script, selection and pin state only; it does not resend a cleared
reader copy.

## Approved design follow-up

The approved Library design guides the first implementation. Destructive-action
recovery is available only through its live Undo toast:

- Use a default **10-second** recovery window, paused while the toast is hovered
  or keyboard-focused. Start the window after the destructive action succeeds.
- Explicitly closing the toast or reaching its timeout ends recovery for that
  operation and discards its recovery snapshot. Do not retain a session Undo
  Delete buffer, hidden menu recovery or durable Trash after dismissal.
- Apply the same lifetime to explicit section-removal recovery. Removing a
  section preserves script text; an expired removal must not be restored through
  a retained destructive-action snapshot.
- Bind Undo to the operation identity and source script. While available, it must
  preserve newer edits and must never restore into a different script or apply
  to a replacement operation. Define toast replacement and teardown so recovery
  data for each dismissed toast is discarded deterministically.
- Keep unrelated native text-editing undo/redo independent. Toast dismissal must
  not erase ordinary editing history or the anchor changes coupled to text edits.

A failed destructive operation is not a successful deletion with an Undo timer.
Preserve its draft and stored data, show actionable failure recovery, and leave
other editing history intact.

## Failure handling and future validation

Store-open, decoding, save, migration and low-storage failures must preserve the
original data for retry or recovery. Use typed failures and useful recovery;
do not reset the store, silently replace the last good save, or log private text.
Successful autosave cannot recover typing that never reached durable storage
before a crash.

The [planned acceptance checklist](ScriptEditingValidation.md#approved-design-adoption-pending)
requires initial-store creation/reopen, stale-write and deletion tests, injected
failures and later migration tests when applicable. Real low-storage, process
termination and filesystem faults require separate evidence. No such Library
or persistence validation is established by the current reader-window prototype.
