//
//  ReaderHostingView.swift
//  Promptly
//
//  Created by Aykut Güven on 26.10.26.
//

import AppKit
import SwiftUI

final class ReaderHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var needsPanelToBecomeKey: Bool { false }
}
