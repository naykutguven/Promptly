import CoreGraphics

@MainActor
protocol ReaderPanelControlling: AnyObject {
    var frame: CGRect { get }
    var displayID: UInt32? { get }
    var displays: [DisplayGeometry] { get }
    var primaryDisplayID: UInt32 { get }
    // Deliver events synchronously; applying a layout must not report user movement or resizing.
    var onEvent: (@MainActor (ReaderPanelEvent) -> Void)? { get set }

    func startObservingDisplays()
    func stopObservingDisplays()
    func apply(_ layout: ReaderPanelLayout)
    func show()
    func hide()
}
