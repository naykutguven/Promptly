//
//  ReaderWindowControllerTests.swift
//  PromptlyTests
//
//  Created by Aykut Güven on 26.10.26.
//

import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import Promptly

@MainActor
struct ReaderWindowControllerTests {
    private static let primary = DisplayGeometry(
        id: 1, frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrame: CGRect(x: 0, y: 60, width: 1512, height: 884),
        safeAreaTop: 38, notchWidth: 180
    )
    private static let external = DisplayGeometry(
        id: 2, frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 1920, y: 60, width: 1920, height: 996),
        safeAreaTop: 0, notchWidth: 0
    )

    @Test func anchoredCollapseUsesRealPanelHeightAndRestoresExpandedSize() throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        fixture.controller.start()
        let expanded = fixture.panel.frame

        fixture.controller.toggleExpansion()
        #expect(fixture.panel.frame.height == ReaderWindowLayout.collapsedHeight + Self.primary.safeAreaTop)
        #expect(fixture.panel.frame.maxY == expanded.maxY)
        #expect(fixture.controller.state.expandedSize == ReaderWindowLayout.defaultExpandedSize)

        fixture.controller.toggleExpansion()
        #expect(fixture.panel.frame == expanded)
    }

    @Test func lockedCollapsedPanelCanReturnToNotchAndUnlock() throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        fixture.controller.start()
        fixture.controller.detach()
        #expect(fixture.panel.isMovable)
        #expect(fixture.panel.styleMask.contains(.resizable))

        fixture.controller.toggleExpansion()
        fixture.controller.toggleLock()
        #expect(!fixture.panel.isMovable)
        #expect(!fixture.panel.styleMask.contains(.resizable))
        #expect(fixture.panel.frame.height == ReaderWindowLayout.collapsedHeight)

        fixture.controller.returnToNotch()
        #expect(fixture.controller.state.placement == .anchored)
        #expect(fixture.controller.state.isLocked)
        #expect(fixture.controller.state.isCollapsed)
        #expect(fixture.panel.frame.maxY == Self.primary.frame.maxY)

        fixture.controller.toggleLock()
        #expect(!fixture.controller.state.isLocked)
    }

    @Test func restoredCollapsedDetachedPanelReexpandsToSavedGeometry() throws {
        var saved = ReaderWindowState()
        saved.placement = .detached
        saved.expansion = .collapsed
        saved.expandedSize = CGSize(width: 720, height: 400)
        saved.detachedFrame = CGRect(x: 400, y: 300, width: 720, height: 400)
        saved.displayID = Self.primary.id
        let fixture = try Fixture(savedState: saved)
        defer { fixture.close() }
        fixture.controller.start()
        #expect(fixture.panel.frame.height == ReaderWindowLayout.collapsedHeight)
        #expect(fixture.controller.state.detachedFrame == saved.detachedFrame)

        fixture.controller.toggleExpansion()
        #expect(fixture.panel.frame == saved.detachedFrame)
        let persisted = try fixture.preferences.load()
        #expect(persisted.expansion == .expanded)
        #expect(persisted.detachedFrame == saved.detachedFrame)
    }

    @Test func collapsedDetachedDragNearBottomSurvivesLockAndShow() throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        fixture.controller.start()
        fixture.controller.detach()
        fixture.controller.toggleExpansion()
        let bottomStrip = CGRect(x: 400, y: Self.primary.visibleFrame.minY,
                                 width: fixture.panel.frame.width,
                                 height: ReaderWindowLayout.collapsedHeight)
        fixture.panel.setFrame(bottomStrip, display: false)
        fixture.controller.finishMoving()
        #expect(fixture.panel.frame == bottomStrip)

        fixture.controller.toggleLock()
        fixture.controller.show()
        #expect(fixture.panel.frame == bottomStrip)
        #expect(fixture.controller.state.isLocked)
        #expect(fixture.controller.state.isCollapsed)

        fixture.controller.toggleExpansion()
        #expect(Self.primary.visibleFrame.contains(fixture.panel.frame))
        #expect(fixture.panel.frame.height == fixture.controller.state.expandedSize.height)
    }

    @Test func anchoredPlacementUsesPrimaryIDRatherThanDisplayListOrder() throws {
        let fixture = try Fixture(displays: [Self.external, Self.primary])
        defer { fixture.close() }
        fixture.controller.start()
        #expect(fixture.panel.frame.midX == Self.primary.frame.midX)
        #expect(fixture.panel.frame.maxY == Self.primary.frame.maxY)
        #expect(fixture.controller.topInset == Self.primary.safeAreaTop)
    }

    @Test func topologyChangesRepairDetachedPlacementAndStopRemovesObserver() throws {
        var saved = ReaderWindowState()
        saved.placement = .detached
        saved.detachedFrame = CGRect(x: 2200, y: 300, width: 640, height: 320)
        saved.displayID = Self.external.id
        let fixture = try Fixture(savedState: saved, displays: [Self.primary, Self.external])
        defer { fixture.close() }
        fixture.controller.start()
        fixture.controller.start()
        #expect(fixture.controller.state.displayID == Self.external.id)

        fixture.environment.displays = [Self.primary]
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        #expect(fixture.controller.state.displayID == Self.primary.id)
        #expect(Self.primary.visibleFrame.contains(fixture.panel.frame))

        fixture.controller.stop()
        let stoppedFrame = fixture.panel.frame
        fixture.environment.displays = [Self.external]
        fixture.environment.primaryID = Self.external.id
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        #expect(fixture.panel.frame == stoppedFrame)
        #expect(fixture.controller.visibility == .hidden)
        #expect(!fixture.panel.isVisible)
    }

    @Test func corruptPreferencesLeaveUsableDefaultPanelAndExposeFailure() throws {
        let fixture = try Fixture(corruptPreferences: true)
        defer { fixture.close() }
        #expect(fixture.controller.preferenceFailure != nil)
        #expect(fixture.controller.state == ReaderWindowState())
        fixture.controller.start()
        #expect(fixture.panel.frame.width > 0)
        #expect(fixture.panel.frame.height > 0)
        #expect(fixture.controller.visibility == .visible)
        fixture.controller.stop()
        #expect(fixture.defaults.data(forKey: "reader.windowPlacement.v1") == Data("invalid placement".utf8))
        fixture.controller.returnToNotch()
        #expect(fixture.controller.preferenceFailure == nil)
        #expect(try fixture.preferences.load() == ReaderWindowState())
    }

    @Test func hidingFlushesLatestDetachedFrameBeforeDebouncedSave() throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        fixture.controller.start()
        fixture.controller.detach()
        let latest = CGRect(x: 360, y: 300, width: 700, height: 400)
        fixture.panel.setFrame(latest, display: false)
        if fixture.controller.state.detachedFrame != latest {
            fixture.controller.windowDidMove(Notification(name: NSWindow.didMoveNotification, object: fixture.panel))
        }
        #expect(fixture.controller.state.detachedFrame == latest)
        #expect(try fixture.preferences.load().detachedFrame != latest)

        // No suspension occurs between moving and hiding; the debounce cannot commit first.
        fixture.controller.hide()
        let reopened = try ReaderWindowPreferences(defaults: fixture.defaults).load()
        #expect(reopened.placement == .detached)
        #expect(reopened.detachedFrame == latest)
        #expect(reopened.expandedSize == latest.size)
        #expect(fixture.controller.visibility == .hidden)
        #expect(!fixture.panel.isVisible)

        fixture.controller.show()
        #expect(fixture.panel.frame == latest)
        #expect(fixture.controller.visibility == .visible)
    }

    @Test func stoppingFlushesLatestDetachedFrameBeforeDebouncedSave() throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        fixture.controller.start()
        fixture.controller.detach()
        let latest = CGRect(x: 390, y: 310, width: 680, height: 380)
        fixture.panel.setFrame(latest, display: false)
        if fixture.controller.state.detachedFrame != latest {
            fixture.controller.windowDidMove(Notification(name: NSWindow.didMoveNotification, object: fixture.panel))
        }
        #expect(fixture.controller.state.detachedFrame == latest)
        #expect(try fixture.preferences.load().detachedFrame != latest)

        fixture.controller.stop()
        let reopened = try ReaderWindowPreferences(defaults: fixture.defaults).load()
        #expect(reopened.placement == .detached)
        #expect(reopened.detachedFrame == latest)
        #expect(reopened.expandedSize == latest.size)
        #expect(fixture.controller.visibility == .hidden)
        #expect(!fixture.panel.isVisible)
    }

    @Test func showingPreservesRestoredDetachedCollapsedLockedState() throws {
        var saved = ReaderWindowState()
        saved.placement = .detached
        saved.expansion = .collapsed
        saved.positionLock = .locked
        saved.expandedSize = CGSize(width: 720, height: 400)
        saved.detachedFrame = CGRect(x: 400, y: 300, width: 720, height: 400)
        saved.displayID = Self.primary.id
        let fixture = try Fixture(savedState: saved)
        defer { fixture.close() }
        fixture.controller.start()
        let collapsedFrame = fixture.panel.frame

        fixture.controller.hide()
        fixture.controller.show()
        fixture.controller.show()

        #expect(fixture.controller.state == saved)
        #expect(fixture.panel.frame == collapsedFrame)
        #expect(fixture.panel.frame.height == ReaderWindowLayout.collapsedHeight)
        #expect(!fixture.panel.isMovable)
        #expect(!fixture.panel.styleMask.contains(.resizable))
        #expect(fixture.controller.visibility == .visible)
        #expect(try fixture.preferences.load() == saved)
    }

    @Test func anchoredLockedCollapsedPanelFollowsPrimaryDisplayChanges() throws {
        let fixture = try Fixture(displays: [Self.primary, Self.external])
        defer { fixture.close() }
        fixture.controller.start()
        fixture.controller.toggleExpansion()
        fixture.controller.toggleLock()
        let expandedSize = fixture.controller.state.expandedSize

        fixture.environment.primaryID = Self.external.id
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        #expect(fixture.panel.frame.midX == Self.external.frame.midX)
        #expect(fixture.panel.frame.maxY == Self.external.visibleFrame.maxY)
        #expect(fixture.panel.frame.height == ReaderWindowLayout.collapsedHeight)
        #expect(fixture.controller.topInset == 0)
        #expect(fixture.controller.state.isCollapsed)
        #expect(fixture.controller.state.isLocked)

        fixture.environment.primaryID = Self.primary.id
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        #expect(fixture.panel.frame.midX == Self.primary.frame.midX)
        #expect(fixture.panel.frame.maxY == Self.primary.frame.maxY)
        #expect(fixture.panel.frame.height == ReaderWindowLayout.collapsedHeight + Self.primary.safeAreaTop)
        #expect(fixture.controller.topInset == Self.primary.safeAreaTop)
        #expect(fixture.controller.state.placement == .anchored)
        #expect(fixture.controller.state.isCollapsed)
        #expect(fixture.controller.state.isLocked)
        #expect(fixture.controller.state.expandedSize == expandedSize)
    }

    private final class DisplayEnvironment {
        var displays: [DisplayGeometry]
        var primaryID: UInt32

        init(displays: [DisplayGeometry], primaryID: UInt32) {
            self.displays = displays
            self.primaryID = primaryID
        }
    }

    private struct Fixture {
        let suiteName: String
        let defaults: UserDefaults
        let preferences: ReaderWindowPreferences
        let panel: ReaderPanel
        let environment: DisplayEnvironment
        let controller: ReaderWindowController

        init(savedState: ReaderWindowState? = nil,
             displays: [DisplayGeometry] = [ReaderWindowControllerTests.primary],
             corruptPreferences: Bool = false) throws {
            suiteName = "PromptlyTests.ReaderWindowController.\(UUID().uuidString)"
            defaults = try #require(UserDefaults(suiteName: suiteName))
            preferences = ReaderWindowPreferences(defaults: defaults)
            if let savedState { try preferences.save(savedState) }
            if corruptPreferences {
                defaults.set(Data("invalid placement".utf8), forKey: "reader.windowPlacement.v1")
            }
            panel = ReaderPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: true)
            environment = DisplayEnvironment(displays: displays, primaryID: ReaderWindowControllerTests.primary.id)
            let environment = environment
            controller = ReaderWindowController(preferences: preferences, panel: panel,
                                                displayProvider: { environment.displays },
                                                primaryDisplayID: { environment.primaryID })
        }

        func close() {
            controller.stop()
            panel.orderOut(nil)
            panel.delegate = nil
            panel.close()
            defaults.removePersistentDomain(forName: suiteName)
        }
    }
}
