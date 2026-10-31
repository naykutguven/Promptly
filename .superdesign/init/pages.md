# Native surface dependency trees

Swift files in this target share module scope and therefore refer to local types without explicit file imports. Trees below trace those local type references recursively, excluding Apple framework internals. Repeated dependencies are marked rather than expanded indefinitely.

## Reader panel (implemented)

Entry: `Promptly/App/PromptlyAppDelegate.swift`

```text
Promptly/App/PromptlyAppDelegate.swift
├── Promptly/Features/Reader/ReaderView.swift
│   ├── Promptly/Features/Reader/ReaderDragHandle.swift
│   ├── Promptly/Services/Windowing/ReaderWindowController.swift
│   │   ├── Promptly/Services/Windowing/ReaderPanel.swift
│   │   ├── Promptly/Services/Windowing/ReaderWindowPreferences.swift
│   │   │   └── Promptly/Domain/ReaderWindowState.swift
│   │   ├── Promptly/Domain/ReaderWindowState.swift [repeated]
│   │   ├── Promptly/Domain/ReaderWindowLayout.swift
│   │   │   ├── Promptly/Domain/ReaderWindowState.swift [repeated]
│   │   │   └── Promptly/Domain/DisplayGeometry.swift
│   │   ├── Promptly/Domain/DisplayGeometry.swift [repeated]
│   │   └── Promptly/Extensions/NSScreen+Extensions.swift
│   │       └── Promptly/Domain/DisplayGeometry.swift [repeated]
│   └── Promptly/Domain/ReaderWindowLayout.swift [repeated]
├── Promptly/Services/Windowing/ReaderHostingView.swift
├── Promptly/Services/Windowing/ReaderWindowController.swift [repeated]
└── Promptly/Services/Windowing/ReaderWindowPreferences.swift [repeated]
```

UI source: ReaderView and ReaderDragHandle; visual constants: ReaderView and ReaderWindowLayout. Window controller owns focus, placement and persistence, not feature presentation. AppKit and SwiftUI are the only UI frameworks. The actual Reader has synthetic text and window controls; playback, scroll, scripts and settings remain planned.

## Menu-bar scene (implemented)

Entry: `Promptly/App/PromptlyApp.swift`

```text
Promptly/App/PromptlyApp.swift
├── Promptly/App/PromptlyAppDelegate.swift [reader dependency tree above]
└── Promptly/Features/Reader/ReaderMenu.swift
    └── Promptly/Services/Windowing/ReaderWindowController.swift [tree above]
```

## Library (approved target, unimplemented)

No source entry or dependency tree exists. References:

```text
Docs/LibraryDesign.md
├── Docs/QuietNativeDesign.md [approved visual baseline and versions]
├── Docs/Design/QuietNative/2026-10-31/LibraryActive.jpg
├── Docs/Design/QuietNative/2026-10-31/LibraryEmpty.jpg
├── Docs/Design/Library/Active-v6.png [historical]
├── Docs/Design/Library/EmptyLibrary-v7.png [historical]
├── Docs/ScriptEditingValidation.md [prospective acceptance]
├── Docs/PersistencePolicy.md [planned persistence constraints]
└── Docs/Architecture.md [planned feature ownership]
```

Quiet Native's active and empty states are approved, with native adoption pending. Preserve the dated snapshots and their versions. Maintain sidebar/editor/Sections structure, one Send action, exact empty-state hierarchy, native system typography, semantic colors, local privacy and synthetic scripts. Further generation requires a new user request; mockup approval is not native implementation validation.

## Context selection

This is the candidate inventory, not an instruction to upload every dependency. For visual exploration, prefer the approved images plus the Library contract and ReaderView/window constants. Do not upload private user content, preferences, stores or diagnostics. Full code for the visual surface and adapters is in layouts.md/components.md; theme.md contains exact implemented visual values.
