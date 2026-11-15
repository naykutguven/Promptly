# AGENTS.md

Instructions for coding agents working on Promptly. Applies to the entire repository.
User instructions take precedence.

## 1. Project

Promptly is a native macOS teleprompter with line-by-line playback and local MCP integration.

- **Platform:** macOS 26.0+
- **Language:** Swift 6.4 toolchain, Swift 6 language mode (`SWIFT_VERSION = 6.0`)
- **UI:** SwiftUI, Observation, minimal AppKit integration
- **Text layout:** Core Text
- **Preferences:** UserDefaults / `@AppStorage`
- **Dependencies:** Prefer native frameworks and minimal external dependencies

Preserve the existing strict concurrency checks, Approachable Concurrency,
default `MainActor` isolation, sandboxing, and security settings across all
targets and configurations.

## 2. Sources of truth

| Document | Purpose |
|---|---|
| `Docs/PRD.md` | Authoritative product requirements and acceptance criteria |
| `Docs/Architecture.md` | Architecture, ownership, source layout, and dependencies |
| `Docs/ImplementationPlan.md` | Implementation sequence and dependencies, once created |
| `Docs/AgentGuides/` | Task-specific engineering guidelines |
| `Docs/Research/` | Technical investigations, compatibility findings, and evidence |
| `README.md` | Project overview, implementation status, and development entry points |
| GitHub Issues | Scoped implementation tasks and their acceptance criteria |

Rules:

- The PRD determines intended product behavior. Existing implementation does
  not necessarily represent the final specification.
- Architecture and engineering guides govern implementation within the PRD's
  requirements.
- Do not introduce requirements from obsolete documentation or previous
  implementations.
- Report material contradictions. Follow the PRD when other project documents
  describe conflicting product behavior; ask for direction when the conflict
  cannot be resolved through the documented hierarchy.
- Do not implement post-MVP features without explicit authorization.
- Keep affected documentation, issue contracts, and implementation consistent.

## 3. Context loading

Load the context relevant to the current task.

1. Read the assigned GitHub Issue, if available.
2. Identify the relevant PRD requirement IDs.
3. Read the corresponding PRD sections, including applicable cross-feature
   requirements.
4. Inspect the working tree, affected source code, and tests.
5. Read the relevant engineering guides completely and consult applicable
   technical research.
6. Consult `Docs/Architecture.md` when ownership, source placement, or
   dependencies are involved.

Do not load the entire PRD, architecture document, or all agent guides by default.

A full-PRD review is appropriate for initial planning, dependency analysis, and
repository-wide consistency reviews.

### Task-specific guides

- **Concurrency, actors, asynchronous work, and playback:**
  `Docs/AgentGuides/ConcurrencyAndPlayback.md`
- **Script handling, files, preferences, privacy, and MCP access:**
  `Docs/AgentGuides/DataAndPrivacy.md`
- **SwiftUI/AppKit, windows, focus, styling, and accessibility:**
  `Docs/AgentGuides/UIAndAccessibility.md`
- **Tests, builds, running, profiling, and code handoff:**
  `Docs/AgentGuides/TestingAndValidation.md`

## 4. Architecture and code organization

Follow `Docs/Architecture.md`.

General ownership:

- `App/`: Application lifecycle, scene composition, and dependency wiring.
- `Features/`: Feature-specific SwiftUI/AppKit UI, presentation state, and workflows.
- `Domain/`: Shared domain values, identities, revisions, and policies.
- `Services/`: Non-UI capabilities and authoritative shared state.

Create folders and abstractions when needed. Avoid speculative layers and empty
directories.

- Keep UI, AppKit access, and presentation state on `MainActor`.
- Keep feature-specific native UI adapters with their owning feature.
- Use one authoritative reading session shared by UI and MCP.
- Use one authoritative settings owner and shared validation rules.
- Do not create competing owners of active script, playback, or settings state.
- Keep unfinished editor drafts independent of the active reading session until
  explicitly loaded. Derived presentation values and immutable snapshots may
  represent authoritative state without becoming additional owners.
- Prefer concrete types; introduce protocols for actual substitution or testing
  needs.
- Avoid unnecessary managers, wrappers, mutable global singletons, and utility
  layers.

## 5. Engineering rules

- Preserve strict Swift concurrency checking. Do not suppress diagnostics with
  unsafe isolation workarounds.
- Prefer structured, cancellable, bounded work with explicit ownership and cleanup.
- Prevent obsolete asynchronous results from overwriting newer state. Revalidate
  operation identity and relevant revisions after suspension and before commit.
- Keep expensive work off the UI actor according to the concurrency guide.
- Prefer native macOS controls and behaviors.
- Before substantial Apple-framework, bridge, or workaround decisions, consult
  official Apple documentation and relevant samples. Check native default
  behavior and choose the smallest approach that meets the requirements.
- Cite official sources for material framework recommendations and limitation
  claims. Distinguish documented behavior, observed behavior, and inference.
- Verify macOS behavior and minimum-deployment-target availability. Check installed
  SDK declarations when signatures or availability matter.
- Preserve logical reading position when layout changes.
- Use explicit failures and useful recovery. Preserve the previous valid session
  and unfinished edits when an operation fails or is superseded.
- Keep changes small, focused, and testable. Avoid unrelated refactoring.
- Do not modify project configuration, entitlements, or dependencies without a
  concrete requirement.

## 6. Privacy and security

- Scripts and editor drafts remain memory-only.
- Persist only preferences and necessary window coordinates. Do not persist
  script content, imported file contents, or imported file paths.
- Never include script content in logs, diagnostics, analytics, identifiers, or
  filenames.
- Use synthetic text in tests, previews, screenshots, and examples.
- Do not introduce cloud synchronization, accounts, or automatic uploads.
- MCP is disabled by default and uses local `stdio` integration without a network
  listener.
- Enforce MCP enablement, the same-user access boundary, and protected settings
  at the application service boundary.
- Do not expose unfinished editor drafts through MCP.
- Explain the PRD's active-script access scope when enabling MCP. Local transport
  does not guarantee that external clients process retrieved text on device.
- Never claim universal screen-sharing invisibility. Report verified capture
  compatibility and disclose unsupported or untested cases.

See PRD-01, PRD-06, PRD-07, and PRD-08 for complete requirements.

## 7. Implementation workflow

For each task:

1. **Understand:** Identify requirements, affected components, acceptance criteria,
   dependencies, and important non-regressions.
2. **Inspect:** Review the working tree, relevant implementation, settings, and
   tests before changing anything. Preserve unrelated work.
3. **Implement:** Make the smallest coherent change that satisfies the requirements.
4. **Validate:** Use the lowest reliable validation layer. Run relevant tests,
   compile affected targets when applicable, and check important failure cases.
   Follow the testing guide for task-specific requirements.
5. **Review:** Check concurrency, privacy, data preservation, regressions,
   accessibility, and scope as applicable.
6. **Report:** Summarize changes, exact validation results, limitations, and
   unresolved decisions.

Do not claim tests, builds, runtime compatibility, or performance checks passed
unless they were executed. Identify skipped checks and their implications.

Ask for direction when a missing decision materially changes product behavior,
privacy, security, persistence compatibility, or destructive behavior. Otherwise,
state a conservative assumption and proceed.

Use the `$aykut-commit-style` skill when drafting, editing, or reviewing commit
messages.
