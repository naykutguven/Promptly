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
