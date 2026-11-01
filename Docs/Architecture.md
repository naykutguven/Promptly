# Architecture and Source Layout

This is Promptly's intended architecture for the complete [feature set](../README.md#planned-features)
and [roadmap](../ROADMAP.md), refined on 2026-11-01. It separates the current
working tree from destination paths. Planned files describe ownership, not
implemented features or permission to build adjacent work.

[AGENTS.md](../AGENTS.md), the [README](../README.md), the
[task guides](../AGENTS.md#task-guides), the
[Quiet Native baseline](QuietNativeDesign.md), the
[Library design](LibraryDesign.md), and the
[persistence policy](PersistencePolicy.md) remain authoritative.

## How to use this map

- Create folders with their first real files, without empty target-folder placeholders.
- Treat proposed filenames as starting points. Keep the ownership when names change.
- Update the snapshot and status markers when files move or behavior is implemented.
- Keep ordinary source in the owning filesystem-synchronized target folder; docs,
  scripts and tooling stay outside it. File membership alone needs no project edit.
- Use one primary type per file. Add a protocol for an actual substitution boundary,
  beside its owning capability, rather than a general `Protocols/` directory.
- Keep one app target until a real reuse, ownership or process boundary needs another.

| Marker | Meaning |
| --- | --- |
| ✅ | Exists at the stated current path in the working tree |
| 🔀 | Existing implementation has an intended move; the migration table gives its current path |
| 🗓️ | Planned destination, created only with the corresponding roadmap work |
| ⚠️ | Destination is conditional on a product, compatibility, privacy or feasibility decision |

## Ownership and dependencies

**Feature UI includes native UI infrastructure.** A reader panel, window
controller, delegate, hosting view, text editor, scrolling adapter or focus policy
belongs to the feature it presents. Importing AppKit does not make it a service.
Conversely, a non-UI operation can belong in Services even when only one feature
currently uses it, such as Library section generation.

| Layer | Owns | Keeps elsewhere |
| --- | --- | --- |
| `App` | Entry point, composition, lifecycle, scenes, app-wide commands, and coordination between feature windows | Panel mechanics, editing state, persistence and playback implementation |
| `Features/<Feature>/` | SwiftUI/AppKit views, feature windows and delegates, presentation state, UI workflows, selection, focus, accessibility, native editor/viewport adapters and feature layout policy | SwiftData contexts, file transactions, model/speech sessions and authoritative shared non-UI session state |
| `Domain/<Capability>/` | Shared identities, revisions, immutable snapshots, persisted value contracts, logical anchors and pure product policies | SwiftUI/AppKit objects, SwiftData records and framework sessions |
| `Services/<Capability>/` | Non-UI state owners and effects: storage, preference serialization, file processing, reader session, text analysis, inference, speech and authorized agent operations | Windows, views, native editor/scroll ownership, navigation and feature presentation |
| `DesignSystem/` | App-specific visuals and semantic tokens reused by independent features | Feature workflows, reader placement policy and speculative control libraries |
| `Extensions/` | Focused, shared extensions to native types | Feature workflows or generic helper collections |

```text
App ── composes and coordinates ──► Features ── intents/values ──► Services
 │                                    │                            │
 └── creates long-lived owners        ├──► DesignSystem             │
                                      └──────────► Domain ◄─────────┘
```

Features may use domain values directly. Services may use narrower services and
domain contracts, with explicit dependencies and no cycles back into Features or
App. Features report navigation/handoff requests through injected callbacks or
capabilities; Library does not construct Reader UI. App wires concrete owners
once, without a service locator or mutable global singleton.

Folder placement does not select an executor. UI, AppKit callbacks, focus and
presentation stay on `MainActor`. A non-UI `ReaderSession` may also use
`MainActor` for synchronized commands and logical position. Expensive storage,
parsing, analysis and inference need an explicit isolated owner or narrowly
scoped concurrent worker under the configured Swift concurrency baseline.
Never pass live SwiftData models or contexts across actors.

## Current source snapshot

This is the working tree, including the reader-controller extraction. It still
implements only window behavior with synthetic text and UserDefaults placement.
Library, script storage, handoff, appearance settings and scrolling are planned.
The paths below have **not** moved as part of this documentation refinement.

```text
Promptly/
├── App/
│   ├── PromptlyApp.swift                     ✅
│   └── PromptlyAppDelegate.swift             ✅
├── Features/Reader/
│   ├── ReaderView.swift                      ✅
│   ├── ReaderMenu.swift                      ✅
│   └── ReaderDragHandle.swift                ✅
├── Domain/
│   ├── DisplayGeometry.swift                 🔀
│   └── ReaderWindowState.swift               🔀
├── Services/Windowing/
│   ├── ReaderHostingView.swift               🔀
│   ├── ReaderPanel.swift                     🔀
│   ├── ReaderPanelControlling.swift          🔀
│   ├── ReaderPanelController.swift           🔀
│   ├── ReaderPanelEvent.swift                🔀
│   ├── ReaderPanelLayout.swift               🔀
│   ├── ReaderWindowController.swift          🔀
│   ├── ReaderWindowGeometry.swift            🔀
│   ├── ReaderWindowLayoutConstants.swift     🔀
│   └── ReaderWindowStateStore.swift          🔀
├── Extensions/
│   └── NSScreen+Extensions.swift             ✅
└── Assets.xcassets/                          ✅

PromptlyTests/
├── Domain/
│   └── ReaderWindowStateTests.swift          🔀
└── Services/Windowing/
    ├── ReaderPanelControllerTests.swift      🔀
    ├── ReaderWindowControllerTests.swift     🔀
    ├── ReaderWindowGeometryTests.swift       🔀
    └── ReaderWindowStateStoreTests.swift     🔀

PromptlyUITests/
└── ReaderWindowUITests.swift                 ✅
```

`PromptlyAppDelegate` currently creates one `ReaderPanelController` and injects
it into the observable `ReaderWindowController`, then attaches the hosted
`ReaderView`. `ReaderView` and `ReaderMenu` share that controller. The split
between presentation policy and native panel mechanics remains useful; the
`Services/Windowing` location is the part this plan corrects.

The window controller owns placement/collapse/lock state, preference recovery,
focus requests and debounced saves. The panel controller owns native effects and
suppresses movement feedback during programmatic layout. Both are Reader UI
owners. `ReaderWindowStateStore` only encodes and stores values, so it remains a
service. See [window validation](WindowBehaviorValidation.md) and
[historical coverage](SourceCoverage.md) for actual evidence and gaps.

## Destination overview

This tree describes the destination, not folders to create immediately. Detailed
statuses and responsibilities follow. Subfolders are justified by coherent UI
surfaces or independent operations, rather than a mandatory folder per type.

```text
Promptly/
├── App/                         Composition, scenes, commands, lifecycle, cross-feature routing
├── Features/
│   ├── Library/
│   │   ├── Windowing/           Library window and native close/focus integration
│   │   ├── Sidebar/             Search, selection, pinned/recent rows and row interactions
│   │   ├── Editor/              Native text editing, draft, selection and text undo
│   │   ├── Sections/            Outline navigation, inline naming and inspector presentation
│   │   ├── Recovery/            Toast presentation and its temporary recovery ownership
│   │   ├── ImportExport/        File pickers and file-operation presentation
│   │   └── SectionSuggestions/  Optional generation and review presentation
│   ├── Reader/
│   │   ├── Windowing/           Panel, delegates, hosting, focus and placement
│   │   ├── Viewport/            Text layout, native scrolling and visual position
│   │   ├── Playback/            Controls, count-in display and keyboard interaction
│   │   ├── Appearance/          Appearance controls and synthetic preview
│   │   ├── VoiceFollowing/     Future opt-in and capture presentation
│   │   └── Tips/               Later contextual reader tips, if needed
│   └── Settings/               Settings shell and agent-access consent UI
├── Domain/
│   ├── Scripts/                IDs, revisions, snapshots, summaries and duration values
│   ├── Sections/               Section IDs, paragraph anchors, mapping and suggestions
│   ├── Reader/                 Sent snapshot, logical reading anchor and appearance values
│   ├── Playback/               Playback state, pace/count-in values and policies
│   ├── Windowing/              Shared display and persisted placement values
│   └── AgentAccess/            Future script-scoped permission and request values
├── Services/
│   ├── Persistence/            Isolated repository, SwiftData models/schema/migrations
│   ├── Preferences/            Local preference codecs and storage
│   ├── Scripts/                Non-UI script operations and bounded duration analysis
│   ├── Playback/               One reader-session owner and non-UI timing
│   ├── Files/                  Bounded import/export processing and safe file transactions
│   ├── Inference/              Optional on-device section generation
│   ├── Speech/                 Future on-device capture, recognition and matching
│   └── AgentAccess/            Future authorization, command dispatch and local transport
├── DesignSystem/               Visuals shared by independent features when reuse exists
├── Extensions/                 Focused shared native-type extensions
└── Assets.xcassets/             Raw image and color resources
```

## Destination layout

Paths in each table are relative to its named folder. 🔀 identifies code that
exists elsewhere; it does not claim that the destination path already exists.

<details open>
<summary><strong><code>App/</code></strong> — composition and coordination</summary>

| Status | Path | Responsibility |
| --- | --- | --- |
| ✅ | `PromptlyApp.swift` | Entry point, scenes and menu-bar composition; owns app-wide Quit. Feature content remains in Features. |
| ✅ | `PromptlyAppDelegate.swift` | Current composition root, launch/reopen/termination forwarding. It constructs the reader's native and observable owners once. |
| 🗓️ | `Composition/AppComposition.swift` | Extract dependency construction when Library, repository and shared reader session make the delegate too large. No runtime lookup container. |
| 🗓️ | `Navigation/AppCoordinator.swift` | Show Library, show/focus Reader, successful handoff presentation, and commands targeting the active editing/reader owner. Never duplicates drafts or playback state. |
| 🗓️ | `Commands/PromptlyCommands.swift` | App-wide Show Library, New Script and Send command wiring, with contextual enablement and editor-safe shortcuts. Reader-specific menu content remains in Reader. |
| 🗓️ | `Lifecycle/AppLifecycleCoordinator.swift` | When needed, coordinates safe close/quit with the editing owner and stops active work. Feature window delegates report requests; this type does not implement panel geometry. |

Use native SwiftUI scenes for Library/Settings when sufficient; dedicated feature
window controllers are warranted by actual AppKit behavior.

</details>

<details open>
<summary><strong><code>Features/Library/</code></strong> — the complete script workspace</summary>

Library includes the sidebar, editor and Sections inspector as one feature.
Import/export and optional suggestions are Library subflows, not new top-level
features or additions to its approved empty state.

| Status | Path | Responsibility |
| --- | --- | --- |
| 🗓️ | `LibraryView.swift` | Composes the approved active/empty workspace, editor, inspector and feedback. |
| 🗓️ | `LibraryModel.swift` | Owns library load/search/selection presentation and coordinates row intents, safe script switching, save/send and close requests through injected capabilities. Does not hold a second editable text copy. |
| 🗓️ | `Windowing/LibraryWindowController.swift` | Native Library lifecycle/focus/close integration if scenes alone are insufficient. Save decisions belong to the editing workflow, not delegate callbacks. |
| 🗓️ | `Sidebar/LibrarySidebar.swift` | Search, Pinned/Recently used grouping, selected row, no matches and genuinely empty presentation from immutable summaries. |
| 🗓️ | `Sidebar/ScriptRow.swift` | Row-local swipe presentation, pin indicator, context menu and keyboard/VoiceOver alternatives; actions carry the row's stable ID. |
| 🗓️ | `Editor/ScriptEditor.swift` | SwiftUI-to-AppKit editor bridge, preserving normal text selection, composition, copy/paste and keyboard behavior. |
| 🗓️ | `Editor/ScriptTextView.swift` | Native text surface and focused interaction customization where required. No repository or inference sessions. |
| 🗓️ | `Editor/ScriptEditingSession.swift` | One authoritative working draft, title/text/section editing, source revision, selection and native text-undo integration on MainActor. Produces immutable save snapshots. |
| 🗓️ | `Sections/SectionOutline.swift` | Inspector, current-section highlight, stable row identity and keyboard navigation. |
| 🗓️ | `Sections/SectionRenameState.swift` | Inline-name workflow and focus, separate from editor selection and save state. Can begin nested in its owner until a separate file is useful. |
| 🗓️ | `Recovery/LibraryRecoveryModel.swift` | The active destructive operation's ID, source and bounded recovery snapshot; owns its cancellable 10-second toast lifetime. No hidden post-expiry history. |
| 🗓️ | `Recovery/UndoToast.swift` | Undo/dismiss interaction, hover/focus pause and one accessibility announcement. Persistent save failures use separate recovery UI. |
| 🗓️ | `ImportExport/LibraryFileWorkflow.swift` | Open/save panel presentation, operation state, progress, cancellation and recovery; passes authorized file access to non-UI processing. |
| 🗓️ | `SectionSuggestions/SectionSuggestionsView.swift` | Availability explanation and review/accept/edit/discard UI; manual sections always remain usable. |
| 🗓️ | `SectionSuggestions/SectionSuggestionsModel.swift` | Bounded request/review workflow with operation identity and source revision; applies accepted values through the editing owner. |

Keep library load, inline rename, save/send, and transient recovery as independent
state axes. Use enums for mutually exclusive states within each axis. Add a
submodel only for a real independent workflow or lifetime, without forwarding
wrappers for every view.

</details>

<details open>
<summary><strong><code>Features/Reader/</code></strong> — window presentation and reading surfaces</summary>

| Status | Path | Responsibility |
| --- | --- | --- |
| ✅ | `ReaderView.swift` | Reader shell and control presentation. Evolves to render the sent snapshot through the viewport. |
| ✅ | `ReaderMenu.swift` | Reader commands and preference warnings. Later playback commands use the same shared session as the panel controls. |
| ✅ | `ReaderDragHandle.swift` | Reader-local AppKit drag bridge; stays feature-owned. |
| 🔀 | `Windowing/ReaderWindowController.swift` | Observable placement, visibility, collapse/lock policy, preference restore/recovery, focus requests and save debounce. Never becomes the script or playback owner. |
| 🔀 | `Windowing/ReaderPanelController.swift` | Panel configuration, display observation, native focus and NSWindowDelegate. Owns programmatic-geometry feedback suppression. |
| 🔀 | `Windowing/ReaderPanel.swift` | Native nonactivating panel and explicit keyboard-focus/Escape hooks. |
| 🔀 | `Windowing/ReaderHostingView.swift` | Native hosting and first-mouse/key policy for Reader content. |
| 🔀 | `Windowing/ReaderPanelControlling.swift` | Feature-local substitution boundary between window policy and native effects. |
| 🔀 | `Windowing/ReaderPanelEvent.swift` | Native frame/display/close events delivered to the feature owner. |
| 🔀 | `Windowing/ReaderPanelLayout.swift` | Frame and interaction constraints consumed by the native adapter. |
| 🔀 | `Windowing/ReaderWindowGeometry.swift` | Pure Reader UI placement calculations; being pure does not make feature layout a shared domain policy or service. |
| 🔀 | `Windowing/ReaderWindowLayoutConstants.swift` | Reader window/control sizing shared by its view and geometry. Feature-specific, not a design-system token set. |
| 🗓️ | `Viewport/ReaderViewport.swift` | Reading text surface, guide/highlight, clicked-paragraph navigation and accessibility presentation. |
| 🗓️ | `Viewport/ReaderScrollController.swift` | Native text layout, scrolling, display-driven updates and mapping between logical anchors and pixel offsets. Feeds reading-position changes to the shared session. |
| 🗓️ | `Playback/ReaderPlaybackControls.swift` | Play/pause/restart/rewind/section controls, pace presets and slider, and count-in presentation. |
| 🗓️ | `Playback/ReaderPlaybackSettings.swift` | Count-in and assumed speaking-rate preference controls hosted by Settings; these do not create another live playback owner. |
| 🗓️ | `Appearance/ReaderAppearanceSettings.swift` | Typography, spacing, width, contrast, opacity, guide and Light/Dark/system controls for the Settings shell. |
| 🗓️ | `Appearance/ReaderAppearancePreview.swift` | Live preview using synthetic text and the same rendering components, isolated from the active reader session. |
| ⚠️ | `VoiceFollowing/VoiceFollowingControls.swift` | Future explicit opt-in, permission/asset state, active capture indication and manual fallback. |
| 🗓️ | `Tips/` | Later Reader-specific contextual tips if TipKit is adopted; configuration belongs in App only when app-wide setup is needed. |

Native frame scheduling and scroll views remain here. The non-UI reader session
owns the sent snapshot, logical anchor and playback state; the viewport's pixel
position/layout cache is a derived representation, not a second reader session.
Window placement, lock and collapse stay independent of playback.

</details>

<details>
<summary><strong><code>Features/Settings/</code></strong> — settings shell and consent presentation</summary>

| Status | Path | Responsibility |
| --- | --- | --- |
| 🗓️ | `SettingsView.swift` | Native settings shell. Hosts Reader appearance/playback settings and later capability-owned settings content through composition. |
| 🗓️ | `SettingsModel.swift` | Only shell-specific selection/presentation state if needed; not a second preference, playback, speech or inference owner. |
| ⚠️ | `AgentAccess/AgentPermissionsView.swift` | Future script-scoped read/edit/playback grants and revocation, including the external-agent processing boundary. |

Settings assembles controls owned by the relevant feature. Permission prompts and
availability messages are UI; recognition/model sessions and authorization
checks belong to the non-UI capabilities. Native settings-window mechanics, if
needed, also belong to this feature.

</details>

<details>
<summary><strong><code>Domain/</code></strong> — shared values and product policy</summary>

These values may use Foundation and CoreGraphics. They do not own AppKit/SwiftUI
objects, SwiftData contexts, model sessions or transport connections. Feature-only
view state and native geometry policies stay with their feature even when pure.

| Status | Path | Responsibility |
| --- | --- | --- |
| 🔀 | `Windowing/DisplayGeometry.swift` | Immutable display snapshot used by placement calculations and native adapters. |
| 🔀 | `Windowing/ReaderWindowState.swift` | Shared Codable placement value used by Reader UI and preference storage, preserving its payload compatibility. Keeping it here prevents Services depending on Features. |
| 🗓️ | `Scripts/ScriptID.swift` | Stable opaque script identity, independent of SwiftData identity and private text. |
| 🗓️ | `Scripts/ScriptRevision.swift` | Exact revision tokens for saves, handoff, generated work and agent edits; define content/metadata revision treatment before storage implementation. |
| 🗓️ | `Scripts/ScriptSnapshot.swift` | Immutable saved or proposed script values, including sections, passed across ownership boundaries. |
| 🗓️ | `Scripts/ScriptSummary.swift` | Bounded Library metadata, including `isPinned`, for grouping without loading script text. |
| 🗓️ | `Scripts/ReadingDurationEstimate.swift` | Approximate speaking time with an explicit assumed reading rate; separate from scroll speed and count-in. |
| 🗓️ | `Sections/ScriptSection.swift` | Section identity/name and paragraph-start boundary metadata, separate from script text. |
| 🗓️ | `Sections/ParagraphAnchor.swift` | Stable section-boundary meaning across text edits. |
| 🗓️ | `Sections/SectionAnchorMapping.swift` | Pure rules for paragraph edits, merges, deletions and their undo data; native editing transactions remain feature-owned. |
| 🗓️ | `Sections/SectionSuggestion.swift` | Validated suggestion with operation/source revision and app-owned provenance, never a live Foundation Models response. |
| 🗓️ | `Reader/SentScriptSnapshot.swift` | The immutable revision explicitly sent to the reader, distinct from the working draft and latest saved Library revision. |
| 🗓️ | `Reader/ReadingAnchor.swift` | Logical content location preserved through viewport reflow and appearance changes. |
| 🗓️ | `Reader/ReaderAppearance.swift` | Validated typography, spacing, width, alignment, contrast, opacity and guide values shared by Reader, settings and preview. |
| 🗓️ | `Playback/PlaybackState.swift` | Legal paused/count-in/playing workflow with associated operation state; window collapse/lock are separate. |
| 🗓️ | `Playback/PlaybackPace.swift` | One scroll-speed value used by presets and slider; custom is derived rather than a competing setting. |
| 🗓️ | `Playback/CountInPolicy.swift` | Configured countdown and start/resume semantics after the milestone's product decision. |
| ⚠️ | `AgentAccess/ScriptAccessGrant.swift` | Future explicit script scope and separate read/edit/playback permissions, including revocation identity. |

A type's name does not determine its layer. Presentation models live in Features,
SwiftData models in Persistence, and model-generated response schemas in Inference.

</details>

<details open>
<summary><strong><code>Services/</code></strong> — non-UI owners and effects</summary>

A service owns a capability, not a screen. Its API accepts IDs, immutable values
and explicit operation context, and returns values or typed failures. It does not
construct windows, reach into an editor, navigate, or choose feature presentation.

| Status | Path | Responsibility |
| --- | --- | --- |
| 🔀 | `Preferences/ReaderWindowStateStore.swift` | Existing UserDefaults codec/storage for placement, preserving `reader.windowPlacement.v1`, payload compatibility and typed failures. ReaderWindowController owns restore/reset policy and save debounce. |
| 🗓️ | `Preferences/ReaderAppearanceStore.swift` | Typed local appearance preferences used by feature controls and Reader. `@AppStorage` may bind preferences, never script storage. |
| 🗓️ | `Preferences/PlaybackPreferencesStore.swift` | Persisted pace/count-in/assumed speaking-rate preferences as defined in their milestones; not the live playback state. |
| 🗓️ | `Persistence/ModelContainerFactory.swift` | Recoverable container creation with CloudKit explicitly disabled, including tests/previews. Never resets a failed store. |
| 🗓️ | `Persistence/ScriptRepository.swift` | One isolated persistence owner: bounded queries, serialized revision-checked content/metadata writes, deletes and recoverable failures. Introduce a substitutable repository contract here when consumers need it. |
| 🗓️ | `Persistence/Models/` | SwiftData records for scripts and sections, including `isPinned: Bool = false` on script metadata. These are not UI models or cross-actor snapshots. |
| 🗓️ | `Persistence/Schema/`, `Persistence/Migrations/` | Initial schema/compatibility design and later explicit migrations preserving IDs, revisions, text, sections and pins. |
| 🗓️ | `Scripts/ScriptDeletionService.swift` | Coordinates committed deletion, stale-work invalidation and clearing the matching reader snapshot. Supports scoped restoration supplied by the live recovery workflow; retains no hidden Undo history. |
| 🗓️ | `Scripts/ReadingDurationEstimator.swift` | Bounded language-aware text analysis returning an estimate and its rate assumption. Does not measure speech or derive scroll speed. |
| 🗓️ | `Playback/ReaderSession.swift` | One non-UI owner of the exact sent snapshot, logical anchor, play/count-in state and speed; shared by Reader controls, menu commands and future authorized agents. No NSView/NSWindow references. |
| 🗓️ | `Playback/PlaybackTiming.swift` | Elapsed-time/count-in calculation and cancellable timing through injected time as needed. Native frame callbacks and scroll application stay in Reader/Viewport. |
| ⚠️ | `Files/ScriptImporter.swift` | Bounded format parsing and validation before committing an import. Existing scripts and unsaved edits survive failure/cancellation. |
| ⚠️ | `Files/ScriptExporter.swift` | Consistent snapshot export, staging, validation, safe destination replacement and cleanup; file formats and write access require decisions first. |
| ⚠️ | `Files/UserSelectedFileAccess.swift` | Security-scoped access lifetime for authorized file operations, released on completion/cancellation. Does not show NSOpenPanel/NSSavePanel. |
| 🗓️ | `Inference/SectionSuggestionService.swift` | Optional on-device availability, bounded model work, cancellation/refusal handling and output validation with operation/source identities. |
| 🗓️ | `Inference/Models/` | Framework-specific structured-generation schemas converted to domain suggestions before review. App-owned prompt/format versions supply provenance. |
| ⚠️ | `Speech/VoiceFollowingService.swift` | Future on-device capture/recognition/matching ownership, availability/assets and bounded buffers. Matches drive the same ReaderSession through authorized intents. |
| ⚠️ | `AgentAccess/ScriptAccessAuthorizer.swift` | Future script-scoped read/edit/playback checks and revocation at execution time, independent of consent UI. |
| ⚠️ | `AgentAccess/AgentCommandService.swift` | Future authorized requests through the same repository/session and revision guards as normal workflows; no direct feature-view access. |
| ⚠️ | `AgentAccess/Transport/` | Future local stdio-helper/XPC or Unix-socket integration after protocol, sandbox and lifecycle feasibility are established. No network-facing script API. |

Services is not shorthand for background execution or for every Apple-framework
adapter. Native file pickers, window delegates, editor undo and NSScrollView
integration are UI. Foundation Models sessions, SwiftData and file transactions
are non-UI. Feature specificity alone is not the deciding factor.

Future MCP implementation requires protocol, sandbox and lifecycle validation.
No service may add analytics, accounts, cloud sync or remote inference.
Core editing/playback remain useful offline without model or speech assets.

</details>

<details>
<summary><strong><code>DesignSystem/</code>, <code>Extensions/</code> and assets</strong></summary>

| Status | Path | Responsibility |
| --- | --- | --- |
| 🗓️ | `DesignSystem/Components/` | Components actually shared by independent features. A Reader-only control stays in Reader, and a Library-only toast stays in Library. |
| 🗓️ | `DesignSystem/Styling/` | Semantic visual treatments reused across features after native adoption demonstrates reuse. Prefer system controls/fonts/colors and the approved SF Symbols. |
| ✅ | `Extensions/NSScreen+Extensions.swift` | Focused native display-to-value conversion; no window workflow or presentation ownership. |
| ✅ | `Assets.xcassets/` | Raw app images and colors. No script-derived resources, identifiers or filenames. |

Do not prebuild a theme framework, generic window service, shared Undo subsystem
or broad UI utility library. Native extensions stay focused and shared; a
feature-only interaction bridge belongs to its feature.

</details>

## Authoritative state and workflow boundaries

| State | Owner | Other layers receive |
| --- | --- | --- |
| Working title/text/sections, selection and native edit undo | Library `ScriptEditingSession` | Immutable revision-bearing save/send requests |
| Library results, selection intent, search/load state | `LibraryModel` | Stable row IDs and bounded summaries |
| Last successfully saved revision and durable metadata | `ScriptRepository` | Immutable snapshots/acknowledgments or typed failures |
| Exact sent script, logical position, playback state and speed | `ReaderSession` | Observed values and narrow commands, shared across all control surfaces |
| Window placement/collapse/lock/visibility and focus requests | Reader `ReaderWindowController` | Native layout requests and feature UI state |
| Native panel, delegates and observer handles | Reader `ReaderPanelController` | Frame/display/close events; no duplicate saved window state |
| Rendered pixels, layout caches and native scroll callbacks | Reader viewport/scroll owner | Logical anchor changes and viewport facts |
| Active destructive recovery snapshot and deadline | Library recovery owner | The current toast's Undo/dismiss intents only |
| File/model/speech operation and cancellation identity | Owning non-UI service | Bounded progress/results tied to source identity and revision |

### Approved Library design adoption

Follow the [active and empty design contract](LibraryDesign.md). Native adoption
and the [acceptance checklist](ScriptEditingValidation.md#approved-design-adoption-pending)
remain planned; the source snapshot supplies no Library baseline.

- Empty Library is a successful ready result with zero scripts, distinct from
  loading/failure, no search matches and an intentionally blank sendable script.
  Filtering must preserve the active editing session.
- Row operations carry the target row's ID even when unselected. New/duplicate
  scripts start unpinned. Pin writes preserve newer text/sections, the sent copy
  and content-based sent-version status. Define deterministic bounded ordering.
- Title naming, editor composition and outline keyboard focus are UI concerns.
  One editing session applies text and paragraph-boundary changes in a coherent
  native undo transaction. Adding/removing section names never inserts headings.
- Explicit script deletion and explicit section removal use the active 10-second
  Undo toast, starting only after the destructive action succeeds and paused on
  hover/focus. Dismissal/expiry discards that operation's recovery data and disables
  Undo. Preserve unrelated native text-edit history; do not create a generic Undo
  service or a retained session deletion buffer.
- Timers, requests and recovery actions have stable identities, cancellation and
  deterministic teardown. A later action must not restore the wrong script or
  overwrite newer section edits. Save failures remain persistent/retryable.

### Library-to-reader handoff

Keep the working draft, last good save and sent snapshot distinct. The Library's
save/send workflow owner captures the intended revision and saves through the
repository. After relevant suspension points it revalidates operation identity,
script identity and the current draft revision. Before the final commit, a
failure, cancellation, deletion or newer edit preserves the active reader and
keeps Library open with the draft intact.

Only a successful final commit installs the stable snapshot into ReaderSession
and permits App coordination to close Library and show Reader paused. Keep that
last identity check and session/presentation commit serialized on MainActor.
App must not start a second save workflow or treat opening a window as a save.
Play is a separate intent; re-sending does not implicitly restart an already
loaded script. Renaming, pinning and autosave never send. Exact same-script
replacement/anchor behavior must be specified when reading positions are built.

Library coordinates save-before-delete against the intended latest draft and
captures the corresponding recovery data; failure to save or delete preserves
the draft, stored data and reader. Deleting the source script clears the matching
active reader snapshot after a successful deletion. Undo restores Library data,
selection and pin state only; it does not resend.
If durable sent copies are later approved, define and test their all-or-nothing
deletion boundary too. Durable sent-copy restoration is still undecided.

### Reading, appearance and playback

The shared session is the single source of truth for content, logical anchor,
play/pause/count-in and speed. Reader UI applies those values to native layout;
settings preview uses synthetic content and never replaces the active snapshot.
Resize, display and style changes reconcile the logical anchor. Native scrolling
uses elapsed time, manual interaction takes precedence, and per-frame work stays
local to the viewport. Do not persist every frame or invalidate unrelated views.

Presets and slider modify the same speed. Count-in has skip/cancel and explicit
start/resume policy. Closing the reader must stop automatic scrolling and cancel
pending count-in; define Hide/show behavior during the playback milestone.
Window placement remains independently restorable.
Duration estimation uses a displayed assumed speaking rate, with count-in
separate; it is not a measurement of delivery or scroll duration.

### File, inference and future-agent boundaries

- Library presents file pickers and recovery. Services own bounded parsing,
  security-scoped access, staging and safe replacement; storage commits only
  validated values. SwiftData and filesystem writes are not one transaction.
- Suggestions stay optional and reviewable. Revalidate script/revision/operation
  after suspension and on acceptance; unavailable assets, refusal, cancellation
  and malformed output cannot block manual work or silently overwrite text.
- Future speech starts only with explicit opt-in and appropriate permission UI.
  Verify processing location and asset/network behavior; maintain manual fallback.
- Future agents receive explicit script-scoped capabilities. Enforce grants and
  revisions at execution, preserve newer drafts on conflicts, and invalidate late
  work after deletion or revocation. Local transport does not establish that an
  external agent processes retrieved text locally. A consent window is not the
  authorization boundary.

## Test destinations

Mirror production ownership, including tests of pure feature geometry or
presentation logic. Importing AppKit determines the validation needed, not the
folder. Keep fixtures close to consumers until actual reuse warrants sharing.

Each test target may have its own `Extensions/` folder for focused type
extensions used only by that target. Add it when needed, keep the files in that
test target, and avoid adding test-only conveniences to the app target.

| Destination | Coverage |
| --- | --- |
| `PromptlyTests/Features/Reader/Windowing/` | Window policy with a fake panel, native panel integration, geometry, callback suppression, focus and observer lifecycle |
| `PromptlyTests/Features/Reader/Viewport/` | Logical-anchor/pixel reconciliation under reflow, manual scroll and viewport changes |
| `PromptlyTests/Features/Library/` | Load/empty/search states, row IDs, native editing and section undo, save/send races, toast identity/expiry and close recovery |
| `PromptlyTests/Services/Preferences/` | Existing payload compatibility, last-good preference bytes, failure preservation and reopen |
| `PromptlyTests/Services/Persistence/` | Initial creation/reopen, revision ordering, deletion, low-storage/injected failures and later migrations |
| `PromptlyTests/Services/Playback/` | One session's handoff, navigation, elapsed-time/count-in, cancellation and stale commands with injected time |
| `PromptlyTests/Services/Files/`, `PromptlyTests/Services/Inference/` | Independent export reading, safe replacement, bounded validation, unavailable/malformed/stale/cancelled results |
| Future `PromptlyTests/Services/Speech/` | On-device availability, capture/recognition teardown, interruption handling and bounded matching with synthetic input |
| Future `PromptlyTests/Services/AgentAccess/` | Script scope, separate grants, revocation, stale/revision-conflicting requests and local-transport lifecycle/limits |
| `PromptlyTests/Domain/<Capability>/` | Shared value compatibility, section mapping, logical anchors and product policies |
| `PromptlyTests/Extensions/` | Focused test-only type extensions shared within the unit/AppKit test target, when needed |
| `PromptlyUITests/` | Reader, Library and Settings journeys on macOS, including keyboard/VoiceOver and synthetic screenshots where applicable |
| `PromptlyUITests/Extensions/` | Focused test-only type extensions shared within the UI test target, when needed |

Native focus, physical displays, capture apps, minimum macOS 26.0 and accessibility
need their recorded real-Mac evidence. A path change or passing unit suite cannot
establish those checks. Keep the existing validation history when tests move.

## Migration from the current layout

These are intended relocations, not completed work. Preserve the existing
controller/panel split, runtime behavior, concurrency settings and preference
payloads. The source move can be a focused implementation change before Library
work; it need not wait for playback or add a new module.

| Current path | Intended destination |
| --- | --- |
| `Promptly/Services/Windowing/ReaderWindowController.swift` | `Promptly/Features/Reader/Windowing/ReaderWindowController.swift` |
| `Promptly/Services/Windowing/ReaderPanelController.swift` | `Promptly/Features/Reader/Windowing/ReaderPanelController.swift` |
| `Promptly/Services/Windowing/ReaderPanel.swift`, `ReaderHostingView.swift` | Same filenames under `Promptly/Features/Reader/Windowing/` |
| `Promptly/Services/Windowing/ReaderPanelControlling.swift`, `ReaderPanelEvent.swift`, `ReaderPanelLayout.swift` | Same filenames under `Promptly/Features/Reader/Windowing/` |
| `Promptly/Services/Windowing/ReaderWindowGeometry.swift`, `ReaderWindowLayoutConstants.swift` | Same filenames under `Promptly/Features/Reader/Windowing/` |
| `Promptly/Services/Windowing/ReaderWindowStateStore.swift` | `Promptly/Services/Preferences/ReaderWindowStateStore.swift` |
| `Promptly/Domain/DisplayGeometry.swift`, `ReaderWindowState.swift` | Same filenames under `Promptly/Domain/Windowing/` |
| `PromptlyTests/Services/Windowing/ReaderPanelControllerTests.swift`, `ReaderWindowControllerTests.swift`, `ReaderWindowGeometryTests.swift` | Same filenames under `PromptlyTests/Features/Reader/Windowing/` |
| `PromptlyTests/Services/Windowing/ReaderWindowStateStoreTests.swift` | `PromptlyTests/Services/Preferences/ReaderWindowStateStoreTests.swift` |
| `PromptlyTests/Domain/ReaderWindowStateTests.swift` | `PromptlyTests/Domain/Windowing/ReaderWindowStateTests.swift` |

Update source links and this snapshot with the move, remove empty old directories,
and validate affected app/test targets plus window journeys. Do not change
UserDefaults keys, reset preferences or claim fresh compatibility evidence from
file relocation. Leave Services independent of Features: moving the Codable
placement contract into Reader UI would break that direction.

## Decisions to settle with implementation

| Area | Still requires a scoped decision or evidence |
| --- | --- |
| Milestone 2 storage | Initial schema/version, private location/filename, compatibility policy, repository executor, bounds, content/metadata revisions, ordering, pagination and search |
| Editing recovery | Safe switch/close/quit during unsaved edits or persistent failure; recovery replacement and retained draft bounds |
| Reader handoff | Whether sent copies persist across relaunch, startup restoration/compatibility and same-script reading-anchor reconciliation |
| Milestones 3–4 | Optional OpenDyslexic suitability/licensing, pace values, Hide/show behavior, first-start/resume count-in, duration tokenization/assumed rate/rounding |
| Milestone 5 | Supported formats, section/style preservation, replacement policy and sandbox export write access; current selected-file access is read-only |
| Milestone 6 | Foundation Models availability/asset behavior, input/output budgets and review validation; no remote fallback |
| Future speech | Supported on-device APIs/locales, permission/capture lifecycle, asset availability, matching budgets and interruption behavior |
| Future agent access | Consent/revocation protocol, transport/helper ownership, sandbox feasibility, bounded requests and SDK/protocol validation |
| Release validation | Physical notch/no-notch/multiple displays, scaling/disconnection, focus/full-screen, VoiceOver/reduced effects, minimum OS and actual capture paths |

This map selects ownership. It does not select these unresolved policies, implement
future milestones, add permissions/dependencies, or promise universal capture
exclusion. Revisit a boundary when real code demonstrates a different ownership
need, while preserving privacy, revision safety and one authoritative state owner.
