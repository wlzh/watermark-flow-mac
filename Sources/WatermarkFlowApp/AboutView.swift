import SwiftUI
import WatermarkCore

struct AboutView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppTheme { AppTheme(colorScheme: colorScheme) }

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 90, height: 90)
                .accessibilityLabel("WatermarkFlow 图片水印图标")

            VStack(spacing: 5) {
                Text("WatermarkFlow")
                    .font(.custom("Avenir Next Heavy", size: 25))
                Text("版本 \(AppVersion.current) (\(AppVersion.build))")
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(theme.textSecondary)
            }

            VStack(spacing: 7) {
                HStack(spacing: 7) {
                    Text("作者")
                        .foregroundStyle(theme.textSecondary)
                    Link(AppVersion.author, destination: URL(string: AppVersion.authorProfileURL)!)
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.accent)
                }
                Link(AppVersion.websiteURL, destination: URL(string: AppVersion.websiteURL)!)
                    .foregroundStyle(theme.accent)
            }
            .font(.system(size: 13))

            Text("图片仅在本机处理，不会上传网络")
                .font(.system(size: 11))
                .foregroundStyle(theme.textSecondary)

            Link(AppVersion.licenseName, destination: URL(string: AppVersion.licenseURL)!)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.accent)
        }
        .frame(width: 420, height: 330)
        .background(theme.background)
        .foregroundStyle(theme.textPrimary)
    }
}
