import SwiftUI
import WatermarkCore

struct AboutView: View {
    @Environment(\.colorScheme) private var colorScheme
    private let gold = Color(red: 0.94, green: 0.68, blue: 0.24)

    private var theme: AppTheme { AppTheme(colorScheme: colorScheme) }

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(theme.accent)
                    .frame(width: 86, height: 86)
                Circle()
                    .fill(gold)
                    .frame(width: 52, height: 52)
                Image(systemName: "seal.fill")
                    .font(.system(size: 29, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
            }

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
        }
        .frame(width: 420, height: 330)
        .background(theme.background)
        .foregroundStyle(theme.textPrimary)
    }
}
