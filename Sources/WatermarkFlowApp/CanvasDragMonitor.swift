import AppKit
import SwiftUI

struct CanvasDragConfiguration: Equatable {
    let imageRect: CGRect
    let watermarkRect: CGRect?
    let canDragWatermark: Bool
    let canPan: Bool
}

enum CanvasDragTarget: Equatable {
    case watermark
    case canvas

    static func resolve(
        location: CGPoint,
        configuration: CanvasDragConfiguration
    ) -> CanvasDragTarget? {
        guard configuration.imageRect.contains(location) else { return nil }
        if configuration.canDragWatermark,
           configuration.watermarkRect?.contains(location) == true {
            return .watermark
        }
        return configuration.canPan ? .canvas : nil
    }
}

struct CanvasDragMonitor: NSViewRepresentable {
    let configuration: CanvasDragConfiguration
    let onWatermarkDrag: (CGSize) -> Void
    let onWatermarkDragEnd: () -> Void

    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.configuration = configuration
        view.onWatermarkDrag = onWatermarkDrag
        view.onWatermarkDragEnd = onWatermarkDragEnd
        return view
    }

    func updateNSView(_ nsView: MonitorView, context: Context) {
        nsView.configuration = configuration
        nsView.onWatermarkDrag = onWatermarkDrag
        nsView.onWatermarkDragEnd = onWatermarkDragEnd
    }

    final class MonitorView: NSView {
        var configuration = CanvasDragConfiguration(
            imageRect: .zero,
            watermarkRect: nil,
            canDragWatermark: false,
            canPan: false
        )
        var onWatermarkDrag: ((CGSize) -> Void)?
        var onWatermarkDragEnd: (() -> Void)?

        override var isFlipped: Bool { true }

        private var eventMonitor: Any?
        private var dragTarget: CanvasDragTarget?
        private var dragStartInWindow: CGPoint?
        private var scrollStartOrigin: CGPoint?
        private weak var activeScrollView: NSScrollView?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeEventMonitor()
            guard window != nil else { return }
            eventMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
            ) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        deinit {
            removeEventMonitor()
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard event.window === window else { return event }

            switch event.type {
            case .leftMouseDown:
                let local = convert(event.locationInWindow, from: nil)
                guard bounds.contains(local),
                      let target = CanvasDragTarget.resolve(
                        location: local,
                        configuration: configuration
                      ) else { return event }

                if target == .canvas {
                    guard let scrollView = enclosingScrollView else { return event }
                    activeScrollView = scrollView
                    scrollStartOrigin = scrollView.contentView.bounds.origin
                }
                dragTarget = target
                dragStartInWindow = event.locationInWindow
                return nil

            case .leftMouseDragged:
                guard let dragTarget,
                      let dragStartInWindow else { return event }
                let delta = CGSize(
                    width: event.locationInWindow.x - dragStartInWindow.x,
                    height: event.locationInWindow.y - dragStartInWindow.y
                )
                if dragTarget == .watermark {
                    onWatermarkDrag?(CGSize(width: delta.width, height: -delta.height))
                } else {
                    panCanvas(windowDelta: delta)
                }
                return nil

            case .leftMouseUp:
                guard let dragTarget else { return event }
                if dragTarget == .watermark {
                    onWatermarkDragEnd?()
                }
                resetDrag()
                return nil

            default:
                return event
            }
        }

        private func panCanvas(windowDelta: CGSize) {
            guard let scrollView = activeScrollView,
                  let start = scrollStartOrigin else { return }
            let documentIsFlipped = scrollView.documentView?.isFlipped ?? true
            var proposed = start
            proposed.x -= windowDelta.width
            proposed.y += documentIsFlipped ? windowDelta.height : -windowDelta.height
            let clipView = scrollView.contentView
            let constrained = clipView.constrainBoundsRect(
                CGRect(origin: proposed, size: clipView.bounds.size)
            )
            clipView.scroll(to: constrained.origin)
            scrollView.reflectScrolledClipView(clipView)
        }

        private func resetDrag() {
            dragTarget = nil
            dragStartInWindow = nil
            scrollStartOrigin = nil
            activeScrollView = nil
        }

        private func removeEventMonitor() {
            guard let eventMonitor else { return }
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
            resetDrag()
        }
    }
}
