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
            let luminanceMap = template.activeContrastMode == .off
                ? nil
                : ImageLuminanceMap(source: sourceCGImage)
            drawWatermark(
                in: context,
                canvasSize: CGSize(width: width, height: height),
                template: template.clamped(),
                luminanceMap: luminanceMap
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

    public static func singleWatermarkBounds(
        canvasSize: CGSize,
        template: WatermarkTemplate
    ) -> CGRect? {
        guard template.layoutMode == .single,
              canvasSize.width > 0,
              canvasSize.height > 0 else { return nil }

        let layout = makeBadgeLayout(canvasSize: canvasSize, template: template)
        let radians = abs(CGFloat(template.activeRotationDegrees) * .pi / 180)
        let width = abs(cos(radians)) * layout.badgeWidth
            + abs(sin(radians)) * layout.badgeHeight
        let height = abs(sin(radians)) * layout.badgeWidth
            + abs(cos(radians)) * layout.badgeHeight
        let center = CGPoint(
            x: CGFloat(template.position.x) * canvasSize.width,
            y: CGFloat(template.position.y) * canvasSize.height
        )
        return CGRect(
            x: center.x - width / 2,
            y: center.y - height / 2,
            width: width,
            height: height
        )
    }

    private static func pixelCGImage(from image: NSImage) -> CGImage? {
        var rect = NSRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    private static func drawWatermark(
        in context: CGContext,
        canvasSize: CGSize,
        template: WatermarkTemplate,
        luminanceMap: ImageLuminanceMap?
    ) {
        let layout = makeBadgeLayout(canvasSize: canvasSize, template: template)
        if template.layoutMode == .tiled {
            drawTiledWatermark(
                in: context,
                canvasSize: canvasSize,
                template: template,
                layout: layout,
                luminanceMap: luminanceMap
            )
            return
        }

        let center = CGPoint(
            x: CGFloat(template.position.x) * canvasSize.width,
            y: (1 - CGFloat(template.position.y)) * canvasSize.height
        )
        drawBadge(
            in: context,
            center: center,
            canvasSize: canvasSize,
            template: template,
            layout: layout,
            luminanceMap: luminanceMap
        )
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
            NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true
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
        layout: BadgeLayout,
        luminanceMap: ImageLuminanceMap?
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
                    canvasSize: canvasSize,
                    template: template,
                    layout: layout,
                    luminanceMap: luminanceMap
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
        canvasSize: CGSize,
        template: WatermarkTemplate,
        layout: BadgeLayout,
        luminanceMap: ImageLuminanceMap?
    ) {
        let badgeHeight = layout.badgeHeight
        let badgeWidth = layout.badgeWidth
        let colors = resolvedColors(
            for: template,
            center: center,
            badgeSize: CGSize(width: badgeWidth, height: badgeHeight),
            canvasSize: canvasSize,
            luminanceMap: luminanceMap
        )

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
        context.setFillColor(colors.background.nsColor.cgColor)
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
                accentColor: colors.accent,
                customLogo: layout.customLogo
            )
            cursorX += layout.iconSize + layout.gap
        }

        if !template.text.isEmpty {
            context.setFillColor(colors.foreground.nsColor.cgColor)
            context.textMatrix = .identity
            context.textPosition = CGPoint(x: cursorX, y: -layout.fontSize * 0.36)
            CTLineDraw(layout.line, context)
        }

        context.restoreGState()
    }

    private static func resolvedColors(
        for template: WatermarkTemplate,
        center: CGPoint,
        badgeSize: CGSize,
        canvasSize: CGSize,
        luminanceMap: ImageLuminanceMap?
    ) -> ResolvedWatermarkColors {
        let fallback = ResolvedWatermarkColors(
            foreground: template.activeForegroundColor,
            background: template.activeBackgroundColor,
            accent: template.activeAccentColor
        )
        guard template.activeContrastMode != .off,
              let luminanceMap else { return fallback }

        let radians = abs(CGFloat(template.activeRotationDegrees) * .pi / 180)
        let sampleWidth = abs(cos(radians)) * badgeSize.width + abs(sin(radians)) * badgeSize.height
        let sampleHeight = abs(sin(radians)) * badgeSize.width + abs(cos(radians)) * badgeSize.height
        let region = CGRect(
            x: center.x - sampleWidth / 2,
            y: center.y - sampleHeight / 2,
            width: sampleWidth,
            height: sampleHeight
        )
        return AdaptiveContrastResolver.resolve(
            foreground: template.activeForegroundColor,
            background: template.activeBackgroundColor,
            accent: template.activeAccentColor,
            brand: template.brand,
            mode: template.activeContrastMode,
            strength: template.activeContrastStrength,
            statistics: luminanceMap.statistics(in: region, canvasSize: canvasSize)
        )
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
        accentColor: RGBAColor,
        customLogo: CGImage?
    ) {
        switch template.brand {
        case .x:
            let inset = rect.width * 0.12
            let left = rect.minX + inset
            let right = rect.maxX - inset
            let bottom = rect.minY + inset
            let top = rect.maxY - inset
            context.setStrokeColor(accentColor.nsColor.cgColor)
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
            context.setFillColor(accentColor.nsColor.cgColor)
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
                drawCustomPlaceholder(in: context, rect: rect, color: accentColor.nsColor)
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

    private struct ImageLuminanceMap {
        let width: Int
        let height: Int
        let sum: [Double]
        let squaredSum: [Double]

        init?(source: CGImage, maximumDimension: Int = 128) {
            let sourceMax = max(source.width, source.height)
            guard sourceMax > 0, maximumDimension > 0 else { return nil }
            let scale = min(1, Double(maximumDimension) / Double(sourceMax))
            let sampleWidth = max(1, Int((Double(source.width) * scale).rounded()))
            let sampleHeight = max(1, Int((Double(source.height) * scale).rounded()))

            var pixels = [UInt8](repeating: 255, count: sampleWidth * sampleHeight * 4)
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
            let rendered = pixels.withUnsafeMutableBytes { bytes -> Bool in
                guard let baseAddress = bytes.baseAddress,
                      let context = CGContext(
                        data: baseAddress,
                        width: sampleWidth,
                        height: sampleHeight,
                        bitsPerComponent: 8,
                        bytesPerRow: sampleWidth * 4,
                        space: colorSpace,
                        bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue
                            | CGImageAlphaInfo.premultipliedLast.rawValue
                      ) else { return false }
                let bounds = CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight)
                context.setFillColor(NSColor.white.cgColor)
                context.fill(bounds)
                context.interpolationQuality = .medium
                context.draw(source, in: bounds)
                return true
            }
            guard rendered else { return nil }

            let stride = sampleWidth + 1
            var sums = [Double](repeating: 0, count: stride * (sampleHeight + 1))
            var squares = [Double](repeating: 0, count: stride * (sampleHeight + 1))
            for y in 0..<sampleHeight {
                var rowSum = 0.0
                var rowSquaredSum = 0.0
                for x in 0..<sampleWidth {
                    let pixel = (y * sampleWidth + x) * 4
                    let red = Self.linearComponent(Double(pixels[pixel]) / 255)
                    let green = Self.linearComponent(Double(pixels[pixel + 1]) / 255)
                    let blue = Self.linearComponent(Double(pixels[pixel + 2]) / 255)
                    let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
                    rowSum += luminance
                    rowSquaredSum += luminance * luminance
                    let index = (y + 1) * stride + x + 1
                    sums[index] = sums[index - stride] + rowSum
                    squares[index] = squares[index - stride] + rowSquaredSum
                }
            }
            width = sampleWidth
            height = sampleHeight
            sum = sums
            squaredSum = squares
        }

        func statistics(in region: CGRect, canvasSize: CGSize) -> WatermarkLuminanceStatistics {
            guard canvasSize.width > 0, canvasSize.height > 0 else {
                return WatermarkLuminanceStatistics(mean: 0.5, deviation: 0)
            }
            let canvas = CGRect(origin: .zero, size: canvasSize)
            let clipped = region.standardized.intersection(canvas)
            guard !clipped.isNull, clipped.width > 0, clipped.height > 0 else {
                return WatermarkLuminanceStatistics(mean: 0.5, deviation: 0)
            }
            let x0 = max(0, min(width - 1, Int(floor(clipped.minX / canvasSize.width * CGFloat(width)))))
            let x1 = max(x0 + 1, min(width, Int(ceil(clipped.maxX / canvasSize.width * CGFloat(width)))))
            let y0 = max(0, min(height - 1, Int(floor(clipped.minY / canvasSize.height * CGFloat(height)))))
            let y1 = max(y0 + 1, min(height, Int(ceil(clipped.maxY / canvasSize.height * CGFloat(height)))))
            let count = Double((x1 - x0) * (y1 - y0))
            let total = integralValue(sum, x0: x0, y0: y0, x1: x1, y1: y1)
            let totalSquared = integralValue(squaredSum, x0: x0, y0: y0, x1: x1, y1: y1)
            let mean = total / count
            let variance = max(0, totalSquared / count - mean * mean)
            return WatermarkLuminanceStatistics(mean: mean, deviation: sqrt(variance))
        }

        private func integralValue(
            _ values: [Double],
            x0: Int,
            y0: Int,
            x1: Int,
            y1: Int
        ) -> Double {
            let stride = width + 1
            return values[y1 * stride + x1]
                - values[y0 * stride + x1]
                - values[y1 * stride + x0]
                + values[y0 * stride + x0]
        }

        private static func linearComponent(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
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
