import Foundation

public enum DefaultTemplates {
    public static let xWLZHID = UUID(uuidString: "8F717A15-0CA6-41AD-A999-000000000001")!
    public static let xGXJDianID = UUID(uuidString: "8F717A15-0CA6-41AD-A999-000000000002")!
    public static let youtubeDuanKuID = UUID(uuidString: "8F717A15-0CA6-41AD-A999-000000000003")!

    public static let all: [WatermarkTemplate] = [
        WatermarkTemplate(
            id: xWLZHID,
            name: "X · @wlzh",
            brand: .x,
            text: "@wlzh",
            foregroundColor: RGBAColor(hex: 0xffffff),
            backgroundColor: RGBAColor(hex: 0x111315, alpha: 0.92),
            accentColor: RGBAColor(hex: 0xffffff),
            opacity: 0.92,
            relativeHeight: 0.085,
            position: NormalizedPoint(x: 0.84, y: 0.9),
            isBuiltIn: true
        ),
        WatermarkTemplate(
            id: xGXJDianID,
            name: "X · @gxjdian",
            brand: .x,
            text: "@gxjdian",
            foregroundColor: RGBAColor(hex: 0xffffff),
            backgroundColor: RGBAColor(hex: 0x111315, alpha: 0.92),
            accentColor: RGBAColor(hex: 0x35d0ba),
            opacity: 0.92,
            relativeHeight: 0.085,
            position: NormalizedPoint(x: 0.83, y: 0.9),
            isBuiltIn: true
        ),
        WatermarkTemplate(
            id: youtubeDuanKuID,
            name: "YouTube · 短裤AI分享",
            brand: .youtube,
            text: "短裤AI分享",
            foregroundColor: RGBAColor(hex: 0x181818),
            backgroundColor: RGBAColor(hex: 0xffffff, alpha: 0.94),
            accentColor: RGBAColor(hex: 0xff0033),
            opacity: 0.94,
            relativeHeight: 0.09,
            position: NormalizedPoint(x: 0.82, y: 0.9),
            isBuiltIn: true
        )
    ]

    public static func template(id: UUID) -> WatermarkTemplate? {
        all.first { $0.id == id }
    }
}
