import SwiftUI

struct MouseTrackingArea: NSViewRepresentable {
  @Binding var mouseEntered: Bool
  var xExit: CGFloat? = nil
  var yExit: CGFloat? = nil

  func makeNSView(context: Context) -> NSView {
    TrackingStrip(mouseEntered: _mouseEntered, xExit: xExit, yExit: yExit)
  }

  func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class TrackingStrip: NSView {
  @Binding var mouseEntered: Bool
  private var trackingArea: NSTrackingArea?
  private let xExit: CGFloat?
  private let yExit: CGFloat?

  init(mouseEntered: Binding<Bool>, xExit: CGFloat?, yExit: CGFloat?) {
    _mouseEntered = mouseEntered
    self.xExit = xExit
    self.yExit = yExit
    super.init(frame: .zero)
  }

  required init?(coder: NSCoder) { fatalError() }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let old = trackingArea { removeTrackingArea(old) }

    let area = NSTrackingArea(
      rect: bounds,
      options: [.mouseEnteredAndExited, .activeInKeyWindow],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(area)
    trackingArea = area
  }

  override func mouseEntered(with event: NSEvent) {
    mouseEntered = true
  }

  override func mouseExited(with event: NSEvent) {
    let mouse = convert(event.locationInWindow, from: nil)

    let xExitCondition = xExit.map { mouse.x > $0 || mouse.x < 0 } ?? true
    let yExitCondition = yExit.map { mouse.y > $0 || mouse.y < 0 } ?? true

    if xExitCondition && yExitCondition {
      mouseEntered = false
    }
  }
}
