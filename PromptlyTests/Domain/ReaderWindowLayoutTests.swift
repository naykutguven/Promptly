//
//  ReaderWindowLayoutTests.swift
//  PromptlyTests
//
//  Created by Aykut Güven on 26.10.26.
//

import CoreGraphics
import Foundation
import Testing
@testable import Promptly

@MainActor
struct ReaderWindowLayoutTests {
    private let primary = DisplayGeometry(
        id: 1,
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrame: CGRect(x: 0, y: 60, width: 1512, height: 884),
        safeAreaTop: 38,
        notchWidth: 180
    )

    private let external = DisplayGeometry(
        id: 2,
        frame: CGRect(x: 3000, y: 200, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 3000, y: 260, width: 1920, height: 996),
        safeAreaTop: 0,
        notchWidth: 0
    )

    @Test func anchoredPanelIncludesCameraHousingAboveContent() {
        let frame = ReaderWindowLayout.anchoredFrame(
            on: primary, expandedSize: CGSize(width: 640, height: 320), expansion: .expanded
        )
        #expect(frame.midX == primary.frame.midX)
        #expect(frame.maxY == primary.frame.maxY)
        #expect(frame.height == 320 + primary.safeAreaTop)
        #expect(frame.width > primary.notchWidth)
    }

    @Test func noNotchPanelLeavesMenuBarAvailable() {
        let frame = ReaderWindowLayout.anchoredFrame(
            on: external, expandedSize: CGSize(width: 640, height: 320), expansion: .expanded
        )
        #expect(frame.maxY == external.visibleFrame.maxY)
        #expect(frame.midX == external.frame.midX)
        #expect(frame.height == 320)
    }

    @Test func collapsingAnchoredPanelRetainsNotchIntegration() {
        let frame = ReaderWindowLayout.anchoredFrame(
            on: primary, expandedSize: CGSize(width: 640, height: 320), expansion: .collapsed
        )
        #expect(frame.maxY == primary.frame.maxY)
        #expect(frame.height == ReaderWindowLayout.collapsedHeight + primary.safeAreaTop)
    }

