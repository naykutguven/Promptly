# Native surface dependency trees

## Prompter window and menu (implemented)

```text
Promptly/App/PromptlyApp.swift
├── SwiftUI Window + MenuBarExtra
├── Promptly/App/PromptlyAppDelegate.swift
│   ├── Features/Prompter/Windowing/PrompterWindowController.swift
│   │   ├── PrompterWindowAccessing.swift / PrompterWindowEvent.swift
│   │   ├── PrompterWindowLayout.swift / PrompterWindowGeometry.swift
│   │   ├── Domain/Windowing/PrompterWindowState.swift / DisplayGeometry.swift
│   │   └── Services/Preferences/PrompterWindowStateStore.swift
│   └── Features/Prompter/Windowing/PrompterWindowAdapter.swift
│       └── Extensions/NSScreen+Extensions.swift
├── Features/Prompter/Windowing/PrompterWindowContent.swift
│   ├── Features/Prompter/PrompterView.swift
│   │   └── native WindowDragGesture + WindowVisibilityToggle
│   └── PrompterWindowAttachment.swift → existing SwiftUI NSWindow
└── Features/Prompter/PrompterMenu.swift
    └── native openWindow / dismissWindow
```

All feature paths are under Promptly/. PrompterWindowLayoutConstants supplies
sizes. The app delegate retains one model/adapter across window closure and
reopening. There is no custom panel, hosting view, native drag view or window
delegate. Exact geometry, preferences and display observation remain native
feature infrastructure. Source snapshots are in layouts.md and components.md.
Normal native activation is allowed; no Focus Prompter mode is implemented.

## Library (approved target, unimplemented)

The Library source, storage and tests remain planned. Use Docs/LibraryDesign.md,
Docs/QuietNativeDesign.md and their frozen synthetic images. Native adoption is
not established by browser mockups. Preserve the approved active/empty states,
manual sections, local privacy and 10-second Undo/recovery contract.

## Context selection

Prefer approved images, feature contracts and the current source snapshots for
visual exploration. Native adapters are behavior dependencies, not reusable web
visuals. Do not upload user scripts, preference files, stores or diagnostics.
The resume manifest preserves earlier design-generation history; its old source
hashes are not the current implementation map.
