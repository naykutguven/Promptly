//
//  PromptlyAppDelegate.swift
//  Promptly
//
//  Created by Aykut Güven on 26.10.26.
//

import AppKit
import SwiftUI

final class PromptlyAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        // TODO: A place for some cleanup - maybe to stop the timer and playback etc.
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
