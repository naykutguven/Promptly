//
//  ReaderWindowController.swift
//  Promptly
//
//  Created by Aykut Güven on 26.10.26.
//

import AppKit
import CoreGraphics
import Observation

@Observable
final class ReaderWindowController: NSObject, NSWindowDelegate {
    enum Visibility { case visible, hidden }

    private(set) var state: ReaderWindowState
    private(set) var visibility: Visibility = .hidden
    private(set) var topInset: CGFloat = 0
    private(set) var preferenceFailure: ReaderWindowPreferences.Failure?
    private(set) var keyboardFocusRequest: UInt = 0

    @ObservationIgnored private let preferences: ReaderWindowPreferences
    @ObservationIgnored private let panel: ReaderPanel
    @ObservationIgnored private let displayProvider: () -> [DisplayGeometry]
    @ObservationIgnored private let primaryDisplayID: () -> UInt32
    @ObservationIgnored private var applyingGeometry = false
    @ObservationIgnored private var started = false
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var previouslyFocusedApplication: NSRunningApplication?
    @ObservationIgnored private var preservesUnreadablePreferences = false

    init(
        preferences: ReaderWindowPreferences,
        panel: ReaderPanel = ReaderPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        ),
        displayProvider: @escaping () -> [DisplayGeometry] = { NSScreen.screens.compactMap(\.displayGeometry) },
        primaryDisplayID: @escaping () -> UInt32 = { CGMainDisplayID() }
    ) {
        self.preferences = preferences
        self.panel = panel
        self.displayProvider = displayProvider
        self.primaryDisplayID = primaryDisplayID
        do {
            state = try preferences.load()
        } catch {
            state = ReaderWindowState()
            preferenceFailure = error
            preservesUnreadablePreferences = true
        }
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

    func start() {
        guard !started else { return }
        started = true
        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged),
                                              name: NSApplication.didChangeScreenParametersNotification,
                                              object: nil)
        show()
    }

    func stop() {
        guard started else { return }
        saveTask?.cancel()
        saveTask = nil
        savePreferences()
        NotificationCenter.default.removeObserver(self)
        panel.orderOut(nil)
        visibility = .hidden
        started = false
    }

    func show() {
        applyGeometry()
        panel.orderFrontRegardless()
        visibility = .visible
    }

    func hide() {
        panel.orderOut(nil)
        visibility = .hidden
        savePreferences()
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
        keyboardFocusRequest &+= 1
    }

    private func releaseKeyboardFocus() {
        panel.allowsKeyboardFocus = false
        // Ordering out releases WindowServer keyboard ownership; resignKey is only a notification hook.
        panel.orderOut(nil)
        if visibility == .visible { panel.orderFrontRegardless() }
        previouslyFocusedApplication?.activate()
        previouslyFocusedApplication = nil
    }

    func toggleExpansion() {
        state.expansion = state.isCollapsed ? .expanded : .collapsed
        applyGeometry()
        savePreferences()
    }

    func toggleLock() {
        state.positionLock = state.isLocked ? .unlocked : .locked
        applyGeometry()
        savePreferences()
    }

    func detach() {
        guard state.placement == .anchored else { return }
        state.placement = .detached
        // First detachment starts near the camera, within the display's usable bounds.
        state.detachedFrame = CGRect(x: panel.frame.minX, y: panel.frame.maxY - topInset - state.expandedSize.height,
                                     width: panel.frame.width, height: state.expandedSize.height)
        state.displayID = primaryDisplay?.id
        applyGeometry()
        savePreferences()
    }

    func returnToNotch() {
        preservesUnreadablePreferences = false
        state.placement = .anchored
        applyGeometry()
        show()
        savePreferences()
    }

    func finishMoving() {
        guard state.placement == .detached, !state.isLocked else { return }
        recordDetachedFrame()
        applyGeometry()
        savePreferences()
    }

    func windowDidMove(_ notification: Notification) {
        guard !applyingGeometry, state.placement == .detached, !state.isLocked else { return }
        recordDetachedFrame()
        scheduleSave()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        finishMoving()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }

    private var displays: [DisplayGeometry] { displayProvider() }

    private var primaryDisplay: DisplayGeometry? {
        let available = displays
        // NSScreen.main follows keyboard focus; CGMainDisplayID follows the configured primary display.
        return available.first { $0.id == primaryDisplayID() } ?? available.first
    }

    @objc private func displaysChanged() {
        applyGeometry()
        scheduleSave()
    }

    private func applyGeometry() {
        guard let primary = primaryDisplay else { return }
        applyingGeometry = true
        defer { applyingGeometry = false }
        state.expandedSize = ReaderWindowLayout.sanitizedExpandedSize(state.expandedSize)
        let frame: CGRect
        let bounds: CGRect
        switch state.placement {
        case .anchored:
            frame = ReaderWindowLayout.anchoredFrame(on: primary, expandedSize: state.expandedSize,
                                                     expansion: state.expansion)
            topInset = min(primary.safeAreaTop, max(0, frame.height - ReaderWindowLayout.collapsedHeight))
            bounds = primary.visibleFrame
            panel.level = .statusBar
        case .detached:
            guard let placement = ReaderWindowLayout.restoredDetachedPlacement(
                frame: state.detachedFrame, displayID: state.displayID, expandedSize: state.expandedSize,
                expansion: state.expansion, displays: displays, primaryDisplayID: primary.id
            ), let display = displays.first(where: { $0.id == placement.displayID }) else { return }
            frame = placement.frame
            state.displayID = placement.displayID
            if state.isCollapsed {
                // The hidden expanded body may extend below the screen. Keep the reachable strip
                // where it was dragged; expanding will fit the full body to visible bounds.
                let height = state.detachedFrame?.height ?? state.expandedSize.height
                state.detachedFrame = CGRect(x: frame.minX, y: frame.maxY - height,
                                             width: frame.width, height: height)
            } else {
                state.detachedFrame = frame
            }
            topInset = 0
            bounds = display.visibleFrame
            panel.level = .floating
        }
        let canResize = state.placement == .detached && !state.isLocked && !state.isCollapsed
        if canResize { panel.styleMask.insert(.resizable) } else { panel.styleMask.remove(.resizable) }
        panel.isMovable = state.placement == .detached && !state.isLocked
        panel.minSize = CGSize(width: min(ReaderWindowLayout.minimumExpandedSize.width, bounds.width),
                               height: min(state.isCollapsed ? ReaderWindowLayout.collapsedHeight
                                           : ReaderWindowLayout.minimumExpandedSize.height, bounds.height))
        panel.maxSize = bounds.size
        panel.setFrame(frame, display: true)
    }

    private func recordDetachedFrame() {
        let live = panel.frame
        if state.isCollapsed {
            let expandedHeight = state.detachedFrame?.height ?? state.expandedSize.height
            state.detachedFrame = CGRect(x: live.minX, y: live.maxY - expandedHeight,
                                         width: live.width, height: expandedHeight)
        } else {
            state.detachedFrame = live
            state.expandedSize = live.size
        }
        state.displayID = panel.screen?.displayGeometry?.id ?? primaryDisplay?.id
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            guard !Task.isCancelled else { return }
            self?.savePreferences()
        }
    }

    private func savePreferences() {
        saveTask?.cancel()
        saveTask = nil
        // A failed restore is read-only until the user explicitly resets placement.
        guard !preservesUnreadablePreferences else { return }
        do {
            try preferences.save(state)
            preferenceFailure = nil
        } catch {
            preferenceFailure = error
        }
    }
}
