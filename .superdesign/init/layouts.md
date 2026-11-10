# Native prompter scene and layouts

The implemented UI is a SwiftUI Window plus MenuBarExtra. The shared model stays
outside the window. The header uses native WindowDragGesture and
WindowVisibilityToggle; the status menu uses native openWindow/dismissWindow.
Library remains a planned separate workspace with approved mockups.

A narrow AppKit attachment applies live primary-display/notch geometry to the
SwiftUI-owned NSWindow. It does not create or show/hide a window or replace its
delegate. Normal native activation is allowed. See Docs/SwiftUIPrompterWindow.md
for verified gaps, native-toggle host behavior and remaining validation.

Full current UI source follows; native adapters are in components.md.

### `Promptly/App/PromptlyApp.swift`

```swift
//
//  PromptlyApp.swift
//  Promptly
//
//  Created by Aykut Güven on 25.10.26.
//

import AppKit
import SwiftUI

@main
struct PromptlyApp: App {
    @NSApplicationDelegateAdaptor(PromptlyAppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Prompter", id: PrompterWindowController.windowID) {
            PrompterWindowContent(controller: appDelegate.prompter, adapter: appDelegate.prompterWindow)
        }
        .windowStyle(.plain)
        .windowLevel(.floating)
        .windowBackgroundDragBehavior(.disabled)
        .windowResizability(.contentSize)
        .defaultSize(PrompterWindowLayoutConstants.defaultExpandedSize)
        .defaultLaunchBehavior(appDelegate.presentsPrompterOnLaunch ? .presented : .suppressed)
        // Explicit primary-display/notch placement also preserves the existing preference payload.
        .restorationBehavior(.disabled)
        .commandsRemoved()

        MenuBarExtra("Promptly", systemImage: "text.viewfinder") {
            PrompterMenu(controller: appDelegate.prompter)
            Divider()
            Button("Quit Promptly") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
```

### `Promptly/App/PromptlyAppDelegate.swift`

```swift
//
//  PromptlyAppDelegate.swift
//  Promptly
//
//  Created by Aykut Güven on 26.10.26.
//

import AppKit
import SwiftUI

final class PromptlyAppDelegate: NSObject, NSApplicationDelegate {
    let prompter: PrompterWindowController
    let prompterWindow: PrompterWindowAdapter
    let presentsPrompterOnLaunch: Bool

    override init() {
        let isUITest = ProcessInfo.processInfo.arguments.contains("--promptly-ui-testing")
        presentsPrompterOnLaunch = isUITest || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        let window = PrompterWindowAdapter()
        prompterWindow = window
        prompter = PrompterWindowController(preferences: PrompterWindowStateStore(defaults: isUITest ? nil : .standard),
                                        window: window)
        super.init()
    }

    func applicationWillTerminate(_ notification: Notification) {
        prompter.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

}
```

### `Promptly/Features/Prompter/Windowing/PrompterWindowContent.swift`

```swift
import SwiftUI

struct PrompterWindowContent: View {
    let controller: PrompterWindowController
    let adapter: PrompterWindowAdapter

    var body: some View {
        let collapsedHeight = min(PrompterWindowLayoutConstants.collapsedHeight + controller.topInset,
                                  controller.maximumSize.height)
        PrompterView(controller: controller)
            .background(PrompterWindowAttachment(adapter: adapter))
            .frame(minWidth: controller.minimumSize.width, maxWidth: controller.maximumSize.width,
                   minHeight: controller.state.isCollapsed
                       ? collapsedHeight : controller.minimumSize.height,
                   maxHeight: controller.state.isCollapsed ? collapsedHeight : controller.maximumSize.height)
            .windowResizeAnchor(.top)
            .windowResizeBehavior(controller.canResize ? .enabled : .disabled)
            .windowMinimizeBehavior(.disabled)
            .windowFullScreenBehavior(.disabled)
    }
}
```

### `Promptly/Features/Prompter/PrompterView.swift`

