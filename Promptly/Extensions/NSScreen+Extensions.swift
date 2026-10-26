//
//  NSScreen+Extensions.swift
//  Promptly
//
//  Created by Aykut Güven on 26.10.26.
//

import AppKit

extension NSScreen {
    var displayGeometry: DisplayGeometry? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        let notchWidth: CGFloat
        if safeAreaInsets.top > 0,
           let left = auxiliaryTopLeftArea,
           let right = auxiliaryTopRightArea {
            notchWidth = max(0, right.minX - left.maxX)
        } else {
            notchWidth = 0
        }
        return DisplayGeometry(id: number.uint32Value, frame: frame, visibleFrame: visibleFrame,
                               safeAreaTop: safeAreaInsets.top, notchWidth: notchWidth)
    }
}
