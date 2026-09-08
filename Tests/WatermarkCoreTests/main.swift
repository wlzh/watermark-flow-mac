import AppKit
import Foundation
import WatermarkCore

struct TestFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct TestRunner {
    private(set) var passed = 0
    private(set) var failed = 0

    mutating func test(_ name: String, _ body: () throws -> Void) {
        do {
            try body()
            passed += 1
            print("PASS \(name)")
        } catch {
            failed += 1
            fputs("FAIL \(name): \(error.localizedDescription)\n", stderr)
        }
    }

    func finish() -> Never {
        print("TEST_CASES_PASSED=\(passed)")
        print("TEST_CASES_FAILED=\(failed)")
        exit(failed == 0 ? EXIT_SUCCESS : EXIT_FAILURE)
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure(message: message) }
}

func makeImage(
    width: Int,
    height: Int,
    drawing: (CGContext) -> Void
) throws -> NSImage {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { throw TestFailure(message: "unable to create bitmap context") }
    drawing(context)
    guard let cgImage = context.makeImage() else {
        throw TestFailure(message: "unable to create image")
    }
    return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
}

func sampleImage(width: Int, height: Int) throws -> NSImage {
    try makeImage(width: width, height: height) { context in
        context.setFillColor(NSColor(calibratedRed: 0.14, green: 0.26, blue: 0.31, alpha: 1).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(NSColor(calibratedRed: 0.92, green: 0.65, blue: 0.2, alpha: 1).cgColor)
        context.fillEllipse(in: CGRect(x: width / 4, y: height / 4, width: width / 2, height: height / 2))
    }
}

func differingPixelCount(_ lhs: NSImage, _ rhs: NSImage) throws -> Int {
    let lhsData = try WatermarkRenderer.encode(image: lhs, format: .png)
    let rhsData = try WatermarkRenderer.encode(image: rhs, format: .png)
    guard let lhsRep = NSBitmapImageRep(data: lhsData),
          let rhsRep = NSBitmapImageRep(data: rhsData),
          lhsRep.pixelsWide == rhsRep.pixelsWide,
          lhsRep.pixelsHigh == rhsRep.pixelsHigh else {
        throw TestFailure(message: "unable to compare rendered pixels")
    }

    var changed = 0
    for y in 0..<lhsRep.pixelsHigh {
        for x in 0..<lhsRep.pixelsWide {
            guard let lhsColor = lhsRep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                  let rhsColor = rhsRep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                continue
            }
            let delta = abs(lhsColor.redComponent - rhsColor.redComponent)
                + abs(lhsColor.greenComponent - rhsColor.greenComponent)
                + abs(lhsColor.blueComponent - rhsColor.blueComponent)
                + abs(lhsColor.alphaComponent - rhsColor.alphaComponent)
            if delta > 0.01 { changed += 1 }
        }
    }
    return changed
}

var runner = TestRunner()

runner.test("application identity links are stable") {
    try expect(AppVersion.author == "X @wlzh", "author changed")
    try expect(AppVersion.authorProfileURL == "https://x.com/wlzh", "author profile URL changed")
    try expect(URL(string: AppVersion.authorProfileURL)?.scheme == "https", "author profile URL is invalid")
    try expect(AppVersion.websiteURL == "https://869hr.uk", "website URL changed")
    try expect(AppVersion.licenseName == "MIT License", "license name changed")
    try expect(URL(string: AppVersion.licenseURL)?.scheme == "https", "license URL is invalid")
}

runner.test("built-in templates are stable") {
    try expect(DefaultTemplates.all.count == 3, "expected three templates")
    try expect(DefaultTemplates.all.map(\.id) == [
        DefaultTemplates.xWLZHID,
        DefaultTemplates.xGXJDianID,
        DefaultTemplates.youtubeDuanKuID
    ], "template identifiers changed")
    try expect(DefaultTemplates.all.map(\.brand) == [.x, .x, .youtube], "template brands mismatch")
    try expect(DefaultTemplates.all.map(\.text) == ["@wlzh", "@gxjdian", "短裤AI分享"], "template text mismatch")
    try expect(DefaultTemplates.all.allSatisfy { $0.layoutMode == .single }, "factory templates should default to single layout")
    try expect(DefaultTemplates.all.allSatisfy { $0.tileDensity == 5 }, "factory tile density changed")
    try expect(DefaultTemplates.all.allSatisfy {
        $0.tiledStyle == WatermarkVisualSettings(
            foregroundColor: $0.foregroundColor,
            backgroundColor: $0.backgroundColor,
            accentColor: $0.accentColor,
            opacity: $0.opacity,
            relativeHeight: $0.relativeHeight,
            rotationDegrees: $0.rotationDegrees
        )
    }, "factory tiled style should initially match single style")
    try expect(DefaultTemplates.all.allSatisfy(\.isBuiltIn), "template must be built in")
}

runner.test("template values clamp to rendering bounds") {
    var template = DefaultTemplates.all[0]
    template.opacity = 4
    template.relativeHeight = -2
    template.position = NormalizedPoint(x: -1, y: 3)
    template.rotationDegrees = 400
    template.tileDensity = 99
    template.tiledStyle.opacity = -4
    template.tiledStyle.relativeHeight = 2
    template.tiledStyle.rotationDegrees = -400
    let clamped = template.clamped()
    try expect(clamped.opacity == 1, "opacity did not clamp")
    try expect(clamped.relativeHeight == 0.035, "height did not clamp")
    try expect(clamped.position == NormalizedPoint(x: 0, y: 1), "position did not clamp")
    try expect(clamped.rotationDegrees == 180, "rotation did not clamp")
    try expect(clamped.tileDensity == 10, "tile density did not clamp")
    try expect(clamped.tiledStyle.opacity == 0.05, "tiled opacity did not clamp")
    try expect(clamped.tiledStyle.relativeHeight == 0.3, "tiled height did not clamp")
    try expect(clamped.tiledStyle.rotationDegrees == -180, "tiled rotation did not clamp")
}

