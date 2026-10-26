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
