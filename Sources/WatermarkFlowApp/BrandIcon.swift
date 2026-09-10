import AppKit

enum BrandIcon {
    static let statusBarSize = NSSize(width: 18, height: 18)

    static func statusBarImage() -> NSImage {
        let image = NSImage(size: statusBarSize, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.setAllowsAntialiasing(true)
            context.setStrokeColor(NSColor.black.cgColor)
            context.setFillColor(NSColor.black.cgColor)
            context.setLineWidth(1.35)
            context.setLineCap(.round)
            context.setLineJoin(.round)

            let photo = CGRect(x: 1.2, y: 4.4, width: 12.4, height: 11.4)
            context.addPath(CGPath(
                roundedRect: photo,
                cornerWidth: 2.1,
                cornerHeight: 2.1,
                transform: nil
            ))
            context.strokePath()
            context.fillEllipse(in: CGRect(x: 9.5, y: 12.0, width: 1.8, height: 1.8))

            context.move(to: CGPoint(x: 2.8, y: 6.2))
            context.addLine(to: CGPoint(x: 6.0, y: 9.6))
            context.addLine(to: CGPoint(x: 8.2, y: 7.5))
            context.addLine(to: CGPoint(x: 10.3, y: 9.3))
            context.addLine(to: CGPoint(x: 12.5, y: 7.0))
            context.strokePath()

            let badge = CGRect(x: 7.0, y: 1.1, width: 10.0, height: 7.2)
            context.saveGState()
            context.setBlendMode(.clear)
            context.addPath(CGPath(
                roundedRect: badge.insetBy(dx: -0.7, dy: -0.7),
                cornerWidth: 2.8,
                cornerHeight: 2.8,
                transform: nil
            ))
            context.fillPath()
            context.restoreGState()

            context.addPath(CGPath(
                roundedRect: badge,
                cornerWidth: 2.1,
                cornerHeight: 2.1,
                transform: nil
            ))
            context.strokePath()
            context.setLineWidth(1.15)
            context.move(to: CGPoint(x: 9.0, y: 6.2))
            context.addLine(to: CGPoint(x: 10.0, y: 3.1))
            context.addLine(to: CGPoint(x: 11.2, y: 5.0))
            context.addLine(to: CGPoint(x: 12.4, y: 3.1))
            context.addLine(to: CGPoint(x: 13.6, y: 6.2))
            context.strokePath()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "WatermarkFlow 图片水印"
        return image
    }
}
