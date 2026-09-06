import Foundation

public struct TemplateLibraryState: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var templates: [WatermarkTemplate]
    public var lastSelectedTemplateID: UUID?

    public init(
        schemaVersion: Int = currentSchemaVersion,
        templates: [WatermarkTemplate],
        lastSelectedTemplateID: UUID? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.templates = templates
        self.lastSelectedTemplateID = lastSelectedTemplateID
    }
}

public enum TemplateRepositoryError: LocalizedError {
    case unsupportedStorageFormat

    public var errorDescription: String? {
        "模板文件格式无法识别"
    }
}

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

    public func loadLibrary() throws -> TemplateLibraryState {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return TemplateLibraryState(templates: DefaultTemplates.all)
        }

        let data = try Data(contentsOf: storageURL)
        if let state = try? JSONDecoder.watermarkFlow.decode(TemplateLibraryState.self, from: data) {
            return normalized(state)
        }

        // v0.1.0 stored only an array of user templates.
        if let legacyTemplates = try? JSONDecoder.watermarkFlow.decode([WatermarkTemplate].self, from: data) {
            return normalized(TemplateLibraryState(templates: legacyTemplates))
        }

        throw TemplateRepositoryError.unsupportedStorageFormat
    }

    public func saveLibrary(_ state: TemplateLibraryState) throws {
        let normalizedState = normalized(state)
        try FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.watermarkFlow.encode(normalizedState)
        try data.write(to: storageURL, options: .atomic)
    }

    public func loadUserTemplates() throws -> [WatermarkTemplate] {
        try loadLibrary().templates.filter { !$0.isBuiltIn }
    }

    public func saveUserTemplates(_ templates: [WatermarkTemplate]) throws {
        let existing = try loadLibrary()
        let state = TemplateLibraryState(
            templates: existing.templates.filter(\.isBuiltIn) + templates,
            lastSelectedTemplateID: existing.lastSelectedTemplateID
        )
        try saveLibrary(state)
    }

    private func normalized(_ state: TemplateLibraryState) -> TemplateLibraryState {
        let builtInIDs = Set(DefaultTemplates.all.map(\.id))
        var seen = Set<UUID>()
        var storedByID: [UUID: WatermarkTemplate] = [:]
        for template in state.templates where !seen.contains(template.id) {
            seen.insert(template.id)
            storedByID[template.id] = template
        }

        let builtIns = DefaultTemplates.all.map { factoryTemplate -> WatermarkTemplate in
            guard var stored = storedByID[factoryTemplate.id] else { return factoryTemplate }
            stored.id = factoryTemplate.id
            stored.isBuiltIn = true
            return stored.clamped()
        }

        let users = state.templates.compactMap { template -> WatermarkTemplate? in
            guard !builtInIDs.contains(template.id) else { return nil }
            guard storedByID[template.id] != nil else { return nil }
            storedByID.removeValue(forKey: template.id)
            var user = template.clamped()
            user.isBuiltIn = false
            return user
        }
        let templates = builtIns + users
        let selectedID = state.lastSelectedTemplateID.flatMap { selected in
            templates.contains { $0.id == selected } ? selected : nil
        }
        return TemplateLibraryState(
            schemaVersion: TemplateLibraryState.currentSchemaVersion,
            templates: templates,
            lastSelectedTemplateID: selectedID
        )
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
