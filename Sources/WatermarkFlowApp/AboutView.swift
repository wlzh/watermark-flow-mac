import SwiftUI
import WatermarkCore

struct AboutView: View {
    private let paper = Color(red: 0.95, green: 0.93, blue: 0.87)
    private let ink = Color(red: 0.08, green: 0.11, blue: 0.12)
    private let accent = Color(red: 0.05, green: 0.52, blue: 0.48)
    private let gold = Color(red: 0.94, green: 0.68, blue: 0.24)

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(accent)
                    .frame(width: 86, height: 86)
                Circle()
                    .fill(gold)
                    .frame(width: 52, height: 52)
                Image(systemName: "seal.fill")
                    .font(.system(size: 29, weight: .semibold))
                    .foregroundStyle(ink)
            }

            VStack(spacing: 5) {
                Text("WatermarkFlow")
                    .font(.custom("Avenir Next Heavy", size: 25))
                Text("版本 \(AppVersion.current) (\(AppVersion.build))")
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(ink.opacity(0.55))
            }

            VStack(spacing: 7) {
                HStack(spacing: 7) {
                    Text("作者")
                        .foregroundStyle(ink.opacity(0.5))
                    Text("X @wlzh")
                        .fontWeight(.semibold)
                }
                Link("https://869hr.uk", destination: URL(string: "https://869hr.uk")!)
                    .foregroundStyle(accent)
            }
            .font(.system(size: 13))

            Text("图片仅在本机处理，不会上传网络")
                .font(.system(size: 11))
                .foregroundStyle(ink.opacity(0.5))
        }
        .frame(width: 420, height: 330)
        .background(paper)
        .foregroundStyle(ink)
    }
}
