# Promptly

Promptly is a lightweight, native macOS teleprompter designed to help you read prepared scripts while working in other applications.

Built for video meetings, interviews, presentations, and AI-assisted workflows, Promptly combines an unobtrusive floating reading interface with automatic line-by-line playback and integration with AI agents through the Model Context Protocol (MCP).

Promptly is designed to be minimal, local-first, and privacy-conscious.

> **Status:** Early development. The repository contains a prototype; the complete MVP is not yet implemented.

## Features

### Planned MVP

- **Floating teleprompter:** An always-on-top reading window that attaches near the MacBook notch or floats independently.
- **Window presets:** Compact and Expanded reading layouts.
- **Script input:** Enter, edit, or import plain-text scripts through a dedicated editor. Supported imports are `.txt` and `.md`; Markdown is treated as literal plain text.
- **Line-by-line playback:** Automatically advance through visual display lines at a configurable words-per-minute rate.
- **Playback controls:** Play, Pause, Rewind, and direct line navigation.
- **Reading focus:** Highlight the current line with configurable Top, Center, or Bottom positioning.
- **Typography:** Customize font family, weight, size, alignment, and text color.
- **Persistent preferences:** Restore settings across application launches while keeping script content in memory only.
- **MCP integration:** Allow local AI agents to load scripts, read display lines, control playback, and update supported settings.

See the [Product Requirements Document](Docs/PRD.md) for the complete specification and acceptance criteria.

## Current implementation

The repository currently contains:

- A SwiftUI menu-bar application and floating prompter window prototype using synthetic text.
- Basic window positioning, visibility, and interaction controls.
- Local window-placement preferences.
- A Core Text engine for calculating visual display lines and Unicode-aware source ranges.
- A standalone SwiftUI line-layout demonstration.
- Initial unit and UI tests.

The following MVP functionality is not yet integrated:

- Script editor and file import.
- Shared reading session and playback engine.
- Automatic line advancement and current-line highlighting.
- Complete settings interface.
- MCP server and tools.

Some prototype behavior differs from the current PRD and will be revised during implementation.

See [Line Layout Engine](Docs/LineLayoutEngine.md) for implementation details, recorded validation, and remaining checks.

## Privacy

Promptly's core functionality is designed to work offline without accounts or cloud services.

The planned MVP follows these rules:

- **Memory-only scripts:** Active scripts and unfinished editor drafts remain in application memory and are discarded when the application quits.
- **Local preferences:** Only preferences and necessary window coordinates are persisted.
- **Optional MCP access:** MCP is disabled by default and uses local `stdio` integration without a network listener.
- **Active-script scope:** While MCP is enabled, any local MCP client running under the same macOS user may access the active script, future replacements, and supported controls. Unfinished editor drafts are excluded.

External MCP clients may process retrieved script text remotely, even though Promptly's transport is local.

### Screen-sharing limitations

Promptly aims to provide an unobtrusive reading experience during meetings and presentations. However, **macOS does not provide a universal guarantee that third-party screen-capture applications will exclude Promptly's window**.

See [Screen-Sharing Compatibility](Docs/Research/ScreenSharingCompatibility.md) for the test matrix and any subsequently recorded results.

## Technology

| Component | Technology |
| --- | --- |
| Platform | macOS 26+ on Apple silicon |
| Language | Swift 6.4 toolchain, Swift 6 language mode |
| UI | SwiftUI, Observation, AppKit where necessary |
| Text layout | Core Text |
| Concurrency | Swift Concurrency with strict checking |
| Preferences | UserDefaults / `@AppStorage` |
| AI agent integration | Local MCP; official Swift SDK is the preferred candidate, pending validation |

The project prioritizes native Apple frameworks and minimal dependencies.

## Development

### Requirements

- A Mac with Apple silicon. Intel-based Macs are not supported.
- macOS 26 or later to run the application.
- Xcode 27.2 with the Swift 6.4 toolchain for development.

### Build and run

1. Clone the repository:

   ```sh
   git clone https://github.com/naykutguven/Promptly.git
   cd Promptly
   ```

2. Open `Promptly.xcodeproj` in Xcode.
3. Select the `Promptly` scheme.
4. Build and run the macOS application.

The current application is a development prototype and does not yet provide the complete teleprompter experience.

## Development Workflow

Promptly uses GitHub-based development workflows:

- **GitHub Issues:** Track implementation tasks, bugs, and technical research.
- **GitHub Project:** Organize development priorities and progress.
- **Pull Requests:** Review and integrate changes.
- **GitHub Actions:** Define automated validation and CI checks.

An agent-assisted engineering workflow using Codex, reusable skills, and deterministic scripts is under development.

The [Product Requirements Document](Docs/PRD.md) defines intended product behavior. GitHub Issues describe individual tasks and their acceptance criteria.

Coding agents should follow [AGENTS.md](AGENTS.md).

## Documentation

| Document | Purpose |
|---|---|
| [Product Requirements](Docs/PRD.md) | Authoritative feature specifications and acceptance criteria |
| [Architecture](Docs/Architecture.md) | Application structure and component responsibilities |
| [Agent Instructions](AGENTS.md) | Rules and guidance for coding agents |
| [Agent Guides](Docs/AgentGuides/) | Specialized engineering and validation guidelines |
| [Line Layout Engine](Docs/LineLayoutEngine.md) | Core Text implementation and validation |
| [MCP SDK Evaluation](Docs/Research/MCPSwiftSDKEvaluation.md) | MCP integration research |
| [Screen-Sharing Research](Docs/Research/ScreenSharingCompatibility.md) | Capture compatibility testing |

Implementation progress and tasks are tracked through [GitHub Issues](https://github.com/naykutguven/Promptly/issues).

---

Promptly is under active development. Features, interfaces, and implementation details may change before the initial release.
