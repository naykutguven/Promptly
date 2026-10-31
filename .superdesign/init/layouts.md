# Native scene and reader layouts

No layout is currently shared across independent features. The implemented UI is one menu-bar scene and one floating reader panel. Library is a planned separate workspace with approved mockups, not an implemented layout.

- PromptlyApp creates the native menu-bar scene and Quit command.
- PromptlyAppDelegate composes and injects the reader capability and hosted view.
- ReaderView renders the notch inset, controls and fixed synthetic reading text; detached/collapsed/locked are independent state axes.
- ReaderMenu supplies native reader window commands.

Full actual UI source follows. The AppKit window controller is a behavioral dependency, not a feature view; consult its source for geometry/focus rather than copying it into a visual prototype.

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
        MenuBarExtra("Promptly", systemImage: "text.viewfinder") {
            ReaderMenu(controller: appDelegate.reader)
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
    let reader: ReaderWindowController

    override init() {
        let isUITest = ProcessInfo.processInfo.arguments.contains("--promptly-ui-testing")
        reader = ReaderWindowController(preferences: ReaderWindowPreferences(defaults: isUITest ? nil : .standard))
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hosted unit tests must not restore or write the user's window preferences.
        let isUITest = ProcessInfo.processInfo.arguments.contains("--promptly-ui-testing")
        guard isUITest || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        reader.setContent(ReaderHostingView(rootView: ReaderView(controller: reader)))
        reader.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        reader.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        reader.show()
        return false
    }
}
```

### `Promptly/Features/Reader/ReaderView.swift`

```swift
//
//  ReaderView.swift
//  Promptly
//
//  Created by Aykut Güven on 26.10.26.
//

import SwiftUI

struct ReaderView: View {
    let controller: ReaderWindowController
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @FocusState private var focusedControl: String?

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: controller.topInset).accessibilityHidden(true)
            controls
                .frame(height: ReaderWindowLayout.collapsedHeight)
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
                            .accessibilityIdentifier("reader.sample")
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
        .onChange(of: controller.keyboardFocusRequest) {
            focusedControl = "reader.collapse"
        }
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
            .overlay {
                ReaderDragHandle(isEnabled: controller.state.placement == .detached && !controller.state.isLocked,
                                 onDragEnded: controller.finishMoving)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)
            }
            .help(controller.state.isLocked ? "Unlock Position to move the prompter"
                  : controller.state.placement == .anchored ? "Detach Prompter to move it"
                  : "Drag to move the prompter")
            control(controller.state.isCollapsed ? "Expand Prompter" : "Collapse Prompter",
                    symbol: controller.state.isCollapsed ? "chevron.down" : "chevron.up",
                    id: "reader.collapse", action: controller.toggleExpansion)
            control(controller.state.isLocked ? "Unlock Position" : "Lock Position",
                    symbol: controller.state.isLocked ? "lock.fill" : "lock.open",
                    id: "reader.lock", action: controller.toggleLock)
            if controller.state.placement == .anchored {
                control("Detach Prompter", symbol: "arrow.up.left.and.arrow.down.right",
                        id: "reader.detach", action: controller.detach)
            } else {
                control("Return to Notch", symbol: "arrow.up.to.line",
                        id: "reader.return", action: controller.returnToNotch)
            }
            control("Hide Prompter", symbol: "xmark", id: "reader.hide", action: controller.hide)
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
        // Explicit focus also works when macOS's full keyboard navigation is disabled.
        .focusable()
        .focused($focusedControl, equals: id)
        .onKeyPress(.space, phases: .down) { _ in
            action()
            return .handled
        }
        .help(Text(title))
        .accessibilityIdentifier(id)
    }
}
```

### `Promptly/Features/Reader/ReaderMenu.swift`

```swift
//
//  ReaderMenu.swift
//  Promptly
//
//  Created by Aykut Güven on 26.10.26.
//

import SwiftUI

struct ReaderMenu: View {
    let controller: ReaderWindowController

    var body: some View {
        Button("Show Prompter", action: controller.show)
            .keyboardShortcut("o")
        Button("Focus Prompter", action: controller.focus)
            .keyboardShortcut("f", modifiers: [.command, .option])
        Divider()
        Button(controller.state.isCollapsed ? "Expand Prompter" : "Collapse Prompter",
               action: controller.toggleExpansion)
        Button(controller.state.isLocked ? "Unlock Position" : "Lock Position",
               action: controller.toggleLock)
        if controller.state.placement == .anchored {
            Button("Detach Prompter", action: controller.detach)
        }
        Button("Return to Notch", action: controller.returnToNotch)
            .keyboardShortcut("r", modifiers: [.command, .option])
        Divider()
        Button("Hide Prompter", action: controller.hide)
        if controller.preferenceFailure != nil {
            Text("Window preferences could not be restored or saved. Return to Notch to reset placement.")
        }
    }
}
```
