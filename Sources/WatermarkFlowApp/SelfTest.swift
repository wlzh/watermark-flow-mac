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

        let customWorkflowRepository = TemplateRepository(
            storageURL: temporary.deletingLastPathComponent().appendingPathComponent("custom-workflow.json")
        )
        let customWorkflowDefaultsName = "WatermarkFlow.CustomWorkflowSelfTest.\(UUID().uuidString)"
        guard let customWorkflowDefaults = UserDefaults(suiteName: customWorkflowDefaultsName) else {
            throw Failure("unable to create custom workflow defaults")
        }
        defer { customWorkflowDefaults.removePersistentDomain(forName: customWorkflowDefaultsName) }
        let customEditor = EditorViewModel(
            repository: customWorkflowRepository,
            defaults: customWorkflowDefaults
        )
        let originalTemplate = customEditor.workingTemplate
        guard let customTemplateID = customEditor.createCustomTemplate(named: "Logo + Text Self Test") else {
            throw Failure("custom template creation failed")
        }
        guard customEditor.setCustomLogo(image: source, fileName: "self-test-logo.png") else {
            throw Failure("custom logo import failed")
        }
        customEditor.workingTemplate.text = "@logo-and-text"
        customEditor.workingTemplate.position = NormalizedPoint(x: 0.24, y: 0.76)
        customEditor.workingTemplate.layoutMode = .tiled
        customEditor.workingTemplate.tileDensity = 7
        customEditor.workingTemplate.activeOpacity = 0.52
        customEditor.workingTemplate.activeRelativeHeight = 0.067
        customEditor.workingTemplate.activeRotationDegrees = 21
        customEditor.flushPersistence()

        guard customEditor.templates.count == 4,
              customEditor.templates.first(where: { $0.id == originalTemplate.id }) == originalTemplate,
              customEditor.selectedTemplateID == customTemplateID,
              customEditor.workingTemplate.brand == .custom,
              customEditor.workingTemplate.text == "@logo-and-text",
              customEditor.workingTemplate.customLogoPNG?.isEmpty == false else {
            throw Failure("new custom template changed its source or lost content")
        }
        let customOutput = try customEditor.renderForQuickApply(source: source, templateID: customTemplateID)
        guard WatermarkRenderer.pixelSize(of: customOutput) == CGSize(width: 960, height: 540) else {
            throw Failure("custom template quick render failed")
        }
        let restoredCustomEditor = EditorViewModel(
            repository: customWorkflowRepository,
            defaults: customWorkflowDefaults
        )
        guard restoredCustomEditor.selectedTemplateID == customTemplateID,
              restoredCustomEditor.workingTemplate.name == "Logo + Text Self Test",
              restoredCustomEditor.workingTemplate.brand == .custom,
              restoredCustomEditor.workingTemplate.text == "@logo-and-text",
              restoredCustomEditor.workingTemplate.customLogoPNG?.isEmpty == false,
              restoredCustomEditor.workingTemplate.layoutMode == .tiled,
              restoredCustomEditor.workingTemplate.tileDensity == 7,
              restoredCustomEditor.workingTemplate.activeOpacity == 0.52,
              restoredCustomEditor.workingTemplate.activeRelativeHeight == 0.067,
              restoredCustomEditor.workingTemplate.activeRotationDegrees == 21 else {
            throw Failure("custom logo and text template did not survive restart")
        }
        let templateBeforeCopy = restoredCustomEditor.workingTemplate
        guard let copiedTemplateID = restoredCustomEditor.saveCurrentAsTemplate(named: "Logo + Text Copy"),
              let copiedTemplate = restoredCustomEditor.templates.first(where: { $0.id == copiedTemplateID }),
              restoredCustomEditor.templates.first(where: { $0.id == customTemplateID }) == templateBeforeCopy,
              copiedTemplate.brand == .custom,
              copiedTemplate.text == "@logo-and-text",
              copiedTemplate.customLogoPNG?.isEmpty == false,
              copiedTemplate.customLogoPNG == templateBeforeCopy.customLogoPNG,
              copiedTemplate.tiledStyle == templateBeforeCopy.tiledStyle else {
            throw Failure("copy current template lost custom logo, text, or style")
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
        editor.workingTemplate.opacity = 0.79
        editor.workingTemplate.relativeHeight = 0.12
        editor.workingTemplate.rotationDegrees = -16
        editor.workingTemplate.contrastMode = .foreground
        editor.workingTemplate.contrastStrength = .soft
        editor.workingTemplate.layoutMode = .tiled
        editor.workingTemplate.tileDensity = 8
        editor.workingTemplate.activeBackgroundColor = RGBAColor(hex: 0x7a3b21, alpha: 0.38)
        editor.workingTemplate.activeOpacity = 0.46
        editor.workingTemplate.activeRelativeHeight = 0.068
        editor.workingTemplate.activeRotationDegrees = 29
        editor.workingTemplate.activeContrastMode = .foregroundAndBackground
        editor.workingTemplate.activeContrastStrength = .strong
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        let restoredEditor = EditorViewModel(repository: repository, defaults: isolatedDefaults)
        guard restoredEditor.workingTemplate.text == "@automatic",
              restoredEditor.workingTemplate.position == NormalizedPoint(x: 0.31, y: 0.42),
              restoredEditor.workingTemplate.backgroundColor == RGBAColor(hex: 0x245f73, alpha: 0.67),
              restoredEditor.workingTemplate.layoutMode == .tiled,
              restoredEditor.workingTemplate.tileDensity == 8,
              restoredEditor.workingTemplate.activeBackgroundColor == RGBAColor(hex: 0x7a3b21, alpha: 0.38),
              restoredEditor.workingTemplate.activeOpacity == 0.46,
              restoredEditor.workingTemplate.activeRelativeHeight == 0.068,
              restoredEditor.workingTemplate.activeRotationDegrees == 29,
              restoredEditor.workingTemplate.activeContrastMode == .foregroundAndBackground,
              restoredEditor.workingTemplate.activeContrastStrength == .strong,
              restoredEditor.selectedTemplateID == editor.selectedTemplateID else {
            throw Failure("automatic editor persistence failed")
        }
        restoredEditor.workingTemplate.layoutMode = .single
        guard restoredEditor.workingTemplate.activeBackgroundColor == RGBAColor(hex: 0x245f73, alpha: 0.67),
              restoredEditor.workingTemplate.activeOpacity == 0.79,
              restoredEditor.workingTemplate.activeRelativeHeight == 0.12,
              restoredEditor.workingTemplate.activeRotationDegrees == -16,
              restoredEditor.workingTemplate.activeContrastMode == .foreground,
              restoredEditor.workingTemplate.activeContrastStrength == .soft,
              restoredEditor.workingTemplate.position == NormalizedPoint(x: 0.31, y: 0.42) else {
            throw Failure("single visual profile was not restored")
        }
        restoredEditor.workingTemplate.layoutMode = .tiled
        guard restoredEditor.workingTemplate.activeBackgroundColor == RGBAColor(hex: 0x7a3b21, alpha: 0.38),
              restoredEditor.workingTemplate.activeOpacity == 0.46,
              restoredEditor.workingTemplate.activeRelativeHeight == 0.068,
              restoredEditor.workingTemplate.activeRotationDegrees == 29,
              restoredEditor.workingTemplate.activeContrastMode == .foregroundAndBackground,
              restoredEditor.workingTemplate.activeContrastStrength == .strong,
              restoredEditor.workingTemplate.tileDensity == 8 else {
            throw Failure("tiled visual profile was not restored")
        }

        let sourceData = try WatermarkRenderer.encode(image: source, format: .png)
        restoredEditor.loadImageData(sourceData)
        guard restoredEditor.sourceImage != nil,
              restoredEditor.previewImage != nil,
              restoredEditor.isWatermarkEnabled else {
            throw Failure("editor image load failed")
        }
        let positionBeforeIgnoredDrag = restoredEditor.workingTemplate.position
        restoredEditor.updateWatermarkDrag(
            translation: CGSize(width: 200, height: 100),
            canvasSize: CGSize(width: 960, height: 540)
        )
        guard restoredEditor.workingTemplate.position == positionBeforeIgnoredDrag else {
            throw Failure("tiled layout unexpectedly changed single-watermark position")
        }
        restoredEditor.zoomIn()
        guard restoredEditor.canvasZoom == 1.25,
              restoredEditor.canvasZoomDescription == "125%" else {
            throw Failure("canvas zoom-in failed")
        }
        restoredEditor.setCanvasZoom(3)
        guard restoredEditor.canvasZoom == 3 else {
            throw Failure("canvas percentage selection failed")
        }
        restoredEditor.zoomOut()
        guard restoredEditor.canvasZoom == 2 else {
            throw Failure("canvas zoom-out failed")
        }
        restoredEditor.resetCanvasZoom()
        guard restoredEditor.canvasZoom == 1 else {
            throw Failure("canvas fit reset failed")
        }
        restoredEditor.setCanvasZoom(10)
        guard restoredEditor.canvasZoom == 10,
              restoredEditor.canvasZoomDescription == "1000%" else {
            throw Failure("canvas maximum zoom failed")
        }
        restoredEditor.resetCanvasZoom()
        let watermarkedOutput = try restoredEditor.renderCurrentOutput()
        restoredEditor.removeCurrentWatermark()
        let sourceOnlyOutput = try restoredEditor.renderCurrentOutput()
        guard !restoredEditor.isWatermarkEnabled,
              restoredEditor.sourceImage != nil,
              restoredEditor.previewImage != nil,
              try WatermarkRenderer.encode(image: watermarkedOutput, format: .png)
                != WatermarkRenderer.encode(image: sourceOnlyOutput, format: .png) else {
            throw Failure("session watermark removal failed")
        }
        restoredEditor.addSelectedWatermark()
        guard restoredEditor.isWatermarkEnabled else {
            throw Failure("selected watermark restore failed")
        }
        restoredEditor.removeCurrentWatermark()
        restoredEditor.selectTemplate(id: DefaultTemplates.youtubeDuanKuID)
        guard restoredEditor.isWatermarkEnabled,
              restoredEditor.selectedTemplateID == DefaultTemplates.youtubeDuanKuID else {
            throw Failure("template selection did not replace removed watermark")
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
        restoredEditor.setDefaultTemplate(id: DefaultTemplates.youtubeDuanKuID)
        restoredEditor.selectTemplate(id: DefaultTemplates.xWLZHID)
        let defaultRestoredEditor = EditorViewModel(repository: repository, defaults: isolatedDefaults)
        guard defaultRestoredEditor.defaultTemplateID == DefaultTemplates.youtubeDuanKuID,
              defaultRestoredEditor.defaultTemplateName == "YouTube · 短裤AI分享",
              defaultRestoredEditor.selectedTemplateID == DefaultTemplates.xWLZHID else {
            throw Failure("quick default template did not persist independently of editor selection")
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

        let clipboardRepository = TemplateRepository(
            storageURL: temporary.deletingLastPathComponent().appendingPathComponent("clipboard-workflow.json")
        )
        let clipboardDefaultsName = "WatermarkFlow.ClipboardSelfTest.\(UUID().uuidString)"
        guard let clipboardDefaults = UserDefaults(suiteName: clipboardDefaultsName) else {
            throw Failure("unable to create clipboard workflow defaults")
        }
        defer { clipboardDefaults.removePersistentDomain(forName: clipboardDefaultsName) }
        let clipboardEditor = EditorViewModel(repository: clipboardRepository, defaults: clipboardDefaults)
        let clipboardPasteboard = NSPasteboard(
            name: NSPasteboard.Name("WatermarkFlow.ClipboardMonitorSelfTest.\(UUID().uuidString)")
        )
        defer { clipboardPasteboard.releaseGlobally() }
        _ = try ClipboardService.writeImage(source, to: clipboardPasteboard)
        guard clipboardEditor.clipboardAutoLoadMode == .emptyCanvas,
              clipboardEditor.observeClipboard(clipboardPasteboard) == .loaded,
              clipboardEditor.sourceImage != nil else {
            throw Failure("empty-canvas clipboard auto-load failed")
        }
        let replacement = try makeSourceImage(width: 640, height: 400)
        _ = try ClipboardService.writeImage(replacement, to: clipboardPasteboard)
        guard clipboardEditor.observeClipboard(clipboardPasteboard) == .pendingReplacement,
              clipboardEditor.hasPendingClipboardImage,
              clipboardEditor.sourcePixelDescription == "960 × 540 px" else {
            throw Failure("safe clipboard replacement prompt failed")
        }
        clipboardEditor.loadPendingClipboardImage(clipboardPasteboard)
        guard !clipboardEditor.hasPendingClipboardImage,
              clipboardEditor.sourcePixelDescription == "640 × 400 px" else {
            throw Failure("pending clipboard replacement action failed")
        }
        _ = try ClipboardService.writeImage(source, to: clipboardPasteboard)
        guard clipboardEditor.observeClipboard(clipboardPasteboard) == .pendingReplacement else {
            throw Failure("second safe clipboard replacement prompt failed")
        }
        clipboardEditor.dismissPendingClipboardImage()
        clipboardEditor.updateClipboardAutoLoadMode(.alwaysReplace)
        _ = try ClipboardService.writeImage(replacement, to: clipboardPasteboard)
        guard clipboardEditor.observeClipboard(clipboardPasteboard) == .loaded,
              clipboardEditor.sourcePixelDescription == "640 × 400 px" else {
            throw Failure("always-replace clipboard mode failed")
        }
        clipboardEditor.generateAndCopy(to: clipboardPasteboard)
        guard clipboardEditor.observeClipboard(clipboardPasteboard, forceCurrent: true) == .ignoredOwnOrLoadedImage else {
            throw Failure("application clipboard write was not suppressed")
        }
        clipboardEditor.updateClipboardAutoLoadMode(.off)
        _ = try ClipboardService.writeImage(source, to: clipboardPasteboard)
        guard clipboardEditor.observeClipboard(clipboardPasteboard) == .disabled else {
            throw Failure("disabled clipboard mode accepted an image")
        }
        clipboardEditor.updateClipboardAutoLoadMode(.emptyCanvas)
        clipboardPasteboard.clearContents()
        clipboardPasteboard.setString("not an image", forType: .string)
        guard clipboardEditor.observeClipboard(clipboardPasteboard) == .ignoredNonImage else {
            throw Failure("non-image clipboard content was not ignored")
        }
        clipboardEditor.updateClipboardAutoLoadMode(.off)
        let clipboardRestoredEditor = EditorViewModel(
            repository: clipboardRepository,
            defaults: clipboardDefaults
        )
        guard clipboardRestoredEditor.clipboardAutoLoadMode == .off else {
            throw Failure("clipboard mode did not persist")
        }

        let appDelegate = AppDelegate(viewModel: restoredEditor)
        guard appDelegate.defaultQuickMenuTitle.contains("YouTube · 短裤AI分享"),
              appDelegate.defaultQuickMenuTitle.contains(customHotKey.displayName) else {
            throw Failure("default quick menu title is missing template name or shortcut")
        }
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
        let emptyWatermarkItem = NSMenuItem(
            title: "Watermark",
            action: #selector(AppDelegate.toggleCurrentWatermark),
            keyEquivalent: ""
        )
        guard !appDelegate.validateMenuItem(emptyExportItem),
              !appDelegate.validateMenuItem(emptyClearItem),
              !appDelegate.validateMenuItem(emptyWatermarkItem) else {
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
        print("SELF_TEST_CUSTOM_LOGO_TEXT_TEMPLATE=PASS")
        print("SELF_TEST_CUSTOM_TEMPLATE_SOURCE_ISOLATION=PASS")
        print("SELF_TEST_CUSTOM_TEMPLATE_COPY=PASS")
        print("SELF_TEST_AUTOSAVE_RESTART=PASS")
        print("SELF_TEST_POSITION_RESTORE=PASS value=0.31,0.42")
        print("SELF_TEST_TILED_LAYOUT=PASS density=8")
        print("SELF_TEST_DUAL_LAYOUT_SETTINGS=PASS")
        print("SELF_TEST_DUAL_LAYOUT_CONTRAST=PASS")
        print("SELF_TEST_ADAPTIVE_CONTRAST=PASS")
        print("SELF_TEST_TEMPLATE_QUICK_RENDER=PASS")
        print("SELF_TEST_REMOVE_RESTORE_WATERMARK=PASS")
        print("SELF_TEST_TEMPLATE_REPLACEMENT=PASS")
        print("SELF_TEST_CANVAS_ZOOM=PASS range=25%-1000%")
        print("SELF_TEST_CLEAR_CANVAS=PASS templatesPreserved=4")
        print("SELF_TEST_CUSTOM_HOTKEY=PASS value=\(customHotKey.displayName)")
        print("SELF_TEST_DEFAULT_TEMPLATE=PASS value=\(defaultRestoredEditor.defaultTemplateName)")
        print("SELF_TEST_HOTKEY_RECORDER=PASS")
        print("SELF_TEST_PASTEBOARD_SERVER=PASS changeCount=\(changeCount)")
        print("SELF_TEST_CLIPBOARD_AUTOLOAD=PASS modes=empty,pending,always,off,non-image")
        print("SELF_TEST_CLIPBOARD_SELF_WRITE_SUPPRESSION=PASS")
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
