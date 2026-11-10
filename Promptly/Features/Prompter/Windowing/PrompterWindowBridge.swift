//
//  PrompterWindowBridge.swift
//  Promptly
//
//  Created by Aykut Güven on 04.11.26.
//

import AppKit
import SwiftUI

struct PrompterWindowBridge: NSViewRepresentable {
    let onWindowChange: @MainActor (NSWindow?) -> Void

    func makeNSView(context: Context) -> WindowReaderView {
        let view = WindowReaderView()
        view.onWindowChange = onWindowChange
        return view
    }

    func updateNSView(
        _ nsView: WindowReaderView,
        context: Context
    ) {
        nsView.onWindowChange = onWindowChange
    }

    // MARK: - Window reader view

    final class WindowReaderView: NSView {
        var onWindowChange: (@MainActor (NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            let callback = onWindowChange
            let currentWindow = window
            // TODO: Question where is the ideal place to set this.
            window?.sharingType = .none

            Task { @MainActor in
                callback?(currentWindow)
            }
        }
    }
}


