//
//  ReaderDragHandle.swift
//  Promptly
//
//  Created by Aykut Güven on 26.10.26.
//

import AppKit
import SwiftUI

struct ReaderDragHandle: NSViewRepresentable {
    let isEnabled: Bool
    let onDragEnded: () -> Void

    func makeNSView(context: Context) -> DragView {
        let view = DragView()
        view.isDragEnabled = isEnabled
        view.onDragEnded = onDragEnded
        return view
    }

    func updateNSView(_ view: DragView, context: Context) {
        view.isDragEnabled = isEnabled
        view.onDragEnded = onDragEnded
    }

    final class DragView: NSView {
        var onDragEnded: (() -> Void)?
        var isDragEnabled = false {
            didSet {
                if isDragEnabled != oldValue { window?.invalidateCursorRects(for: self) }
            }
        }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override var needsPanelToBecomeKey: Bool { false }

        override func resetCursorRects() {
            super.resetCursorRects()
            if isDragEnabled { addCursorRect(bounds, cursor: .openHand) }
        }

        override func mouseDown(with event: NSEvent) {
            guard isDragEnabled, let window, window.isMovable else { return }
            window.performDrag(with: event)
            onDragEnded?()
        }
    }
}
