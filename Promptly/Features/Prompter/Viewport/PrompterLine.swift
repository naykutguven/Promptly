import Foundation

nonisolated struct PrompterLine: Equatable, Sendable {
    /// UTF-16 coordinates in the unchanged input, including any hard line break.
    let sourceRange: NSRange

    /// The source substring with only its terminal hard line break removed.
    let text: String
}
