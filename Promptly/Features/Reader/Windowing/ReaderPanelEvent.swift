import CoreGraphics

enum ReaderPanelEvent: Equatable, Sendable {
    case moved(frame: CGRect, displayID: UInt32?)
    case resized(frame: CGRect, displayID: UInt32?)
    case displaysChanged
    case closeRequested
}
