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

var runner = TestRunner()

runner.test("built-in templates are stable") {
    try expect(DefaultTemplates.all.count == 3, "expected three templates")
    try expect(DefaultTemplates.all.map(\.id) == [
        DefaultTemplates.xWLZHID,
        DefaultTemplates.xGXJDianID,
        DefaultTemplates.youtubeDuanKuID
    ], "template identifiers changed")
    try expect(DefaultTemplates.all.map(\.brand) == [.x, .x, .youtube], "template brands mismatch")
    try expect(DefaultTemplates.all.map(\.text) == ["@wlzh", "@gxjdian", "短裤AI分享"], "template text mismatch")
    try expect(DefaultTemplates.all.allSatisfy(\.isBuiltIn), "template must be built in")
}

runner.test("template values clamp to rendering bounds") {
    var template = DefaultTemplates.all[0]
    template.opacity = 4
    template.relativeHeight = -2
    template.position = NormalizedPoint(x: -1, y: 3)
    template.rotationDegrees = 400
    let clamped = template.clamped()
    try expect(clamped.opacity == 1, "opacity did not clamp")
    try expect(clamped.relativeHeight == 0.035, "height did not clamp")
    try expect(clamped.position == NormalizedPoint(x: 0, y: 1), "position did not clamp")
    try expect(clamped.rotationDegrees == 180, "rotation did not clamp")
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