runner.test("single and tiled visual settings remain independent") {
    var template = DefaultTemplates.all[0]
    template.foregroundColor = RGBAColor(hex: 0x112233)
    template.backgroundColor = RGBAColor(hex: 0x445566, alpha: 0.7)
    template.accentColor = RGBAColor(hex: 0x778899)
    template.opacity = 0.82
    template.relativeHeight = 0.11
    template.rotationDegrees = -12
    template.contrastMode = .foreground
    template.contrastStrength = .soft
    template.position = NormalizedPoint(x: 0.18, y: 0.83)

    template.layoutMode = .tiled
    template.activeForegroundColor = RGBAColor(hex: 0xf1e2d3)
    template.activeBackgroundColor = RGBAColor(hex: 0xa4b5c6, alpha: 0.35)
    template.activeAccentColor = RGBAColor(hex: 0xd7e8f9)
    template.activeOpacity = 0.43
    template.activeRelativeHeight = 0.065
    template.activeRotationDegrees = 31
    template.activeContrastMode = .foregroundAndBackground
    template.activeContrastStrength = .strong
    template.tileDensity = 9

    try expect(template.activeOpacity == 0.43, "tiled opacity was not active")
    try expect(template.activeRelativeHeight == 0.065, "tiled size was not active")
    try expect(template.activeRotationDegrees == 31, "tiled rotation was not active")

    template.layoutMode = .single
    try expect(template.activeForegroundColor == RGBAColor(hex: 0x112233), "single foreground was overwritten")
    try expect(template.activeBackgroundColor == RGBAColor(hex: 0x445566, alpha: 0.7), "single background was overwritten")
    try expect(template.activeAccentColor == RGBAColor(hex: 0x778899), "single accent was overwritten")
    try expect(template.activeOpacity == 0.82, "single opacity was overwritten")
    try expect(template.activeRelativeHeight == 0.11, "single size was overwritten")
    try expect(template.activeRotationDegrees == -12, "single rotation was overwritten")
    try expect(template.activeContrastMode == .foreground, "single contrast mode was overwritten")
    try expect(template.activeContrastStrength == .soft, "single contrast strength was overwritten")
    try expect(template.position == NormalizedPoint(x: 0.18, y: 0.83), "single position was overwritten")

    template.layoutMode = .tiled
    try expect(template.activeForegroundColor == RGBAColor(hex: 0xf1e2d3), "tiled foreground was not restored")
    try expect(template.activeBackgroundColor == RGBAColor(hex: 0xa4b5c6, alpha: 0.35), "tiled background was not restored")
    try expect(template.activeAccentColor == RGBAColor(hex: 0xd7e8f9), "tiled accent was not restored")
    try expect(template.activeOpacity == 0.43, "tiled opacity was not restored")
    try expect(template.activeRelativeHeight == 0.065, "tiled size was not restored")
    try expect(template.activeRotationDegrees == 31, "tiled rotation was not restored")
    try expect(template.activeContrastMode == .foregroundAndBackground, "tiled contrast mode was not restored")
    try expect(template.activeContrastStrength == .strong, "tiled contrast strength was not restored")
    try expect(template.tileDensity == 9, "tiled density was not restored")
}

runner.test("drag delta keeps clicks stable and moves relatively") {
    let start = NormalizedPoint(x: 0.8, y: 0.9)
    try expect(start.offsetBy(deltaX: 0, deltaY: 0) == start, "zero-distance click moved watermark")
    try expect(
        start.offsetBy(deltaX: -0.25, deltaY: -0.4) == NormalizedPoint(x: 0.55, y: 0.5),
        "relative drag produced wrong position"
    )
    try expect(
        start.offsetBy(deltaX: 0.5, deltaY: 0.5) == NormalizedPoint(x: 1, y: 1),
        "drag should clamp at image edge"
    )
}

runner.test("single watermark bounds match rendered placement and rotation") {
    var template = DefaultTemplates.all[0]
    template.position = NormalizedPoint(x: 0.8, y: 0.9)
    template.relativeHeight = 0.1
    template.rotationDegrees = 0
    let canvas = CGSize(width: 1_000, height: 500)
    let bounds = WatermarkRenderer.singleWatermarkBounds(canvasSize: canvas, template: template)
    try expect(bounds != nil, "single watermark bounds were missing")
    try expect(abs(bounds!.midX - 800) < 0.001, "watermark bounds x position was incorrect")
    try expect(abs(bounds!.midY - 450) < 0.001, "watermark bounds y position was incorrect")
    try expect(abs(bounds!.height - 50) < 0.001, "watermark bounds height was incorrect")

    template.rotationDegrees = 90
    let rotated = WatermarkRenderer.singleWatermarkBounds(canvasSize: canvas, template: template)
    try expect(rotated != nil, "rotated watermark bounds were missing")
    try expect(abs(rotated!.width - 50) < 0.001, "rotated watermark width was incorrect")
    try expect(abs(rotated!.height - bounds!.width) < 0.001, "rotated watermark height was incorrect")

    template.layoutMode = .tiled
    try expect(
        WatermarkRenderer.singleWatermarkBounds(canvasSize: canvas, template: template) == nil,
        "tiled watermark unexpectedly returned a single hit region"
    )
}

