# Architecture

This document assigns ownership for Promptly's MVP: which component owns each
piece of state, which layer each responsibility belongs to, how components may
depend on each other, and where source files go. It does not define product
behavior.

- The [PRD](PRD.md) defines behavior and acceptance criteria. This document
  cites requirement IDs instead of restating them; when the two differ, the PRD
  wins.
- For ownership, dependencies, and source placement, this document takes
  precedence over the [engineering guides](AgentGuides/).
- [ImplementationPlan.md](ImplementationPlan.md) sequences the work, and GitHub
  Issues scope it. [Research](Research/) records investigations and evidence.

Components described here are planned unless §8.2 lists them as present. A
planned component does not authorize building it outside its scheduled task.

## 1. Scope

Promptly is a menu-bar-only macOS app with:

- one reading session, shared by the UI and MCP;
- one settings owner, shared by the UI and MCP;
- three windows: the prompter, the script editor, and Settings;
- optional local MCP integration, disabled by default.

Toolchain, isolation defaults, sandboxing, and dependency policy follow
[AGENTS.md §1](../AGENTS.md#1-project). The framework choices that shape this
architecture are SwiftUI and Observation for UI and state owners, AppKit only
where a validated need exists, Core Text for line breaking, UserDefaults for
preferences, and stdio for MCP.

Keep one app target. Add a target only for a process boundary that research
establishes, such as an MCP helper (§4.8).

Post-MVP items (PRD-09 and PRD §13) do not shape MVP types. Add no speculative
hooks for script libraries, continuous scrolling, speech following, visual
transitions, or per-client permissions.

## 2. Layers and dependencies

| Layer | Owns | Does not own |
|---|---|---|
| `App/` | Entry point, scenes, composition root, app-wide commands, AppKit lifecycle (quit, sleep and wake), cross-window routing | Feature UI, session logic, settings logic |
| `Features/<Feature>/` | SwiftUI views, feature windows and AppKit adapters, presentation state, focus, accessibility, feature-only geometry | Shared session, settings, file reading, MCP |
| `Domain/<Capability>/` | Immutable values, identities, revisions, typed errors, and pure policies used by more than one layer | Mutable owners, framework objects, I/O |
| `Services/<Capability>/` | Authoritative shared state and non-UI capabilities: reading session, layout, playback, settings, file reading, MCP | Views, windows, navigation between windows |

```text
App ──► Features ──► Services
 │         │            │
 └─────────┴────────────┴──► Domain
```

- **Responsibility decides the layer.** An AppKit window bridge is Prompter UI.
  The Core Text engine is a service. Importing a framework decides neither.
- **No upward calls.** Services never reference feature types. When a service
  operation needs a UI effect, App injects a narrow capability at construction,
  such as the closure that reveals the prompter after a successful load (F01.3,
  F05.5).
- **Features don't call each other.** The editor does not open the prompter.
  The load operation does, through the capability App injected.
- **State flows down, events flow up.** Features observe service state and
  report user intent and native facts as service calls: visibility, scroll
  interaction, transition completion. Services hold no callbacks into views.
- **Services may depend on narrower services, without cycles.** The reading
  session depends on the settings service. The settings service never depends
  on the session (§4.4).
- **Domain** uses Foundation and CoreGraphics. Services may use SwiftUI, AppKit,
  or Core Text value types where a contract requires them (the layout engine
  takes `Font.Resolved`), but never own views or windows.
- App builds each long-lived owner once, in one composition root reachable from
  both scenes and AppKit lifecycle callbacks, and injects it. Use no service
  locator and no mutable global singleton.
- Prefer concrete types. Add a protocol only for a real substitution need, such
  as an injected clock or defaults store in tests, and keep it beside its
  capability.
- Folder placement does not choose an executor (§6).

## 3. State ownership

| State | Owner | Others receive |
|---|---|---|
| Source text, script revision, committed layout (lines, layout revision, layout configuration), current line, logical source position, playback state, active-line timing, operation phase, prompter-visible fact | Reading session, `Services/Prompter/` | Immutable snapshots and typed command results |
| Scheduler task, pending timer, scroll-transition token | Playback engine, inside the reading session | Nothing; not visible outside the session |
| Validated preferences, defaults, settings generation, MCP enabled flag | Settings service, `Services/Preferences/` | Observed values and change records |
| Draft text, edit revision, unfinished-edit flag, pending load identity, selection, undo | Editor model, `Features/ScriptEditor/` | Nothing |
| Native window reference, observed visibility and display, window frame including the last floating position | Prompter window model, `Features/Prompter/Windowing/` | The session gets visibility |
| Scroll geometry, interaction phase, animations, row caches | Viewport, `Features/Prompter/Viewport/` | The session gets transition completion, manual-scroll start, and the settled line |
| Client connections, in-flight requests, transport bounds | MCP bridge, `Services/MCP/` | Nothing |

- Views keep no copy of the active script, layout, current line, playback
  state, or editable settings. The editor draft is the one sanctioned separate
  copy of script text, and it never reaches MCP (F01.6, F07.15).
- Snapshots, derived values, and command results can represent owned state
  without becoming owners.
- **Window preferences versus window state.** Settings owns the size preset
  and the placement mode. The Settings UI, the menu, the window, and MCP all
  change them (F05.4, F07.8), and Restore All Defaults resets them (F08.6).
  The window model applies those values and owns the window frame,
  including the last floating position. The system restores the frame across
  launches, so Promptly stores no window coordinates of its own (§10).
- **Visibility** is native state. The window model reports it to the session,
  which needs it to gate Play and answer `promptly_get_state` (F03.1, F03.9,
  F07.6).
- Keep the committed session as one value, replaced by one MainActor
  assignment. Observers and snapshots then never see a partially committed
  state (F01.3).

## 4. Components

### 4.1 Reading session (`Services/Prompter/`)

The session is an `@MainActor @Observable` owner and the only mutation boundary
for script, layout, position, and playback (PRD §10.1, F07.11).

| Operation | Requirement |
|---|---|
| Load text; clear | F01.3, F01.5 |
| Play, Pause, Rewind | F03.1–F03.3, F03.10 |
| Go to line (index and layout revision) | F03.8, F07.4 |
| Manual scroll began; scroll settled on a line | F03.7 |
| Scroll transition completed (token) | F03.5 |
| Prompter visibility changed | F03.9 |
| System will sleep | F03.11 |
| Settings change applied | F02.4, F02.6, F03.6, F04.3 |

- One operation phase (idle, loading, recalculating) gates commands. A command
  the current state forbids returns a typed error from `Domain/Prompter/`, such
  as layout-in-progress or window-hidden (F02.7, F07.11, PRD §10.4). UI controls
  derive their enabled state from the same predicates, and MCP maps the same
  errors, so the UI and MCP cannot disagree.
- The session mints script and layout revisions. Revisions are opaque and
  unique, and never derived from script content (§7).
- Playback states are the PRD's four: Stopped, Playing, Paused, and Completed
  (PRD-03 §3.2). Loading, recalculation, and scroll transitions are operation
  state, not playback states.

### 4.2 Line layout (`Services/Prompter/`)

`LineLayoutEngine` is stateless. It takes source text, a resolved font, and a
reading width, and returns display lines through an `@concurrent` entry point
with `Sendable` inputs and results (F02.1, F02.7). Native Core Text objects stay
inside one call, and Core Text's default bounded layout stays on. Engine limits
supplement the product limits in F01.7; they do not replace them. See
[LineLayoutEngine.md](LineLayoutEngine.md) for implementation detail.

- **Layout configuration.** One function turns typography preferences and the
  size preset into a layout configuration: a resolved font and a reading
  width. Each committed layout stores the configuration that produced it. The
  viewport renders from that stored configuration, not from live settings, so
  the previous layout stays correct while a new one is computed (F02.3, F02.7).
- **Reading width** comes from the size preset through a Domain policy (F05.1),
  and the engine lays out to exactly that width. Padding that the view adds
  around the reading area is view layout and never affects line breaking.
  Nothing is measured from a view, so placement never changes width (F02.4).
- **Revisions and identity.** The session mints a layout revision for each
  request. Generation stamps every line with an identity and that revision
  (F02.2). Only an accepted result is published; a discarded revision is never
  observable.
- **Reflow anchor.** The logical position is a UTF-16 offset in the current
  script revision. Mapping it to the containing or nearest line of a new layout
  is a pure Domain policy (F02.6).

### 4.3 Playback engine (`Services/Prompter/`)

The playback engine is part of the session's implementation and runs at most
one scheduler task (F03.5).

- **Duration** is a pure Domain policy: Unicode-aware word count, the WPM
  formula, and the 0.6-second minimum (F03.4). It is computed when a line's
  timer starts and stored in the session's timing state, never in display
  lines. A WPM change applies from the next line (F03.6).
- **Cycle.** The session makes a line current and publishes a scroll request
  with a fresh transition token. The viewport scrolls and reports completion
  with that token. If the token is still current and the state is Playing, the
  engine starts the line's timer. Any command that supersedes the request
  invalidates the token, so a late completion cannot start playback (F03.5).
- Pause stores the remaining time, and resume schedules only that remaining
  time (F03.2). Time comes from an injected monotonic clock.
- App observes system sleep and forwards it to the session (F03.11).

### 4.4 Settings service (`Services/Preferences/`)

The settings service is an `@MainActor @Observable` owner of preferences,
defaults, validation, UserDefaults coding, and Restore All Defaults (PRD-08).

- **One mutation entry point** takes a partial update and its origin, user or
  agent. It merges the update, validates the whole result, and rejects unknown
  keys and any protected key from an agent. It then commits atomically,
  persists, and increments a settings generation (F08.8–F08.9, F07.8,
  F07.10). Restore All Defaults is user-only.
- **Change records** list the changed keys and the subsystems they affect:

  | Change | Affects | Requirement |
  |---|---|---|
  | Font family, weight, or size | Layout: pause and reflow | F02.4 |
  | Size preset | Window frame and layout | F05.1 |
  | Placement mode | Window only | F05.4, F07.9 |
  | Text color, alignment, reading focus | Viewport only | F04.3, F08.2 |
  | WPM | Playback, from the next line | F03.6 |
  | MCP enabled | MCP bridge | F07.14 |

- Restore All Defaults produces a change record covering every subsystem. The
  window model also discards its remembered floating position (F08.6).
- **Side effects apply in the commit's MainActor turn.** The session, the
  window model, and the MCP bridge react synchronously to a change record. A
  layout-affecting commit therefore pauses playback and enters the
  recalculating phase before any further UI or MCP command runs (F07.11).
- **Recovery without a cycle.** If a settings-triggered layout fails, the
  session asks settings to revert the affected keys, but only those still at
  the value that failed. Newer updates survive (F02.9, F08.9).
- `@AppStorage` is fine for view-local UI state, such as the selected Settings
  section. It must not write a shared preference around the service.

### 4.5 Prompter feature (`Features/Prompter/`)

- **Windowing** attaches to the `NSWindow` that SwiftUI created, without
  replacing its delegate or lifecycle. It applies the preset size and the
  placement: attached near the notch on the built-in display, or floating at
  the last floating position (F05.1–F05.3, F05.6). It validates a
  system-restored frame against the current displays (F05.7). It observes
  visibility and display changes and reports visibility to the session.
  Placement geometry is a pure, feature-local calculation.
- **Viewport** renders committed lines as identified `Text` rows in a
  `ScrollView`, using the layout's stored configuration (F02.3). It applies
  current-line emphasis and the focus position without changing geometry
  (F04.2, F04.3).
- The viewport performs the session's scroll requests and reports completion
  by token. Under Reduced Motion, it completes immediately (F04.5).
- The viewport detects user scrolling from a native interaction signal, not
  from offset changes, and reports manual-scroll start and the settled line
  (F03.7). The layout demo already uses `onScrollPhaseChange`; validate it
  with physical input on macOS 26.
- **Controls and menu items** call session and settings operations. Their
  enabled state comes from the session's command predicates.

### 4.6 Script editor (`Features/ScriptEditor/`)

- The editor is a separate window scene. Its model owns the draft and the
  draft's edit revision (F01.1, F01.6).
- **Import.** The file picker is UI. Bounded reading, UTF-8 validation, and
  releasing security-scoped access belong to `Services/Files/` (F01.2, F01.7).
  An import result replaces the draft, after any discard confirmation. It never
  goes straight to the session.
- **Load.** The editor submits the draft to the session's load operation. On
  success, it closes only if the edit revision has not changed since
  submission. On failure or supersession, the draft stays (F01.1).
- **Sync.** When the session's script revision changes, the editor adopts the
  new text only if it has no unfinished edits. Otherwise it offers Use Active
  Script (F01.6).
- App's quit path asks the editor model before terminating (F01.6).

### 4.7 Settings feature (`Features/Settings/`)

The Settings scene uses the sidebar sections in F08.1, and its controls
submit partial updates. Enabling MCP presents the access-scope and
external-processing disclosure (F07.15). Restore All Defaults asks for
confirmation (F08.6).

### 4.8 MCP (`Services/MCP/`)

The app-side bridge registers the ten PRD-07 tools and validates their
arguments. It calls session and settings operations with the agent origin and
maps results and typed errors into responses. It owns no script, layout,
playback, or preference state (PRD-07 §7.1).

- Enforce enablement and the same-user boundary inside the app. Recheck both
  after every suspension, before mutating or disclosing content. Disabling MCP
  invalidates in-flight requests (F07.14, F07.15).
- Line reads come from immutable session snapshots. Pagination and navigation
  validate the layout revision, and a stale revision is never remapped (F07.2,
  F07.12).
- **Process layout is undecided.** The
  [SDK evaluation](Research/MCPSwiftSDKEvaluation.md) prefers a client-launched
  Swift stdio helper built on the official SDK, forwarding requests to the
  running app over authenticated local IPC. If adopted, the helper is its own
  stateless target. Add no dependency, target, or entitlement before that
  decision.

## 5. Cross-component flows

Each flow names its route and commit point. Behavior details stay in the cited
requirements.

| Flow | Route | Commit point | Requirement |
|---|---|---|---|
| Load | Editor or MCP → session → off-main layout → recheck request, configuration, and phase → commit → App reveals the prompter | Session, on MainActor; the latest request wins | F01.3, F07.1 |
| Clear | Menu or editor → session clears and invalidates pending loads and layouts | Session | F01.5 |
| Layout setting | Settings UI or MCP → settings commit → session pauses and recalculates → commit with the mapped anchor, or ask settings to revert | Settings, then session | F02.6, F02.9, F08.9 |
| Play cycle | Session → scroll request with token → viewport → completion → timer → advance | Session | F03.5 |
| Manual scroll | Viewport → session pauses and invalidates → settled line → session | Session | F03.7 |
| Navigate | UI or MCP → session checks revision and index → pause, set line, scroll request | Session | F03.8, F07.4 |
| Hide or show | Window model → session visibility fact; hiding pauses | Session | F03.9, F05.5 |
| Placement or preset | Window, menu, Settings UI, or MCP → settings → window model applies it; a preset change also reflows | Settings | F05.4, F07.9 |
| Sleep | App → session pauses | Session | F03.11 |
| Restore defaults | Settings UI → settings reset, with MCP disabled → normal side effects; the window model discards its floating position | Settings | F08.6 |

## 6. Concurrency and lifetime

- The session, settings service, editor model, window model, and viewport state
  are MainActor-isolated, and their commits happen there.
- CPU-heavy or blocking work, such as layout and file reading, leaves MainActor
  through explicit `@concurrent` functions with `Sendable` inputs and results.
  `async` or `Task {}` alone does not leave the actor.
- Every asynchronous operation has an owner, an identity, a cancellation path,
  and an applicability check after each suspension. Cancellation never replaces
  identity and revision checks.
- Bound file reads, layout input, in-flight MCP requests, transport frames, and
  responses.
- Playback scheduling uses an injected clock. Views own no timers (PRD §10.3).
- Remove observers symmetrically. On quit, stop the scheduler and close MCP
  connections.
- Do not weaken concurrency checks or use unchecked isolation escapes.

## 7. Persistence and privacy

| Data | Storage |
|---|---|
| Active script, editor draft, display lines, revisions, position, playback state | Memory only |
| Preferences | UserDefaults, through the settings service |
| Prompter window frame | Restored by the system; Promptly stores no coordinates |

- Keep script text, imported paths, and script-derived values out of logs,
  diagnostics, identifiers, accessibility identifiers, and filenames. Generate
  revisions randomly or from counters, never by hashing content (F01.4, PRD
  §10.6).
- Tests, previews, and evidence use synthetic text.
- MCP is off by default and uses local stdio without a network listener. It
  exposes the active script and never drafts. Enabling it explains that clients
  may process text remotely (F07.13, F07.15).
- Screen-capture behavior is research, not architecture. Window settings such
  as `NSWindow.sharingType` are not capture protection (PRD-06). Record results
  in [ScreenSharingCompatibility.md](Research/ScreenSharingCompatibility.md).

## 8. Source layout

### 8.1 Destination

Create a folder with its first real file. Names describe responsibilities, not
required types.

```text
Promptly/
├── App/                     Scenes, composition root, commands, quit and sleep forwarding
├── Features/
│   ├── Prompter/            Shell, controls, menu content
│   │   ├── Windowing/       Window attachment, preset frames, placement geometry
│   │   └── Viewport/        Rows, emphasis, focus position, scroll requests and reports
│   ├── ScriptEditor/        Draft, import presentation, discard confirmation
│   └── Settings/            Sidebar sections, controls, MCP disclosure, Restore All Defaults
├── Domain/
│   ├── Prompter/            Revisions, display line, anchor mapping, playback state, duration policy, typed errors
│   └── Settings/            Preference values, including window preset and placement; partial updates; validation; change classification; reading-width policy
├── Services/
│   ├── Prompter/            Reading session, layout engine and configuration, playback engine
│   ├── Preferences/         Settings service, UserDefaults coding
│   ├── Files/               Bounded import reading
│   └── MCP/                 Tool bridge, access enforcement, transport integration
└── Assets.xcassets/
```

### 8.2 Current snapshot

The app is a window prototype with synthetic text plus a standalone layout
engine. None of the shared owners in §3 exist yet.

| Path | Today | Gap to the PRD |
|---|---|---|
| `App/PromptlyMain.swift` | Entry point; starts `PromptlyApp`, or in Debug builds a windowless app when Xcode hosts unit tests in the app | None |
| `App/PromptlyApp.swift` | Menu-bar extra and prompter `Window` scene; holds `PrompterWindowModel` as `@State` | Resizable content-size window; no editor or Settings scene (F05.1, F01.1, PRD-08) |
| `App/PromptlyAppDelegate.swift` | Keeps the app running after its last window closes | No composition root, quit, or sleep forwarding |
| `Domain/Prompter/PrompterLine.swift` | Display text and UTF-16 source range | No `id` or `layoutRevision` (F02.2) |
| `Domain/Windowing/PrompterWindowState.swift` | Prototype `Codable` state: anchored or detached, collapse, lock, freeform size | Unused by the app and never persisted; replace with preset and placement preferences (F05.1–F05.3) |
| `Features/Prompter/PrompterView.swift` | Synthetic shell with lock, attach, and hide controls | No viewport or playback controls; lock is not an MVP control |
| `Features/Prompter/PrompterMenu.swift` | Show or hide, lock, attach or detach, return to notch | Placement changes must go through settings (F05.4) |
| `Features/Prompter/Windowing/PrompterWindowBridge.swift` | Reports SwiftUI's `NSWindow`; sets `sharingType = .none` | That setting is not capture protection; decide it with the PRD-06 research |
| `Features/Prompter/Windowing/PrompterWindowModel.swift` | Weak window reference, visibility through `orderOut`, move near the top of the current screen | Doesn't target the built-in display or report visibility to a session (F05.2, F03.9) |
| `Features/Prompter/Windowing/PrompterWindowLayoutConstants.swift` | Scene ID and prototype sizes | Sizes are not the PRD presets (F05.1) |
| `Features/Prompter/Viewport/PrompterLineLayoutDemoModel.swift`, `PrompterLineLayoutDemoView.swift` | Preview-only demo of layout, last-good result, and anchor reconciliation | Not part of the app; fold into the session and viewport, or delete, when the real viewport lands |
| `Services/Prompter/LineLayoutEngine.swift` | Stateless `@concurrent` Core Text engine | Revision and identity stamping pending (F02.2) |
| `PromptlyTests/Services/Prompter/LineLayoutEngineTests.swift`, `PromptlyTests/Domain/Windowing/PrompterWindowStateTests.swift`, `PromptlyUITests/PrompterWindowUITests.swift` | Engine, prototype state, and window UI tests | Window-state tests go when the prototype type goes |
| `PromptlyTests/App/UnitTestHostTests.swift` | Checks the unit-test host decision and that hosting unit tests creates no Promptly windows | None |

### 8.3 Placement rules

- Use one primary type per file. Small private helpers may share it.
- Mirror production paths under `PromptlyTests/`. Put native journeys in
  `PromptlyUITests/`.
- Add a shared `Extensions/` or design-system folder only when two independent
  features reuse the code.
- Update §8.2 when files move, appear, or close a listed gap.

## 9. Validation boundaries

| Area | Lowest reliable layer | Evidence |
|---|---|---|
| Domain policies: duration, anchor mapping, validation, change classification | Unit | Table-driven cases, including Unicode and blank lines |
| Layout engine | Unit | Source coverage, blank lines, composed characters, limits, cancellation |
| Reading session and playback | Unit, with injected clock, layout function, and presenter | Latest load wins, stale tokens and revisions, phase gating, remaining time, hide and sleep, one scheduler |
| Settings | Unit, with an isolated defaults suite | Atomic rejection, partial merge, protected keys, side effects in the commit turn, conditional revert |
| Editor | Unit for the model; UI tests for journeys | Draft protection, safe close after load, import errors |
| MCP | Unit for the bridge; recorded client runs | Enablement, same-user boundary, draft exclusion, revision-safe pagination, disabling mid-request, tested Codex and Claude Desktop versions |
| Native UI | UI tests plus recorded manual evidence | Presets, placement, display changes, Spaces, keyboard, VoiceOver, Reduced Motion |

Compilation and unit tests do not establish runtime compatibility. Record
minimum-OS, physical-display, full-screen Spaces, capture, signed IPC, and
packaging evidence separately, following the
[Testing and Validation guide](AgentGuides/TestingAndValidation.md).

## 10. Open architectural decisions

| Decision | Why it matters | Settle in |
|---|---|---|
| MCP process layout, IPC, peer validation, packaging | Adds a target, a dependency, and entitlements | MCP research (F07.13) |
| System restoration of the prompter frame | The borderless prompter must restore across launches, survive display changes, and stop returning a floating position after Restore All Defaults; within a launch the window model returns the last floating position | Windowing task (F05.3, F05.7, F08.6) |
| Non-activating prompter | Showing or using the prompter must not activate Promptly, which likely needs an AppKit non-activating panel hosting the SwiftUI view instead of a SwiftUI `Window` scene | Windowing task (F05.6) |
| Font resolution outside a view | The session must build the same `Font.Resolved` that the rows render | Layout integration task |
| User-scroll detection signal | Separates manual from programmatic scrolling | Viewport task (F03.7) |
| Clock behavior across sleep (`ContinuousClock` or `SuspendingClock`) | Remaining time if the sleep notification arrives late | Playback task (F03.11) |
| Composition root location | Owners must be reachable from scenes and app-delegate callbacks | First task that adds a shared owner |
| Unit of MCP source ranges | PRD-07 returns ranges without naming a unit; the engine uses UTF-16 | PRD clarification (F07.2, F07.3) |

## 11. Changing this architecture

This document fixes ownership and dependency direction. It does not prescribe
every type.

- Extend an existing component while its responsibilities stay cohesive.
  Extract a new one when independent state, lifetime, or testability requires
  it.
- Keep feature-specific behavior inside its feature. Never duplicate
  authoritative session or settings state.
- Prefer small, explicit service interfaces over broad abstraction layers.
- Preserve the privacy, concurrency, revision, and recovery guarantees when
  moving a boundary.
- Revisit a boundary when real code shows a different ownership need. Record
  the outcome here, and move any decision from §10 into the relevant section
  once it is settled.

Update this document when ownership, dependencies, or the source layout change
materially, and update §8.2 when files move or close a listed gap. Task status,
validation history, and implementation detail belong in issues, research
documents, and the code.
