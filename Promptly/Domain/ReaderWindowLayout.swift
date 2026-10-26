//
//  ReaderWindowLayout.swift
//  Promptly
//
//  Created by Aykut Güven on 26.10.26.
//

import CoreGraphics
import Foundation

enum ReaderWindowLayout {
    static let defaultExpandedSize = CGSize(width: 640, height: 320)
    static let minimumExpandedSize = CGSize(width: 360, height: 200)
    static let collapsedHeight: CGFloat = 58

    static func sanitizedExpandedSize(_ size: CGSize) -> CGSize {
        CGSize(
            width: sanitizedDimension(size.width, fallback: defaultExpandedSize.width,
                                      minimum: minimumExpandedSize.width),
            height: sanitizedDimension(size.height, fallback: defaultExpandedSize.height,
                                       minimum: minimumExpandedSize.height)
        )
    }

    static func anchoredFrame(
        on display: DisplayGeometry,
        expandedSize: CGSize,
        expansion: ReaderWindowState.Expansion
    ) -> CGRect {
        let size = sanitizedExpandedSize(expandedSize)
        let safeAreaTop = display.safeAreaTop.isFinite
            ? min(max(0, display.safeAreaTop), display.frame.height) : 0
        let hasNotch = safeAreaTop > 0
        let bounds = hasNotch
            ? CGRect(x: display.frame.minX, y: display.visibleFrame.minY,
                     width: display.frame.width,
                     height: display.frame.maxY - display.visibleFrame.minY)
            : display.visibleFrame
        let notchWidth = display.notchWidth.isFinite ? max(0, display.notchWidth) : 0
        let width = min(max(size.width, hasNotch ? notchWidth + 96 : 0), bounds.width)
        let bodyHeight = expansion == .collapsed ? collapsedHeight : size.height
        let height = min(bodyHeight + (hasNotch ? safeAreaTop : 0), bounds.height)
        let x = min(max(display.frame.midX - width / 2, bounds.minX), bounds.maxX - width)
        return CGRect(x: x, y: bounds.maxY - height, width: width, height: height)
    }

    static func restoredDetachedPlacement(
        frame: CGRect?,
        displayID: UInt32?,
        expandedSize: CGSize,
        expansion: ReaderWindowState.Expansion,
        displays: [DisplayGeometry],
        primaryDisplayID: UInt32?
    ) -> (frame: CGRect, displayID: UInt32)? {
        let available = displays.filter { isValid($0.frame) && isValid($0.visibleFrame) }
        guard !available.isEmpty else { return nil }
        let savedFrame = frame.flatMap { isValid($0) ? $0 : nil }
        let primary = available.first { $0.id == primaryDisplayID } ?? available[0]
        let display: DisplayGeometry
        if let savedDisplay = available.first(where: { $0.id == displayID }) {
            display = savedDisplay
        } else if let savedFrame,
                  let intersecting = available.max(by: {
                      intersectionArea(savedFrame, $0.visibleFrame)
                          < intersectionArea(savedFrame, $1.visibleFrame)
                  }), intersectionArea(savedFrame, intersecting.visibleFrame) > 0 {
            display = intersecting
        } else {
            display = primary
        }

        let size = sanitizedExpandedSize(expandedSize)
        let expandedFrame = savedFrame ?? CGRect(
            x: display.visibleFrame.midX - size.width / 2,
            y: display.visibleFrame.maxY - size.height - 24,
            width: size.width,
            height: size.height
        )
        // A collapsed strip can sit near the bottom even when its hidden expanded
        // geometry would not fit there. Clamp the full rectangle only on expansion.
        return (detachedFrame(fromExpandedFrame: expandedFrame,
                              expansion: expansion, on: display), display.id)
    }

    static func detachedFrame(
        fromExpandedFrame frame: CGRect,
        expansion: ReaderWindowState.Expansion,
        on display: DisplayGeometry
    ) -> CGRect {
        let size = sanitizedExpandedSize(frame.size)
        let bounds = display.visibleFrame
        let width = min(size.width, bounds.width)
        let height = min(expansion == .collapsed ? collapsedHeight : size.height, bounds.height)
        // Preserve the top edge when expanding or collapsing; clamp against one real screen.
        let proposedX = frame.origin.x.isFinite ? frame.origin.x : bounds.midX - width / 2
        let proposedTop = frame.maxY.isFinite ? frame.maxY : bounds.maxY
        let x = min(max(proposedX, bounds.minX), bounds.maxX - width)
        let y = min(max(proposedTop - height, bounds.minY), bounds.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func sanitizedDimension(
        _ value: CGFloat,
        fallback: CGFloat,
        minimum: CGFloat
    ) -> CGFloat {
        value.isFinite && value > 0 ? max(value, minimum) : fallback
    }

    private static func isValid(_ frame: CGRect) -> Bool {
        frame.origin.x.isFinite && frame.origin.y.isFinite
            && frame.size.width.isFinite && frame.size.height.isFinite
            && frame.size.width > 0 && frame.size.height > 0
            && frame.maxX.isFinite && frame.maxY.isFinite
    }

    private static func intersectionArea(_ frame: CGRect, _ bounds: CGRect) -> CGFloat {
        let intersection = frame.intersection(bounds)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }
}
