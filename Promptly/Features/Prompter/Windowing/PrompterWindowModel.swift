//
//  PrompterWindowModel.swift
//  Promptly
//
//  Created by Aykut Güven on 04.11.26.
//

import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class PrompterWindowModel {
    @ObservationIgnored private weak var window: NSWindow?

    private(set) var isShowing: Bool = false
    var isAttachedToNotch: Bool = false
    var isLocked: Bool = false

    var canMoveNearNotch: Bool {
        isShowing && !isLocked && !isAttachedToNotch
    }

    func attach(_ window: NSWindow?) {
        self.window = window

        if let window {
            // The window may not be onscreen yet
            // when its content is first attached.
            isShowing = isShowing || window.isVisible
        } else {
            isShowing = false
        }
    }

    func didRequestOpen() {
        isShowing = true
    }

    @discardableResult
    func showExisting() -> Bool {
        guard let window else { return false }

        NSApp.activate()
        window.makeKeyAndOrderFront(nil)

        isShowing = window.isVisible
        return true
    }

    func hide() {
        window?.orderOut(nil)
        isShowing = window?.isVisible == true
    }

    func moveNearNotch() {
        guard let window, let screen = window.screen ?? NSScreen.main else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let currentFrame = window.frame

        // TODO: This might need some refining in the distance, something like below for the animation
//
//        import QuartzCore
//
//        NSAnimationContext.runAnimationGroup { context in
//            context.duration = 0.4
//            context.timingFunction = CAMediaTimingFunction(
//                name: .easeInEaseOut
//            )
//
//            window.animator().setFrame(
//                targetFrame,
//                display: true
//            )
//        }

        let targetFrame = NSRect(
            x: visibleFrame.midX - currentFrame.width / 2,
            y: visibleFrame.maxY - currentFrame.height - 12,
            width: currentFrame.width,
            height: currentFrame.height
        )

        window.setFrame(targetFrame, display: true, animate: true)
    }
}
