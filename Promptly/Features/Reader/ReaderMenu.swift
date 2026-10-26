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