runner.test("user templates persist as JSON") {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("WatermarkCoreTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let repository = TemplateRepository(storageURL: root.appendingPathComponent("templates.json"))
    var userTemplate = DefaultTemplates.all[1]
    userTemplate.id = UUID()
    userTemplate.name = "Custom X"
    userTemplate.isBuiltIn = false
    try repository.saveUserTemplates([userTemplate])
    let loaded = try repository.loadUserTemplates()
    try expect(loaded == [userTemplate.clamped()], "template round-trip mismatch")
}

runner.test("custom logo and text template survives persistence and renders") {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("WatermarkCustomTemplateTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let repository = TemplateRepository(storageURL: root.appendingPathComponent("templates.json"))
    let logo = try makeImage(width: 420, height: 180) { context in
        context.clear(CGRect(x: 0, y: 0, width: 420, height: 180))
        context.setFillColor(NSColor(calibratedRed: 0.05, green: 0.72, blue: 0.64, alpha: 0.86).cgColor)
        context.fillEllipse(in: CGRect(x: 24, y: 12, width: 156, height: 156))
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 200, y: 58, width: 188, height: 64))
    }
    var custom = DefaultTemplates.all[0]
    custom.id = UUID()
    custom.name = "Custom Logo + Text"
    custom.brand = .custom
    custom.text = "@custom-account"
    custom.customLogoPNG = try WatermarkRenderer.normalizedLogoPNG(image: logo)
    custom.isBuiltIn = false
    custom.layoutMode = .single
    custom.position = NormalizedPoint(x: 0.23, y: 0.74)
    custom.layoutMode = .tiled
    custom.tileDensity = 7
    custom.activeOpacity = 0.51
    custom.activeRelativeHeight = 0.066
    custom.activeRotationDegrees = 19

    try repository.saveLibrary(TemplateLibraryState(
        templates: DefaultTemplates.all + [custom],
        lastSelectedTemplateID: custom.id
    ))
    let restoredLibrary = try repository.loadLibrary()
    guard let restored = restoredLibrary.templates.first(where: { $0.id == custom.id }) else {
        throw TestFailure(message: "saved custom template was not restored")
    }
    try expect(restored == custom.clamped(), "custom logo and text changed during persistence")
    try expect(restored.brand == .custom, "custom icon type was lost")
    try expect(restored.text == "@custom-account", "custom template text was lost")
    try expect(restored.customLogoPNG?.isEmpty == false, "custom logo bytes were lost")
    try expect(restoredLibrary.lastSelectedTemplateID == custom.id, "custom selection was lost")
    guard let logoData = restored.customLogoPNG,
          NSBitmapImageRep(data: logoData)?.cgImage != nil else {
        throw TestFailure(message: "persisted custom logo PNG is not decodable")
    }

    let source = try sampleImage(width: 1_200, height: 800)
    let output = try WatermarkRenderer.render(source: source, template: restored)
    let sourcePNG = try WatermarkRenderer.encode(image: source, format: .png)
    let outputPNG = try WatermarkRenderer.encode(image: output, format: .png)
    try expect(outputPNG != sourcePNG, "restored custom logo and text rendered no watermark")
}

