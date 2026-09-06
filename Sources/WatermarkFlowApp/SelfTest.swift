import AppKit
import Foundation
import WatermarkCore

enum SelfTest {
    static func run() throws {
        let pasteboardSnapshot = PasteboardSnapshot(pasteboard: .general)
        defer { pasteboardSnapshot.restore(to: .general) }

        let source = try makeSourceImage(width: 960, height: 540)
        for template in DefaultTemplates.all {
            let output = try WatermarkRenderer.render(source: source, template: template)
            guard WatermarkRenderer.pixelSize(of: output) == CGSize(width: 960, height: 540) else {
                throw Failure("rendered size mismatch for \(template.name)")
            }
            let png = try WatermarkRenderer.encode(image: output, format: .png)
            guard png.count > 10_000 else { throw Failure("PNG too small for \(template.name)") }
        }

        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("watermark-flow-self-test-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("templates.json")
        defer { try? FileManager.default.removeItem(at: temporary.deletingLastPathComponent()) }
        let repository = TemplateRepository(storageURL: temporary)
        var custom = DefaultTemplates.all[0]
        custom.id = UUID()
        custom.name = "Self Test"
        custom.isBuiltIn = false
        try repository.saveUserTemplates([custom])
        guard try repository.loadUserTemplates() == [custom.clamped()] else {
            throw Failure("template persistence mismatch")
        }

        let output = try WatermarkRenderer.render(source: source, template: DefaultTemplates.all[0])
        let changeCount = try ClipboardService.writeImage(output)
        let reread = try ClipboardService.readImage()
        guard changeCount > 0,
              WatermarkRenderer.pixelSize(of: reread) == CGSize(width: 960, height: 540) else {
            throw Failure("general pasteboard round-trip failed")
        }

        print("SELF_TEST_VERSION=\(AppVersion.current)")
        print("SELF_TEST_TEMPLATES=\(DefaultTemplates.all.count)")
        print("SELF_TEST_RENDER=PASS 960x540")
        print("SELF_TEST_PERSISTENCE=PASS")
        print("SELF_TEST_GENERAL_PASTEBOARD=PASS changeCount=\(changeCount)")
    }

    private static func makeSourceImage(width: Int, height: Int) throws -> NSImage {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw Failure("source context creation failed") }
        let colors = [NSColor(calibratedRed: 0.08, green: 0.22, blue: 0.28, alpha: 1).cgColor,
                      NSColor(calibratedRed: 0.94, green: 0.68, blue: 0.26, alpha: 1).cgColor] as CFArray
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1])!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: width, y: height),
            options: []
        )
        guard let image = context.makeImage() else { throw Failure("source image creation failed") }
        return NSImage(cgImage: image, size: NSSize(width: width, height: height))
    }

    struct Failure: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }

    private struct PasteboardSnapshot {
        let items: [NSPasteboardItem]

        init(pasteboard: NSPasteboard) {
            items = (pasteboard.pasteboardItems ?? []).map { source in
                let copy = NSPasteboardItem()
                for type in source.types {
                    if let data = source.data(forType: type) {
                        copy.setData(data, forType: type)
                    }
                }
                return copy
            }
        }

        func restore(to pasteboard: NSPasteboard) {
            pasteboard.clearContents()
            if !items.isEmpty {
                pasteboard.writeObjects(items)
            }
        }
    }
}
