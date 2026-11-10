import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Promptly

@MainActor
struct PrompterLineLayoutDemoModelTests {
    private typealias Model = PrompterLineLayoutDemoModel

    @Test func reflowPreservesTheExactSourceAnchorThroughARoundTrip() async {
        let source = String(repeating: "x", count: 200)
        let original = rows(source, boundaries: [0, 100, 200])
        let reflowed = rows(source, boundaries: [0, 80, 140, 200])
        let model = Model { request in request.width == 100 ? original : reflowed }
        let originalRequest = request(text: source, width: 100)

        await model.update(for: originalRequest)
        model.selectLine(id: 100)
        await model.update(for: request(text: source, width: 200))

        #expect(model.sourceOffset == 100)
        #expect(model.currentLineID == 80)
        #expect(model.currentLineIndex == 1)

        await model.update(for: originalRequest)

        #expect(model.sourceOffset == 100)
        #expect(model.currentLineID == 100)
        #expect(model.currentLineIndex == 1)
    }

    @Test func navigationDuringLayoutIsAppliedToTheNewRows() async throws {
        let source = String(repeating: "x", count: 200)
        let original = rows(source, boundaries: [0, 50, 100, 150, 200])
        let reflowed = rows(source, boundaries: [0, 80, 140, 200])
        let gate = ControllableDemoLayout()
        let model = Model { request in
            if request.width == 100 { return original }
            return try await gate.layout(for: request)
        }
        await model.update(for: request(text: source, width: 100))
        model.selectLine(id: 100)
        let previous = try #require(model.layout)
        let nextRequest = request(text: source, width: 200)
        let update = Task { @MainActor in await model.update(for: nextRequest) }
        await gate.waitUntilStarted(count: 1)

        #expect(model.phase == .loading(previous: previous))
        #expect(model.layout == previous)
        model.move(by: 1)
        #expect(model.sourceOffset == 150)

        await gate.succeed(0, lines: reflowed)
        await update.value

        #expect(model.sourceOffset == 150)
        #expect(model.currentLineID == 140)
        #expect(model.currentLineIndex == 2)
        #expect(model.layout?.request == nextRequest)
        #expect(!model.isLoading)
    }

    @Test(arguments: [false, true])
    func supersededResultsCannotReplaceANewerSource(olderFails: Bool) async {
        let originalSource = String(repeating: "x", count: 200)
        let replacementSource = String(repeating: "y", count: 120)
        let original = rows(originalSource, boundaries: [0, 100, 200])
        let olderRows = rows(originalSource, boundaries: [0, 80, 160, 200])
        let replacementRows = rows(replacementSource, boundaries: [0, 60, 120])
        let gate = ControllableDemoLayout()
        let model = Model { request in
            if request.width == 100 { return original }
            return try await gate.layout(for: request)
        }
        await model.update(for: request(text: originalSource, width: 100))
        model.selectLine(id: 100)
        let olderRequest = request(text: originalSource, width: 160)
        let older = Task { @MainActor in await model.update(for: olderRequest) }
        await gate.waitUntilStarted(count: 1)
        let newestRequest = request(text: replacementSource, width: 240)
        let newest = Task { @MainActor in await model.update(for: newestRequest) }
        await gate.waitUntilStarted(count: 2)

        await gate.succeed(1, lines: replacementRows)
        await newest.value
        #expect(model.sourceOffset == 0)
        model.selectLine(id: 60)

        if olderFails {
            await gate.fail(0, error: PrompterLineLayoutEngine.Failure.widthTooNarrow)
        } else {
            await gate.succeed(0, lines: olderRows)
        }
        await older.value

        #expect(model.layout?.request == newestRequest)
        #expect(model.layout?.lines == replacementRows)
        #expect(model.sourceOffset == 60)
        #expect(model.currentLineID == 60)
        #expect(model.errorMessage == nil)
        #expect(!model.isLoading)
    }

    @Test func returningToTheDisplayedRequestInvalidatesAnOutstandingReflow() async throws {
        let source = String(repeating: "x", count: 200)
        let original = rows(source, boundaries: [0, 100, 200])
        let reflowed = rows(source, boundaries: [0, 80, 140, 200])
        let gate = ControllableDemoLayout()
        let model = Model { request in
            if request.width == 100 { return original }
            return try await gate.layout(for: request)
        }
        let originalRequest = request(text: source, width: 100)
        await model.update(for: originalRequest)
        model.selectLine(id: 100)
        let previous = try #require(model.layout)
        let nextRequest = request(text: source, width: 200)
        let outstanding = Task { @MainActor in await model.update(for: nextRequest) }
        await gate.waitUntilStarted(count: 1)

        await model.update(for: originalRequest)
        #expect(model.phase == .ready(previous))
        await gate.succeed(0, lines: reflowed)
        await outstanding.value

        #expect(model.phase == .ready(previous))
        #expect(model.sourceOffset == 100)
        #expect(model.currentLineID == 100)
    }

