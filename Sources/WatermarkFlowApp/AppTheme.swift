import SwiftUI

struct AppTheme {
    let background: Color
    let surface: Color
    let controlFill: Color
    let textPrimary: Color
    let textSecondary: Color
    let border: Color
    let accent: Color
    let warning: Color
    let onAccent: Color
    let canvas: Color

    init(colorScheme: ColorScheme) {
        if colorScheme == .dark {
            background = Color(hex: 0x15191A)
            surface = Color(hex: 0x1C2122)
            controlFill = Color(hex: 0x272D2E)
            textPrimary = Color(hex: 0xE5E0D4)
            textSecondary = Color(hex: 0xA6AAA4)
            border = Color(hex: 0x394041)
            accent = Color(hex: 0x48B9AA)
            warning = Color(hex: 0xD6A45B)
            onAccent = Color(hex: 0x0B1514)
            canvas = Color(hex: 0x0B0F10)
        } else {
            background = Color(hex: 0xF2EDE2)
            surface = Color(hex: 0xF8F4EA)
            controlFill = Color(hex: 0xFFFDF7)
            textPrimary = Color(hex: 0x151A1B)
            textSecondary = Color(hex: 0x5C6463)
            border = Color(hex: 0xD4CCBE)
            accent = Color(hex: 0x0D887C)
            warning = Color(hex: 0x9A5A08)
            onAccent = Color.white
            canvas = Color(hex: 0x111617)
        }
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255
        )
    }
}
