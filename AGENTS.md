# AGENTS.md

These instructions apply to the whole repository. User instructions take precedence.
This file and the README's product contracts govern the task guides. Keep these
instructions self-contained; do not depend on global agent files or skills.

## Project facts

- Promptly is a private, offline, native macOS teleprompter targeting macOS 26.0+.
- Project/scheme: `Promptly.xcodeproj` / `Promptly`, with Debug and Release configurations.
- Targets: `Promptly`, `PromptlyTests`, and `PromptlyUITests`, all targeting macOS 26.0+.
- Swift 6.4 toolchain, Swift 6 language mode (`SWIFT_VERSION = 6.0`). Never set
  the language-mode setting to the compiler's minor version.
- Complete concurrency checking, Approachable Concurrency, and default `MainActor`
  isolation apply to all three targets in both configurations. Preserve this baseline.
- `MemberImportVisibility`, `InternalImportsByDefault`, and `ExistentialAny` are enabled.
- The app enables App Sandbox and Hardened Runtime, with read-only user-selected
  file access; network and microphone access are disabled.
- Planned stack: SwiftUI, AppKit, SwiftData with CloudKit disabled, `@AppStorage`,
  and optional on-device Foundation Models section suggestions.
- Voice-following and a local MCP interface are future scope; TipKit is later.
  The README describes plans, not implemented behavior or permission to build
  adjacent features.
- This is a Mac app. Do not carry over iOS targets, audio-session assumptions,
  touch-only interactions, or device-validation workflows.

The three target folders use Xcode filesystem-synchronized groups. Add ordinary
target files on disk; keep docs/tool configuration outside them and do not edit
`project.pbxproj` solely for file membership.

Source is still SwiftUI/SwiftData starter scaffolding. `Item`, the unbounded
`@Query`, direct view-side persistence, startup `fatalError`, and placeholder tests
are not production patterns; replace them as the requested features need.

## Task guides

Read the relevant guide completely before acting; tasks may need several:

- Tasks, actors, isolation, callbacks, scrolling/playback, inference, or future
  speech work: [Concurrency and Playback](Docs/AgentGuides/ConcurrencyAndPlayback.md).
- SwiftData, autosave, files, import/export, deletion, generated sections, or agent
  access: [Data and Privacy](Docs/AgentGuides/DataAndPrivacy.md).
- SwiftUI/AppKit, windows, focus, styling, permissions, localization, or
  accessibility: [UI and Accessibility](Docs/AgentGuides/UIAndAccessibility.md).
- Tests, builds, running, profiling, or code handoff:
  [Testing and Validation](Docs/AgentGuides/TestingAndValidation.md).

## Product contracts

- Promptly's script and speech processing stays on device. Apple-managed model
  assets may need downloads; core editing and playback remain useful offline
  and without Apple Intelligence or Speech assets. Verify processing location
  and network behavior before adopting an API.
- Scripts, section metadata, preferences, speech input, and derived data are
  private. Use synthetic content in tests, previews, screenshots, and diagnostics;
  never log private text or put it in identifiers or filenames.
- Do not introduce analytics, tracking, a backend, required accounts, cloud sync,
  or remote inference. Prefer the README's Apple framework stack; discuss changes
  that add dependencies or change privacy boundaries before implementing them.
- Preserve user text, edits, and the last good save. Autosave, import, migration,
  or generated suggestions must not silently overwrite newer work. Never recover
  by deleting or recreating a failed store.
- AI section suggestions are optional and reviewable; manual sections remain
  available. Unavailable models and failed suggestions must not block normal use.
- Preserve a logical reading position through window resizing and text styling.
  Screen-sharing exclusion is a compatibility goal, not a universal guarantee;
  report the actual capture methods and applications tested.
- Future MCP access uses local transport with separate read, edit, and playback
  permissions scoped to explicitly authorized scripts. Local transport does not
  ensure an external agent processes retrieved text locally; explain that boundary.

## Engineering standards

