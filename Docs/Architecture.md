# Architecture and Source Layout

This is a living map of Promptly's code ownership and intended destinations.
[AGENTS.md](../AGENTS.md), the [README](../README.md), and the
[task guides](../AGENTS.md#task-guides) remain authoritative. Planned paths follow
the [roadmap](../ROADMAP.md); they do not authorize adjacent features, new
dependencies, permissions, or changes to privacy boundaries.

## Ownership and dependencies

| Layer | Owns | Keeps elsewhere |
| --- | --- | --- |
| `App` | Composition, lifecycle, scenes, app-wide commands, and window presentation coordination | Feature business rules and framework implementation details |
| `Features` | SwiftUI views, `@MainActor` presentation state, user intents, and feature-local UI adapters | Persistence contexts, file transactions, and inference sessions |
| `Domain` | Identities, immutable snapshots, state machines, and shared policies | SwiftUI views, SwiftData records, and framework adapters |
| `Services` | Framework capabilities, explicit state owners, persistence, files, and long operations | Concrete feature views and feature navigation |
| `DesignSystem` | Reused app-specific visuals and semantic style tokens | Feature workflows, script settings, and business policy |
| `Extensions` | Focused extensions to native Swift and Apple types | General-purpose helper collections |

`App` composes features and services. Features depend on domain values and
injected capabilities; services depend on domain contracts, never feature views.
The composition root creates long-lived services once. Introduce protocols where
a consumer needs substitution, beside the owning contract rather than in a
generic `Protocols/` folder.

Folder placement does not establish isolation. AppKit windows, focus, and SwiftUI
presentation stay on `MainActor`; persistence and expensive work have explicit
isolated owners. Pass stable IDs or immutable `Sendable` snapshots across actors.
Domain values may use Foundation and CoreGraphics value types without depending
on UI or persistence frameworks.

## Current source snapshot

The application currently implements the first window-behavior prototype with
synthetic text and local UserDefaults placement preferences. The Library feature,
SwiftData storage, and scrolling are not implemented.

```text
Promptly/
├── App/
│   ├── PromptlyApp.swift
│   └── PromptlyAppDelegate.swift
├── Domain/
│   ├── DisplayGeometry.swift
│   ├── ReaderWindowLayout.swift
│   └── ReaderWindowState.swift
├── Features/Reader/
│   ├── ReaderDragHandle.swift
│   ├── ReaderMenu.swift
│   └── ReaderView.swift
├── Services/Windowing/
│   ├── ReaderHostingView.swift
│   ├── ReaderPanel.swift
│   ├── ReaderWindowController.swift
│   └── ReaderWindowPreferences.swift
├── Extensions/
│   └── NSScreen+Extensions.swift
└── Assets.xcassets/
```

`PromptlyAppDelegate` currently supplies the composition root: it creates the
window controller and injects the hosted `ReaderView` through `setContent(NSView)`.
The controller manages panel mechanics without constructing a feature view.
`ReaderDragHandle` is a reader-local AppKit bridge and stays with that feature.
`App/PromptlyApp.swift` composes the menu-bar scene, including the app-wide Quit
command; `ReaderMenu` supplies reader commands and preference warnings. A separate
composition type is not required for the present scale.

Unit/AppKit tests mirror `Domain/` and `Services/Windowing/` under `PromptlyTests/`.
`PromptlyUITests/ReaderWindowUITests.swift` covers reader journeys. See the
[window validation record](WindowBehaviorValidation.md) and
[coverage report](SourceCoverage.md) for evidence and remaining hardware,
accessibility, minimum-OS, and capture checks.

## Approved Library design adoption

The [approved active and empty states](LibraryDesign.md) are the target for
[milestone 2](../ROADMAP.md#2-scripts-and-safe-local-editing), not part of the
current source snapshot above. Library, script-domain, persistence and
handoff code must be implemented from scratch. The planned ownership is:

- `Features/Library/` will render the script sidebar/editor/Sections layout and own
  its presentation models and editing sessions. Keep row gesture presentation
  local to the list; action ownership and target script IDs belong to the
  feature's state owner even when the action's row is not selected.
- Derive a genuinely empty library from a successful ready result, separately
  from loading/failure, no search matches and an intentionally blank document.
  Filtering must not clear the active editing session. Empty/active rendering,
  outline naming focus and transient feedback are feature presentation concerns.
- A native editing-session owner will coordinate section metadata, paragraph
  anchors and ordinary editor undo. Inline rename, jump and remove intents use it;
  views must not create a separate section collection or edit script text to
  simulate section names. Scope outline keys so editor typing and composition
  retain native behavior.
- Keep rename state, save/send workflow, library load state and toast visibility
  as independent state axes. A destructive action's recovery snapshot is owned
  only for its active 10-second Undo toast window. Explicit close or timeout must
  discard that snapshot and disable its recovery action. Keep unrelated native
  editor undo independent; do not introduce a session Undo Delete buffer.
  Use cancellable, identity-checked timers on `MainActor`, inject time for tests,
  and avoid stale Undo actions after a later operation or script change.
- Script and pin metadata will belong to planned domain contracts and an isolated
  repository, with feature grouping derived from immutable summaries. The agreed
  script metadata field is `isPinned: Bool = false`, exposed in those summaries;
  no separate pin model is needed. No script types or schema currently exist.
  Include the field in the initial schema and define ordering, pagination and
  revision strategy under the [pin metadata decision](PersistencePolicy.md#pin-metadata-decision).
  Pin/unpin must not mutate sent content or bypass save guards.
- `App/` will add Show Library, New Script and Send menu commands and
  Library/reader coordination. These commands do not exist yet. Window services
  will host injected content;
  editing, persistence and recovery ownership belong outside window controllers.

The design uses feature-local composition and native controls. Introduce reused
visuals in `DesignSystem/` only when independent features actually share them.
Library names the complete workspace; editor-specific and script-domain types
retain Script/Section terminology rather than taking the feature's name.
The first implementation's acceptance checks belong in the
[planned checklist](ScriptEditingValidation.md#approved-design-adoption-pending).

## Destination layout

Paths below are relative to `Promptly/`. ✅ means present, 🗓️ means planned, and
⚠️ marks a decision needed before implementation. Planned names are starting
points; preserve ownership when implementation details change.

| Status | Destination | Responsibility and growth |
| --- | --- | --- |
| ✅ | `App/` | Lifecycle and dependency wiring. Add `Composition/` only when wiring grows; keep native scenes, app-wide commands/menus, and cross-window presentation coordination here. |
| 🗓️ | `Features/Library/` | First implementation of the approved Library/editor/Sections design, editing sessions, save-state presentation and Send to Prompter in milestone 2. Import/export and suggestions arrive later. |
| ✅ | `Features/Reader/` | Reader content and controls. Add appearance, logical-position presentation, and playback controls with their milestones. Keep script-management UI in the Library. |
| 🗓️ | `Features/Settings/` | Preference controls and synthetic appearance previews; capability-specific state stays with its owner. |
| ✅ | `Domain/` | Current display geometry, placement policy, and independent window states. Retain the small flat layout until capability folders improve clarity. |
| 🗓️ | `Domain/Scripts/`, `Sections/`, `Reader/`, `Playback/` | Stable script IDs/revisions, snapshots, section meaning, reading anchors, appearance values, and playback states/policies. These are capability folders under `Domain/`. |
| ✅ | `Services/Windowing/` | Panel lifecycle, focus, display integration, geometry application, and placement preferences on `MainActor`. Owns window tasks and observers, not script storage or playback. |
| 🗓️ | `Services/Persistence/` | Isolated script store and recoverable container construction; `Models/`, `Schema/`, and `Migrations/` hold SwiftData representations and compatibility policy. Explicitly disable CloudKit. |
| 🗓️ | `Services/Playback/` | One reader-session owner, starting with the sent snapshot at handoff. Add logical anchors, playback state, speed, count-in, and cancellable elapsed-time updates with their milestones; UI-bound scrolling stays on `MainActor`. |
| ⚠️ | `Services/Files/` | Bounded import parsing, validation, staged export, and cleanup. Define supported formats and compatibility, and review export write access during the file milestone. |
| 🗓️ | `Services/Inference/` | Optional on-device section generation, availability, bounded execution, and output validation. `Models/` contains framework output schemas; review UI stays in the Library. |
| 🗓️ | `DesignSystem/` | Components and semantic visuals reused by independent features. Prefer native controls; create folders only after actual reuse. |
| ✅ | `Extensions/` | Narrow native-type extensions such as the existing `NSScreen` geometry adapter. |

Mirror production ownership under `PromptlyTests/`; add feature presentation tests
with injected capabilities as those workflows arrive. Keep UI journeys in
`PromptlyUITests/`. Test doubles and synthetic fixtures stay close to their
consumers until reuse warrants sharing.

Voice-following, local MCP access, and TipKit remain separately scoped future
work. This map creates no destinations or capabilities for them in advance.

## Common placement decisions

| Code being added | Destination |
| --- | --- |
| App-wide scene, command, or Library/reader window coordination | `App/` |
| Feature presentation model (`@MainActor @Observable`) | Beside its owning feature view |
| Feature-only component or `NSViewRepresentable` interaction bridge | `Features/<Feature>/`, optionally `Components/` |
| Component reused by independent features | `DesignSystem/Components/` |
| Script ID, revision, immutable snapshot, section, or shared policy | Matching capability under `Domain/` |
| Logical reading anchor, reader appearance values, or playback state | `Domain/Reader/` or `Domain/Playback/`, according to meaning |
| SwiftData `@Model` record | `Services/Persistence/Models/` |
| SwiftData schema or migration | `Services/Persistence/Schema/` or `Migrations/` |
| Foundation Models structured-output schema | `Services/Inference/Models/` |
| Validated section suggestion with source revision/provenance | `Domain/Sections/` |
| Panel mechanics, display callbacks, or applied window preferences | `Services/Windowing/` |
| Other persisted preferences | Owning capability under `Services/`; SwiftUI preference bindings remain in feature UI |
| Raw image or color resource | `Assets.xcassets/` |
| Reused semantic visual treatment | Matching folder under `DesignSystem/` |
| Focused native-type extension | `Extensions/TypeName+Extensions.swift` |

The word “model” does not determine placement: presentation models, domain
values, SwiftData records, and Foundation Models schemas have different owners.
AppKit imports also do not turn a feature-local view bridge into a service.
Window services may host an injected view and control its panel; feature content
and app-wide routing remain with features and the app shell.

## Library-to-reader handoff

This is a planned workflow. No Library window, script persistence or
reader-session/handoff implementation is present in the source snapshot.

Keep three distinct forms of state: the Library's working draft, the last
successfully saved script revision, and the immutable revision explicitly sent
to the reader. The persistence owner serializes writes; the Library owns edit
and save/send presentation; the reader-session owner holds the active snapshot.

Send to Prompter saves the intended draft and prepares a stable snapshot. Before
committing, revalidate the operation identity, script identity, and source
revision after relevant suspension points. Failure, cancellation, deletion, or
newer edits before commit preserve the active reader and keep the Library open
with edits intact. Only a successful handoff permits app-level coordination to
close the Library and show the reader paused. Sending does not implicitly
restart an already loaded script; Play remains a separate intent.

Further edits reach the reader only through another explicit send. Show Library
reopens the workspace with the selected script. Keep placement, collapse and
position locking independent of playback; resizing and styling preserve a logical
reading anchor. Window presentation must not become an alternative owner of
script or playback state.

## Growth and review rules

- Create folders with their first real file; do not add empty target-folder
  placeholders. Keep docs and tooling outside the filesystem-synchronized targets.
- Update this snapshot and destination statuses when ownership or paths change.
  Existing files do not imply completion of their roadmap behavior.
- Keep one primary type per file. Avoid generic `Utils`, `Helpers`, `Managers`,
  `Common`, or `Shared` folders and speculative view models or service layers.
- Add targets/packages only for a real boundary. In the current app target,
  dependency direction is a review convention rather than module enforcement.
- Check privacy, revision safety, failure recovery, cancellation, accessibility,
  and window behavior with the relevant task guides. Define schema/migration
  policy before distributing durable script stores; never reset a failed store.
