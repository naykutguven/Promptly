//
//  UnitTestHostTests.swift
//  PromptlyTests
//
//  Created by Aykut Güven on 17.11.26.
//

import AppKit
import Testing

@testable import Promptly

@MainActor
struct UnitTestHostTests {
    @Test func startsWindowlessHostOnlyForHostedUnitTests() {
        let hosted = ["XCTestConfigurationFilePath": "/synthetic/Promptly.xctestconfiguration"]
        #expect(PromptlyMain.isHostingUnitTests(environment: hosted, arguments: ["Promptly"]))
        #expect(
            !PromptlyMain.isHostingUnitTests(
                environment: hosted, arguments: ["Promptly", PromptlyMain.uiTestingArgument]))
        #expect(!PromptlyMain.isHostingUnitTests(environment: [:], arguments: ["Promptly"]))
    }

    /// Unit tests run inside the app, which must not create its prompter window or
    /// menu-bar extra while hosting them. Windows that other tests open are ignored.
    @Test func hostingUnitTestsCreatesNoPromptlyWindows() {
        let promptlyWindows = NSApplication.shared.windows.filter { window in
            window.identifier?.rawValue == PrompterWindowLayoutConstants.windowID || window.level == .statusBar
        }
        let windowTypes = promptlyWindows.map { String(describing: type(of: $0)) }
        #expect(promptlyWindows.isEmpty, "Promptly windows: \(windowTypes)")
    }
}
