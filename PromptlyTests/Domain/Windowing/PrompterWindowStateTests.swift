//
//  PrompterWindowStateTests.swift
//  PromptlyTests
//
//  Created by Aykut Güven on 26.10.26.
//

import CoreGraphics
import Foundation
import Testing
@testable import Promptly

@MainActor
struct PrompterWindowStateTests {
    @Test func windowStatesRoundTripWithoutLosingExpandedGeometry() throws {
        var state = PrompterWindowState()
        state.placement = .detached
        state.expansion = .collapsed
        state.positionLock = .locked
        state.expandedSize = CGSize(width: 720, height: 400)
        state.detachedFrame = CGRect(x: -1400, y: 300, width: 720, height: 400)
        state.displayID = 42

        let restored = try JSONDecoder().decode(
            PrompterWindowState.self, from: JSONEncoder().encode(state)
        )
        #expect(restored == state)
        #expect(restored.isCollapsed)
        #expect(restored.isLocked)
        #expect(restored.detachedFrame?.height == 400)
    }

    @Test func freshStateIsExpandedAndAnchored() {
        let state = PrompterWindowState()
        #expect(state.placement == .anchored)
        #expect(state.expansion == .expanded)
        #expect(state.positionLock == .unlocked)
        #expect(state.detachedFrame == nil)
        #expect(state.expandedSize == PrompterWindowLayoutConstants.defaultExpandedSize)
    }
}