runner.test("complete library restores built-in overrides and last selection") {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("WatermarkLibraryTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let storageURL = root.appendingPathComponent("templates.json")
    let repository = TemplateRepository(storageURL: storageURL)

    var builtInOverride = DefaultTemplates.all[0]
    builtInOverride.text = "@saved"
    builtInOverride.foregroundColor = RGBAColor(hex: 0x123456, alpha: 0.71)
    builtInOverride.backgroundColor = RGBAColor(hex: 0x654321, alpha: 0.62)
    builtInOverride.accentColor = RGBAColor(hex: 0xabcdef, alpha: 0.83)
    builtInOverride.opacity = 0.74
    builtInOverride.relativeHeight = 0.143
    builtInOverride.position = NormalizedPoint(x: 0.27, y: 0.64)
    builtInOverride.rotationDegrees = -17
    builtInOverride.layoutMode = .tiled
    builtInOverride.tileDensity = 9
    builtInOverride.activeForegroundColor = RGBAColor(hex: 0xfedcba, alpha: 0.66)
    builtInOverride.activeBackgroundColor = RGBAColor(hex: 0x102030, alpha: 0.44)
    builtInOverride.activeAccentColor = RGBAColor(hex: 0x405060)
    builtInOverride.activeOpacity = 0.48
    builtInOverride.activeRelativeHeight = 0.071
    builtInOverride.activeRotationDegrees = 28

    var userTemplate = builtInOverride
    userTemplate.id = UUID()
    userTemplate.name = "Saved Custom Logo"
    userTemplate.brand = .custom
    userTemplate.customLogoPNG = Data([0, 1, 2, 3, 4, 5])
    userTemplate.isBuiltIn = false

    try repository.saveLibrary(TemplateLibraryState(
        templates: [builtInOverride, DefaultTemplates.all[1], DefaultTemplates.all[2], userTemplate],
        lastSelectedTemplateID: userTemplate.id
    ))
    let restored = try repository.loadLibrary()

    try expect(restored.schemaVersion == 4, "schema version mismatch")
    try expect(restored.templates.count == 4, "template count mismatch")
    try expect(restored.templates[0] == builtInOverride.clamped(), "built-in override was not restored")
    try expect(restored.templates[3] == userTemplate.clamped(), "custom logo template was not restored")
    try expect(restored.lastSelectedTemplateID == userTemplate.id, "last selection was not restored")
    let json = try String(contentsOf: storageURL, encoding: .utf8)
    try expect(json.contains("\"schemaVersion\""), "versioned JSON key missing")
}

runner.test("v0.1.0 template array migrates without data loss") {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("WatermarkMigrationTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let storageURL = root.appendingPathComponent("templates.json")
    var legacy = DefaultTemplates.all[1]
    legacy.id = UUID()
    legacy.name = "Legacy User Template"
    legacy.text = "@legacy"
    legacy.isBuiltIn = false
    try JSONEncoder().encode([legacy]).write(to: storageURL, options: .atomic)

    let restored = try TemplateRepository(storageURL: storageURL).loadLibrary()
    try expect(restored.schemaVersion == 4, "legacy state did not migrate schema")
    try expect(restored.templates.count == 4, "factory templates were not merged")
    try expect(restored.templates.prefix(3).map(\.id) == DefaultTemplates.all.map(\.id), "factory order changed")
    try expect(restored.templates[3] == legacy.clamped(), "legacy user template was lost")
    let migratedJSON = try String(contentsOf: storageURL, encoding: .utf8)
    try expect(migratedJSON.contains("\"schemaVersion\" : 4"), "legacy array migration was not written to disk")
    try expect(migratedJSON.contains("\"tiledStyle\""), "legacy array is missing persisted tiled profile")
}

runner.test("v0.2.3 templates migrate to single layout defaults") {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("WatermarkLayoutMigrationTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let storageURL = root.appendingPathComponent("templates.json")
    let encoded = try JSONEncoder().encode(TemplateLibraryState(
        schemaVersion: 1,
        templates: DefaultTemplates.all,
        lastSelectedTemplateID: DefaultTemplates.xWLZHID
    ))
    guard var json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any],
          var templates = json["templates"] as? [[String: Any]] else {
        throw TestFailure(message: "unable to create legacy template fixture")
    }
    for index in templates.indices {
        templates[index].removeValue(forKey: "layoutMode")
        templates[index].removeValue(forKey: "tileDensity")
        templates[index].removeValue(forKey: "tiledStyle")
    }
    json["templates"] = templates
    try JSONSerialization.data(withJSONObject: json).write(to: storageURL, options: .atomic)

    let restored = try TemplateRepository(storageURL: storageURL).loadLibrary()
    try expect(restored.schemaVersion == 4, "layout migration did not advance schema")
    try expect(restored.templates.allSatisfy { $0.layoutMode == .single }, "legacy layout did not default to single")
    try expect(restored.templates.allSatisfy { $0.tileDensity == 5 }, "legacy density did not default to five")
    try expect(restored.templates.allSatisfy {
        $0.tiledStyle.foregroundColor == $0.foregroundColor
            && $0.tiledStyle.backgroundColor == $0.backgroundColor
            && $0.tiledStyle.accentColor == $0.accentColor
            && $0.tiledStyle.opacity == $0.opacity
            && $0.tiledStyle.relativeHeight == $0.relativeHeight
            && $0.tiledStyle.rotationDegrees == $0.rotationDegrees
    }, "legacy visual settings were not copied into tiled style")
    let migratedJSON = try String(contentsOf: storageURL, encoding: .utf8)
    try expect(migratedJSON.contains("\"schemaVersion\" : 4"), "schema 1 migration was not written to disk")
    try expect(migratedJSON.contains("\"tiledStyle\""), "schema 1 migration is missing persisted tiled profile")
}

runner.test("v0.3.0 shared visual settings migrate into tiled profile") {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("WatermarkDualStyleMigrationTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let storageURL = root.appendingPathComponent("templates.json")
    var legacy = DefaultTemplates.all[0]
    legacy.layoutMode = .tiled
    legacy.tileDensity = 8
    legacy.foregroundColor = RGBAColor(hex: 0x102938)
    legacy.backgroundColor = RGBAColor(hex: 0x475665, alpha: 0.52)
    legacy.accentColor = RGBAColor(hex: 0xaabbcc)
    legacy.opacity = 0.63
    legacy.relativeHeight = 0.081
    legacy.rotationDegrees = 24
    let encoded = try JSONEncoder().encode(TemplateLibraryState(
        schemaVersion: 2,
        templates: [legacy, DefaultTemplates.all[1], DefaultTemplates.all[2]],
        lastSelectedTemplateID: legacy.id
    ))
    guard var json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any],
          var templates = json["templates"] as? [[String: Any]] else {
        throw TestFailure(message: "unable to create v0.3.0 template fixture")
    }
    for index in templates.indices {
        templates[index].removeValue(forKey: "tiledStyle")
    }
    json["templates"] = templates
    try JSONSerialization.data(withJSONObject: json).write(to: storageURL, options: .atomic)

    let restored = try TemplateRepository(storageURL: storageURL).loadLibrary()
    let migrated = restored.templates[0]
    try expect(restored.schemaVersion == 4, "dual-style migration did not advance schema")
    try expect(migrated.layoutMode == .tiled, "v0.3.0 layout mode changed during migration")
    try expect(migrated.tileDensity == 8, "v0.3.0 density changed during migration")
    try expect(migrated.tiledStyle.foregroundColor == legacy.foregroundColor, "foreground was not migrated")
    try expect(migrated.tiledStyle.backgroundColor == legacy.backgroundColor, "background was not migrated")
    try expect(migrated.tiledStyle.accentColor == legacy.accentColor, "accent was not migrated")
    try expect(migrated.tiledStyle.opacity == legacy.opacity, "opacity was not migrated")
    try expect(migrated.tiledStyle.relativeHeight == legacy.relativeHeight, "size was not migrated")
    try expect(migrated.tiledStyle.rotationDegrees == legacy.rotationDegrees, "rotation was not migrated")
    let migratedJSON = try String(contentsOf: storageURL, encoding: .utf8)
    try expect(migratedJSON.contains("\"schemaVersion\" : 4"), "schema 2 migration was not written to disk")
    try expect(migratedJSON.contains("\"tiledStyle\""), "schema 2 migration is missing persisted tiled profile")
}

runner.test("v0.3.2 visual profiles migrate with adaptive contrast disabled") {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("WatermarkContrastMigrationTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let storageURL = root.appendingPathComponent("templates.json")
    let encoded = try JSONEncoder().encode(TemplateLibraryState(
        schemaVersion: 3,
        templates: DefaultTemplates.all,
        lastSelectedTemplateID: DefaultTemplates.xGXJDianID
    ))
    guard var json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any],
          var templates = json["templates"] as? [[String: Any]] else {
        throw TestFailure(message: "unable to create v0.3.2 template fixture")
    }
    for index in templates.indices {
        templates[index].removeValue(forKey: "contrastMode")
        templates[index].removeValue(forKey: "contrastStrength")
        if var tiled = templates[index]["tiledStyle"] as? [String: Any] {
            tiled.removeValue(forKey: "contrastMode")
            tiled.removeValue(forKey: "contrastStrength")
            templates[index]["tiledStyle"] = tiled
        }
    }
    json["templates"] = templates
    try JSONSerialization.data(withJSONObject: json).write(to: storageURL, options: .atomic)

    let restored = try TemplateRepository(storageURL: storageURL).loadLibrary()
    try expect(restored.schemaVersion == 4, "contrast migration did not advance schema")
    try expect(restored.templates.allSatisfy { $0.contrastMode == .off }, "single contrast should migrate off")
    try expect(restored.templates.allSatisfy { $0.contrastStrength == .standard }, "single strength should migrate standard")
    try expect(restored.templates.allSatisfy { $0.tiledStyle.contrastMode == .off }, "tiled contrast should migrate off")
    try expect(restored.templates.allSatisfy { $0.tiledStyle.contrastStrength == .standard }, "tiled strength should migrate standard")
    let migratedJSON = try String(contentsOf: storageURL, encoding: .utf8)
    try expect(migratedJSON.contains("\"schemaVersion\" : 4"), "schema 3 migration was not written")
    try expect(migratedJSON.contains("\"contrastMode\" : \"off\""), "migrated contrast mode was not persisted")
}

runner.test("future template schema fails closed without rewriting data") {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("WatermarkFutureSchemaTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let storageURL = root.appendingPathComponent("templates.json")
    let encoded = try JSONEncoder().encode(TemplateLibraryState(
        schemaVersion: 999,
        templates: DefaultTemplates.all,
        lastSelectedTemplateID: DefaultTemplates.xWLZHID
    ))
    try encoded.write(to: storageURL, options: .atomic)
    let before = try Data(contentsOf: storageURL)
    do {
        _ = try TemplateRepository(storageURL: storageURL).loadLibrary()
        throw TestFailure(message: "future schema should be rejected")
    } catch TemplateRepositoryError.unsupportedStorageFormat {
        // Expected: never downgrade data created by a newer application.
    }
    let after = try Data(contentsOf: storageURL)
    try expect(after == before, "future schema data was rewritten")
}

runner.test("adaptive contrast resolves local tones without overwriting manual colors") {
    let foreground = RGBAColor(hex: 0x247a91, alpha: 0.73)
    let background = RGBAColor(hex: 0xf2c04f, alpha: 0.31)
    let accent = RGBAColor(hex: 0xff0033, alpha: 0.88)
    let off = AdaptiveContrastResolver.resolve(
        foreground: foreground,
        background: background,
        accent: accent,
        brand: .youtube,
        mode: .off,
        strength: .strong,
        statistics: WatermarkLuminanceStatistics(mean: 1, deviation: 0.5)
    )
    try expect(off == ResolvedWatermarkColors(
        foreground: foreground,
        background: background,
        accent: accent
    ), "disabled adaptive contrast changed manual colors")

    let darkRegion = AdaptiveContrastResolver.resolve(
        foreground: foreground,
        background: background,
        accent: accent,
        brand: .youtube,
        mode: .foreground,
        strength: .standard,
        statistics: WatermarkLuminanceStatistics(mean: 0.02, deviation: 0.01)
    )
    try expect(darkRegion.foreground == RGBAColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 0.73), "dark region did not choose light text")
    try expect(darkRegion.background == background, "foreground-only mode changed background")
    try expect(darkRegion.accent == accent, "YouTube accent should retain brand color")

    let busyLightRegion = AdaptiveContrastResolver.resolve(
        foreground: foreground,
        background: background,
        accent: accent,
        brand: .x,
        mode: .foregroundAndBackground,
        strength: .standard,
        statistics: WatermarkLuminanceStatistics(mean: 0.92, deviation: 0.24)
    )
    try expect(busyLightRegion.foreground == RGBAColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 0.73), "light region did not choose light text over dark backplate")
    try expect(busyLightRegion.background == RGBAColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 0.72), "busy region did not strengthen contrasting backplate")
    try expect(busyLightRegion.accent == RGBAColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 0.88), "X accent did not follow adaptive foreground")
}

