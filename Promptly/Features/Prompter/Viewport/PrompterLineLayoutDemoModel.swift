import CoreGraphics
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class PrompterLineLayoutDemoModel {
    nonisolated struct Request: Equatable, Sendable {
        let text: String
        let font: Font.Resolved
        let width: CGFloat

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.text == rhs.text && lhs.font == rhs.font &&
                (lhs.width == rhs.width || (lhs.width.isNaN && rhs.width.isNaN))
        }
    }

    nonisolated struct Layout: Equatable, Sendable {
        let request: Request
        let lines: [PrompterLine]
    }

    nonisolated enum Failure: Equatable, Sendable {
        case engine(LineLayoutEngine.Failure)
        case unavailable

        var message: LocalizedStringResource {
            switch self {
            case .engine(.invalidWidth):
                "Choose a positive reading width."
            case .engine(.invalidFont):
                "Choose a valid font and size."
            case .engine(.invalidLimits), .engine(.inputTooLong):
                "This sample is too long to lay out."
            case .engine(.tooManyLines):
                "This layout has too many lines. Increase the reading width or reduce the font size."
            case .engine(.widthTooNarrow):
                "Increase the reading width or reduce the font size."
            case .engine(.typesettingFailed), .unavailable:
                "The sample could not be laid out. Try a different font or sample."
            }
        }
    }

    nonisolated enum Phase: Equatable, Sendable {
        case idle
        case loading(previous: Layout?)
        case ready(Layout)
        case failed(Failure, previous: Layout?)
    }

    private(set) var phase: Phase = .idle
    private(set) var sourceOffset = 0

    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var activeRequest: Request?
    private let performLayout: @Sendable (Request) async throws -> [PrompterLine]

    init(
        initialLayout: Layout? = nil,
        layout: @escaping @Sendable (Request) async throws -> [PrompterLine] = { request in
            try await LineLayoutEngine().layout(
                text: request.text, font: request.font, width: request.width
            )
        }
    ) {
        performLayout = layout
        if let initialLayout { phase = .ready(initialLayout) }
    }

    var layout: Layout? {
        switch phase {
        case .idle: nil
        case .loading(let previous), .failed(_, let previous): previous
        case .ready(let layout): layout
        }
    }

    var isLoading: Bool {
        if case .loading = phase { true } else { false }
    }

    var errorMessage: LocalizedStringResource? {
        if case .failed(let failure, _) = phase { failure.message } else { nil }
    }

    var currentLineIndex: Int? {
        guard let layout else { return nil }
        return lineIndex(at: sourceOffset, in: layout.lines)
    }

    var currentLineID: Int? {
        guard let layout, let currentLineIndex else { return nil }
        return layout.lines[currentLineIndex].sourceRange.location
    }

    func update(for request: Request) async {
        guard !Task.isCancelled else { return }

        let id = UUID()
        let previous = layout
        generation = id
        activeRequest = request

        if let previous, previous.request == request {
            phase = .ready(previous)
            return
        }

        phase = .loading(previous: previous)

        do {
            let lines = try await performLayout(request)
            try Task.checkCancellation()
            guard generation == id, activeRequest == request else { return }

            // Reflow keeps the exact source anchor, rather than the new row's start.
            // A different source replaces its layout and anchor together.
            if previous?.request.text != request.text {
                sourceOffset = 0
            }
            phase = .ready(Layout(request: request, lines: lines))
        } catch {
            guard generation == id, activeRequest == request else { return }
            if error is CancellationError || Task.isCancelled {
                phase = previous.map(Phase.ready) ?? .idle
            } else {
                let failure = (error as? LineLayoutEngine.Failure)
                    .map(Failure.engine) ?? .unavailable
                phase = .failed(failure, previous: previous)
            }
        }
    }

    func move(by delta: Int) {
        guard delta != 0, let layout, let currentLineIndex else { return }
        let (proposed, overflow) = currentLineIndex.addingReportingOverflow(delta)
        let target = overflow
            ? (delta > 0 ? layout.lines.count - 1 : 0)
            : min(max(proposed, 0), layout.lines.count - 1)
        sourceOffset = layout.lines[target].sourceRange.location
    }

    func invalidatePendingLayout() {
        // A scroll-phase callback can run before SwiftUI cancels the old view task.
        generation = UUID()
        activeRequest = nil
        if case .loading(let previous) = phase {
            phase = previous.map(Phase.ready) ?? .idle
        }
    }

    func selectLine(id: Int) {
        guard let layout, let index = lineIndex(at: id, in: layout.lines),
              layout.lines[index].sourceRange.location == id else { return }
        sourceOffset = id
    }

    private func lineIndex(at offset: Int, in lines: [PrompterLine]) -> Int? {
        guard !lines.isEmpty else { return nil }
        var lower = 0
        var upper = lines.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if lines[middle].sourceRange.location <= offset {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return max(0, lower - 1)
    }
}
