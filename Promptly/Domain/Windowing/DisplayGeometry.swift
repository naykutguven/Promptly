//
//  DisplayGeometry.swift
//  Promptly
//
//  Created by Aykut Güven on 26.10.26.
//

import CoreGraphics
import Foundation

struct DisplayGeometry: Equatable, Sendable {
    let id: UInt32
    let frame: CGRect
    let visibleFrame: CGRect
    let safeAreaTop: CGFloat
    let notchWidth: CGFloat
}
