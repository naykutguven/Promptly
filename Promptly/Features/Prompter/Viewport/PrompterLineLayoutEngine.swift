import CoreFoundation
import CoreText
import Foundation
import SwiftUI

/// Derives display rows without changing the source or owning reading position.
nonisolated struct PrompterLineLayoutEngine: Sendable {
    nonisolated enum Failure: Error, Equatable, Sendable {
        case invalidWidth
        case invalidFont
        case invalidLimits
        case inputTooLong
        case tooManyLines
        case typesettingFailed
        case widthTooNarrow
    }

    private let maximumUTF16Count: Int
    private let maximumLineCount: Int

    init(maximumUTF16Count: Int = 1_000_000, maximumLineCount: Int = 100_000) {
        self.maximumUTF16Count = maximumUTF16Count
        self.maximumLineCount = maximumLineCount
    }

    /// All native layout objects stay within this uninterrupted background pass.
    /// Cancellation is checked between native calls; a native call cannot be interrupted.
    @concurrent
    func layout(text: String, font: Font.Resolved, width: CGFloat) async throws -> [PrompterLine] {
        try Task.checkCancellation()
        guard width.isFinite, width > 0 else { throw Failure.invalidWidth }
        guard maximumUTF16Count > 0, maximumLineCount > 0 else { throw Failure.invalidLimits }

        let pointSize = CTFontGetSize(font.ctFont)
        guard pointSize.isFinite, pointSize > 0 else { throw Failure.invalidFont }
        // Reject oversized input before bridging or asking Core Text to analyze it.
        guard text.utf16.dropFirst(maximumUTF16Count).isEmpty else { throw Failure.inputTooLong }
        guard !text.isEmpty else { return [] }

        let source = text as NSString
        let attributedText = NSAttributedString(
            string: text,
            attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font.ctFont]
        )

        try Task.checkCancellation()
        // Keep Core Text's default protection against unreasonably expensive layout.
        guard let typesetter = CTTypesetterCreateWithAttributedStringAndOptions(
            attributedText as CFAttributedString, nil
        ) else {
            throw Failure.typesettingFailed
        }

        var lines: [PrompterLine] = []
        var offset = 0
        var endsWithHardBreak = false

        while offset < source.length {
            try Task.checkCancellation()
            guard lines.count < maximumLineCount else { throw Failure.tooManyLines }

            let count = try breakLength(
                typesetter: typesetter, source: source, offset: offset, width: width
            )
            let range = NSRange(location: offset, length: count)
            let delimiterLength = hardBreakLength(atEndOf: range, in: source)
            let displayRange = NSRange(location: offset, length: count - delimiterLength)

            lines.append(PrompterLine(
                sourceRange: range,
                text: source.substring(with: displayRange)
            ))
            offset += count
            endsWithHardBreak = delimiterLength > 0
        }

        try Task.checkCancellation()
        if endsWithHardBreak {
            guard lines.count < maximumLineCount else { throw Failure.tooManyLines }
            lines.append(PrompterLine(
                sourceRange: NSRange(location: source.length, length: 0), text: ""
            ))
        }
        return lines
    }

    private func breakLength(
        typesetter: CTTypesetter, source: NSString, offset: Int, width: CGFloat
    ) throws -> Int {
        let suggested = CTTypesetterSuggestLineBreak(typesetter, offset, Double(width))
        let count = try composedBreakLength(suggested, source: source, offset: offset)
        if count > 0, fits(typesetter: typesetter, offset: offset, count: count, width: width) {
            return count
        }

        try Task.checkCancellation()
        let clusterBreak = CTTypesetterSuggestClusterBreak(typesetter, offset, Double(width))
        let clusterCount = try composedBreakLength(clusterBreak, source: source, offset: offset)
        guard clusterCount > 0,
              fits(typesetter: typesetter, offset: offset, count: clusterCount, width: width) else {
            // Preserve the chosen font and Unicode clusters instead of truncating or shrinking them.
            throw Failure.widthTooNarrow
        }
        return clusterCount
    }

    private func composedBreakLength(_ count: Int, source: NSString, offset: Int) throws -> Int {
        guard count >= 0, count <= source.length - offset else { throw Failure.typesettingFailed }
        guard count > 0 else { return 0 }

        let end = offset + count
        let lastCharacter = source.rangeOfComposedCharacterSequence(at: end - 1)
        if NSMaxRange(lastCharacter) > end {
            return max(0, lastCharacter.location - offset)
        }
        return count
    }

    private func fits(typesetter: CTTypesetter, offset: Int, count: Int, width: CGFloat) -> Bool {
        let line = CTTypesetterCreateLine(typesetter, CFRange(location: offset, length: count))
        // Consumed trailing whitespace remains in the source range even when it extends past the edge.
        let advance = CTLineGetTypographicBounds(line, nil, nil, nil)
            - CTLineGetTrailingWhitespaceWidth(line)
        return advance.isFinite && advance <= Double(width) + 0.0001
    }

    private func hardBreakLength(atEndOf range: NSRange, in source: NSString) -> Int {
        let end = NSMaxRange(range)
        switch source.character(at: end - 1) {
        case 0x000A:
            return range.length > 1 && source.character(at: end - 2) == 0x000D ? 2 : 1
        case 0x000B, 0x000C, 0x000D, 0x0085, 0x2028, 0x2029:
            return 1
        default:
            return 0
        }
    }
}
