# Native destinations and intents

This app has no URL routes, router config or browser navigation. Do not invent implemented web paths.

| Native surface | Entry | Layout and behavior |
| --- | --- | --- |
| Promptly menu-bar extra | `Promptly/App/PromptlyApp.swift` → `Promptly/Features/Prompter/PrompterMenu.swift` | Native openWindow/dismissWindow Show/Hide, Collapse/Expand, Lock/Unlock, Detach/Return to Notch, Quit; local menu shortcuts rather than global hotkeys. |
| Prompter window | `Promptly/App/PromptlyApp.swift` → `PrompterWindowContent` → `PrompterView` | Plain floating SwiftUI Window, with live notch/primary-display geometry through a narrow adapter. Native header visibility toggle and drag gesture; normal activation allowed. Local placement preferences, collapse and lock survive native hide/close/reopen. Synthetic text; no scrolling yet. |
| Library (planned) | `Docs/LibraryDesign.md`; `Docs/QuietNativeDesign.md`; frozen `Docs/Design/QuietNative/2026-10-31/` images | Dedicated script sidebar/editor/Sections workspace. No implementation, script store, autosave, Send handoff, or native Library tests exist. |

Library approved interactions are design contracts, not existing app routes. Keep Pinned above Recently used, one Send to Prompter · ⌘↵ control, title/save state, plain-text editor, compact Sections; empty state has one Create a Script · ⌘N action. No toolbar branding duplication or footer. Use the design contract for detailed swipe, section naming and timed Undo requirements.

The full current scene source and menu command source are in layouts.md. Quiet Native is the approved visual baseline; native adoption remains pending. Earlier Native v6/v7 images remain historical references. Future exploration must preserve the approved snapshots and current app implementation unless the user requests changes.
