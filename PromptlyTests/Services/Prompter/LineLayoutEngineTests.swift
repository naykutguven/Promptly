import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Promptly

@MainActor
struct LineLayoutEngineTests {
    private typealias Failure = LineLayoutEngine.Failure

    @Test func emptySourceProducesNoRows() async throws {
        let lines = try await LineLayoutEngine().layout(
            text: "", font: resolvedFont(), width: 320
        )

        #expect(lines.isEmpty)
    }

    @Test func unwrappedTextRetainsSpacesAndTabs() async throws {
        let source = "  A synthetic\treading sample.  "
        let lines = try await LineLayoutEngine().layout(
            text: source, font: resolvedFont(), width: 4096
        )

        #expect(lines == [PrompterLine(
            sourceRange: NSRange(location: 0, length: source.utf16.count),
            text: source
        )])
    }

    @Test(arguments: [" ", "\t", "\n", "\r\n", " \t \n\n"])
    func whitespaceOnlySourceRetainsCoverageAtNarrowWidths(source: String) async throws {
        let lines = try await LineLayoutEngine().layout(
            text: source, font: resolvedFont(), width: 0.01
        )

        try expectSourceCoverage(lines, source: source)
    }

    @Test(arguments: ["\n", "\r", "\r\n", "\u{000B}", "\u{000C}", "\u{0085}", "\u{2028}", "\u{2029}"])
    func hardBreaksKeepBlankLinesAndConsumeTheirDelimiters(delimiter: String) async throws {
        let source = "  First\t  " + delimiter + delimiter + "Second " + delimiter
        let chunks = ["  First\t  " + delimiter, delimiter, "Second " + delimiter, ""]
        let expectedText = ["  First\t  ", "", "Second ", ""]
        let lines = try await LineLayoutEngine().layout(
            text: source, font: resolvedFont(), width: 4096
        )

        #expect(lines.map(\.text) == expectedText)
        try expectSourceCoverage(lines, source: source)

        var offset = 0
        for (line, chunk) in zip(lines, chunks) {
            #expect(line.sourceRange == NSRange(location: offset, length: chunk.utf16.count))
            offset += chunk.utf16.count
        }
    }

    @Test func mixedHardBreaksKeepCRLFAtomic() async throws {
        let source = "First\r\n\rSecond\n\nThird"
        let chunks = ["First\r\n", "\r", "Second\n", "\n", "Third"]
        let lines = try await LineLayoutEngine().layout(
            text: source, font: resolvedFont(), width: 4096
        )

        #expect(lines.map(\.text) == ["First", "", "Second", "", "Third"])
        try expectSourceCoverage(lines, source: source)

        var offset = 0
        for (line, chunk) in zip(lines, chunks) {
            #expect(line.sourceRange == NSRange(location: offset, length: chunk.utf16.count))
            offset += chunk.utf16.count
        }
    }

    @Test func aTrailingHardBreakHasAnEmptyRowAtTheSourceEnd() async throws {
        let source = "A\r\n"
        let lines = try await LineLayoutEngine().layout(
            text: source, font: resolvedFont(), width: 320
        )

        #expect(lines == [
            PrompterLine(sourceRange: NSRange(location: 0, length: 3), text: "A"),
            PrompterLine(sourceRange: NSRange(location: 3, length: 0), text: "")
        ])
    }

    @Test(arguments: [
        "Cafe\u{301} 👨‍👩‍👧‍👦 🇩🇪 👍🏽 Cafe\u{301} 👨‍👩‍👧‍👦 🇩🇪 👍🏽",
        "这是用于验证自动换行和源文本范围的合成段落。这是另一句合成文字。",
        "هذه فقرة تجريبية للقراءة مع نص مختلط 123 وكلمات إضافية للتحقق من التفاف السطور.",
        "नमस्ते क्‍ष नमस्ते क्‍ष नमस्ते क्‍ष नमस्ते क्‍ष नमस्ते क्‍ष"
    ])
    func wrappedUnicodePreservesSourceAndGraphemeBoundaries(source: String) async throws {
        let lines = try await LineLayoutEngine().layout(
            text: source, font: resolvedFont(), width: 180
        )

        #expect(lines.count > 1)
        #expect(lines.map(\.text).joined() == source)
        try expectSourceCoverage(lines, source: source)
    }

    @Test func aLongWordWrapsWithoutDroppingCharacters() async throws {
        let source = String(repeating: "abcdefghij", count: 15)
        let lines = try await LineLayoutEngine().layout(
            text: source, font: resolvedFont(), width: 90
        )

        #expect(lines.count > 1)
        #expect(lines.allSatisfy { !$0.text.isEmpty })
        #expect(lines.map(\.text).joined() == source)
        try expectSourceCoverage(lines, source: source)
    }

    @Test func changingWidthReflowsTheSameSource() async throws {
        let source = String(repeating: "A synthetic sentence for a quiet reading window. ", count: 12)
        let engine = LineLayoutEngine()
        let font = resolvedFont()
        let narrow = try await engine.layout(text: source, font: font, width: 160)
        let wide = try await engine.layout(text: source, font: font, width: 480)

        #expect(narrow.count > wide.count)
        #expect(narrow.map(\.text).joined() == source)
        #expect(wide.map(\.text).joined() == source)
        try expectSourceCoverage(narrow, source: source)
        try expectSourceCoverage(wide, source: source)
    }

    @Test func changingFontSizeReflowsTheSameSource() async throws {
        let source = String(repeating: "A synthetic sentence for a quiet reading window. ", count: 12)
        let engine = LineLayoutEngine()
        let small = try await engine.layout(text: source, font: resolvedFont(size: 14), width: 320)
        let large = try await engine.layout(text: source, font: resolvedFont(size: 32), width: 320)

        #expect(large.count > small.count)
        try expectSourceCoverage(small, source: source)
        try expectSourceCoverage(large, source: source)
    }

    @Test(arguments: [CGFloat.zero, -1, .nan, .infinity, -.infinity])
    func invalidWidthsReportFailure(width: CGFloat) async {
        let font = resolvedFont()

        await #expect(throws: Failure.invalidWidth) {
            try await LineLayoutEngine().layout(text: "Sample", font: font, width: width)
        }
    }

    @Test(arguments: [(0, 10), (-1, 10), (10, 0), (10, -1)])
    func invalidLimitsReportFailure(maximumUTF16Count: Int, maximumLineCount: Int) async {
        let engine = LineLayoutEngine(
            maximumUTF16Count: maximumUTF16Count,
            maximumLineCount: maximumLineCount
        )
        let font = resolvedFont()

        await #expect(throws: Failure.invalidLimits) {
            try await engine.layout(text: "Sample", font: font, width: 320)
        }
    }

    @Test func theInputLimitCountsUTF16UnitsRatherThanCharacters() async throws {
        let source = "😀"
        let font = resolvedFont()

        await #expect(throws: Failure.inputTooLong) {
            try await LineLayoutEngine(maximumUTF16Count: 1).layout(
                text: source, font: font, width: 320
            )
        }

        let atLimit = try await LineLayoutEngine(maximumUTF16Count: 2).layout(
            text: source, font: font, width: 320
        )
        #expect(atLimit == [PrompterLine(sourceRange: NSRange(location: 0, length: 2), text: source)])
    }

    @Test func theLineLimitRejectsPartialResults() async {
        let font = resolvedFont()

        await #expect(throws: Failure.tooManyLines) {
            try await LineLayoutEngine(maximumLineCount: 2).layout(
                text: "First\nSecond\nThird", font: font, width: 4096
            )
        }
    }

    @Test func theFinalEmptyRowCountsTowardTheLineLimit() async throws {
        let font = resolvedFont()

        await #expect(throws: Failure.tooManyLines) {
            try await LineLayoutEngine(maximumLineCount: 1).layout(
                text: "First\n", font: font, width: 4096
            )
        }

        let atLimit = try await LineLayoutEngine(maximumLineCount: 2).layout(
            text: "First\n", font: font, width: 4096
        )
        #expect(atLimit.count == 2)
    }

    @Test(arguments: ["W", "e\u{301}", "👨‍👩‍👧‍👦"])
    func aWidthNarrowerThanOneIndivisibleClusterReportsFailure(source: String) async {
        let font = resolvedFont()

        await #expect(throws: Failure.widthTooNarrow) {
            try await LineLayoutEngine().layout(text: source, font: font, width: 0.01)
        }
    }

    @Test func cancellationBeforeLayoutDoesNotProduceRows() async {
        let font = resolvedFont()
        let task = Task { @MainActor in
            try await LineLayoutEngine().layout(text: "Sample", font: font, width: 320)
        }
        // This MainActor task cannot start before the synchronous cancellation.
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    private func resolvedFont(size: CGFloat = 24) -> Font.Resolved {
        Font.system(size: size).resolve(in: EnvironmentValues().fontResolutionContext)
    }

    private func expectSourceCoverage(_ lines: [PrompterLine], source: String) throws {
        let boundaries = Set(source.indices).union([source.endIndex])
        var nextUTF16Offset = 0
        var reconstructed = ""

        for (index, line) in lines.enumerated() {
            #expect(line.sourceRange.location == nextUTF16Offset)
            #expect(line.sourceRange.length > 0 || index == lines.count - 1)
            let range = try #require(Range(line.sourceRange, in: source))
            #expect(boundaries.contains(range.lowerBound))
            #expect(boundaries.contains(range.upperBound))
            reconstructed += source[range]
            nextUTF16Offset += line.sourceRange.length
        }

        #expect(nextUTF16Offset == source.utf16.count)
        #expect(reconstructed == source)
    }
}
