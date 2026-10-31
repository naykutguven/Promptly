# Planned script editing validation

**Status:** The Library feature, script persistence and their native tests are not
implemented. The feature will be built from scratch in
[roadmap milestone 2](../ROADMAP.md#2-scripts-and-safe-local-editing), using the
[approved Library design](LibraryDesign.md). This is an acceptance plan,
not evidence of a completed or partially implemented Library feature.

The current source contains the reader-window prototype with synthetic text and
window-placement preferences. Its [window validation record](WindowBehaviorValidation.md)
and [coverage report](SourceCoverage.md) are separate evidence; they do not
validate script editing, storage, sent-copy handoff or scrolling.

## Evidence status

| Area | Status |
| --- | --- |
| Active and empty-library mockups | Quiet Native approved on 2026-10-31; frozen synthetic references and versions are in QuietNativeDesign.md and linked from LibraryDesign.md |
| Native Library implementation | Not implemented |
| Script storage and initial schema | Not implemented; design and compatibility policy remain to be defined |
| Library unit, AppKit and UI tests | Not implemented; no passing Library test counts are claimed |
| Native gestures, accessibility and minimum-OS behavior | Not validated for the Library |

Use synthetic scripts in every future test, screenshot and diagnostic. Follow
[Testing and Validation](AgentGuides/TestingAndValidation.md) and the
[planned persistence policy](PersistencePolicy.md). Record the actual compiler,
SDK, runtime, target/configuration and hardware with each result. A newer host
alone does not establish minimum macOS 26.0 compatibility.

## Approved design adoption pending

All acceptance items below are pending. Browser-prototype interaction checks
and design approval establish the intended experience, not native behavior,
data preservation, migration compatibility or coverage of code that is absent.

| Journey | Required acceptance | Native status |
| --- | --- | --- |
| Empty library → first script | Show the approved empty copy only for a successfully loaded empty library. Disable search/Send/section toggle, hide Sections and save/version hints, then select the new title on Create or ⌘N. A blank script remains valid and sendable. | Pending |
| No-match search → recovery | Preserve the selected editor and its text when no rows match. Clear Search restores results and search focus; loading/failure cannot masquerade as an empty library. | Pending |
| Editing and autosave | Native selection, paste, marked-text composition, title editing and undo/redo work. Pending/saving/saved/failure states are honest; rapid script switches, close and quit cannot discard newer work. | Pending |
| Row actions and selection | Circular controls and full left/right swipes target the row's stable ID. Reversal/vertical movement do not delete accidentally; completion commits once. Context-menu, keyboard and VoiceOver alternatives work without replacing another script's unsaved draft. Duplicate opens an independent unpinned copy. | Pending |
| Pins, queries and reopen | Validate the initial script model's `isPinned: Bool = false` metadata and its library-summary projection. New/duplicate scripts start unpinned; pin state survives reopen without changing content or sent-version status. Pinned/recent grouping has no duplicate rows and preserves selection. Validate deterministic ordering, bounded queries and search across both groups. | Pending |
| Last-script delete → empty → Undo | Finish saving before deletion; return to the empty screen only on success. Undo through the live toast restores selection and pin state in the library. A cleared sent copy stays cleared. A failed save leaves the draft and recovery UI intact. | Pending |
| Inline section naming and navigation | Single-click jump and double-click naming coexist. Return/Escape/blur, empty/invalid names, composition, row keys and focus changes preserve names and normal editor behavior. Highlight follows the editor cursor without a leading marker or forced outline focus. | Pending |
| Section edits and explicit removal | Add uses the last cursor's paragraph and opens naming without duplicate boundaries. Explicit Remove preserves script text and offers toast-limited recovery. Text edits and their coupled anchor changes retain coherent native undo/redo; switching scripts must preserve names and anchors. | Pending |
| Toast lifetime and final dismissal | Inject time to check the 10-second window, hover/focus pause, explicit close, expiry, replacement and teardown. Close or expiry discards that operation's recovery data; no session Undo Delete/menu fallback remains. Undo must not target a later operation or wrong script, and unrelated native editing undo remains intact. | Pending |
| Initial storage and failure recovery | Define schema/payload formats and bounds, then test isolated initial-store creation/reopen, revision-checked saves, late saves after deletion and injected failures. Test later migrations when a durable format exists. Failed open/save/migration must not reset the store or overwrite newer work. | Pending |
| Save/send and reader handoff | First scripts have no sent-version hint; local save, newer edits and explicit Send are distinct. Pin-only edits do not mislabel sent content. ⌘↵ works in relevant editing contexts; verify stable sent copies, handoff cancellation/failure, reader visibility coordination and any explicitly chosen restoration policy. | Pending |
| Native appearance and accessibility | Validate real macOS trackpad gestures, keyboard-only use, VoiceOver, long/localized names, Light/Dark, contrast/reduced effects and minimum macOS 26.0. Browser checks and mockup pixels are not native compatibility evidence. | Pending |

## Planned manual acceptance journey

Run this journey once the native feature and isolated test stores exist:

1. Show Library with a ready, empty synthetic library. Verify the approved
   copy, Create action, disabled controls, focus order and hidden inspector.
   Repeat failed-open/loading states and confirm neither looks like an empty
   library or offers a destructive store reset.
2. Create a script. Check title focus, the blank body placeholder and valid empty
   text. Enter synthetic content; exercise selection, paste, native undo/redo,
   composition and immediate switching between documents.
3. Add and name paragraph sections. Test single-click jump, double-click rename,
   Return/Escape/blur and keyboard outline navigation. Edit text before and
   across boundaries, then undo the text edit and verify its coupled anchors.
4. Pin, unpin and duplicate rows, including unselected rows. Search titles and
   body text, clear a no-match query, and reopen the library to verify the chosen
   pin/query ordering policy and saved content.
5. Delete a script and use Undo while its toast remains active. Repeat with the
   final library script and verify the empty screen, restored selection and pin
   state. If it was sent, Undo must restore the library without resending.
6. Repeat deletion, allow the 10-second unpaused interval to expire, and verify
   recovery data is discarded and no hidden Undo Delete command remains. Repeat
   with immediate explicit close, hover/focus pause and a replacement toast.
7. Explicitly remove a section, then test live-toast Undo and final dismissal.
   Script text must remain intact. Expired destructive recovery must not revive
   through a retained snapshot, and unrelated native text undo must still work.
8. Send, show the Library again and make newer edits. Verify the reader keeps its
   exact sent copy until another explicit Send. Once a restoration policy is
   chosen, test any relaunch behavior separately from newer library edits and
   pin-only changes; do not infer it from an in-memory reader copy.
9. Exercise save/send cancellation, stale results and injected storage failures.
   Confirm useful retry, intact drafts and last good saves, and safe close/quit
   behavior. Record real low-storage and abrupt-termination checks separately.
10. Validate keyboard, menus, VoiceOver, focus, long/translated names and reduced
    effects on supported Macs. Repeat relevant window-placement and presenting-
    app focus checks from the window validation record.

## Recording future results

For each implemented slice, record the date, exact tools/commands, destination,
configuration, test selection, results and remaining limitations. Build the app
and affected test targets, then validate at the lowest reliable layer. Keep
native UI/accessibility and real failure-environment checks distinct from logic
or injected-failure coverage.

Do not reuse Library test counts or implementation evidence from removed
code. No new native build or test result is claimed by this documentation reset.
