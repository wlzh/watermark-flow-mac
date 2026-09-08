import AppKit
import SwiftUI

enum MouseWheelZoomDirection: Equatable {
    case zoomIn
    case zoomOut

    static func resolve(
        horizontalDelta: CGFloat,
        verticalDelta: CGFloat,
        hasPreciseScrollingDeltas: Bool
    ) -> MouseWheelZoomDirection? {
        guard !hasPreciseScrollingDeltas,
              abs(verticalDelta) > abs(horizontalDelta),
              verticalDelta != 0 else { return nil }
        return verticalDelta > 0 ? .zoomIn : .zoomOut
    }
}

struct MouseWheelZoomMonitor: NSViewRepresentable {
    let onZoom: (MouseWheelZoomDirection) -> Void

    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.onZoom = onZoom
        return view
    }

    func updateNSView(_ nsView: MonitorView, context: Context) {
        nsView.onZoom = onZoom
    }

    final class MonitorView: NSView {
        var onZoom: ((MouseWheelZoomDirection) -> Void)?
        private var eventMonitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeEventMonitor()
            guard window != nil else { return }
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self,
                      event.window === self.window,
                      self.bounds.contains(self.convert(event.locationInWindow, from: nil)),
                      let direction = MouseWheelZoomDirection.resolve(
                        horizontalDelta: event.scrollingDeltaX,
                        verticalDelta: event.scrollingDeltaY,
                        hasPreciseScrollingDeltas: event.hasPreciseScrollingDeltas
                      ) else {
                    return event
                }
                self.onZoom?(direction)
                return nil
            }
        }

        deinit {
            removeEventMonitor()
        }

        private func removeEventMonitor() {
            guard let eventMonitor else { return }
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
}