runner.test("adaptive contrast renders uniform and split images at full resolution") {
    let black = try makeImage(width: 1_000, height: 600) { context in
        context.setFillColor(NSColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 1_000, height: 600))
    }
    let split = try makeImage(width: 1_000, height: 600) { context in
        context.setFillColor(NSColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 500, height: 600))
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 500, y: 0, width: 500, height: 600))
    }
    var template = DefaultTemplates.all[0]
    template.contrastMode = .foregroundAndBackground
    template.contrastStrength = .strong
    template.position = NormalizedPoint(x: 0.25, y: 0.5)
    let darkOutput = try WatermarkRenderer.render(source: black, template: template)
    let splitLeftOutput = try WatermarkRenderer.render(source: split, template: template)
    var expectedLeft = template
    expectedLeft.contrastMode = .off
    expectedLeft.foregroundColor = RGBAColor(hex: 0x000000)
    expectedLeft.backgroundColor = RGBAColor(hex: 0xffffff, alpha: 0.82)
    expectedLeft.accentColor = RGBAColor(hex: 0x000000)
    let expectedSplitLeftOutput = try WatermarkRenderer.render(source: split, template: expectedLeft)
    template.position = NormalizedPoint(x: 0.75, y: 0.5)
    let splitRightOutput = try WatermarkRenderer.render(source: split, template: template)
    var expectedRight = template
    expectedRight.contrastMode = .off
    expectedRight.foregroundColor = RGBAColor(hex: 0xffffff)
    expectedRight.backgroundColor = RGBAColor(hex: 0x000000, alpha: 0.82)
    expectedRight.accentColor = RGBAColor(hex: 0xffffff)
    let expectedSplitRightOutput = try WatermarkRenderer.render(source: split, template: expectedRight)
    let leftPNG = try WatermarkRenderer.encode(image: splitLeftOutput, format: .png)
    let rightPNG = try WatermarkRenderer.encode(image: splitRightOutput, format: .png)
    let expectedLeftPNG = try WatermarkRenderer.encode(image: expectedSplitLeftOutput, format: .png)
    let expectedRightPNG = try WatermarkRenderer.encode(image: expectedSplitRightOutput, format: .png)
    try expect(WatermarkRenderer.pixelSize(of: darkOutput) == CGSize(width: 1_000, height: 600), "adaptive render changed dimensions")
    try expect(leftPNG != rightPNG, "local image regions did not produce distinct adaptive renders")
    try expect(
        leftPNG == expectedLeftPNG,
        "left dark region did not use the expected local adaptive colors"
    )
    try expect(
        rightPNG == expectedRightPNG,
        "right light region did not use the expected local adaptive colors"
    )

    template.layoutMode = .tiled
    template.activeContrastMode = .foregroundAndBackground
    template.activeContrastStrength = .strong
    template.tileDensity = 10
    let tiled = try WatermarkRenderer.render(source: split, template: template)
    try expect(WatermarkRenderer.pixelSize(of: tiled) == CGSize(width: 1_000, height: 600), "adaptive tiled render changed dimensions")
}

