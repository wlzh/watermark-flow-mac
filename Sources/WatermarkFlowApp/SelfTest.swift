import AppKit
import Carbon
import Foundation
import WatermarkCore

enum SelfTest {
    @MainActor
    static func run() throws {
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

        let defaultsName = "WatermarkFlow.SelfTest.\(UUID().uuidString)"
        guard let isolatedDefaults = UserDefaults(suiteName: defaultsName) else {
            throw Failure("unable to create isolated defaults")
        }
        defer { isolatedDefaults.removePersistentDomain(forName: defaultsName) }
        let editor = EditorViewModel(repository: repository, defaults: isolatedDefaults)
        editor.workingTemplate.text = "@automatic"
        editor.workingTemplate.position = NormalizedPoint(x: 0.31, y: 0.42)
        editor.workingTemplate.backgroundColor = RGBAColor(hex: 0x245f73, alpha: 0.67)
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        let restoredEditor = EditorViewModel(repository: repository, defaults: isolatedDefaults)
        guard restoredEditor.workingTemplate.text == "@automatic",
              restoredEditor.workingTemplate.position == NormalizedPoint(x: 0.31, y: 0.42),
              restoredEditor.workingTemplate.backgroundColor == RGBAColor(hex: 0x245f73, alpha: 0.67),
              restoredEditor.selectedTemplateID == editor.selectedTemplateID else {
            throw Failure("automatic editor persistence failed")
        }

        let sourceData = try WatermarkRenderer.encode(image: source, format: .png)
        restoredEditor.loadImageData(sourceData)
        guard restoredEditor.sourceImage != nil, restoredEditor.previewImage != nil else {
            throw Failure("editor image load failed")
        }
        let quickOutput = try restoredEditor.renderForQuickApply(
            source: source,
            templateID: DefaultTemplates.youtubeDuanKuID
        )
        guard WatermarkRenderer.pixelSize(of: quickOutput) == CGSize(width: 960, height: 540) else {
            throw Failure("template-specific quick render failed")
        }
        restoredEditor.clearCanvas()
        guard restoredEditor.sourceImage == nil,
              restoredEditor.previewImage == nil,
              restoredEditor.templates.count == 4 else {
            throw Failure("clear canvas removed saved templates or retained image state")
        }
        let customHotKey = HotKeyConfiguration(
            keyCode: UInt32(kVK_ANSI_K),
            modifiers: UInt32(cmdKey | shiftKey),
            keyLabel: "K"
        )
        restoredEditor.hotKeyRegistrationHandler = { _ in true }
        restoredEditor.updateHotKey(customHotKey)
        let hotKeyRestoredEditor = EditorViewModel(repository: repository, defaults: isolatedDefaults)
        guard hotKeyRestoredEditor.hotKeyConfiguration == customHotKey,
              hotKeyRestoredEditor.hotKeyConfiguration.displayName == "⇧⌘K" else {
            throw Failure("custom hotkey persistence failed")
        }
        var recordedHotKey: HotKeyConfiguration?
        let recorderCoordinator = HotKeyRecorderView.Coordinator(
            onChange: { recordedHotKey = $0 },
            onInvalid: {}
        )
        let recorderButton = RecorderButton()
        recorderButton.target = recorderCoordinator
        recorderCoordinator.beginRecording(recorderButton)
        guard let keyEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "k",
            charactersIgnoringModifiers: "k",
            isARepeat: false,
            keyCode: UInt16(kVK_ANSI_K)
        ) else { throw Failure("unable to create hotkey event") }
        recorderButton.keyDown(with: keyEvent)
        guard recordedHotKey == customHotKey, !recorderButton.isRecording else {
            throw Failure("hotkey recorder control failed")
        }

        let output = try WatermarkRenderer.render(source: source, template: DefaultTemplates.all[0])
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("WatermarkFlow.SelfTest.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let changeCount = try ClipboardService.writeImage(output, to: pasteboard)
        let reread = try ClipboardService.readImage(from: pasteboard)
        guard changeCount > 0,
              WatermarkRenderer.pixelSize(of: reread) == CGSize(width: 960, height: 540) else {
            throw Failure("pasteboard server round-trip failed")
        }

        let appDelegate = AppDelegate(viewModel: restoredEditor)
        let emptyExportItem = NSMenuItem(
            title: "Export",
            action: #selector(AppDelegate.exportImage),
            keyEquivalent: ""
        )
        let emptyClearItem = NSMenuItem(
            title: "Clear",
            action: #selector(AppDelegate.clearCanvas),
            keyEquivalent: ""
        )
        guard !appDelegate.validateMenuItem(emptyExportItem),
              !appDelegate.validateMenuItem(emptyClearItem) else {
            throw Failure("empty-canvas menu validation failed")
        }
        let quickMenu = appDelegate.makeQuickTemplateMenu()
        guard quickMenu.items.map(\.title) == restoredEditor.templates.map(\.name),
              quickMenu.items.count == 4,
              quickMenu.items.filter({ $0.state == .on }).count == 1,
              quickMenu.items.first(where: { $0.state == .on })?.representedObject as? String
                == restoredEditor.defaultTemplateID.uuidString else {
            throw Failure("dynamic quick-template menu failed")
        }

        print("SELF_TEST_VERSION=\(AppVersion.current)")
        print("SELF_TEST_BUILD=\(AppVersion.build)")
        print("SELF_TEST_TEMPLATES=\(DefaultTemplates.all.count)")
        print("SELF_TEST_RENDER=PASS 960x540")
        print("SELF_TEST_PERSISTENCE=PASS")
        print("SELF_TEST_AUTOSAVE_RESTART=PASS")
        print("SELF_TEST_POSITION_RESTORE=PASS value=0.31,0.42")
        print("SELF_TEST_TEMPLATE_QUICK_RENDER=PASS")
        print("SELF_TEST_CLEAR_CANVAS=PASS templatesPreserved=4")
        print("SELF_TEST_CUSTOM_HOTKEY=PASS value=\(customHotKey.displayName)")
        print("SELF_TEST_HOTKEY_RECORDER=PASS")
        print("SELF_TEST_PASTEBOARD_SERVER=PASS changeCount=\(changeCount)")
        print("SELF_TEST_EMPTY_MENU_VALIDATION=PASS")
        print("SELF_TEST_QUICK_TEMPLATE_MENU=PASS items=\(quickMenu.items.count)")
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

}
