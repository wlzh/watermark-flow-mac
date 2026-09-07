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

        return try render(
            sourceCGImage: sourceCGImage,
            template: template,
            outputWidth: sourceCGImage.width,
            outputHeight: sourceCGImage.height
        )
    }

    public static func renderSource(source: NSImage) throws -> NSImage {
        guard let sourceCGImage = pixelCGImage(from: source) else {
            throw WatermarkRenderError.invalidSourceImage
        }

        return try render(
            sourceCGImage: sourceCGImage,
            template: nil,
            outputWidth: sourceCGImage.width,
            outputHeight: sourceCGImage.height
        )
    }

    public static func renderPreview(
        source: NSImage,
        template: WatermarkTemplate,
        maxPixelDimension: Int = 1_200
    ) throws -> NSImage {
        guard maxPixelDimension > 0,
              let sourceCGImage = pixelCGImage(from: source) else {
            throw WatermarkRenderError.invalidSourceImage
        }

        let sourceMax = max(sourceCGImage.width, sourceCGImage.height)
        let scale = min(1, Double(maxPixelDimension) / Double(sourceMax))
        let width = max(1, Int((Double(sourceCGImage.width) * scale).rounded()))
        let height = max(1, Int((Double(sourceCGImage.height) * scale).rounded()))
        return try render(
            sourceCGImage: sourceCGImage,
            template: template,
            outputWidth: width,
            outputHeight: height
        )
    }

    public static func renderSourcePreview(
        source: NSImage,
        maxPixelDimension: Int = 1_200
    ) throws -> NSImage {
        guard maxPixelDimension > 0,
              let sourceCGImage = pixelCGImage(from: source) else {
            throw WatermarkRenderError.invalidSourceImage
        }

        let sourceMax = max(sourceCGImage.width, sourceCGImage.height)
        let scale = min(1, Double(maxPixelDimension) / Double(sourceMax))
        let width = max(1, Int((Double(sourceCGImage.width) * scale).rounded()))
        let height = max(1, Int((Double(sourceCGImage.height) * scale).rounded()))
        return try render(
            sourceCGImage: sourceCGImage,
            template: nil,
            outputWidth: width,
            outputHeight: height
        )
    }

    private static func render(
        sourceCGImage: CGImage,
        template: WatermarkTemplate?,
        outputWidth width: Int,
        outputHeight height: Int
    ) throws -> NSImage {
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
        if let template {
            drawWatermark(
                in: context,
                canvasSize: CGSize(width: width, height: height),
                template: template.clamped()
            )
        }

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

    public static func normalizedLogoPNG(
        image: NSImage,
        maxPixelDimension: Int = 1_024
    ) throws -> Data {
        guard maxPixelDimension > 0,
              let source = pixelCGImage(from: image) else {
            throw WatermarkRenderError.invalidSourceImage
        }

        let sourceMax = max(source.width, source.height)
        guard sourceMax > maxPixelDimension else {
            return try encode(image: image, format: .png)
        }

        let scale = Double(maxPixelDimension) / Double(sourceMax)
        let width = max(1, Int((Double(source.width) * scale).rounded()))
        let height = max(1, Int((Double(source.height) * scale).rounded()))
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
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let result = context.makeImage() else {
            throw WatermarkRenderError.outputCreationFailed
        }
        return try encode(
            image: NSImage(cgImage: result, size: NSSize(width: width, height: height)),
            format: .png
        )
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
        let layout = makeBadgeLayout(canvasSize: canvasSize, template: template)
        if template.layoutMode == .tiled {
            drawTiledWatermark(
                in: context,
                canvasSize: canvasSize,
                template: template,
                layout: layout
            )
            return
        }

        let center = CGPoint(
            x: CGFloat(template.position.x) * canvasSize.width,
            y: (1 - CGFloat(template.position.y)) * canvasSize.height
        )
        drawBadge(in: context, center: center, template: template, layout: layout)
    }

    private static func makeBadgeLayout(
        canvasSize: CGSize,
        template: WatermarkTemplate
    ) -> BadgeLayout {
        let badgeHeight = max(24, canvasSize.height * template.activeRelativeHeight)
        let fontSize = badgeHeight * 0.4
        let font = NSFont(name: "Avenir Next Demi Bold", size: fontSize)
            ?? NSFont.boldSystemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: template.activeForegroundColor.nsColor
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: template.text, attributes: attributes))
        let textWidth = template.text.isEmpty ? 0 : CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        let padding = badgeHeight * 0.22
        let iconSize = badgeHeight * 0.56
        let showsIcon = template.brand != .text
        let iconWidth = showsIcon ? iconSize : 0
        let gap = showsIcon && !template.text.isEmpty ? badgeHeight * 0.16 : 0
        let badgeWidth = max(badgeHeight, padding * 2 + iconWidth + gap + textWidth)

        return BadgeLayout(
            badgeHeight: badgeHeight,
            fontSize: fontSize,
            line: line,
            padding: padding,
            iconSize: iconSize,
            showsIcon: showsIcon,
            gap: gap,
            badgeWidth: badgeWidth,
            customLogo: decodedCustomLogo(from: template)
        )
    }

    private static func drawTiledWatermark(
        in context: CGContext,
        canvasSize: CGSize,
        template: WatermarkTemplate,
        layout: BadgeLayout
    ) {
        let normalizedDensity = CGFloat((template.tileDensity - 1) / 9)
        let spacingMultiplier = 2.9 - normalizedDensity * 1.5
        let horizontalStep = max(layout.badgeWidth * spacingMultiplier, layout.badgeHeight * 1.8)
        let verticalStep = max(layout.badgeHeight * spacingMultiplier * 1.15, layout.badgeHeight * 1.55)

        var row = 0
        var centerY = -verticalStep
        while centerY <= canvasSize.height + verticalStep {
            let stagger = row.isMultiple(of: 2) ? 0 : horizontalStep / 2
            var centerX = -horizontalStep + stagger
            while centerX <= canvasSize.width + horizontalStep {
                drawBadge(
                    in: context,
                    center: CGPoint(x: centerX, y: centerY),
                    template: template,
                    layout: layout
                )
                centerX += horizontalStep
            }
            row += 1
            centerY += verticalStep
        }
    }

    private static func drawBadge(
        in context: CGContext,
        center: CGPoint,
        template: WatermarkTemplate,
        layout: BadgeLayout
    ) {
        let badgeHeight = layout.badgeHeight
        let badgeWidth = layout.badgeWidth

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: -CGFloat(template.activeRotationDegrees) * .pi / 180)
        context.setAlpha(CGFloat(template.activeOpacity))

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
        context.setFillColor(template.activeBackgroundColor.nsColor.cgColor)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()

        var cursorX = badgeRect.minX + layout.padding
        if layout.showsIcon {
            let iconRect = CGRect(
                x: cursorX,
                y: -layout.iconSize / 2,
                width: layout.iconSize,
                height: layout.iconSize
            )
            drawIcon(
                in: context,
                rect: iconRect,
                template: template,
                customLogo: layout.customLogo
            )
            cursorX += layout.iconSize + layout.gap
        }

        if !template.text.isEmpty {
            context.textMatrix = .identity
            context.textPosition = CGPoint(x: cursorX, y: -layout.fontSize * 0.36)
            CTLineDraw(layout.line, context)
        }

        context.restoreGState()
    }

    private struct BadgeLayout {
        let badgeHeight: CGFloat
        let fontSize: CGFloat
        let line: CTLine
        let padding: CGFloat
        let iconSize: CGFloat
        let showsIcon: Bool
        let gap: CGFloat
        let badgeWidth: CGFloat
        let customLogo: CGImage?
    }

    private static func decodedCustomLogo(from template: WatermarkTemplate) -> CGImage? {
        guard template.brand == .custom,
              let data = template.customLogoPNG,
              let representation = NSBitmapImageRep(data: data) else { return nil }
        return representation.cgImage
    }

    private static func drawIcon(
        in context: CGContext,
        rect: CGRect,
        template: WatermarkTemplate,
        customLogo: CGImage?
    ) {
        switch template.brand {
        case .x:
            let inset = rect.width * 0.12
            let left = rect.minX + inset
            let right = rect.maxX - inset
            let bottom = rect.minY + inset
            let top = rect.maxY - inset
            context.setStrokeColor(template.activeAccentColor.nsColor.cgColor)
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
            context.setFillColor(template.activeAccentColor.nsColor.cgColor)
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
            guard let customLogo else {
                drawCustomPlaceholder(in: context, rect: rect, color: template.activeAccentColor.nsColor)
                return
            }
            let fitted = aspectFit(
                size: CGSize(width: customLogo.width, height: customLogo.height),
                in: rect
            )
            context.draw(customLogo, in: fitted)

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