runner.test("all built-in templates preserve source pixels") {
    let source = try sampleImage(width: 1200, height: 800)
    let sourcePNG = try WatermarkRenderer.encode(image: source, format: .png)
    for template in DefaultTemplates.all {
        let output = try WatermarkRenderer.render(source: source, template: template)
        try expect(WatermarkRenderer.pixelSize(of: output) == CGSize(width: 1200, height: 800), "pixel size changed")
        let outputPNG = try WatermarkRenderer.encode(image: output, format: .png)
        try expect(outputPNG.count > 1_000, "PNG is unexpectedly small")
        try expect(outputPNG != sourcePNG, "watermark did not change output")
    }
}

runner.test("renderer uses only the active layout visual profile") {
    let source = try sampleImage(width: 960, height: 540)
    var tiled = DefaultTemplates.all[0]
    tiled.layoutMode = .tiled
    tiled.activeForegroundColor = RGBAColor(hex: 0xfefefe)
    tiled.activeBackgroundColor = RGBAColor(hex: 0x101010, alpha: 0.5)
    tiled.activeAccentColor = RGBAColor(hex: 0xffaa00)
    tiled.activeOpacity = 0.55
    tiled.activeRelativeHeight = 0.07
    tiled.activeRotationDegrees = 27
    let tiledBaseline = try WatermarkRenderer.encode(
        image: WatermarkRenderer.render(source: source, template: tiled),
        format: .png
    )

    tiled.foregroundColor = RGBAColor(hex: 0x00ff00)
    tiled.backgroundColor = RGBAColor(hex: 0xff0000)
    tiled.accentColor = RGBAColor(hex: 0x0000ff)
    tiled.opacity = 1
    tiled.relativeHeight = 0.3
    tiled.rotationDegrees = -90
    let tiledAfterSingleEdit = try WatermarkRenderer.encode(
        image: WatermarkRenderer.render(source: source, template: tiled),
        format: .png
    )
    try expect(tiledAfterSingleEdit == tiledBaseline, "single profile leaked into tiled rendering")

    tiled.activeOpacity = 0.95
    let tiledAfterActiveEdit = try WatermarkRenderer.encode(
        image: WatermarkRenderer.render(source: source, template: tiled),
        format: .png
    )
    try expect(tiledAfterActiveEdit != tiledBaseline, "tiled profile edit did not affect rendering")

    tiled.layoutMode = .single
    let singleBaseline = try WatermarkRenderer.encode(
        image: WatermarkRenderer.render(source: source, template: tiled),
        format: .png
    )
    tiled.tiledStyle.opacity = 0.05
    tiled.tiledStyle.relativeHeight = 0.035
    tiled.tiledStyle.rotationDegrees = 150
    let singleAfterTiledEdit = try WatermarkRenderer.encode(
        image: WatermarkRenderer.render(source: source, template: tiled),
        format: .png
    )
    try expect(singleAfterTiledEdit == singleBaseline, "tiled profile leaked into single rendering")
}