```swift
//
//  PrompterView.swift
//  Promptly
//
//  Created by Aykut Güven on 26.10.26.
//

import SwiftUI

struct PrompterView: View {
    let controller: PrompterWindowController
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: controller.topInset).accessibilityHidden(true)
            controls
                .frame(height: PrompterWindowLayoutConstants.collapsedHeight)
            if !controller.state.isCollapsed {
                // Resizing changes the viewport and wrapping, never the script or its font size.
                GeometryReader { _ in
                    VStack(alignment: .leading, spacing: 16) {
                        Text("SAMPLE SCRIPT")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(contrast == .increased ? 1 : 0.7))
                        Text("Take a breath.\nKeep your eyes near the camera.\nYour next idea starts here.")
                            .font(.system(size: 28, weight: .medium))
                            .lineSpacing(8)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("prompter.sample")
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                    .clipped()
                }
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.black.opacity(reduceTransparency ? 1 : 0.97))
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: controller.state.placement == .anchored ? 0 : 20,
            bottomLeadingRadius: 24, bottomTrailingRadius: 24,
            topTrailingRadius: controller.state.placement == .anchored ? 0 : 20))
        .overlay(alignment: .bottomTrailing) {
            if controller.state.placement == .detached && !controller.state.isLocked && !controller.state.isCollapsed {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 10)).rotationEffect(.degrees(-45))
                    .foregroundStyle(.white.opacity(0.5)).padding(10)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            HStack {
                Text("Promptly")
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 4)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(WindowDragGesture().onEnded { _ in controller.finishMoving() },
                     isEnabled: controller.state.placement == .detached && !controller.state.isLocked)
            .allowsWindowActivationEvents()
            .help(controller.state.isLocked ? "Unlock Position to move the prompter"
                  : controller.state.placement == .anchored ? "Detach Prompter to move it"
                  : "Drag to move the prompter")
            control(controller.state.isCollapsed ? "Expand Prompter" : "Collapse Prompter",
                    symbol: controller.state.isCollapsed ? "chevron.down" : "chevron.up",
                    id: "prompter.collapse", action: controller.toggleExpansion)
            control(controller.state.isLocked ? "Unlock Position" : "Lock Position",
                    symbol: controller.state.isLocked ? "lock.fill" : "lock.open",
                    id: "prompter.lock", action: controller.toggleLock)
            if controller.state.placement == .anchored {
                control("Detach Prompter", symbol: "arrow.up.left.and.arrow.down.right",
                        id: "prompter.detach", action: controller.detach)
            } else {
                control("Return to Notch", symbol: "arrow.up.to.line",
                        id: "prompter.return", action: controller.returnToNotch)
            }
            WindowVisibilityToggle(windowID: PrompterWindowController.windowID)
                .buttonStyle(HideButtonStyle())
                .accessibilityLabel("Hide Prompter")
                .help("Hide Prompter")
                .accessibilityIdentifier("prompter.hide")
        }
        .padding(.horizontal, 20)
    }

    private func control(_ title: LocalizedStringKey, symbol: String, id: String,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).labelStyle(.iconOnly)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(Text(title))
        .accessibilityIdentifier(id)
    }

    private struct HideButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            Image(systemName: "xmark")
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
                .opacity(configuration.isPressed ? 0.5 : 1)
        }
    }
}
```

### `Promptly/Features/Prompter/PrompterMenu.swift`

```swift
//
//  PrompterMenu.swift
//  Promptly
//
//  Created by Aykut Güven on 26.10.26.
//

import SwiftUI

struct PrompterMenu: View {
    let controller: PrompterWindowController
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Button("Show Prompter") { openWindow(id: PrompterWindowController.windowID) }
            .keyboardShortcut("o")
        Divider()
        Button(controller.state.isCollapsed ? "Expand Prompter" : "Collapse Prompter",
               action: controller.toggleExpansion)
        Button(controller.state.isLocked ? "Unlock Position" : "Lock Position",
               action: controller.toggleLock)
        if controller.state.placement == .anchored {
            Button("Detach Prompter", action: controller.detach)
        }
        Button("Return to Notch") {
            controller.returnToNotch()
            openWindow(id: PrompterWindowController.windowID)
        }
            .keyboardShortcut("r", modifiers: [.command, .option])
        Divider()
        Button("Hide Prompter") { dismissWindow(id: PrompterWindowController.windowID) }
        if controller.preferenceFailure != nil {
            Text("Window preferences could not be restored or saved. Return to Notch to reset placement.")
        }
    }
}
```
