//
//  ReaderWindowUITests.swift
//  PromptlyUITests
//
//  Created by Aykut Güven on 26.10.26.
//

import XCTest

nonisolated final class ReaderWindowUITests: XCTestCase {
    @MainActor
    func testMenuRecoversLockedCollapsedReaderAndQuits() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--promptly-ui-testing"]
        app.launch()
        defer {
            if app.state != .notRunning { app.terminate() }
        }
        let window = app.descendants(matching: .any).matching(identifier: "reader.window").firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        let expandedHeight = window.frame.height

        chooseMenuItem("Detach Prompter", in: app)
        XCTAssertTrue(app.buttons["reader.return"].waitForExistence(timeout: 2))
        chooseMenuItem("Collapse Prompter", in: app)
        chooseMenuItem("Lock Position", in: app)
        XCTAssertEqual(app.buttons["reader.collapse"].label, "Expand Prompter")
        XCTAssertEqual(app.buttons["reader.lock"].label, "Unlock Position")

        chooseMenuItem("Hide Prompter", in: app)
        XCTAssertFalse(window.exists)
        chooseMenuItem("Return to Notch", in: app)
        XCTAssertTrue(app.buttons["reader.detach"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["reader.collapse"].label, "Expand Prompter")
        XCTAssertEqual(app.buttons["reader.lock"].label, "Unlock Position")
        chooseMenuItem("Expand Prompter", in: app)
        chooseMenuItem("Unlock Position", in: app)
        XCTAssertEqual(window.frame.height, expandedHeight, accuracy: 1)
        XCTAssertEqual(app.buttons["reader.lock"].label, "Lock Position")

        chooseMenuItem("Hide Prompter", in: app)
        XCTAssertFalse(window.exists)
        chooseMenuItem("Show Prompter", in: app)
        XCTAssertTrue(window.waitForExistence(timeout: 2))
        chooseMenuItem("Quit Promptly", in: app)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
    }

    @MainActor
    private func chooseMenuItem(_ title: String, in app: XCUIApplication,
                                file: StaticString = #filePath, line: UInt = #line) {
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 2), file: file, line: line)
        statusItem.click()
        let item = statusItem.menuItems[title]
        XCTAssertTrue(item.waitForExistence(timeout: 2), file: file, line: line)
        item.click()
    }

    @MainActor
    func testResizingPreservesSampleTextAndFontSize() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--promptly-ui-testing"]
        app.launch()
        defer { app.terminate() }

        let window = app.descendants(matching: .any).matching(identifier: "reader.window").firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        app.buttons["reader.detach"].click()
        let sample = app.staticTexts["reader.sample"]
        XCTAssertTrue(sample.waitForExistence(timeout: 2))
        let originalText = sample.value as? String ?? sample.label
        let originalTextHeight = sample.frame.height
        let originalWindow = window.frame

        // Keep the width fixed and leave enough room for the full sample, while
        // crossing the old compact-layout threshold. Equal text height detects a font change.
        let bottomEdge = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1))
            .withOffset(CGVector(dx: 0, dy: -1))
        bottomEdge.click(forDuration: 0.1, thenDragTo: bottomEdge.withOffset(CGVector(dx: 0, dy: -60)))
        XCTAssertLessThan(window.frame.height, originalWindow.height - 40)
        XCTAssertEqual(window.frame.width, originalWindow.width, accuracy: 1)
        XCTAssertEqual(sample.frame.height, originalTextHeight, accuracy: 1)
        XCTAssertEqual(sample.value as? String ?? sample.label, originalText)

        let rightEdge = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: -1, dy: 0))
        rightEdge.click(forDuration: 0.1, thenDragTo: rightEdge.withOffset(CGVector(dx: -180, dy: 0)))
        XCTAssertLessThan(window.frame.width, 500)
        XCTAssertEqual(sample.value as? String ?? sample.label, originalText)
        XCTAssertTrue(app.buttons["reader.collapse"].isHittable)
        XCTAssertTrue(app.buttons["reader.lock"].isHittable)
    }

    @MainActor
    func testDraggingEmptyHeaderAcrossWindowStates() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--promptly-ui-testing"]
        app.launch()
        defer { app.terminate() }

        let window = app.descendants(matching: .any).matching(identifier: "reader.window").firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        app.buttons["reader.detach"].click()

        // The empty header should drag just like its title, across repeated state changes.
        dragEmptyHeader(of: window, offset: CGVector(dx: 24, dy: 32))
        dragEmptyHeader(of: window, offset: CGVector(dx: -24, dy: -32))
        app.buttons["reader.collapse"].click()
        dragEmptyHeader(of: window, offset: CGVector(dx: 24, dy: 32))
        app.buttons["reader.lock"].click()
        dragEmptyHeader(of: window, offset: CGVector(dx: -24, dy: 32), shouldMove: false)
        app.buttons["reader.lock"].click()
        dragEmptyHeader(of: window, offset: CGVector(dx: -24, dy: -32))
        app.buttons["reader.collapse"].click()
        dragEmptyHeader(of: window, offset: CGVector(dx: 24, dy: 32))
    }

    @MainActor
    private func dragEmptyHeader(of window: XCUIElement, offset: CGVector, shouldMove: Bool = true,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let before = window.frame
        let header = window.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0))
            .withOffset(CGVector(dx: 0, dy: 29))
        header.click(forDuration: 0.1, thenDragTo: header.withOffset(offset))
        XCTAssertEqual(window.frame.minX, before.minX + (shouldMove ? offset.dx : 0), accuracy: 3,
                       file: file, line: line)
        XCTAssertEqual(window.frame.minY, before.minY + (shouldMove ? offset.dy : 0), accuracy: 3,
                       file: file, line: line)
    }

    @MainActor
    func testMenuRecoveryAndKeyboardControls() {
        let app = XCUIApplication()
        app.launchArguments = ["--promptly-ui-testing"]
        app.launch()
        defer { app.terminate() }

        let collapse = app.buttons["reader.collapse"]
        XCTAssertTrue(collapse.waitForExistence(timeout: 5))
        app.buttons["reader.hide"].click()
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 2))
        statusItem.click()
        app.menuItems["Focus Prompter"].click()
        XCTAssertTrue(collapse.waitForExistence(timeout: 2))
        collapse.typeKey(XCUIKeyboardKey.space, modifierFlags: [])
        XCTAssertEqual(collapse.label, "Expand Prompter")
        collapse.typeKey(XCUIKeyboardKey.tab, modifierFlags: [])
        let lock = app.buttons["reader.lock"]
        lock.typeKey(XCUIKeyboardKey.space, modifierFlags: [])
        XCTAssertEqual(lock.label, "Unlock Position")
        lock.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        lock.typeKey(XCUIKeyboardKey.space, modifierFlags: [])
        XCTAssertEqual(lock.label, "Unlock Position")
        XCTAssertTrue(collapse.exists)
    }

    @MainActor
    func testWindowJourneyAndLockedEscape() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--promptly-ui-testing"]
        app.launch()
        defer { app.terminate() }

        // AppKit exposes a nonactivating NSPanel as a dialog rather than a regular window.
        let window = app.descendants(matching: .any).matching(identifier: "reader.window").firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        let expandedHeight = window.frame.height
        app.buttons["reader.detach"].click()
        XCTAssertTrue(app.buttons["reader.return"].waitForExistence(timeout: 2))
        let detachedOrigin = window.frame.origin
        let title = window.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.09))
        title.click(forDuration: 0.1, thenDragTo: title.withOffset(CGVector(dx: 40, dy: 60)))
        XCTAssertGreaterThan(window.frame.minY, detachedOrigin.y + 10)
        let beforeResize = window.frame.height
        let bottomEdge = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1))
            .withOffset(CGVector(dx: 0, dy: -1))
        bottomEdge.click(forDuration: 0.1, thenDragTo: bottomEdge.withOffset(CGVector(dx: 0, dy: 40)))
        XCTAssertGreaterThan(window.frame.height, beforeResize + 10)
        let detachedHeight = window.frame.height

        app.buttons["reader.collapse"].click()
        XCTAssertLessThan(window.frame.height, detachedHeight)
        XCTAssertEqual(window.frame.height, 58, accuracy: 1)
        app.buttons["reader.lock"].click()
        XCTAssertEqual(app.buttons["reader.lock"].label, "Unlock Position")
        app.buttons["reader.collapse"].click()
        XCTAssertEqual(window.frame.height, detachedHeight, accuracy: 1)

        // Explicit return remains an escape even when the position is locked.
        app.buttons["reader.return"].click()
        XCTAssertTrue(app.buttons["reader.detach"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["reader.lock"].label, "Unlock Position")
        XCTAssertGreaterThanOrEqual(window.frame.height, expandedHeight)
        let screenshot = XCTAttachment(screenshot: window.screenshot())
        screenshot.name = "Synthetic anchored reader"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
