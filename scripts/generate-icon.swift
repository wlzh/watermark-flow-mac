import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: generate-icon.swift OUTPUT_ICONSET\n", stderr)
    exit(2)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

let variants: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    ).cgColor
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawIcon(in context: CGContext, size: CGFloat) {
    let bounds = CGRect(x: 0, y: 0, width: size, height: size)
    let outer = bounds.insetBy(dx: size * 0.04, dy: size * 0.04)
    let outerPath = roundedRect(outer, radius: size * 0.23)

    context.saveGState()
    context.addPath(outerPath)
    context.clip()
    let background = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [color(0x073D39), color(0x0D887C), color(0x3BC2AD)] as CFArray,
        locations: [0, 0.58, 1]
    )!
    context.drawLinearGradient(
        background,
        start: CGPoint(x: size * 0.08, y: size * 0.92),
        end: CGPoint(x: size * 0.92, y: size * 0.08),
        options: []
    )
    context.restoreGState()

    context.setStrokeColor(color(0xB9F0E4, alpha: 0.42))
    context.setLineWidth(max(0.6, size * 0.012))
    context.addPath(outerPath)
    context.strokePath()

    let card = CGRect(x: size * 0.17, y: size * 0.19, width: size * 0.66, height: size * 0.64)
    let cardPath = roundedRect(card, radius: size * 0.075)
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -size * 0.035),
        blur: size * 0.055,
        color: color(0x001C1A, alpha: 0.42)
    )
    context.setFillColor(color(0xF7F1E5))
    context.addPath(cardPath)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(cardPath)
    context.clip()

    let sky = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [color(0xDDF1EA), color(0xF7F1E5)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        sky,
        start: CGPoint(x: card.midX, y: card.maxY),
        end: CGPoint(x: card.midX, y: card.minY),
        options: []
    )

    context.setFillColor(color(0xF2B44C))
    context.fillEllipse(in: CGRect(
        x: card.minX + card.width * 0.64,
        y: card.minY + card.height * 0.60,
        width: card.width * 0.15,
        height: card.width * 0.15
    ))

    let rearMountain = CGMutablePath()
    rearMountain.move(to: CGPoint(x: card.minX, y: card.minY + card.height * 0.19))
    rearMountain.addLine(to: CGPoint(x: card.minX + card.width * 0.34, y: card.minY + card.height * 0.57))
    rearMountain.addLine(to: CGPoint(x: card.minX + card.width * 0.54, y: card.minY + card.height * 0.34))
    rearMountain.addLine(to: CGPoint(x: card.minX + card.width * 0.76, y: card.minY + card.height * 0.50))
    rearMountain.addLine(to: CGPoint(x: card.maxX, y: card.minY + card.height * 0.17))
    rearMountain.closeSubpath()
    context.setFillColor(color(0x70B5A5))
    context.addPath(rearMountain)
    context.fillPath()

    let frontMountain = CGMutablePath()
    frontMountain.move(to: CGPoint(x: card.minX, y: card.minY))
    frontMountain.addLine(to: CGPoint(x: card.minX, y: card.minY + card.height * 0.17))
    frontMountain.addLine(to: CGPoint(x: card.minX + card.width * 0.28, y: card.minY + card.height * 0.42))
    frontMountain.addLine(to: CGPoint(x: card.minX + card.width * 0.52, y: card.minY + card.height * 0.17))
    frontMountain.addLine(to: CGPoint(x: card.maxX, y: card.minY + card.height * 0.38))
    frontMountain.addLine(to: CGPoint(x: card.maxX, y: card.minY))
    frontMountain.closeSubpath()
    context.setFillColor(color(0x165C55))
    context.addPath(frontMountain)
    context.fillPath()

    context.translateBy(x: card.midX, y: card.minY + card.height * 0.37)
    context.rotate(by: CGFloat(12 * Double.pi / 180))
    let band = CGRect(x: -card.width * 0.58, y: -size * 0.075, width: card.width * 1.16, height: size * 0.15)
    context.setFillColor(color(0x082F2C, alpha: 0.90))
    context.fill(band)
    context.setStrokeColor(color(0x80E3D0, alpha: 0.78))
    context.setLineWidth(max(0.5, size * 0.009))
    context.move(to: CGPoint(x: band.minX, y: band.maxY))
    context.addLine(to: CGPoint(x: band.maxX, y: band.maxY))
    context.strokePath()

    let halfWidth = size * 0.105
    let halfHeight = size * 0.041
    context.setStrokeColor(color(0xFFF8EC))
    context.setLineWidth(max(1, size * 0.026))
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.move(to: CGPoint(x: -halfWidth, y: halfHeight))
    context.addLine(to: CGPoint(x: -halfWidth * 0.45, y: -halfHeight))
    context.addLine(to: CGPoint(x: 0, y: halfHeight * 0.35))
    context.addLine(to: CGPoint(x: halfWidth * 0.45, y: -halfHeight))
    context.addLine(to: CGPoint(x: halfWidth, y: halfHeight))
    context.strokePath()
    context.restoreGState()

    context.setStrokeColor(color(0xFFFFFF, alpha: 0.40))
    context.setLineWidth(max(0.5, size * 0.009))
    context.addPath(cardPath)
    context.strokePath()
}

for (name, pixels) in variants {
    let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setAllowsAntialiasing(true)
    drawIcon(in: context, size: CGFloat(pixels))

    let image = context.makeImage()!
    let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
    try data.write(to: output.appendingPathComponent(name), options: .atomic)
}
