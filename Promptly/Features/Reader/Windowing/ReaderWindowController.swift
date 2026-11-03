//
//  ReaderWindowController.swift
//  Promptly
//
//  Created by Aykut Güven on 26.10.26.
//

import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class ReaderWindowController {
    enum Visibility { case visible, hidden }

    private(set) var state: ReaderWindowState
    private(set) var visibility: Visibility = .hidden
    private(set) var topInset: CGFloat = 0
    private(set) var preferenceFailure: ReaderWindowStateStore.Failure?

    @ObservationIgnored private let preferences: ReaderWindowStateStore
    @ObservationIgnored private let panel: any ReaderPanelControlling
    @ObservationIgnored private var started = false
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var preservesUnreadablePreferences = false

    init(
        preferences: ReaderWindowStateStore,
        panel: any ReaderPanelControlling
    ) {
        self.preferences = preferences
        self.panel = panel
        do {
            state = try preferences.load()
        } catch {
            state = ReaderWindowState()
            preferenceFailure = error
            preservesUnreadablePreferences = true
        }
        panel.onEvent = { [weak self] event in self?.handlePanelEvent(event) }
    }

    func start() {
        guard !started else { return }
        started = true
        panel.startObservingDisplays()
        show()
    }

    func stop() {
        guard started else { return }
        savePreferences()
        panel.stopObservingDisplays()
        panel.hide()
        visibility = .hidden
        started = false
    }

    func show() {
        applyGeometry()
        panel.show()
        visibility = .visible
    }

    func hide() {
        panel.hide()
        visibility = .hidden
        savePreferences()
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
        let frame = panel.frame
        state.detachedFrame = CGRect(x: frame.minX, y: frame.maxY - topInset - state.expandedSize.height,
                                     width: frame.width, height: state.expandedSize.height)
        state.displayID = primaryDisplay(in: panel.displays)?.id
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
        finishMoving(frame: panel.frame, displayID: panel.displayID)
    }

    private func finishMoving(frame: CGRect, displayID: UInt32?) {
        guard state.placement == .detached, !state.isLocked else { return }
        recordDetachedFrame(frame, displayID: displayID)
        applyGeometry()
        savePreferences()
    }

    private func handlePanelEvent(_ event: ReaderPanelEvent) {
        guard started else { return }
        switch event {
        case let .moved(frame, displayID):
            guard state.placement == .detached, !state.isLocked else { return }
            recordDetachedFrame(frame, displayID: displayID)
            scheduleSave()
        case let .resized(frame, displayID):
            finishMoving(frame: frame, displayID: displayID)
        case .displaysChanged:
            applyGeometry()
            scheduleSave()
        case .closeRequested:
            hide()
        }
    }

    private func primaryDisplay(in displays: [DisplayGeometry]) -> DisplayGeometry? {
        displays.first { $0.id == panel.primaryDisplayID } ?? displays.first
    }

    private func applyGeometry() {
        let displays = panel.displays
        guard let primary = primaryDisplay(in: displays) else { return }
        state.expandedSize = ReaderWindowGeometry.sanitizedExpandedSize(state.expandedSize)
        let frame: CGRect
        let bounds: CGRect
        switch state.placement {
        case .anchored:
            frame = ReaderWindowGeometry.anchoredFrame(on: primary, expandedSize: state.expandedSize,
                                                       expansion: state.expansion)
            topInset = min(primary.safeAreaTop, max(0, frame.height - ReaderWindowLayoutConstants.collapsedHeight))
            bounds = primary.visibleFrame
        case .detached:
            guard let placement = ReaderWindowGeometry.restoredDetachedPlacement(
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
        }
        let canResize = state.placement == .detached && !state.isLocked && !state.isCollapsed
        panel.apply(ReaderPanelLayout(
            frame: frame,
            placement: state.placement,
            isMovable: state.placement == .detached && !state.isLocked,
            isResizable: canResize,
            minimumSize: CGSize(width: min(ReaderWindowLayoutConstants.minimumExpandedSize.width, bounds.width),
                                height: min(state.isCollapsed ? ReaderWindowLayoutConstants.collapsedHeight
                                            : ReaderWindowLayoutConstants.minimumExpandedSize.height, bounds.height)),
            maximumSize: bounds.size
        ))
    }

    private func recordDetachedFrame(_ live: CGRect, displayID: UInt32?) {
        if state.isCollapsed {
            let expandedHeight = state.detachedFrame?.height ?? state.expandedSize.height
            state.detachedFrame = CGRect(x: live.minX, y: live.maxY - expandedHeight,
                                         width: live.width, height: expandedHeight)
        } else {
            state.detachedFrame = live
            state.expandedSize = live.size
        }
        state.displayID = displayID ?? primaryDisplay(in: panel.displays)?.id
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
