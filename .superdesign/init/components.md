# Native UI component inventory

Promptly is a native macOS 26+ SwiftUI/AppKit app. There is no web component
library or shared DesignSystem implementation. Prompter controls remain feature
owned. PrompterView's private control function renders 30-point borderless icon
buttons with labels, help and stable identifiers. Its native visibility toggle
uses a prompter-local ButtonStyle for the same xmark and target.

Native WindowDragGesture replaces the old AppKit drag handle. SwiftUI creates
and presents the prompter. The following adapters only attach to that existing
window for exact geometry, display/overlay policy and native notifications; they
are not visual components to reproduce in browser code.

### `Promptly/Features/Prompter/Windowing/PrompterWindowAttachment.swift`

```swift
import AppKit
import SwiftUI

struct PrompterWindowAttachment: NSViewRepresentable {
    let adapter: PrompterWindowAdapter

    func makeNSView(context: Context) -> AttachmentView {
        AttachmentView(adapter: adapter)
    }

    func updateNSView(_ view: AttachmentView, context: Context) {}

    static func dismantleNSView(_ view: AttachmentView, coordinator: ()) {
        view.adapter.detach(view.attachedWindow)
    }

    final class AttachmentView: NSView {
        let adapter: PrompterWindowAdapter
        private(set) weak var attachedWindow: NSWindow?

        init(adapter: PrompterWindowAdapter) {
            self.adapter = adapter
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window {
                attachedWindow = window
                adapter.attach(window)
            } else {
                adapter.detach(attachedWindow)
                attachedWindow = nil
            }
        }
    }
}
```

### `Promptly/Features/Prompter/Windowing/PrompterWindowAdapter.swift`

```swift
import AppKit
import CoreGraphics

@MainActor
final class PrompterWindowAdapter: NSObject, PrompterWindowAccessing {
    var onEvent: (@MainActor (PrompterWindowEvent) -> Void)?

    var frame: CGRect { window?.frame ?? .zero }
    var displayID: UInt32? { window?.screen?.displayGeometry?.id }
    var displays: [DisplayGeometry] { displayProvider() }
    var primaryDisplayID: UInt32 { primaryDisplayIDProvider() }

    private weak var window: NSWindow?
    private let displayProvider: () -> [DisplayGeometry]
    private let primaryDisplayIDProvider: () -> UInt32
    private let notificationCenter: NotificationCenter
    private var applyingGeometry = false
    private var observingDisplays = false

    init(
        displayProvider: @escaping () -> [DisplayGeometry] = { NSScreen.screens.compactMap(\.displayGeometry) },
        primaryDisplayID: @escaping () -> UInt32 = { CGMainDisplayID() },
        notificationCenter: NotificationCenter = .default
    ) {
        self.displayProvider = displayProvider
        self.primaryDisplayIDProvider = primaryDisplayID
        self.notificationCenter = notificationCenter
    }

    func attach(_ window: NSWindow) {
        guard self.window !== window else { return }
        detach(self.window)
        self.window = window
        window.setAccessibilityIdentifier("prompter.window")
        window.backgroundColor = .clear
        window.isOpaque = false
        window.animationBehavior = .none
        window.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .ignoresCycle]
        // SwiftUI owns the window and its delegate. Only observe native geometry/lifecycle.
        for (name, selector) in [
            (NSWindow.didMoveNotification, #selector(windowMoved)),
            (NSWindow.didEndLiveResizeNotification, #selector(windowResized)),
            (NSWindow.willCloseNotification, #selector(windowClosed)),
            (NSWindow.didChangeOcclusionStateNotification, #selector(windowOcclusionChanged))
        ] {
            notificationCenter.addObserver(self, selector: selector, name: name, object: window)
        }
        onEvent?(.attached)
    }

    func detach(_ window: NSWindow?) {
        guard let current = self.window, current === window else { return }
        notificationCenter.removeObserver(self, name: nil, object: current)
        self.window = nil
        onEvent?(.closed)
    }

    func startObservingDisplays() {
        guard !observingDisplays else { return }
        observingDisplays = true
        notificationCenter.addObserver(self, selector: #selector(displaysChanged),
                                       name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func stopObservingDisplays() {
        guard observingDisplays else { return }
        notificationCenter.removeObserver(self, name: NSApplication.didChangeScreenParametersNotification, object: nil)
        observingDisplays = false
    }

    func apply(_ layout: PrompterWindowLayout) {
        guard let window else { return }
        applyingGeometry = true
        defer { applyingGeometry = false }
        window.level = layout.placement == .anchored ? .statusBar : .floating
        window.isMovable = layout.isMovable
        window.minSize = layout.minimumSize
        window.maxSize = layout.maximumSize
        window.setFrame(layout.frame, display: true)
    }

    @objc private func windowMoved(_ notification: Notification) {
        guard !applyingGeometry else { return }
        onEvent?(.moved(frame: frame, displayID: displayID))
    }

    @objc private func windowResized(_ notification: Notification) {
        guard !applyingGeometry else { return }
        onEvent?(.resized(frame: frame, displayID: displayID))
    }

    @objc private func windowClosed(_ notification: Notification) {
        onEvent?(.closed)
    }

    @objc private func windowOcclusionChanged(_ notification: Notification) {
        if window?.isVisible == false { onEvent?(.hidden) }
    }

    @objc private func displaysChanged() {
        onEvent?(.displaysChanged)
    }
}
```
