//
//  PromptlyApp.swift
//  Promptly
//
//  Created by Aykut Güven on 25.10.26.
//

import SwiftUI

@main
struct PromptlyApp: App {
    @NSApplicationDelegateAdaptor(PromptlyAppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Promptly", systemImage: "text.viewfinder") {
            ReaderMenu(controller: appDelegate.reader)
        }
    }
}