    @Test func savedDisplayIsPreferredOverAnotherIntersectingDisplay() throws {
        let result = try #require(ReaderWindowLayout.restoredDetachedPlacement(
            frame: CGRect(x: 400, y: 300, width: 640, height: 320),
            displayID: external.id, expandedSize: CGSize(width: 640, height: 320),
            expansion: .expanded, displays: [primary, external], primaryDisplayID: primary.id
        ))
        #expect(result.displayID == external.id)
        #expect(external.visibleFrame.contains(result.frame))
    }

    @Test func positionInDisplayGapFallsBackToPrimary() throws {
        let result = try #require(ReaderWindowLayout.restoredDetachedPlacement(
            frame: CGRect(x: 2000, y: 400, width: 640, height: 320),
            displayID: nil, expandedSize: CGSize(width: 640, height: 320),
            expansion: .expanded, displays: [external, primary], primaryDisplayID: primary.id
        ))
        #expect(result.displayID == primary.id)
        #expect(primary.visibleFrame.contains(result.frame))
    }

    @Test func missingSavedDisplayUsesActualIntersection() throws {
        let result = try #require(ReaderWindowLayout.restoredDetachedPlacement(
            frame: CGRect(x: 3400, y: 500, width: 640, height: 320),
            displayID: 99, expandedSize: CGSize(width: 640, height: 320),
            expansion: .expanded, displays: [primary, external], primaryDisplayID: primary.id
        ))
        #expect(result.displayID == external.id)
        #expect(result.frame.origin == CGPoint(x: 3400, y: 500))
    }

    @Test func disconnectedDisplayPlacementRemainsReachable() throws {
        let result = try #require(ReaderWindowLayout.restoredDetachedPlacement(
            frame: CGRect(x: 3400, y: 500, width: 640, height: 320),
            displayID: external.id, expandedSize: CGSize(width: 640, height: 320),
            expansion: .expanded, displays: [primary], primaryDisplayID: primary.id
        ))
        #expect(result.displayID == primary.id)
        #expect(primary.visibleFrame.contains(result.frame))
    }

    @Test func detachedWindowSupportsNegativeDisplayOrigins() throws {
        let left = DisplayGeometry(
            id: 3, frame: CGRect(x: -1920, y: -200, width: 1920, height: 1080),
            visibleFrame: CGRect(x: -1920, y: -140, width: 1920, height: 996),
            safeAreaTop: 0, notchWidth: 0
        )
        let result = try #require(ReaderWindowLayout.restoredDetachedPlacement(
            frame: CGRect(x: -2100, y: -400, width: 640, height: 320),
            displayID: left.id, expandedSize: CGSize(width: 640, height: 320),
            expansion: .expanded, displays: [primary, left], primaryDisplayID: primary.id
        ))
        #expect(result.displayID == left.id)
        #expect(left.visibleFrame.contains(result.frame))
        #expect(result.frame.minX < 0)
    }

    @Test func scalingAndOversizedWindowsClampToActualVisibleBounds() throws {
        let small = DisplayGeometry(
            id: 1, frame: CGRect(x: 0, y: 0, width: 300, height: 220),
            visibleFrame: CGRect(x: 0, y: 20, width: 300, height: 176),
            safeAreaTop: 0, notchWidth: 0
        )
        let result = try #require(ReaderWindowLayout.restoredDetachedPlacement(
            frame: CGRect(x: 900, y: 800, width: 1000, height: 700),
            displayID: small.id, expandedSize: CGSize(width: 1000, height: 700),
            expansion: .expanded, displays: [small], primaryDisplayID: small.id
        ))
        #expect(result.frame == small.visibleFrame)
    }

    @Test func collapseAndExpansionUseSavedExpandedTopEdge() {
        let expanded = CGRect(x: 400, y: 400, width: 700, height: 400)
        let collapsed = ReaderWindowLayout.detachedFrame(
            fromExpandedFrame: expanded, expansion: .collapsed, on: primary
        )
        let restored = ReaderWindowLayout.detachedFrame(
            fromExpandedFrame: expanded, expansion: .expanded, on: primary
        )
        #expect(collapsed.maxY == expanded.maxY)
        #expect(collapsed.height == ReaderWindowLayout.collapsedHeight)
        #expect(restored == expanded)
    }

    @Test func malformedSavedGeometryFallsBackToSafeDefaults() throws {
        let result = try #require(ReaderWindowLayout.restoredDetachedPlacement(
            frame: CGRect(x: CGFloat.nan, y: 0, width: -4, height: CGFloat.infinity),
            displayID: nil, expandedSize: CGSize(width: CGFloat.nan, height: -1),
            expansion: .expanded, displays: [external, primary], primaryDisplayID: primary.id
        ))
        #expect(result.displayID == primary.id)
        #expect(primary.visibleFrame.contains(result.frame))
        #expect(result.frame.size == ReaderWindowLayout.defaultExpandedSize)
    }

    @Test func collapsedPlacementRetainsTopWhenHiddenExpandedGeometryIsOffscreen() throws {
        let saved = CGRect(x: 400, y: -200, width: 700, height: 600)
        let collapsed = try #require(ReaderWindowLayout.restoredDetachedPlacement(
            frame: saved, displayID: primary.id, expandedSize: saved.size,
            expansion: .collapsed, displays: [primary], primaryDisplayID: primary.id
        ))
        let savedExpanded = CGRect(x: collapsed.frame.minX,
                                   y: collapsed.frame.maxY - saved.height,
                                   width: collapsed.frame.width, height: saved.height)
        let reopened = try #require(ReaderWindowLayout.restoredDetachedPlacement(
            frame: savedExpanded, displayID: primary.id, expandedSize: saved.size,
            expansion: .collapsed, displays: [primary], primaryDisplayID: primary.id
        ))
        let expanded = try #require(ReaderWindowLayout.restoredDetachedPlacement(
            frame: savedExpanded, displayID: primary.id, expandedSize: saved.size,
            expansion: .expanded, displays: [primary], primaryDisplayID: primary.id
        ))
        #expect(collapsed.frame == reopened.frame)
        #expect(collapsed.frame.maxY == saved.maxY)
        #expect(savedExpanded.minY < primary.visibleFrame.minY)
        #expect(primary.visibleFrame.contains(expanded.frame))
    }

    @Test func negativeSavedDimensionsAreRejectedRatherThanStandardized() throws {
        let result = try #require(ReaderWindowLayout.restoredDetachedPlacement(
            frame: CGRect(x: 400, y: 500, width: -700, height: -300),
            displayID: primary.id, expandedSize: ReaderWindowLayout.defaultExpandedSize,
            expansion: .expanded, displays: [primary], primaryDisplayID: primary.id
        ))
        #expect(result.frame.size == ReaderWindowLayout.defaultExpandedSize)
        #expect(primary.visibleFrame.contains(result.frame))
    }

    @Test func noScreensProducesNoPlacement() {
        #expect(ReaderWindowLayout.restoredDetachedPlacement(
            frame: nil, displayID: nil, expandedSize: ReaderWindowLayout.defaultExpandedSize,
            expansion: .expanded, displays: [], primaryDisplayID: nil
        ) == nil)
    }

    @Test func invalidDisplaySnapshotsAreExcludedFromRestoration() throws {
        let invalidFrame = DisplayGeometry(
            id: 90, frame: .zero, visibleFrame: primary.visibleFrame,
            safeAreaTop: 0, notchWidth: 0
        )
        let invalidVisibleFrame = DisplayGeometry(
            id: 91, frame: external.frame, visibleFrame: .zero,
            safeAreaTop: 0, notchWidth: 0
        )
        let saved = CGRect(x: 4000, y: 300, width: 640, height: 320)
        let result = try #require(ReaderWindowLayout.restoredDetachedPlacement(
            frame: saved, displayID: invalidVisibleFrame.id,
            expandedSize: ReaderWindowLayout.defaultExpandedSize,
            expansion: .expanded, displays: [invalidFrame, invalidVisibleFrame, primary],
            primaryDisplayID: invalidFrame.id
        ))

        #expect(result.displayID == primary.id)
        #expect(primary.visibleFrame.contains(result.frame))
        #expect(result.frame.size == ReaderWindowLayout.defaultExpandedSize)
        #expect(ReaderWindowLayout.restoredDetachedPlacement(
            frame: saved, displayID: invalidVisibleFrame.id,
            expandedSize: ReaderWindowLayout.defaultExpandedSize,
            expansion: .expanded, displays: [invalidFrame, invalidVisibleFrame],
            primaryDisplayID: invalidFrame.id
        ) == nil)
    }
}
