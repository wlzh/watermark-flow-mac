import AppKit
import Foundation

public enum ClipboardError: LocalizedError {
    case noImage
    case encodingFailed
    case writeFailed

    public var errorDescription: String? {
        switch self {
        case .noImage: return "剪贴板中没有可读取的图片"
        case .encodingFailed: return "无法编码生成后的图片"
        case .writeFailed: return "无法将图片写入系统剪贴板"
        }
    }
}

public enum ClipboardService {
    public static func readImage(from pasteboard: NSPasteboard = .general) throws -> NSImage {
        guard let image = NSImage(pasteboard: pasteboard) else {
            throw ClipboardError.noImage
        }
        return image
    }

    @discardableResult
    public static func writeImage(_ image: NSImage, to pasteboard: NSPasteboard = .general) throws -> Int {
        guard let png = try? WatermarkRenderer.encode(image: image, format: .png),
              let tiff = image.tiffRepresentation else {
            throw ClipboardError.encodingFailed
        }

        pasteboard.clearContents()
        let pngWritten = pasteboard.setData(png, forType: .png)
        let tiffWritten = pasteboard.setData(tiff, forType: .tiff)
        guard pngWritten || tiffWritten else { throw ClipboardError.writeFailed }
        return pasteboard.changeCount
    }
}
