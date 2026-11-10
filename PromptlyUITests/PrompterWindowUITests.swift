//
//  PrompterWindowUITests.swift
//  PromptlyUITests
//
//  Created by Aykut Güven on 26.10.26.
//

import AppKit
import CoreGraphics
import XCTest

nonisolated final class PrompterWindowUITests: XCTestCase {
    @MainActor
    func testPrompterStartsAtTopOfConfiguredPrimaryDisplay() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--promptly-ui-testing"]
        app.launch()
        defer { app.terminate() }
        let window = app.descendants(matching: .any).matching(identifier: "prompter.window").firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        let primaryID = CGMainDisplayID()
        let screen = try XCTUnwrap(NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == primaryID
        })
        let bounds = CGDisplayBounds(primaryID)
        let top = screen.safeAreaInsets.top > 0 ? bounds.minY
            : bounds.minY + screen.frame.maxY - screen.visibleFrame.maxY
        XCTAssertEqual(window.frame.midX, bounds.midX, accuracy: 1)
        XCTAssertEqual(window.frame.minY, top, accuracy: 1)
        XCTAssertEqual(window.frame.height, 320 + screen.safeAreaInsets.top, accuracy: 1)
    }

    @MainActor
    func testMenuRecoversLockedCollapsedPrompterAndQuits() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--promptly-ui-testing"]
        app.launch()
        defer {
            if app.state != .notRunning { app.terminate() }
        }
        let window = app.descendants(matching: .any).matching(identifier: "prompter.window").firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        let expandedHeight = window.frame.height

        chooseMenuItem("Detach Prompter", in: app)
        XCTAssertTrue(app.buttons["prompter.return"].waitForExistence(timeout: 2))
        chooseMenuItem("Collapse Prompter", in: app)
        chooseMenuItem("Lock Position", in: app)
        XCTAssertEqual(app.buttons["prompter.collapse"].label, "Expand Prompter")
        XCTAssertEqual(app.buttons["prompter.lock"].label, "Unlock Position")

        let detachedCollapsedFrame = window.frame
        app.buttons["prompter.hide"].click()
        XCTAssertFalse(window.exists)
        chooseMenuItem("Show Prompter", in: app)
        XCTAssertTrue(window.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["prompter.return"].exists)
        XCTAssertEqual(app.buttons["prompter.collapse"].label, "Expand Prompter")
        XCTAssertEqual(app.buttons["prompter.lock"].label, "Unlock Position")
        XCTAssertEqual(window.frame, detachedCollapsedFrame)

        chooseMenuItem("Hide Prompter", in: app)
        XCTAssertFalse(window.exists)
        chooseMenuItem("Show Prompter", in: app)
        XCTAssertTrue(window.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["prompter.return"].exists)
        XCTAssertEqual(app.buttons["prompter.collapse"].label, "Expand Prompter")
        XCTAssertEqual(app.buttons["prompter.lock"].label, "Unlock Position")
        XCTAssertEqual(window.frame, detachedCollapsedFrame)
        chooseMenuItem("Return to Notch", in: app)
        XCTAssertTrue(app.buttons["prompter.detach"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["prompter.collapse"].label, "Expand Prompter")
        XCTAssertEqual(app.buttons["prompter.lock"].label, "Unlock Position")
        chooseMenuItem("Expand Prompter", in: app)
        chooseMenuItem("Unlock Position", in: app)
        XCTAssertEqual(window.frame.height, expandedHeight, accuracy: 1)
        XCTAssertEqual(app.buttons["prompter.lock"].label, "Lock Position")

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
        XCTAssertTrue(item.waitForExistence(timeout: 2), statusItem.debugDescription, file: file, line: line)
        item.click()
    }

    @MainActor
    func testResizingPreservesSampleTextAndFontSize() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--promptly-ui-testing"]
        app.launch()
        defer { app.terminate() }

        let window = app.descendants(matching: .any).matching(identifier: "prompter.window").firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        app.buttons["prompter.detach"].click()
        let sample = app.staticTexts["prompter.sample"]
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
        XCTAssertTrue(app.buttons["prompter.collapse"].isHittable)
        XCTAssertTrue(app.buttons["prompter.lock"].isHittable)
    }

    @MainActor
    func testDraggingEmptyHeaderAcrossWindowStates() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--promptly-ui-testing"]
        app.launch()
        defer { app.terminate() }

        let window = app.descendants(matching: .any).matching(identifier: "prompter.window").firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        app.buttons["prompter.detach"].click()

        // The empty header should drag just like its title, across repeated state changes.
        dragEmptyHeader(of: window, offset: CGVector(dx: 64, dy: 80))
        dragEmptyHeader(of: window, offset: CGVector(dx: -64, dy: -80))
        app.buttons["prompter.collapse"].click()
        dragEmptyHeader(of: window, offset: CGVector(dx: 64, dy: 80))
        app.buttons["prompter.lock"].click()
        dragEmptyHeader(of: window, offset: CGVector(dx: -64, dy: 80), shouldMove: false)
        app.buttons["prompter.lock"].click()
        dragEmptyHeader(of: window, offset: CGVector(dx: -64, dy: -80))
        app.buttons["prompter.collapse"].click()
        dragEmptyHeader(of: window, offset: CGVector(dx: 64, dy: 80))
    }

    @MainActor
    private func dragEmptyHeader(of window: XCUIElement, offset: CGVector, shouldMove: Bool = true,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let before = window.frame
        let header = window.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0))
            .withOffset(CGVector(dx: 0, dy: 29))
        header.click(forDuration: 0.1, thenDragTo: header.withOffset(offset))
        let after = window.frame
        if shouldMove {
            // Native window dragging consumes initial pointer travel before movement starts.
            let xTravel = (after.minX - before.minX) * (offset.dx > 0 ? 1 : -1)
            let yTravel = (after.minY - before.minY) * (offset.dy > 0 ? 1 : -1)
            XCTAssertGreaterThan(xTravel, abs(offset.dx) * 0.5, file: file, line: line)
            XCTAssertGreaterThan(yTravel, abs(offset.dy) * 0.5, file: file, line: line)
            XCTAssertLessThanOrEqual(xTravel, abs(offset.dx) + 3, file: file, line: line)
            XCTAssertLessThanOrEqual(yTravel, abs(offset.dy) + 3, file: file, line: line)
        } else {
            XCTAssertEqual(after.minX, before.minX, accuracy: 1, file: file, line: line)
            XCTAssertEqual(after.minY, before.minY, accuracy: 1, file: file, line: line)
        }
    }

    @MainActor
    func testMenuRecoveryKeepsPointerControlsAvailable() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--promptly-ui-testing"]
        app.launch()
        defer { app.terminate() }

        let collapse = app.buttons["prompter.collapse"]
        XCTAssertTrue(collapse.waitForExistence(timeout: 5))
        app.buttons["prompter.hide"].click()
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 2))
        statusItem.click()
        let show = statusItem.menuItems["Show Prompter"]
        XCTAssertTrue(show.waitForExistence(timeout: 2), statusItem.debugDescription)
        XCTAssertFalse(statusItem.menuItems["Focus Prompter"].exists)
        show.click()
        XCTAssertTrue(collapse.waitForExistence(timeout: 2))
        collapse.click()
        XCTAssertEqual(collapse.label, "Expand Prompter")
        let lock = app.buttons["prompter.lock"]
        lock.click()
        XCTAssertEqual(lock.label, "Unlock Position")
        XCTAssertTrue(collapse.exists)
    }

    @MainActor
    func testWindowJourneyAndLockedEscape() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--promptly-ui-testing"]
        app.launch()
        defer { app.terminate() }

        // SwiftUI owns the prompter window; its accessibility identifier is stable across reopening.
        let window = app.descendants(matching: .any).matching(identifier: "prompter.window").firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        let expandedHeight = window.frame.height
        app.buttons["prompter.detach"].click()
        XCTAssertTrue(app.buttons["prompter.return"].waitForExistence(timeout: 2))
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

        app.buttons["prompter.collapse"].click()
        XCTAssertLessThan(window.frame.height, detachedHeight)
        XCTAssertEqual(window.frame.height, 58, accuracy: 1)
        app.buttons["prompter.lock"].click()
        XCTAssertEqual(app.buttons["prompter.lock"].label, "Unlock Position")
        app.buttons["prompter.collapse"].click()
        XCTAssertEqual(window.frame.height, detachedHeight, accuracy: 1)

        let lockedFrame = window.frame
        let lockedBottom = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1))
            .withOffset(CGVector(dx: 0, dy: -1))
        lockedBottom.click(forDuration: 0.1, thenDragTo: lockedBottom.withOffset(CGVector(dx: 0, dy: 40)))
        XCTAssertEqual(window.frame, lockedFrame)

        // Explicit return remains an escape even when the position is locked.
        app.buttons["prompter.return"].click()
        XCTAssertTrue(app.buttons["prompter.detach"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["prompter.lock"].label, "Unlock Position")
        XCTAssertGreaterThanOrEqual(window.frame.height, expandedHeight)
        let screenshot = XCTAttachment(screenshot: window.screenshot())
        screenshot.name = "Synthetic anchored prompter"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
