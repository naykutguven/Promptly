# SwiftUI prompter window

Implemented on 2026-11-03. The user approved normal native window activation.
The prompter remains a synthetic-text prototype; this migration adds no script
editing, storage, playback, network access or new permissions.

## Ownership and native controls

`PromptlyApp` declares one SwiftUI `Window("Prompter", id: "reader")` and a
menu-bar extra. The app delegate retains one prompter model and adapter across
native hiding, closing and reopening. SwiftUI owns creation, visibility and the
window delegate. There is no custom NSPanel, hosting view or visibility enum.

The header uses a real
[`WindowVisibilityToggle`](https://developer.apple.com/documentation/swiftui/windowvisibilitytoggle).
Its prompter-local ButtonStyle preserves the native action and enabled semantics
while rendering the existing xmark and 30-point target. The accessible title,
help and identifier are on the control. The menu uses native
[`openWindow`](https://developer.apple.com/documentation/swiftui/environmentvalues/openwindow)
and [`dismissWindow`](https://developer.apple.com/documentation/swiftui/environmentvalues/dismisswindow)
actions for the existing separate Show and Hide commands. Header dragging uses
[`WindowDragGesture`](https://developer.apple.com/documentation/swiftui/windowdraggesture),
enabled only when detached and unlocked. Native window-resize behavior and
display-fitted content constraints handle resizing and collapse.

## Why a narrow native adapter remains

The simplest scene APIs were reviewed first, with an independent alternatives
review. [`defaultWindowPlacement`](https://developer.apple.com/documentation/swiftui/scene/defaultwindowplacement(_:))
governs initial creation and yields to restored placement;
[`windowIdealPlacement`](https://developer.apple.com/documentation/swiftui/scene/windowidealplacement(_:))
governs zoom. These do not provide the existing live Return to Notch operation.
The installed SDK's DisplayProxy also lacks stable display IDs and the notch's
auxiliary areas used by the current geometry policy.

`PrompterWindowAttachment` therefore attaches a weak `PrompterWindowAdapter` to
SwiftUI's existing NSWindow. It applies exact primary-display geometry, native
movement constraints, levels and the existing overlay collection behavior. It
observes notifications without replacing SwiftUI's delegate. Old-window events
and late detach callbacks are filtered by identity. The controller suppresses
programmatic geometry feedback and preserves the last good preference payload.

The native window has the same requested
[`canJoinAllApplications`](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallapplications)
and Spaces policy as the panel prototype. This setting does not establish
compatibility with every full-screen app or capture path.

## Visibility-toggle host probe

On this macOS 27.2 host, the real toggle resolves the prompter and hides it when
placed inside Window content. In the NSMenu-backed MenuBarExtra it instead
renders a disabled, generic Show Window item. The same failure reproduced in a
minimal Window + synthetic Text + MenuBarExtra example without the app delegate,
geometry adapter or prompter model. Scene order, commandsRemoved and a normal
titled window did not repair that status-menu lookup. The native content toggle
passed its pointer-interaction probe.

This is an observed host/context limitation, not proof that every status-menu
use is unsupported. Keeping the native toggle in its working window context and
native window actions in the menu avoids private environment keys, manual
window ordering or a second presentation owner.

## State, validation and limits

The `reader.windowPlacement.v1` key and Codable payload are unchanged. Collapse,
lock, expanded size and detached placement remain app-owned. Native hide/close
and app termination flush pending placement; closing a view does not discard
prompter state. Model, attachment and window notifications stay on MainActor.

See the [window validation record](WindowBehaviorValidation.md) for the final
build/test results, initial-display geometry, both hide/reopen paths, native
dragging/resize and remaining release gates. Native drag recognition consumes
some initial pointer travel; journey tests require substantial movement in the
requested direction and no movement while locked, rather than exact equality
between pointer travel and window travel. Physical keyboard/VoiceOver, varied
displays, minimum macOS 26.0 and actual sharing applications remain separate
checks.
