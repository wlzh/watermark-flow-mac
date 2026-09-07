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

public enum WatermarkLayoutMode: String, Codable, CaseIterable, Sendable {
    case single
    case tiled

    public var displayName: String {
        switch self {
        case .single: return "单个"
        case .tiled: return "满屏"
        }
    }
}

public struct WatermarkVisualSettings: Codable, Equatable, Sendable {
    public var foregroundColor: RGBAColor
    public var backgroundColor: RGBAColor
    public var accentColor: RGBAColor
    public var opacity: Double
    public var relativeHeight: Double
    public var rotationDegrees: Double

    public init(
        foregroundColor: RGBAColor,
        backgroundColor: RGBAColor,
        accentColor: RGBAColor,
        opacity: Double,
        relativeHeight: Double,
        rotationDegrees: Double
    ) {
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.accentColor = accentColor
        self.opacity = opacity
        self.relativeHeight = relativeHeight
        self.rotationDegrees = rotationDegrees
    }

    public func clamped() -> WatermarkVisualSettings {
        WatermarkVisualSettings(
            foregroundColor: foregroundColor.clamped(),
            backgroundColor: backgroundColor.clamped(),
            accentColor: accentColor.clamped(),
            opacity: opacity.clamped(to: 0.05...1),
            relativeHeight: relativeHeight.clamped(to: 0.035...0.3),
            rotationDegrees: rotationDegrees.clamped(to: -180...180)
        )
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
    public var layoutMode: WatermarkLayoutMode
    public var tileDensity: Double
    public var tiledStyle: WatermarkVisualSettings
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
        layoutMode: WatermarkLayoutMode = .single,
        tileDensity: Double = 5,
        tiledStyle: WatermarkVisualSettings? = nil,
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
        self.layoutMode = layoutMode
        self.tileDensity = tileDensity
        self.tiledStyle = tiledStyle ?? WatermarkVisualSettings(
            foregroundColor: foregroundColor,
            backgroundColor: backgroundColor,
            accentColor: accentColor,
            opacity: opacity,
            relativeHeight: relativeHeight,
            rotationDegrees: rotationDegrees
        )
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
        copy.tileDensity = tileDensity.clamped(to: 1...10)
        copy.tiledStyle = tiledStyle.clamped()
        return copy
    }

    public var activeForegroundColor: RGBAColor {
        get { layoutMode == .tiled ? tiledStyle.foregroundColor : foregroundColor }
        set {
            if layoutMode == .tiled {
                tiledStyle.foregroundColor = newValue
            } else {
                foregroundColor = newValue
            }
        }
    }

    public var activeBackgroundColor: RGBAColor {
        get { layoutMode == .tiled ? tiledStyle.backgroundColor : backgroundColor }
        set {
            if layoutMode == .tiled {
                tiledStyle.backgroundColor = newValue
            } else {
                backgroundColor = newValue
            }
        }
    }

    public var activeAccentColor: RGBAColor {
        get { layoutMode == .tiled ? tiledStyle.accentColor : accentColor }
        set {
            if layoutMode == .tiled {
                tiledStyle.accentColor = newValue
            } else {
                accentColor = newValue
            }
        }
    }

    public var activeOpacity: Double {
        get { layoutMode == .tiled ? tiledStyle.opacity : opacity }
        set {
            if layoutMode == .tiled {
                tiledStyle.opacity = newValue
            } else {
                opacity = newValue
            }
        }
    }

    public var activeRelativeHeight: Double {
        get { layoutMode == .tiled ? tiledStyle.relativeHeight : relativeHeight }
        set {
            if layoutMode == .tiled {
                tiledStyle.relativeHeight = newValue
            } else {
                relativeHeight = newValue
            }
        }
    }

    public var activeRotationDegrees: Double {
        get { layoutMode == .tiled ? tiledStyle.rotationDegrees : rotationDegrees }
        set {
            if layoutMode == .tiled {
                tiledStyle.rotationDegrees = newValue
            } else {
                rotationDegrees = newValue
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case brand
        case text
        case foregroundColor
        case backgroundColor
        case accentColor
        case opacity
        case relativeHeight
        case position
        case rotationDegrees
        case layoutMode
        case tileDensity
        case tiledStyle
        case customLogoPNG
        case isBuiltIn
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        brand = try container.decode(WatermarkBrand.self, forKey: .brand)
        text = try container.decode(String.self, forKey: .text)
        foregroundColor = try container.decode(RGBAColor.self, forKey: .foregroundColor)
        backgroundColor = try container.decode(RGBAColor.self, forKey: .backgroundColor)
        accentColor = try container.decode(RGBAColor.self, forKey: .accentColor)
        opacity = try container.decode(Double.self, forKey: .opacity)
        relativeHeight = try container.decode(Double.self, forKey: .relativeHeight)
        position = try container.decode(NormalizedPoint.self, forKey: .position)
        rotationDegrees = try container.decode(Double.self, forKey: .rotationDegrees)
        layoutMode = try container.decodeIfPresent(WatermarkLayoutMode.self, forKey: .layoutMode) ?? .single
        tileDensity = try container.decodeIfPresent(Double.self, forKey: .tileDensity) ?? 5
        tiledStyle = try container.decodeIfPresent(WatermarkVisualSettings.self, forKey: .tiledStyle)
            ?? WatermarkVisualSettings(
                foregroundColor: foregroundColor,
                backgroundColor: backgroundColor,
                accentColor: accentColor,
                opacity: opacity,
                relativeHeight: relativeHeight,
                rotationDegrees: rotationDegrees
            )
        customLogoPNG = try container.decodeIfPresent(Data.self, forKey: .customLogoPNG)
        isBuiltIn = try container.decode(Bool.self, forKey: .isBuiltIn)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
