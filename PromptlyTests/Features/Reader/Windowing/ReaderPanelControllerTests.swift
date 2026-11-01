import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import Promptly

@MainActor
struct ReaderPanelControllerTests {
    private static let display = DisplayGeometry(
        id: 1, frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrame: CGRect(x: 0, y: 60, width: 1512, height: 884),
        safeAreaTop: 38, notchWidth: 180
    )

    @Test func programmaticLayoutDoesNotPublishMovementAndUserMovementReportsActualGeometry() {
        let panel = makePanel()
        let adapter = ReaderPanelController(panel: panel)
        defer { close(panel, adapter: adapter) }
        var events: [ReaderPanelEvent] = []
        adapter.onEvent = { events.append($0) }
        let layout = ReaderPanelLayout(
            frame: CGRect(x: 300, y: 300, width: 640, height: 320),
            placement: .detached, isMovable: true, isResizable: true,
            minimumSize: ReaderWindowLayoutConstants.minimumExpandedSize,
            maximumSize: Self.display.visibleFrame.size
        )

        adapter.apply(layout)
        #expect(panel.frame == layout.frame)
        #expect(events.isEmpty)

        let moved = layout.frame.offsetBy(dx: 20, dy: 20)
        panel.setFrame(moved, display: false)
        adapter.windowDidMove(Notification(name: NSWindow.didMoveNotification, object: panel))
        #expect(events.contains(.moved(frame: moved, displayID: adapter.displayID)))
    }

    @Test func nativeResizeCollapseAndLockRestoreExpandedGeometry() {
        let panel = makePanel()
        let adapter = ReaderPanelController(panel: panel, displayProvider: { [Self.display] }, primaryDisplayID: { 1 })
        let preferences = ReaderWindowStateStore(defaults: nil)
        let controller = ReaderWindowController(preferences: preferences, panel: adapter)
        defer {
            controller.stop()
            close(panel, adapter: adapter)
        }
        controller.start()
        #expect(panel.level == .statusBar)
        #expect(panel.frame.height == ReaderWindowLayoutConstants.defaultExpandedSize.height + Self.display.safeAreaTop)

        controller.detach()
        #expect(panel.level == .floating)
        #expect(panel.isMovable)
        #expect(panel.styleMask.contains(.resizable))
        let resized = CGRect(x: 400, y: 300, width: 720, height: 400)
        panel.setFrame(resized, display: false)
        adapter.windowDidEndLiveResize(Notification(name: NSWindow.didEndLiveResizeNotification, object: panel))
        #expect(controller.state.expandedSize == resized.size)

        controller.toggleExpansion()
        controller.toggleLock()
        #expect(panel.frame.height == ReaderWindowLayoutConstants.collapsedHeight)
        #expect(!panel.isMovable)
        #expect(!panel.styleMask.contains(.resizable))
        controller.toggleExpansion()
        #expect(panel.frame == resized)
        controller.returnToNotch()
        #expect(controller.state.isLocked)
        #expect(panel.level == .statusBar)
        #expect(panel.frame.maxY == Self.display.frame.maxY)
    }

    @Test func displayObservationIsIdempotentAndStopsUntilRestarted() {
        let panel = makePanel()
        let notifications = NotificationCenter()
        let adapter = ReaderPanelController(panel: panel, notificationCenter: notifications)
        defer { close(panel, adapter: adapter) }
        var displayChanges = 0
        adapter.onEvent = { if $0 == .displaysChanged { displayChanges += 1 } }

        adapter.startObservingDisplays()
        adapter.startObservingDisplays()
        notifications.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        #expect(displayChanges == 1)

        adapter.stopObservingDisplays()
        adapter.stopObservingDisplays()
        notifications.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        #expect(displayChanges == 1)

        adapter.startObservingDisplays()
        notifications.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        #expect(displayChanges == 2)
    }

    @Test func nativeCloseRequestHidesReaderAndFlushesPendingPlacement() throws {
        let suiteName = "PromptlyTests.ReaderPanelController.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let panel = makePanel()
        let adapter = ReaderPanelController(panel: panel, displayProvider: { [Self.display] }, primaryDisplayID: { 1 })
        let preferences = ReaderWindowStateStore(defaults: defaults)
        let controller = ReaderWindowController(preferences: preferences, panel: adapter)
        defer {
            controller.stop()
            close(panel, adapter: adapter)
            defaults.removePersistentDomain(forName: suiteName)
        }
        controller.start()
        controller.detach()
        let moved = CGRect(x: 400, y: 300, width: 700, height: 400)
        panel.setFrame(moved, display: false)
        adapter.windowDidMove(Notification(name: NSWindow.didMoveNotification, object: panel))
        #expect(try preferences.load().detachedFrame != moved)

        #expect(!adapter.windowShouldClose(panel))
        #expect(!panel.isVisible)
        #expect(controller.visibility == .hidden)
        #expect(try preferences.load().detachedFrame == moved)
    }

    private func makePanel() -> ReaderPanel {
        ReaderPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    }

    private func close(_ panel: ReaderPanel, adapter: ReaderPanelController) {
        adapter.stopObservingDisplays()
        panel.orderOut(nil)
        panel.delegate = nil
        panel.close()
    }
}