    @Test func aCancelledLayoutCannotCommitEvenWhenItsLoaderReturnsSuccess() async throws {
        let source = String(repeating: "x", count: 200)
        let original = rows(source, boundaries: [0, 100, 200])
        let reflowed = rows(source, boundaries: [0, 80, 140, 200])
        let gate = ControllableDemoLayout()
        let model = Model { request in
            if request.width == 100 { return original }
            return try await gate.layout(for: request)
        }
        await model.update(for: request(text: source, width: 100))
        model.selectLine(id: 100)
        let previous = try #require(model.layout)
        let nextRequest = request(text: source, width: 200)
        let update = Task { @MainActor in await model.update(for: nextRequest) }
        await gate.waitUntilStarted(count: 1)

        update.cancel()
        await gate.succeed(0, lines: reflowed)
        await update.value

        #expect(model.phase == .ready(previous))
        #expect(model.sourceOffset == 100)
        #expect(model.currentLineID == 100)
        #expect(model.errorMessage == nil)
    }

    @Test func failureRetainsTheLastGoodLayoutAndReadingAnchor() async throws {
        let source = String(repeating: "x", count: 200)
        let original = rows(source, boundaries: [0, 100, 200])
        let reflowed = rows(source, boundaries: [0, 80, 140, 200])
        let model = Model { request in
            if request.width == 1 { throw PrompterLineLayoutEngine.Failure.widthTooNarrow }
            return request.width == 100 ? original : reflowed
        }
        await model.update(for: request(text: source, width: 100))
        model.selectLine(id: 100)
        let previous = try #require(model.layout)

        await model.update(for: request(text: source, width: 1))

        #expect(model.phase == .failed(.engine(.widthTooNarrow), previous: previous))
        #expect(model.layout == previous)
        #expect(model.sourceOffset == 100)
        #expect(model.currentLineID == 100)
        #expect(model.errorMessage != nil)

        await model.update(for: request(text: source, width: 200))

        #expect(model.errorMessage == nil)
        #expect(model.sourceOffset == 100)
        #expect(model.currentLineID == 80)
    }

    @Test func manualInteractionInvalidatesAResultBeforeTaskCancellationArrives() async throws {
        let source = String(repeating: "x", count: 200)
        let original = rows(source, boundaries: [0, 50, 100, 150, 200])
        let reflowed = rows(source, boundaries: [0, 80, 140, 200])
        let gate = ControllableDemoLayout()
        let model = Model { request in
            if request.width == 100 { return original }
            return try await gate.layout(for: request)
        }
        await model.update(for: request(text: source, width: 100))
        model.selectLine(id: 100)
        let previous = try #require(model.layout)
        let next = request(text: source, width: 200)
        let outstanding = Task { @MainActor in await model.update(for: next) }
        await gate.waitUntilStarted(count: 1)

        model.invalidatePendingLayout()
        model.move(by: 1)
        await gate.succeed(0, lines: reflowed)
        await outstanding.value

        #expect(model.phase == .ready(previous))
        #expect(model.sourceOffset == 150)
        #expect(model.currentLineID == 150)
    }

    @Test func aPreparedPreviewLayoutIsAvailableWithoutAnotherEnginePass() async {
        let source = "Synthetic preview sample"
        let initialRequest = request(text: source, width: 320)
        let initial = Model.Layout(
            request: initialRequest, lines: rows(source, boundaries: [0, source.utf16.count])
        )
        let model = Model(initialLayout: initial) { _ in
            Issue.record("An unchanged prepared layout should be reused")
            throw SyntheticDemoLayoutFailure.unavailable
        }

        #expect(model.phase == .ready(initial))
        #expect(model.currentLineID == 0)
        await model.update(for: initialRequest)
        #expect(model.phase == .ready(initial))
        #expect(model.errorMessage == nil)
    }

    @Test func replacementFailureKeepsTheDisplayedSourcesAnchor() async {
        let originalSource = String(repeating: "x", count: 200)
        let original = rows(originalSource, boundaries: [0, 100, 200])
        let model = Model { request in
            if request.text != originalSource { throw SyntheticDemoLayoutFailure.unavailable }
            return original
        }
        await model.update(for: request(text: originalSource, width: 100))
        model.selectLine(id: 100)

        await model.update(for: request(text: "Replacement synthetic sample", width: 200))

        #expect(model.layout?.request.text == originalSource)
        #expect(model.sourceOffset == 100)
        #expect(model.currentLineID == 100)
        #expect(model.errorMessage != nil)
    }

