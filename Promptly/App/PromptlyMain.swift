//
//  PromptlyMain.swift
//  Promptly
//
//  Created by Aykut Güven on 17.11.26.
//

import Foundation
import SwiftUI

/// Starts Promptly, or in Debug builds a windowless host when Xcode runs unit tests
/// inside the app.
@main
enum PromptlyMain {
    /// UI tests pass this launch argument; they test the real app.
    static let uiTestingArgument = "--promptly-ui-testing"

    static func main() {
        #if DEBUG
            let processInfo = ProcessInfo.processInfo
            if isHostingUnitTests(environment: processInfo.environment, arguments: processInfo.arguments) {
                UnitTestHostApp.main()
                return
            }
        #endif
        PromptlyApp.main()
    }

    #if DEBUG
        /// Xcode sets the test configuration path in the app it hosts unit tests in.
        static func isHostingUnitTests(environment: [String: String], arguments: [String]) -> Bool {
            environment["XCTestConfigurationFilePath"] != nil && !arguments.contains(uiTestingArgument)
        }
    #endif
}

#if DEBUG
    /// Hosts unit tests without the menu-bar extra or the prompter window.
    private struct UnitTestHostApp: App {
        var body: some Scene {
            Settings {
                EmptyView()
            }
        }
    }
#endif
