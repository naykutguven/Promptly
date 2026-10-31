# Approved Library design

**Status:** Quiet Native visuals approved on 2026-10-31, superseding the earlier
Native visuals approved on 2026-10-27. The recovery policy revised on 2026-10-28
is unchanged. The [shared Library and reader baseline](QuietNativeDesign.md)
records the approved versions, final refinements and frozen images.
The Library must be implemented from scratch in
[roadmap milestone 2](../ROADMAP.md#2-scripts-and-safe-local-editing). No Library
window, script editor/store or native Library test suite currently exists.
The [README's current implementation](../README.md#current-implementation)
describes the reader-window prototype; the
[Library acceptance checklist](ScriptEditingValidation.md) is prospective.

## Visual baseline

Library is the complete script workspace: managing, editing and sectioning
scripts before sending them to the reader. The sidebar is one part of this
feature, not a separate destination from its editor.

The approved direction is Quiet Native: a restrained macOS window, a quiet Library
sidebar, a spacious plain-text editor, and a compact, collapsible Sections
inspector. Use native controls, system typography, semantic colors, and accessible
hit areas. The images establish layout and hierarchy rather than fixed pixel
geometry or a custom replacement for native window chrome.

### Active script

![Approved Quiet Native active-script mockup](Design/QuietNative/2026-10-31/LibraryActive.jpg)

### Empty library

![Approved Quiet Native empty-library mockup](Design/QuietNative/2026-10-31/LibraryEmpty.jpg)

These are synthetic browser mockups, not screenshots or validation of the macOS
app. The [approval record](QuietNativeDesign.md) freezes the current visuals
independently of the mutable Superdesign canvas and records their versions.
Earlier [Native active v6](Design/Library/Active-v6.png) and
[empty v7](Design/Library/EmptyLibrary-v7.png) images remain unchanged as historical
references. Canvas review controls are not product UI. The interaction and
recovery contracts below remain authoritative, including the 10-second Undo window.

## Shared chrome and state

- Use **Library** as the sidebar heading. Omit repeated app/feature toolbar
  labels and the YOUR SCRIPT label above the title. Provide a meaningful
  accessible window name and the planned **Show Library** menu command.
- Keep library/inspector controls and one primary **Send to Prompter** button.
  Show **⌘↵** inside that button in place of the arrow, with a normal trailing
  window inset. Expose its keyboard shortcut separately from its accessible name.
- Omit an editor footer, its divider and reserved height, including Plain text
  and the repeated Send label/shortcut. Keep comfortable text padding and the
  caret reachable when feedback is visible.
- Omit the old active sidebar's disk/On this Mac/script-count footer. Keep local
  save status near the document title. Use SF Symbols, accent-colored `pin.fill`
  indicators and proportional system-font section numbers as specified in the
  [shared visual baseline](QuietNativeDesign.md).
- Present saved, pending, saving, and failed-save states honestly near the
  document title. **Saved on this Mac** describes local storage. **Edits since
  last send** applies only when this script has a sent copy with newer library
  edits; a first script has no sent-version hint. Save failures remain actionable
  with Retry Save and must not disappear as transient success feedback.
- Implement the planned Library/reader lifecycle. Send saves an exact
  revision, closes the Library only after a successful handoff, and shows the
  reader without automatic movement. Pinning, renaming, and autosave do not send.

## Library rows

Show **Pinned** above **Recently used**, omitting empty groups and avoiding a
second copy of pinned scripts in the recent group. Keep a clear selected row and
a small pin indicator on pinned scripts. Search covers titles and body text in
both groups.

| Intent | Approved interaction |
| --- | --- |
| Duplicate or delete | A short left swipe reveals separate, icon-only circular Duplicate and Delete controls on a neutral row background. Duplicate is neutral gray; Delete is red. |
| Full-left delete | A deliberate full left swipe commits Delete on completion/release. Reversing before release can cancel the action. Use the time-limited Undo toast rather than a confirmation dialog. |
| Pin or unpin | A right swipe reveals an accent-colored circular Pin/Unpin control. A deliberate full right swipe can commit it. |
| Gesture alternatives | The row context menu and accessible menu/keyboard actions provide Pin/Unpin, Duplicate, and Delete. Trackpad swipes are an enhancement, not the only way to manage a script. |

Every action targets the row's stable script ID, including an unselected row.
Pin/unpin retains the current selection, draft and editor context. Duplicate opens
an independent, unpinned copy. Undo through the active toast restores the library
script and its pin state; it does not restore or resend a cleared reader copy.
That recovery ends when the toast is closed or expires.

Pins are local library metadata, stored as `isPinned: Bool = false` directly in
the script storage model and exposed in library summaries. A separate pin model
is not needed. This [agreed metadata decision](PersistencePolicy.md#pin-metadata-decision)
belongs in the first script schema; storage is not implemented yet. Revision
treatment, deterministic ordering and bounded pagination/search remain
implementation work. Pin-only changes do not alter script content or sent-version
status. The mockup's circular dimensions, swipe thresholds and animations
do not establish native trackpad behavior; tune and validate them on macOS with
accessible target sizes and Reduce Motion.

## Compact section outline

Keep section names as separately stored paragraph-start metadata. Do not turn
them into headings inserted into the script or add a rich-text toolbar.

| Intent | Approved interaction |
| --- | --- |
| Jump | Single-click a section to move the editor to its paragraph. |
| Rename | Double-click the name for inline editing, selecting the full name. Return on a focused outline row also begins renaming; F2 may be an additional shortcut where available. |
| Finish naming | Return saves, Escape restores the previous name, and clicking elsewhere saves. An empty name retains the previous value rather than removing the section. Respect composition and define bounded name validation during implementation. |
| Browse by keyboard | Up/Down and Home/End move outline focus; Space jumps to the focused section. Keep these handlers scoped to the outline so normal editor typing is unaffected. |
| Add | The + control uses the last editor cursor's paragraph and immediately opens the new name for editing. At an existing boundary, rename that section instead of creating a duplicate. |
| Remove | The context menu offers Rename and Remove Section. Removal changes metadata only, preserves script text, and offers recovery through its active Undo toast. |

Highlight the section containing the editor cursor, retaining stronger name
weight and a distinguishable keyboard-focus treatment. There is **no leading
marker** in addition to the highlight. Browsing outline focus does not move the
editor until a jump is requested. Keep rows stable between single and double
clicks; renaming must not require delayed normal navigation.

Use a quiet section count and **Double-click a section to rename it.** guidance
when sections exist. With no sections, show **Place the cursor in a paragraph,
then add a section.** and omit the zero count and rename guidance. Keep names and
boundaries through script switches, and keep text edits and their affected
boundaries coherent through native undo/redo. Recovery for an explicit destructive
removal follows the toast window below. Do not add permanent edit or remove
buttons to every row, or drag reordering that implies moving paragraphs.

## Empty, first-script and search states

| State | Presentation and behavior |
| --- | --- |
| Ready, genuinely empty library | Sidebar: Library, compose action, disabled search and **No scripts yet.** Hide Pinned/Recently used headings and the zero script count. Main area: a small document symbol, **Your next idea starts here**, **Create a script to start preparing.**, and **Create a Script · ⌘N**. Hide Sections; disable its toggle and Send in their usual toolbar positions. Show no save/sent-version status without a document. |
| Create the first script | Open the normal editor, select the **Untitled Script** title for naming, and show **Start writing your script…** as a body placeholder. Enable search and Send, and restore the inspector according to its visibility preference. A blank script is valid and sendable. Show no last-sent hint before its first Send. |
| No search matches | Show **No matching scripts.** and **Clear Search** in the sidebar. Keep the current script and editor visible. Clear Search restores results and returns focus to search. This is not an empty library. |
| Delete the last script | Return to the same empty-library screen after deletion succeeds, with the Undo toast. While it is active, Undo restores the script and selection without claiming that its sent copy was restored. Closing or expiring the toast ends that recovery. |
| Loading or failure | Use the real loading, failed-open, failed-save and retry states. An unavailable or failed library is not an empty library and must never offer a reset disguised as recovery. |

Create a Script and the sidebar compose action share the New Script intent and
**⌘N** command. Disabled controls are skipped by keyboard focus. Keep the empty
state to one primary action; import/export, AI suggestions, accounts and other
onboarding actions are outside this approved change.

## Undo feedback and recovery

Use a nonblocking toast with concise feedback, **Undo**, and a close control.
The default lifetime is **10 seconds**, paused while hovered or keyboard-focused;
the user can close it sooner. Announce the result once and avoid covering the
caret or trapping focus.

The toast is the recovery window. Explicit dismissal or timeout is final: discard
that operation's recovery snapshot and disable its Undo action. Do not retain a
hidden session Undo Delete history, a post-dismissal recovery command or a durable
Trash. A later toast must not resurrect an expired operation, apply Undo to the
wrong action or overwrite newer section edits. Keep unrelated native editing
undo independent of this destructive-action recovery policy.

Implement save-before-delete and failure recovery. If deletion clears a sent copy,
make that consequence understandable: Undo restores the library only. Keep
persistent data-safety failures and Retry Save distinct from transient toasts.

## Adoption and validation

Build the Library from scratch in
[milestone 2](../ROADMAP.md#2-scripts-and-safe-local-editing). Planned ownership is
described in [Architecture](Architecture.md#approved-library-design-adoption);
script/pin storage must follow the planned initial-store policy. There is no new
permission, network, dependency, platform, import/export or automatic-playback scope.

The [planned acceptance matrix](ScriptEditingValidation.md#approved-design-adoption-pending)
defines the first implementation's validation. Browser mockup approval and interaction
checks do not establish native gesture fidelity, VoiceOver, minimum-OS support,
persistence migration or reader-window compatibility.
