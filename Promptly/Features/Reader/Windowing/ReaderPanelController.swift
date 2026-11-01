import AppKit
import CoreGraphics

@MainActor
final class ReaderPanelController: NSObject, ReaderPanelControlling, NSWindowDelegate {
    var onEvent: (@MainActor (ReaderPanelEvent) -> Void)?

    var frame: CGRect { panel.frame }
    var displayID: UInt32? { panel.screen?.displayGeometry?.id }
    var displays: [DisplayGeometry] { displayProvider() }
    // NSScreen.main follows keyboard focus; this ID follows the configured primary display.
    var primaryDisplayID: UInt32 { primaryDisplayIDProvider() }

    private let panel: ReaderPanel
    private let displayProvider: () -> [DisplayGeometry]
    private let primaryDisplayIDProvider: () -> UInt32
    private let notificationCenter: NotificationCenter
    private var applyingGeometry = false
    private var observingDisplays = false
    private var previouslyFocusedApplication: NSRunningApplication?

    init(
        panel: ReaderPanel = ReaderPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        ),
        displayProvider: @escaping () -> [DisplayGeometry] = { NSScreen.screens.compactMap(\.displayGeometry) },
        primaryDisplayID: @escaping () -> UInt32 = { CGMainDisplayID() },
        notificationCenter: NotificationCenter = .default
    ) {
        self.panel = panel
        self.displayProvider = displayProvider
        self.primaryDisplayIDProvider = primaryDisplayID
        self.notificationCenter = notificationCenter
        super.init()
        panel.delegate = self
        panel.title = "Promptly Reader"
        panel.setAccessibilityIdentifier("reader.window")
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .ignoresCycle]
        panel.isRestorable = false
        panel.animationBehavior = .none
        panel.onRelinquishFocus = { [weak self] in self?.releaseKeyboardFocus() }
    }

    func setContent(_ view: NSView) {
        panel.contentView = view
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

    func apply(_ layout: ReaderPanelLayout) {
        // Style and frame changes can synchronously call the window delegate.
        applyingGeometry = true
        defer { applyingGeometry = false }
        panel.level = layout.placement == .anchored ? .statusBar : .floating
        if layout.isResizable { panel.styleMask.insert(.resizable) } else { panel.styleMask.remove(.resizable) }
        panel.isMovable = layout.isMovable
        panel.minSize = layout.minimumSize
        panel.maxSize = layout.maximumSize
        panel.setFrame(layout.frame, display: true)
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func focus() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previouslyFocusedApplication = frontmost
        }
        show()
        panel.allowsKeyboardFocus = true
        NSApplication.shared.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    func windowDidMove(_ notification: Notification) {
        guard !applyingGeometry else { return }
        onEvent?(.moved(frame: frame, displayID: displayID))
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard !applyingGeometry else { return }
        onEvent?(.resized(frame: frame, displayID: displayID))
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        onEvent?(.closeRequested)
        return false
    }

    @objc private func displaysChanged() {
        onEvent?(.displaysChanged)
    }

    private func releaseKeyboardFocus() {
        panel.allowsKeyboardFocus = false
        let wasVisible = panel.isVisible
        // Ordering out releases WindowServer keyboard ownership; resignKey is only a notification hook.
        panel.orderOut(nil)
        if wasVisible { panel.orderFrontRegardless() }
        previouslyFocusedApplication?.activate()
        previouslyFocusedApplication = nil
    }
}
