# Native UI component inventory

Promptly is a native macOS 26.0+ app built with SwiftUI and AppKit, not a web app. There is no React/Vue frontend, package manifest, CSS, Tailwind, routing library, third-party UI library, or cross-feature shared component system. `DesignSystem/` is planned and absent. SwiftUI supplies Button, Label, Text, Divider, HStack/VStack and semantic typography.

The private `control` helper in `ReaderView.swift` supplies icon-only borderless buttons with 30×30-point hit regions, explicit keyboard focus, Space activation, help, and stable accessibility IDs. Its entire source is included with ReaderView in layouts.md; it is not a shared exported primitive.

The following actual source files are reader-local native adapters rather than reusable web visual components. They preserve pointer/focus behavior; do not invent browser equivalents as implemented app functionality.

### `Promptly/Features/Reader/ReaderDragHandle.swift`

```swift
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
```

### `Promptly/Services/Windowing/ReaderHostingView.swift`

```swift
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
```

### `Promptly/Services/Windowing/ReaderPanel.swift`

```swift
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
```
