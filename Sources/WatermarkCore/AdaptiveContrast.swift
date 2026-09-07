import Foundation

public struct WatermarkLuminanceStatistics: Equatable, Sendable {
    public var mean: Double
    public var deviation: Double

    public init(mean: Double, deviation: Double) {
        self.mean = mean.clamped(to: 0...1)
        self.deviation = deviation.clamped(to: 0...0.5)
    }
}

public struct ResolvedWatermarkColors: Equatable, Sendable {
    public var foreground: RGBAColor
    public var background: RGBAColor
    public var accent: RGBAColor

    public init(foreground: RGBAColor, background: RGBAColor, accent: RGBAColor) {
        self.foreground = foreground
        self.background = background
        self.accent = accent
    }
}

public enum AdaptiveContrastResolver {
    public static func resolve(
        foreground: RGBAColor,
        background: RGBAColor,
        accent: RGBAColor,
        brand: WatermarkBrand,
        mode: WatermarkContrastMode,
        strength: WatermarkContrastStrength,
        statistics: WatermarkLuminanceStatistics
    ) -> ResolvedWatermarkColors {
        guard mode != .off else {
            return ResolvedWatermarkColors(
                foreground: foreground,
                background: background,
                accent: accent
            )
        }

        let tones = grayscaleTones(strength: strength)
        let foregroundOnly = statistics.mean > 0.179 ? tones.dark : tones.light
        guard mode == .foregroundAndBackground else {
            let resolvedForeground = foregroundOnly.withAlpha(foreground.alpha)
            return ResolvedWatermarkColors(
                foreground: resolvedForeground,
                background: background,
                accent: brand == .x ? foregroundOnly.withAlpha(accent.alpha) : accent
            )
        }

        let combinedForeground = statistics.mean > 0.179 ? tones.light : tones.dark
        let combinedBackground = statistics.mean > 0.179 ? tones.dark : tones.light
        let baseAlpha: Double
        switch strength {
        case .soft: baseAlpha = 0.42
        case .standard: baseAlpha = 0.62
        case .strong: baseAlpha = 0.82
        }
        let complexityBoost = statistics.deviation > 0.18 ? 0.10 : 0
        let resolvedForeground = combinedForeground.withAlpha(foreground.alpha)
        let resolvedBackground = combinedBackground.withAlpha(min(0.92, baseAlpha + complexityBoost))
        return ResolvedWatermarkColors(
            foreground: resolvedForeground,
            background: resolvedBackground,
            accent: brand == .x ? combinedForeground.withAlpha(accent.alpha) : accent
        )
    }

    private static func grayscaleTones(
        strength: WatermarkContrastStrength
    ) -> (light: RGBAColor, dark: RGBAColor) {
        let light: Double
        let dark: Double
        switch strength {
        case .soft:
            light = 0.86
            dark = 0.14
        case .standard:
            light = 0.95
            dark = 0.06
        case .strong:
            light = 1
            dark = 0
        }
        return (gray(light), gray(dark))
    }

    private static func gray(_ value: Double) -> RGBAColor {
        RGBAColor(red: value, green: value, blue: value)
    }
}

private extension RGBAColor {
    func withAlpha(_ alpha: Double) -> RGBAColor {
        var copy = self
        copy.alpha = alpha
        return copy
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
