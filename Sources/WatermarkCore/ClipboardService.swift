import AppKit
import Foundation

public enum ClipboardError: LocalizedError {
    case noImage
    case encodingFailed
    case writeFailed
    case multipleWebImages
    case unsupportedWebImageSource
    case webImageUnavailable
    case imageTooLarge

    public var errorDescription: String? {
        switch self {
        case .noImage: return "剪贴板中没有可读取的图片"
        case .encodingFailed: return "无法编码生成后的图片"
        case .writeFailed: return "无法将图片写入系统剪贴板"
        case .multipleWebImages: return "复制内容包含多张网页图片，请单独复制一张图片"
        case .unsupportedWebImageSource: return "网页图片地址不受支持，请在图片上右键选择“复制图像”后重试"
        case .webImageUnavailable: return "已识别网页图片，但无法读取原图，请在图片上右键选择“复制图像”后重试"
        case .imageTooLarge: return "复制的网页图片超过 64 MB 限制"
        }
    }
}

public enum ClipboardService {
    public typealias RemoteImageDataLoader = (URLRequest) async throws -> (Data, URLResponse)

    private static let maximumWebImageBytes = 64 * 1_024 * 1_024

    public static func readImage(from pasteboard: NSPasteboard = .general) throws -> NSImage {
        guard let image = NSImage(pasteboard: pasteboard) else {
            throw ClipboardError.noImage
        }
        return image
    }

    @MainActor
    public static func readImageResolvingWebContent(
        from pasteboard: NSPasteboard = .general,
        remoteLoader: RemoteImageDataLoader? = nil
    ) async throws -> NSImage {
        if let image = NSImage(pasteboard: pasteboard) {
            return image
        }
        guard let html = clipboardHTML(from: pasteboard) else {
            throw ClipboardError.noImage
        }

        let sources = imageSources(in: html)
        guard !sources.isEmpty else { throw ClipboardError.noImage }
        guard sources.count == 1 else { throw ClipboardError.multipleWebImages }

        let data: Data
        let source = sources[0]
        if source.lowercased().hasPrefix("data:image/") {
            data = try decodeImageDataURL(source)
        } else {
            guard let url = URL(string: source), url.scheme?.lowercased() == "https" else {
                throw ClipboardError.unsupportedWebImageSource
            }
            data = try await loadRemoteImage(url: url, loader: remoteLoader)
        }

        guard data.count <= maximumWebImageBytes else { throw ClipboardError.imageTooLarge }
        guard let image = NSImage(data: data) else { throw ClipboardError.webImageUnavailable }
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

    private static func clipboardHTML(from pasteboard: NSPasteboard) -> String? {
        guard let data = pasteboard.data(forType: .html) else { return nil }
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .unicode)
    }

    private static func imageSources(in html: String) -> [String] {
        guard let tagExpression = try? NSRegularExpression(
            pattern: #"<img\b[^>]*>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ), let attributeExpression = try? NSRegularExpression(
            pattern: #"([A-Za-z_:][-A-Za-z0-9_:.]*)\s*=\s*([\"'])(.*?)\2"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return [] }

        let htmlRange = NSRange(html.startIndex..<html.endIndex, in: html)
        var sources: [String] = []
        for tagMatch in tagExpression.matches(in: html, range: htmlRange) {
            guard let tagRange = Range(tagMatch.range, in: html) else { continue }
            let tag = String(html[tagRange])
            let range = NSRange(tag.startIndex..<tag.endIndex, in: tag)
            var primarySource: String?
            var fallbackSource: String?
            for attributeMatch in attributeExpression.matches(in: tag, range: range) {
                guard let nameRange = Range(attributeMatch.range(at: 1), in: tag),
                      let valueRange = Range(attributeMatch.range(at: 3), in: tag) else { continue }
                let name = tag[nameRange].lowercased()
                let value = decodeHTMLEntities(String(tag[valueRange]))
                if name == "src" {
                    primarySource = value
                } else if name == "data-src" {
                    fallbackSource = value
                }
            }
            if let source = primarySource ?? fallbackSource, !source.isEmpty {
                sources.append(source)
            }
        }
        var seen = Set<String>()
        return sources.filter { seen.insert($0).inserted }
    }

    private static func decodeHTMLEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&", options: .caseInsensitive)
            .replacingOccurrences(of: "&quot;", with: "\"", options: .caseInsensitive)
            .replacingOccurrences(of: "&#39;", with: "'", options: .caseInsensitive)
            .replacingOccurrences(of: "&lt;", with: "<", options: .caseInsensitive)
            .replacingOccurrences(of: "&gt;", with: ">", options: .caseInsensitive)
    }

    private static func decodeImageDataURL(_ source: String) throws -> Data {
        guard let separator = source.firstIndex(of: ",") else {
            throw ClipboardError.webImageUnavailable
        }
        let metadata = source[..<separator].lowercased()
        let payload = String(source[source.index(after: separator)...])
        let data: Data?
        if metadata.contains(";base64") {
            data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters)
        } else {
            data = payload.removingPercentEncoding?.data(using: .utf8)
        }
        guard let data else { throw ClipboardError.webImageUnavailable }
        guard data.count <= maximumWebImageBytes else { throw ClipboardError.imageTooLarge }
        return data
    }

    private static func loadRemoteImage(
        url: URL,
        loader: RemoteImageDataLoader?
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("image/avif,image/webp,image/png,image/jpeg,image/*;q=0.8", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = if let loader {
                try await loader(request)
            } else {
                try await URLSession.shared.data(for: request)
            }
            if let http = response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                throw ClipboardError.webImageUnavailable
            }
            guard response.url?.scheme?.lowercased() == "https" else {
                throw ClipboardError.unsupportedWebImageSource
            }
            guard data.count <= maximumWebImageBytes else { throw ClipboardError.imageTooLarge }
            return data
        } catch let error as ClipboardError {
            throw error
        } catch {
            throw ClipboardError.webImageUnavailable
        }
    }
}