    @Test func successfulSourceReplacementResetsTheAnchorAndEmptySourceHasNoSelection() async {
        let originalSource = String(repeating: "x", count: 200)
        let replacementSource = "New sample"
        let original = rows(originalSource, boundaries: [0, 100, 200])
        let replacement = rows(replacementSource, boundaries: [0, replacementSource.utf16.count])
        let model = Model { request in
            if request.text.isEmpty { return [] }
            return request.text == originalSource ? original : replacement
        }
        await model.update(for: request(text: originalSource, width: 100))
        model.selectLine(id: 100)

        await model.update(for: request(text: replacementSource, width: 100))

        #expect(model.sourceOffset == 0)
        #expect(model.currentLineID == 0)
        #expect(model.currentLineIndex == 0)

        await model.update(for: request(text: "", width: 100))
        model.move(by: 1)
        model.selectLine(id: 100)

        #expect(model.layout?.lines.isEmpty == true)
        #expect(model.sourceOffset == 0)
        #expect(model.currentLineID == nil)
        #expect(model.currentLineIndex == nil)
    }

    @Test func navigationClampsAndCanSelectTheFinalEmptyRow() async {
        let lines = [
            PrompterLine(sourceRange: NSRange(location: 0, length: 2), text: "A"),
            PrompterLine(sourceRange: NSRange(location: 2, length: 0), text: "")
        ]
        let model = Model { _ in lines }
        await model.update(for: request(text: "A\n", width: 100))

        model.selectLine(id: 2)
        #expect(model.sourceOffset == 2)
        #expect(model.currentLineIndex == 1)
        model.move(by: Int.max)
        #expect(model.currentLineID == 2)
        model.move(by: Int.min)
        #expect(model.currentLineID == 0)
        model.selectLine(id: 1)
        #expect(model.currentLineID == 0)
    }

    @Test func preCancelledUpdateLeavesTheLastGoodStateUntouched() async throws {
        let source = "Synthetic sample"
        let lines = rows(source, boundaries: [0, source.utf16.count])
        let model = Model { request in
            #expect(request.width == 100)
            return lines
        }
        let originalRequest = request(text: source, width: 100)
        await model.update(for: originalRequest)
        let previous = try #require(model.layout)
        let nextRequest = request(text: source, width: 200)
        let update = Task { @MainActor in await model.update(for: nextRequest) }
        update.cancel()
        await update.value

        #expect(model.phase == .ready(previous))
        #expect(model.sourceOffset == 0)
        #expect(model.errorMessage == nil)
    }

    @Test func aNaNWidthStillProducesTheCurrentRequestsFailure() async {
        let model = Model { _ in throw PrompterLineLayoutEngine.Failure.invalidWidth }
        let invalid = request(text: "Synthetic sample", width: .nan)

        await model.update(for: invalid)

        #expect(invalid == invalid)
        #expect(model.phase == .failed(.engine(.invalidWidth), previous: nil))
        #expect(model.layout == nil)
        #expect(model.errorMessage != nil)
    }

    private func request(text: String, width: CGFloat) -> Model.Request {
        Model.Request(
            text: text,
            font: Font.system(size: 24).resolve(in: EnvironmentValues().fontResolutionContext),
            width: width
        )
    }

    private func rows(_ source: String, boundaries: [Int]) -> [PrompterLine] {
        let string = source as NSString
        return zip(boundaries, boundaries.dropFirst()).map { start, end in
            let range = NSRange(location: start, length: end - start)
            return PrompterLine(sourceRange: range, text: string.substring(with: range))
        }
    }
}

private nonisolated enum SyntheticDemoLayoutFailure: Error, Sendable {
    case unavailable
}

private actor ControllableDemoLayout {
    private var started = 0
    private var pending: [Int: CheckedContinuation<[PrompterLine], any Error>] = [:]
    private var waiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func layout(for request: PrompterLineLayoutDemoModel.Request) async throws -> [PrompterLine] {
        try await withCheckedThrowingContinuation { continuation in
            let index = started
            started += 1
            pending[index] = continuation
            let ready = waiters.filter { $0.count <= started }
            waiters.removeAll { $0.count <= started }
            for waiter in ready { waiter.continuation.resume() }
        }
    }

    func waitUntilStarted(count: Int) async {
        guard started < count else { return }
        await withCheckedContinuation { continuation in
            waiters.append((count, continuation))
        }
    }

    func succeed(_ index: Int, lines: [PrompterLine]) {
        let continuation = pending.removeValue(forKey: index)
        #expect(continuation != nil)
        continuation?.resume(returning: lines)
    }

    func fail(_ index: Int, error: any Error) {
        let continuation = pending.removeValue(forKey: index)
        #expect(continuation != nil)
        continuation?.resume(throwing: error)
    }
}