- Prioritize correctness, data preservation, privacy, and thread safety, followed
  by maintainability, accessibility, responsiveness, and energy use.
- Prefer small readable diffs and clear names. Omit redundant `internal` modifiers;
  use narrower access where appropriate. Broader APIs are maintenance promises.
- Comments explain non-obvious intent, invariants, ownership, data-loss constraints,
  or measured tradeoffs. Avoid restating the code.
- Use native macOS controls and conventions. Keep UI, AppKit windows, and
  presentation state on `MainActor`; give mutable non-UI subsystems one explicit
  owner. Never pass live SwiftData models or `ModelContext` across actors.
- Prefer structured, cancellable, bounded work. Revalidate operation identity and
  source revision after suspension before committing. Keep expensive parsing,
  persistence, inference, and matching off the UI path.
- Preserve configured concurrency checks. Do not silence diagnostics with broad
  isolation escapes or unchecked `Sendable` without a documented invariant.
- Use typed failures and useful recovery. Avoid empty catches, forced operations,
  and fatal termination for recoverable file, store, or system failures.
- Inject time, IDs, file roots, and capabilities where substitution or determinism
  requires it.
- Keep configuration changes minimal. Do not change platform scope, deployment
  target, signing, sandbox entitlements, capabilities, or permission strings unless
  the requested behavior requires it.

## Architecture and state

Grow toward this shape without reorganizing unrelated files:

```text
Promptly/
  App/                    Composition, lifecycle, routing
  Features/<Feature>/     Feature UI and presentation
  Domain/                 Shared value types and policies
  Services/<Capability>/  Persistence, files, windowing, speech, inference
  DesignSystem/           Reused app-specific visuals only
  Extensions/             Focused native-type extensions
```

- The app composition root creates long-lived dependencies once and injects them.
  Avoid service locators and mutable global singletons.
- Views render state and send intents; framework integration belongs in injected
  capability services.
- Maintain one-way dependencies: features depend on domain contracts/services;
  services do not depend on feature views or control feature presentation.
- Add a protocol where a consumer needs substitution, not for every concrete type.
- Model mutually exclusive view-model workflow states with enums and associated
  values. Render with exhaustive switches and derive convenience properties
  instead of parallel Boolean/optional flags.
- Keep independent state axes in separate enums rather than one Cartesian-product
  mega-enum. Add `Equatable`/`Sendable` when their semantics make them useful.
- Long operations use explicit legal transitions, cancellation/retry, a stable
  generation ID, and a last safe commit point. Revalidate identity/revision after
  each relevant `await`.
- Keep one primary type per file, named `TypeName.swift`. Put native extensions in
  `Promptly/Extensions/TypeName+Extensions.swift`.
- Mirror source folders under `PromptlyTests/`, using `TypeNameTests.swift` or
  `TypeName+ExtensionsTests.swift`. Keep UI journey tests under `PromptlyUITests/`
  with names such as `FeatureUITests.swift`.
- Avoid generic `Utils`, `Helpers`, and `Manager` dumping grounds.
- Add a target/package only for a real ownership, reuse, or dependency boundary.

## Working and validation

1. Inspect the working tree, relevant README sections, implementation, settings,
   and tests. Define observable acceptance criteria and important non-regressions.
2. Choose the smallest focused change with clear ownership, failure recovery,
   cancellation, and data-preservation behavior.
3. Validate at the lowest reliable layer. Add a root-cause regression test for a
   bug when practical; build affected targets, including test targets when relevant.
4. Review privacy, stale results, bounded work, reading-position stability, window
   behavior, and accessibility as applicable. Update affected docs.
5. Report what changed and why, exact validation and gaps, and material privacy,
   persistence, concurrency, or recovery implications. Keep the handoff proportional
   to the change; do not claim untested compatibility or performance.

Ask for direction when a missing decision materially changes privacy, persistence
compatibility, product behavior, or destructive behavior. Otherwise state a
conservative assumption and proceed. Reviews report actionable issues introduced
by the change with exact file/line references. Use Conventional Commits for commit
messages.
