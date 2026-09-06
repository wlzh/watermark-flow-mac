import AppKit
import Foundation

public struct RGBAColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public init(hex: UInt32, alpha: Double = 1) {
        red = Double((hex >> 16) & 0xff) / 255
        green = Double((hex >> 8) & 0xff) / 255
        blue = Double(hex & 0xff) / 255
        self.alpha = alpha
    }

    public init(nsColor: NSColor) {
        let color = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        red = Double(color.redComponent)
        green = Double(color.greenComponent)
        blue = Double(color.blueComponent)
        alpha = Double(color.alphaComponent)
    }

    public var nsColor: NSColor {
        NSColor(
            calibratedRed: CGFloat(red.clamped(to: 0...1)),
            green: CGFloat(green.clamped(to: 0...1)),
            blue: CGFloat(blue.clamped(to: 0...1)),
            alpha: CGFloat(alpha.clamped(to: 0...1))
        )
    }

    public func clamped() -> RGBAColor {
        RGBAColor(
            red: red.clamped(to: 0...1),
            green: green.clamped(to: 0...1),
            blue: blue.clamped(to: 0...1),
            alpha: alpha.clamped(to: 0...1)
        )
    }
}

public struct NormalizedPoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public func clamped() -> NormalizedPoint {
        NormalizedPoint(x: x.clamped(to: 0...1), y: y.clamped(to: 0...1))
    }

    public func offsetBy(deltaX: Double, deltaY: Double) -> NormalizedPoint {
        NormalizedPoint(x: x + deltaX, y: y + deltaY).clamped()
    }
}

public enum WatermarkBrand: String, Codable, CaseIterable, Sendable {
    case x
    case youtube
    case text
    case custom

    public var displayName: String {
        switch self {
        case .x: return "X"
        case .youtube: return "YouTube"
        case .text: return "纯文字"
        case .custom: return "自定义 Logo"
        }
    }
}

public struct WatermarkTemplate: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var brand: WatermarkBrand
    public var text: String
    public var foregroundColor: RGBAColor
    public var backgroundColor: RGBAColor
    public var accentColor: RGBAColor
    public var opacity: Double
    public var relativeHeight: Double
    public var position: NormalizedPoint
    public var rotationDegrees: Double
    public var customLogoPNG: Data?
    public var isBuiltIn: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        brand: WatermarkBrand,
        text: String,
        foregroundColor: RGBAColor,
        backgroundColor: RGBAColor,
        accentColor: RGBAColor,
        opacity: Double = 0.9,
        relativeHeight: Double = 0.09,
        position: NormalizedPoint = NormalizedPoint(x: 0.82, y: 0.9),
        rotationDegrees: Double = 0,
        customLogoPNG: Data? = nil,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.text = text
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.accentColor = accentColor
        self.opacity = opacity
        self.relativeHeight = relativeHeight
        self.position = position
        self.rotationDegrees = rotationDegrees
        self.customLogoPNG = customLogoPNG
        self.isBuiltIn = isBuiltIn
    }

    public func clamped() -> WatermarkTemplate {
        var copy = self
        copy.foregroundColor = foregroundColor.clamped()
        copy.backgroundColor = backgroundColor.clamped()
        copy.accentColor = accentColor.clamped()
        copy.opacity = opacity.clamped(to: 0.05...1)
        copy.relativeHeight = relativeHeight.clamped(to: 0.035...0.3)
        copy.position = position.clamped()
        copy.rotationDegrees = rotationDegrees.clamped(to: -180...180)
        return copy
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
