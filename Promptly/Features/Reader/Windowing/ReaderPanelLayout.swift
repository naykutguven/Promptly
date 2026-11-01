import CoreGraphics

struct ReaderPanelLayout: Equatable, Sendable {
    let frame: CGRect
    let placement: ReaderWindowState.Placement
    let isMovable: Bool
    let isResizable: Bool
    let minimumSize: CGSize
    let maximumSize: CGSize
}
