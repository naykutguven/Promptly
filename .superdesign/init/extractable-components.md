# Reusable visual candidates

No cross-feature shared visual components are implemented. Native SwiftUI/AppKit controls are framework primitives rather than app-owned web DraftComponents. There is no app logo asset or complete AppIcon image; do not invent a logo mark. The menu-bar symbol is `text.viewfinder`.

These are optional conceptual extraction candidates from current feature UI, not existing remote components. Do not extract native window geometry/display adapters into web components or treat them as reusable visual assets.

## ReaderHeader
- Source: `Promptly/Features/Prompter/PrompterView.swift` (`controls`)
- Category: layout
- Description: Compact native prompter title/drag area and four state-aware window controls.
- Extractable state props: isCollapsed, isLocked, placement (anchored/detached).
- Hardcoded elements: current Promptly title, chevron up/down, lock/open-lock, detach/return symbol, Hide symbol, 30-point hit regions, icon-only styling.
- Scope: prompter-only; not a shared Library toolbar. Alternative design may use a quiet script title as concept scope.

## PrompterIconControl
- Source: `Promptly/Features/Prompter/PrompterView.swift` (`control`)
- Category: basic
- Description: Native borderless icon button with accessible label and help; the header Hide uses a native WindowVisibilityToggle with matching icon styling.
- Extractable state props: enabled, focused, selected if required by the concept.
- Hardcoded elements: system icon names per action and native visual states; accessibility labels must remain meaningful.
- Scope: private helper today; possible shared visual family in new alternatives, not an implemented reusable exported type.

## Planned Library patterns

Sidebar rows, Sections rows, Send button, empty state and title/save status exist only in approved reference images and Docs/LibraryDesign.md. They have no source implementation and must not be represented as existing extracted components. Native Library toolbar and prompter controls should share icon weights, semantic colors and spacing, while retaining their different purposes.
