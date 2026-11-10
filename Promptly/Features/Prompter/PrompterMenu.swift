//
//  PrompterMenu.swift
//  Promptly
//
//  Created by Aykut Güven on 26.10.26.
//

import SwiftUI

struct PrompterMenu: View {
    let windowModel: PrompterWindowModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(windowModel.isShowing ? "Hide Prompter" : "Show Prompter") {
            if windowModel.isShowing {
                windowModel.hide()
            } else if !windowModel.showExisting() {
                windowModel.didRequestOpen()

                NSApp.activate()
                openWindow(id: PrompterWindowLayoutConstants.windowID)
            }
        }

        Button(windowModel.isLocked ? "Unlock Position" : "Lock Position") {
            windowModel.isLocked.toggle()
        }

        Button(windowModel.isAttachedToNotch ? "Detach Prompter" : "Attach Prompter") {
            windowModel.isAttachedToNotch.toggle()
        }

        Button("Return to Notch") {
            windowModel.moveNearNotch()
        }
        .keyboardShortcut("r", modifiers: [.command, .option])
        .disabled(!windowModel.canMoveNearNotch)
    }

}
