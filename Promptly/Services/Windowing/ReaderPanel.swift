//
//  ReaderPanel.swift
//  Promptly
//
//  Created by Aykut Güven on 26.10.26.
//

import AppKit

final class ReaderPanel: NSPanel {
    var allowsKeyboardFocus = false
    var onRelinquishFocus: (() -> Void)?

    override var canBecomeKey: Bool { allowsKeyboardFocus }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        allowsKeyboardFocus = false
    }

    override func cancelOperation(_ sender: Any?) {
        onRelinquishFocus?()
    }
}
