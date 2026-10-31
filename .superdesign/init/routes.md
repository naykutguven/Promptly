# Native destinations and intents

This app has no URL routes, router config or browser navigation. Do not invent implemented web paths.

| Native surface | Entry | Layout and behavior |
| --- | --- | --- |
| Promptly menu-bar extra | `Promptly/App/PromptlyApp.swift` → `Promptly/Features/Reader/ReaderMenu.swift` | Show/Focus, Collapse/Expand, Lock/Unlock, Detach/Return to Notch, Hide, Quit; local menu shortcuts rather than global hotkeys. |
| Reader panel | `Promptly/App/PromptlyAppDelegate.swift` → `Promptly/Features/Reader/ReaderView.swift` | Floating borderless nonactivating AppKit panel. Starts from local placement preferences; anchored or detached, expanded or collapsed, locked or unlocked. Fixed synthetic content; no playback or scrolling yet. |
| Library (planned) | `Docs/LibraryDesign.md`; `Docs/QuietNativeDesign.md`; frozen `Docs/Design/QuietNative/2026-10-31/` images | Dedicated script sidebar/editor/Sections workspace. No implementation, script store, autosave, Send handoff, or native Library tests exist. |

Library approved interactions are design contracts, not existing app routes. Keep Pinned above Recently used, one Send to Prompter · ⌘↵ control, title/save state, plain-text editor, compact Sections; empty state has one Create a Script · ⌘N action. No toolbar branding duplication or footer. Use the design contract for detailed swipe, section naming and timed Undo requirements.

The full current scene source and menu command source are in layouts.md. Quiet Native is the approved visual baseline; native adoption remains pending. Earlier Native v6/v7 images remain historical references. Future exploration must preserve the approved snapshots and current app implementation unless the user requests changes.
