//
//  ReaderWindowState.swift
//  Promptly
//
//  Created by Aykut Güven on 26.10.26.
//

import CoreGraphics
import Foundation

struct ReaderWindowState: Codable, Equatable, Sendable {
    enum Placement: String, Codable, Sendable {
        case anchored
        case detached
    }

    enum Expansion: String, Codable, Sendable {
        case expanded
        case collapsed
    }

    enum PositionLock: String, Codable, Sendable {
        case unlocked
        case locked
    }

    var placement: Placement = .anchored
    var expansion: Expansion = .expanded
    var positionLock: PositionLock = .unlocked
    var expandedSize = CGSize(width: 640, height: 320)

    // Keep expanded geometry while collapsed so collapse never replaces the user's size.
    var detachedFrame: CGRect?
    var displayID: UInt32?

    var isCollapsed: Bool { expansion == .collapsed }
    var isLocked: Bool { positionLock == .locked }
}
