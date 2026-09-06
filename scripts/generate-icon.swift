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

for (name, size) in variants {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setAllowsAntialiasing(true)

    let bounds = CGRect(x: 0, y: 0, width: size, height: size)
    let outer = bounds.insetBy(dx: CGFloat(size) * 0.04, dy: CGFloat(size) * 0.04)
    let outerPath = CGPath(
        roundedRect: outer,
        cornerWidth: CGFloat(size) * 0.23,
        cornerHeight: CGFloat(size) * 0.23,
        transform: nil
    )
    context.setFillColor(NSColor(calibratedRed: 0.035, green: 0.49, blue: 0.45, alpha: 1).cgColor)
    context.addPath(outerPath)
    context.fillPath()

    let seal = bounds.insetBy(dx: CGFloat(size) * 0.2, dy: CGFloat(size) * 0.2)
    context.setFillColor(NSColor(calibratedRed: 0.96, green: 0.69, blue: 0.25, alpha: 1).cgColor)
    context.fillEllipse(in: seal)

    context.setStrokeColor(NSColor(calibratedWhite: 0.08, alpha: 1).cgColor)
    context.setLineWidth(max(1, CGFloat(size) * 0.075))
    context.setLineCap(.round)
    context.move(to: CGPoint(x: CGFloat(size) * 0.31, y: CGFloat(size) * 0.62))
    context.addLine(to: CGPoint(x: CGFloat(size) * 0.43, y: CGFloat(size) * 0.36))
    context.addLine(to: CGPoint(x: CGFloat(size) * 0.52, y: CGFloat(size) * 0.57))
    context.addLine(to: CGPoint(x: CGFloat(size) * 0.61, y: CGFloat(size) * 0.36))
    context.addLine(to: CGPoint(x: CGFloat(size) * 0.73, y: CGFloat(size) * 0.62))
    context.strokePath()

    let image = context.makeImage()!
    let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
    try data.write(to: output.appendingPathComponent(name), options: .atomic)
}
