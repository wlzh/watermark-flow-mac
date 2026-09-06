import Foundation

public final class TemplateRepository {
    public let storageURL: URL

    public init(storageURL: URL? = nil) {
        if let storageURL {
            self.storageURL = storageURL
            return
        }

        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        self.storageURL = support
            .appendingPathComponent(AppVersion.bundleIdentifier, isDirectory: true)
            .appendingPathComponent("templates.json")
    }

    public func loadUserTemplates() throws -> [WatermarkTemplate] {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return [] }
        let data = try Data(contentsOf: storageURL)
        return try JSONDecoder.watermarkFlow.decode([WatermarkTemplate].self, from: data)
            .filter { !$0.isBuiltIn }
    }

    public func saveUserTemplates(_ templates: [WatermarkTemplate]) throws {
        let userTemplates = templates.map { template -> WatermarkTemplate in
            var copy = template.clamped()
            copy.isBuiltIn = false
            return copy
        }
        try FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.watermarkFlow.encode(userTemplates)
        try data.write(to: storageURL, options: .atomic)
    }
}

private extension JSONEncoder {
    static var watermarkFlow: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}

private extension JSONDecoder {
    static var watermarkFlow: JSONDecoder { JSONDecoder() }
}
