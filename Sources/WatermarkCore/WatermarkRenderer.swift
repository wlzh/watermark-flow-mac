import AppKit
import CoreGraphics
import CoreText
import Foundation

public enum ImageOutputFormat: String, CaseIterable {
    case png
    case jpeg
}

public enum WatermarkRenderError: LocalizedError {
    case invalidSourceImage
    case contextCreationFailed
    case outputCreationFailed
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .invalidSourceImage: return "无法读取原图像素数据"
        case .contextCreationFailed: return "无法创建图片渲染上下文"
        case .outputCreationFailed: return "无法生成合成图片"
        case .encodingFailed: return "无法编码输出图片"
        }
    }
}

public enum WatermarkRenderer {
    public static func render(source: NSImage, template: WatermarkTemplate) throws -> NSImage {
        guard let sourceCGImage = pixelCGImage(from: source) else {
            throw WatermarkRenderError.invalidSourceImage
        }

        let width = sourceCGImage.width
        let height = sourceCGImage.height
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw WatermarkRenderError.contextCreationFailed
        }

        context.interpolationQuality = .high
        context.draw(sourceCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        drawWatermark(in: context, canvasSize: CGSize(width: width, height: height), template: template.clamped())

        guard let result = context.makeImage() else {
            throw WatermarkRenderError.outputCreationFailed
        }
        return NSImage(cgImage: result, size: NSSize(width: width, height: height))
    }

    public static func encode(
        image: NSImage,
        format: ImageOutputFormat,
        jpegQuality: Double = 0.92
    ) throws -> Data {
        guard let image = pixelCGImage(from: image) else {
            throw WatermarkRenderError.invalidSourceImage
        }
        let representation = NSBitmapImageRep(cgImage: image)
        let data: Data?
        switch format {
        case .png:
            data = representation.representation(using: .png, properties: [:])
        case .jpeg:
            data = representation.representation(
                using: .jpeg,
                properties: [.compressionFactor: jpegQuality.clamped(to: 0.1...1)]
            )
        }
        guard let data else { throw WatermarkRenderError.encodingFailed }
        return data
    }

    public static func pixelSize(of image: NSImage) -> CGSize? {
        guard let image = pixelCGImage(from: image) else { return nil }
        return CGSize(width: image.width, height: image.height)
    }

    private static func pixelCGImage(from image: NSImage) -> CGImage? {
        var rect = NSRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    private static func drawWatermark(
        in context: CGContext,
        canvasSize: CGSize,
        template: WatermarkTemplate
    ) {
        let badgeHeight = max(24, canvasSize.height * template.relativeHeight)
        let fontSize = badgeHeight * 0.4
        let font = NSFont(name: "Avenir Next Demi Bold", size: fontSize)
            ?? NSFont.boldSystemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: template.foregroundColor.nsColor
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: template.text, attributes: attributes))
        let textWidth = template.text.isEmpty ? 0 : CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        let padding = badgeHeight * 0.22
        let iconSize = badgeHeight * 0.56
        let showsIcon = template.brand != .text
        let iconWidth = showsIcon ? iconSize : 0
        let gap = showsIcon && !template.text.isEmpty ? badgeHeight * 0.16 : 0
        let badgeWidth = max(badgeHeight, padding * 2 + iconWidth + gap + textWidth)

        let centerX = CGFloat(template.position.x) * canvasSize.width
        let centerY = (1 - CGFloat(template.position.y)) * canvasSize.height

        context.saveGState()
        context.translateBy(x: centerX, y: centerY)
        context.rotate(by: -CGFloat(template.rotationDegrees) * .pi / 180)
        context.setAlpha(CGFloat(template.opacity))

        let badgeRect = CGRect(
            x: -badgeWidth / 2,
            y: -badgeHeight / 2,
            width: badgeWidth,
            height: badgeHeight
        )
        let path = CGPath(
            roundedRect: badgeRect,
            cornerWidth: badgeHeight * 0.28,
            cornerHeight: badgeHeight * 0.28,
            transform: nil
        )

        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -badgeHeight * 0.08),
            blur: badgeHeight * 0.16,
            color: NSColor.black.withAlphaComponent(0.28).cgColor
        )
        context.setFillColor(template.backgroundColor.nsColor.cgColor)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()

        var cursorX = badgeRect.minX + padding
        if showsIcon {
            let iconRect = CGRect(
                x: cursorX,
                y: -iconSize / 2,
                width: iconSize,
                height: iconSize
            )
            drawIcon(in: context, rect: iconRect, template: template)
            cursorX += iconSize + gap
        }

        if !template.text.isEmpty {
            context.textMatrix = .identity
            context.textPosition = CGPoint(x: cursorX, y: -fontSize * 0.36)
            CTLineDraw(line, context)
        }

        context.restoreGState()
    }

    private static func drawIcon(
        in context: CGContext,
        rect: CGRect,
        template: WatermarkTemplate
    ) {
        switch template.brand {
        case .x:
            let inset = rect.width * 0.12
            let left = rect.minX + inset
            let right = rect.maxX - inset
            let bottom = rect.minY + inset
            let top = rect.maxY - inset
            context.setStrokeColor(template.accentColor.nsColor.cgColor)
            context.setLineCap(.square)
            context.setLineWidth(rect.width * 0.13)
            context.move(to: CGPoint(x: left, y: top))
            context.addLine(to: CGPoint(x: right, y: bottom))
            context.strokePath()
            context.setLineWidth(rect.width * 0.07)
            context.move(to: CGPoint(x: right, y: top))
            context.addLine(to: CGPoint(x: left, y: bottom))
            context.strokePath()

        case .youtube:
            let logoRect = rect.insetBy(dx: 0, dy: rect.height * 0.14)
            let logoPath = CGPath(
                roundedRect: logoRect,
                cornerWidth: logoRect.height * 0.25,
                cornerHeight: logoRect.height * 0.25,
                transform: nil
            )
            context.setFillColor(template.accentColor.nsColor.cgColor)
            context.addPath(logoPath)
            context.fillPath()

            let triangle = CGMutablePath()
            triangle.move(to: CGPoint(x: logoRect.midX - logoRect.width * 0.1, y: logoRect.midY - logoRect.height * 0.22))
            triangle.addLine(to: CGPoint(x: logoRect.midX + logoRect.width * 0.2, y: logoRect.midY))
            triangle.addLine(to: CGPoint(x: logoRect.midX - logoRect.width * 0.1, y: logoRect.midY + logoRect.height * 0.22))
            triangle.closeSubpath()
            context.setFillColor(NSColor.white.cgColor)
            context.addPath(triangle)
            context.fillPath()

        case .custom:
            guard let data = template.customLogoPNG,
                  let representation = NSBitmapImageRep(data: data),
                  let image = representation.cgImage else {
                drawCustomPlaceholder(in: context, rect: rect, color: template.accentColor.nsColor)
                return
            }
            let fitted = aspectFit(size: CGSize(width: image.width, height: image.height), in: rect)
            context.draw(image, in: fitted)

        case .text:
            break
        }
    }

    private static func drawCustomPlaceholder(in context: CGContext, rect: CGRect, color: NSColor) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(max(1, rect.width * 0.08))
        context.strokeEllipse(in: rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.08))
        context.move(to: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.midY))
        context.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.midY))
        context.strokePath()
    }

    private static func aspectFit(size: CGSize, in rect: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return rect }
        let scale = min(rect.width / size.width, rect.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(
            x: rect.midX - fitted.width / 2,
            y: rect.midY - fitted.height / 2,
            width: fitted.width,
            height: fitted.height
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