runner.test("preview limits work while full render preserves pixels") {
    let source = try sampleImage(width: 4_000, height: 3_000)
    let previewStarted = Date()
    let preview = try WatermarkRenderer.renderPreview(
        source: source,
        template: DefaultTemplates.all[0],
        maxPixelDimension: 1_200
    )
    let previewMilliseconds = Date().timeIntervalSince(previewStarted) * 1_000
    let fullStarted = Date()
    let full = try WatermarkRenderer.render(source: source, template: DefaultTemplates.all[0])
    let fullMilliseconds = Date().timeIntervalSince(fullStarted) * 1_000
    var tiledTemplate = DefaultTemplates.all[0]
    tiledTemplate.layoutMode = .tiled
    tiledTemplate.tileDensity = 10
    let tiledStarted = Date()
    let tiledFull = try WatermarkRenderer.render(source: source, template: tiledTemplate)
    let tiledMilliseconds = Date().timeIntervalSince(tiledStarted) * 1_000
    tiledTemplate.activeContrastMode = .foregroundAndBackground
    tiledTemplate.activeContrastStrength = .standard
    let adaptiveStarted = Date()
    let adaptiveTiledFull = try WatermarkRenderer.render(source: source, template: tiledTemplate)
    let adaptiveMilliseconds = Date().timeIntervalSince(adaptiveStarted) * 1_000
    try expect(WatermarkRenderer.pixelSize(of: preview) == CGSize(width: 1_200, height: 900), "preview size mismatch")
    try expect(WatermarkRenderer.pixelSize(of: full) == CGSize(width: 4_000, height: 3_000), "full render lost pixels")
    try expect(WatermarkRenderer.pixelSize(of: tiledFull) == CGSize(width: 4_000, height: 3_000), "tiled render lost pixels")
    try expect(WatermarkRenderer.pixelSize(of: adaptiveTiledFull) == CGSize(width: 4_000, height: 3_000), "adaptive tiled render lost pixels")
    print(String(
        format: "PERF preview_4k_ms=%.1f full_render_4k_ms=%.1f tiled_render_4k_ms=%.1f adaptive_tiled_4k_ms=%.1f",
        previewMilliseconds,
        fullMilliseconds,
        tiledMilliseconds,
        adaptiveMilliseconds
    ))
}

runner.test("transparent source pixels use white as adaptive contrast fallback") {
    let transparent = try makeImage(width: 600, height: 400) { context in
        context.clear(CGRect(x: 0, y: 0, width: 600, height: 400))
    }
    var adaptive = DefaultTemplates.all[0]
    adaptive.position = NormalizedPoint(x: 0.5, y: 0.5)
    adaptive.contrastMode = .foreground
    adaptive.contrastStrength = .strong
    let adaptiveOutput = try WatermarkRenderer.render(source: transparent, template: adaptive)
    var expected = adaptive
    expected.contrastMode = .off
    expected.foregroundColor = RGBAColor(hex: 0x000000)
    expected.accentColor = RGBAColor(hex: 0x000000)
    let expectedOutput = try WatermarkRenderer.render(source: transparent, template: expected)
    let adaptivePNG = try WatermarkRenderer.encode(image: adaptiveOutput, format: .png)
    let expectedPNG = try WatermarkRenderer.encode(image: expectedOutput, format: .png)
    try expect(adaptivePNG == expectedPNG, "transparent region did not fall back to white")
}

runner.test("adaptive luminance sampling distinguishes red and blue channels") {
    let split = try makeImage(width: 800, height: 400) { context in
        context.setFillColor(NSColor.red.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
        context.setFillColor(NSColor.blue.cgColor)
        context.fill(CGRect(x: 400, y: 0, width: 400, height: 400))
    }
    var adaptive = DefaultTemplates.all[0]
    adaptive.contrastMode = .foreground
    adaptive.contrastStrength = .strong
    adaptive.position = NormalizedPoint(x: 0.25, y: 0.5)
    let redAdaptive = try WatermarkRenderer.render(source: split, template: adaptive)
    var redExpected = adaptive
    redExpected.contrastMode = .off
    redExpected.foregroundColor = RGBAColor(hex: 0x000000)
    redExpected.accentColor = RGBAColor(hex: 0x000000)
    let redManual = try WatermarkRenderer.render(source: split, template: redExpected)

    adaptive.position = NormalizedPoint(x: 0.75, y: 0.5)
    let blueAdaptive = try WatermarkRenderer.render(source: split, template: adaptive)
    var blueExpected = adaptive
    blueExpected.contrastMode = .off
    blueExpected.foregroundColor = RGBAColor(hex: 0xffffff)
    blueExpected.accentColor = RGBAColor(hex: 0xffffff)
    let blueManual = try WatermarkRenderer.render(source: split, template: blueExpected)
    let redAdaptivePNG = try WatermarkRenderer.encode(image: redAdaptive, format: .png)
    let redManualPNG = try WatermarkRenderer.encode(image: redManual, format: .png)
    let blueAdaptivePNG = try WatermarkRenderer.encode(image: blueAdaptive, format: .png)
    let blueManualPNG = try WatermarkRenderer.encode(image: blueManual, format: .png)

    try expect(
        redAdaptivePNG == redManualPNG,
        "red region luminance used the wrong channel order"
    )
    try expect(
        blueAdaptivePNG == blueManualPNG,
        "blue region luminance used the wrong channel order"
    )
}

runner.test("source-only render supports reversible watermark removal") {
    let source = try sampleImage(width: 1_600, height: 900)
    let plain = try WatermarkRenderer.renderSource(source: source)
    let preview = try WatermarkRenderer.renderSourcePreview(source: source, maxPixelDimension: 800)
    let watermarked = try WatermarkRenderer.render(source: source, template: DefaultTemplates.all[0])
    let plainPNG = try WatermarkRenderer.encode(image: plain, format: .png)
    let watermarkedPNG = try WatermarkRenderer.encode(image: watermarked, format: .png)

    try expect(WatermarkRenderer.pixelSize(of: plain) == CGSize(width: 1_600, height: 900), "source-only output changed dimensions")
    try expect(WatermarkRenderer.pixelSize(of: preview) == CGSize(width: 800, height: 450), "source-only preview size mismatch")
    try expect(plainPNG != watermarkedPNG, "removing watermark did not change output")
}

runner.test("tiled watermark density increases full-screen coverage") {
    let source = try makeImage(width: 900, height: 600) { context in
        context.setFillColor(NSColor(calibratedWhite: 0.2, alpha: 1).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 900, height: 600))
    }
    let plain = try WatermarkRenderer.renderSource(source: source)
    var sparse = DefaultTemplates.all[0]
    sparse.layoutMode = .tiled
    sparse.tileDensity = 1
    sparse.rotationDegrees = -22
    let sparseOutput = try WatermarkRenderer.render(source: source, template: sparse)

    var dense = sparse
    dense.tileDensity = 10
    let denseOutput = try WatermarkRenderer.render(source: source, template: dense)
    let sparseChanged = try differingPixelCount(plain, sparseOutput)
    let denseChanged = try differingPixelCount(plain, denseOutput)
    let sparsePNG = try WatermarkRenderer.encode(image: sparseOutput, format: .png)
    let densePNG = try WatermarkRenderer.encode(image: denseOutput, format: .png)

    try expect(sparseChanged > 0, "sparse tiled watermark changed no pixels")
    try expect(denseChanged > sparseChanged, "higher density did not increase coverage")
    try expect(sparsePNG != densePNG, "density levels rendered identical output")
    print("TILE_COVERAGE sparse_pixels=\(sparseChanged) dense_pixels=\(denseChanged)")
}

