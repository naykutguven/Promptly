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

    @State private var windowModel = PrompterWindowModel()

    var body: some Scene {
        MenuBarExtra("Promptly", systemImage: "text.viewfinder") {
            PrompterMenu(windowModel: windowModel)
            Divider()
            Button("Quit Promptly") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }

        Window("Prompter", id: PrompterWindowLayoutConstants.windowID) {
            PrompterView(windowModel: windowModel)
                .windowResizeBehavior(.enabled)
                .background {
                    PrompterWindowBridge { window in
                        windowModel.attach(window)
                    }
                }
                .onAppear {
                    windowModel.didRequestOpen()
                }
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .windowLevel(.floating)
        .windowBackgroundDragBehavior(.disabled)
        .defaultSize(PrompterWindowLayoutConstants.defaultExpandedSize)
        // TODO: Add default window placement.
        .defaultLaunchBehavior(.presented)
        .commandsRemoved()
    }
}