runner.test("high zoom preview is capped and never upscales source") {
    let wideSource = try sampleImage(width: 7_000, height: 700)
    let capped = try WatermarkRenderer.renderPreview(
        source: wideSource,
        template: DefaultTemplates.all[1],
        maxPixelDimension: 6_000
    )
    try expect(
        WatermarkRenderer.pixelSize(of: capped) == CGSize(width: 6_000, height: 600),
        "high zoom preview did not respect pixel cap"
    )

    let smallSource = try sampleImage(width: 800, height: 600)
    let unchanged = try WatermarkRenderer.renderSourcePreview(
        source: smallSource,
        maxPixelDimension: 6_000
    )
    try expect(
        WatermarkRenderer.pixelSize(of: unchanged) == CGSize(width: 800, height: 600),
        "preview should not upscale a smaller source"
    )
}

runner.test("custom logos are bounded and keep transparency") {
    let largeLogo = try makeImage(width: 4_096, height: 2_048) { context in
        context.clear(CGRect(x: 0, y: 0, width: 4_096, height: 2_048))
        context.setFillColor(NSColor.systemTeal.withAlphaComponent(0.55).cgColor)
        context.fillEllipse(in: CGRect(x: 256, y: 256, width: 1_536, height: 1_536))
    }
    let normalizedData = try WatermarkRenderer.normalizedLogoPNG(image: largeLogo)
    guard let normalizedImage = NSImage(data: normalizedData),
          let representation = NSBitmapImageRep(data: normalizedData) else {
        throw TestFailure(message: "normalized logo is unreadable")
    }
    try expect(
        WatermarkRenderer.pixelSize(of: normalizedImage) == CGSize(width: 1_024, height: 512),
        "large logo was not bounded"
    )
    try expect(representation.hasAlpha, "logo transparency was removed")

    let smallLogo = try sampleImage(width: 128, height: 64)
    let smallData = try WatermarkRenderer.normalizedLogoPNG(image: smallLogo)
    let normalizedSmall = NSImage(data: smallData)!
    try expect(
        WatermarkRenderer.pixelSize(of: normalizedSmall) == CGSize(width: 128, height: 64),
        "small logo should keep its pixels"
    )
}

runner.test("portrait and small images preserve dimensions") {
    for size in [CGSize(width: 300, height: 900), CGSize(width: 64, height: 64)] {
        let source = try sampleImage(width: Int(size.width), height: Int(size.height))
        let output = try WatermarkRenderer.render(source: source, template: DefaultTemplates.all[2])
        try expect(WatermarkRenderer.pixelSize(of: output) == size, "non-landscape dimensions changed")
    }
}

runner.test("text and custom logo render to PNG and JPEG") {
    let source = try sampleImage(width: 640, height: 360)
    var textTemplate = DefaultTemplates.all[0]
    textTemplate.brand = .text
    textTemplate.text = "WatermarkFlow"
    let textOutput = try WatermarkRenderer.render(source: source, template: textTemplate)

    let logo = try makeImage(width: 96, height: 48) { context in
        context.setFillColor(NSColor.systemTeal.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 96, height: 48))
    }
    var logoTemplate = textTemplate
    logoTemplate.brand = .custom
    logoTemplate.customLogoPNG = try WatermarkRenderer.encode(image: logo, format: .png)
    logoTemplate.layoutMode = .tiled
    logoTemplate.tileDensity = 10
    let logoOutput = try WatermarkRenderer.render(source: source, template: logoTemplate)

    let textPNG = try WatermarkRenderer.encode(image: textOutput, format: .png)
    let logoPNG = try WatermarkRenderer.encode(image: logoOutput, format: .png)
    let logoJPEG = try WatermarkRenderer.encode(image: logoOutput, format: .jpeg)
    try expect(textPNG.count > 1_000, "text PNG is too small")
    try expect(logoJPEG.count > 1_000, "logo JPEG is too small")
    try expect(textPNG != logoPNG, "text and logo render should differ")
}

runner.test("clipboard round-trip works on isolated pasteboard") {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("WatermarkFlowTests.\(UUID().uuidString)"))
    defer { pasteboard.releaseGlobally() }
    let source = try sampleImage(width: 320, height: 180)
    let output = try WatermarkRenderer.render(source: source, template: DefaultTemplates.all[2])
    let changeCount = try ClipboardService.writeImage(output, to: pasteboard)
    let reread = try ClipboardService.readImage(from: pasteboard)
    try expect(changeCount > 0, "pasteboard change count did not advance")
    try expect(WatermarkRenderer.pixelSize(of: reread) == CGSize(width: 320, height: 180), "pasteboard changed pixels")
    try expect(pasteboard.types?.contains(.png) == true, "PNG pasteboard type missing")
}

runner.finish()
