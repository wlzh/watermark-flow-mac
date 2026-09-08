import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers
import WatermarkCore

@MainActor
final class EditorViewModel: ObservableObject {
    @Published private(set) var sourceImage: NSImage?
    @Published private(set) var previewImage: NSImage?
    @Published private(set) var isWatermarkEnabled = true
    @Published private(set) var canvasZoom = 1.0
    @Published private(set) var templates: [WatermarkTemplate]
    @Published var selectedTemplateID: UUID
    @Published var workingTemplate: WatermarkTemplate {
        didSet {
            if isWatermarkEnabled {
                refreshPreview()
            }
            scheduleAutomaticPersistence()
        }
    }
    @Published var statusMessage = "复制图片可自动载入，也可把图片拖到左侧"
    @Published private(set) var hotKeyConfiguration: HotKeyConfiguration
    @Published private(set) var defaultTemplateID: UUID
    @Published private(set) var clipboardAutoLoadMode: ClipboardAutoLoadMode
    @Published private(set) var hasPendingClipboardImage = false

    private let repository: TemplateRepository
    private let defaults: UserDefaults
    private let defaultTemplateKey = "defaultTemplateID"
    private let clipboardAutoLoadModeKey = "clipboardAutoLoadMode"
    private var dragStartPosition: NormalizedPoint?
    private var persistenceTask: Task<Void, Never>?
    private var persistenceEnabled = false
    private var lastObservedPasteboardRevision: PasteboardRevision?
    private var lastLoadedPasteboardRevision: PasteboardRevision?
    private var lastWrittenPasteboardRevision: PasteboardRevision?
    var hotKeyRegistrationHandler: ((HotKeyConfiguration) -> Bool)?
    var clipboardModeChangeHandler: (() -> Void)?

    init(
        repository: TemplateRepository = TemplateRepository(),
        defaults: UserDefaults = .standard
    ) {
        self.repository = repository
        self.defaults = defaults
        hotKeyConfiguration = HotKeyConfiguration.load(from: defaults)
        clipboardAutoLoadMode = defaults.string(forKey: clipboardAutoLoadModeKey)
            .flatMap(ClipboardAutoLoadMode.init(rawValue:)) ?? .emptyCanvas

        let library = (try? repository.loadLibrary())
            ?? TemplateLibraryState(templates: DefaultTemplates.all)
        let loadedTemplates = library.templates
        templates = loadedTemplates
        let savedDefaultID = defaults.string(forKey: defaultTemplateKey).flatMap(UUID.init(uuidString:))
        defaultTemplateID = loadedTemplates.contains { $0.id == savedDefaultID }
            ? savedDefaultID!
            : DefaultTemplates.xWLZHID

        let savedID = library.lastSelectedTemplateID
            ?? defaults.string(forKey: defaultTemplateKey).flatMap(UUID.init(uuidString:))
        let initial = loadedTemplates.first { $0.id == savedID } ?? DefaultTemplates.all[0]
        selectedTemplateID = initial.id
        workingTemplate = initial
        persistenceEnabled = true
    }

    var canDeleteSelectedTemplate: Bool {
        templates.first { $0.id == selectedTemplateID }?.isBuiltIn == false
    }

    var defaultTemplateName: String {
        templates.first { $0.id == defaultTemplateID }?.name ?? "X · @wlzh"
    }

    var isSelectedTemplateDefault: Bool {
        selectedTemplateID == defaultTemplateID
    }

    var sourcePixelDescription: String {
        guard let sourceImage,
              let size = WatermarkRenderer.pixelSize(of: sourceImage) else { return "未载入图片" }
        return "\(Int(size.width)) × \(Int(size.height)) px"
    }

    var canvasZoomDescription: String {
        "\(Int((canvasZoom * 100).rounded()))%"
    }

    var canvasZoomOptions: [Double] {
        Self.canvasZoomLevels
    }

    func selectTemplate(id: UUID) {
        guard templates.contains(where: { $0.id == id }) else { return }
        flushPersistence()
        guard let template = templates.first(where: { $0.id == id }) else { return }
        persistenceEnabled = false
        isWatermarkEnabled = true
        selectedTemplateID = id
        workingTemplate = template
        persistenceEnabled = true
        persistLibrary()
        statusMessage = "已载入模板：\(template.name)"
    }

    func setPosition(x: Double, y: Double) {
        workingTemplate.position = NormalizedPoint(x: x, y: y).clamped()
    }

    func updateWatermarkDrag(translation: CGSize, canvasSize: CGSize) {
        guard isWatermarkEnabled,
              workingTemplate.layoutMode == .single,
              canvasSize.width > 0,
              canvasSize.height > 0 else { return }
        if dragStartPosition == nil {
            dragStartPosition = workingTemplate.position
        }
        guard let start = dragStartPosition else { return }
        workingTemplate.position = start.offsetBy(
            deltaX: translation.width / canvasSize.width,
            deltaY: translation.height / canvasSize.height
        )
    }

    func endWatermarkDrag() {
        dragStartPosition = nil
        flushPersistence(showStatus: true)
    }

    func zoomIn() {
        guard sourceImage != nil else { return }
        let levels = Self.canvasZoomLevels
        canvasZoom = levels.first(where: { $0 > canvasZoom + 0.001 }) ?? levels.last!
        refreshPreview()
        statusMessage = "画布缩放：\(canvasZoomDescription)"
    }

    func zoomOut() {
        guard sourceImage != nil else { return }
        let levels = Self.canvasZoomLevels
        canvasZoom = levels.last(where: { $0 < canvasZoom - 0.001 }) ?? levels.first!
        refreshPreview()
        statusMessage = "画布缩放：\(canvasZoomDescription)"
    }

    func zoomWithMouseWheel(_ direction: MouseWheelZoomDirection) {
        switch direction {
        case .zoomIn:
            zoomIn()
        case .zoomOut:
            zoomOut()
        }
    }

    func resetCanvasZoom() {
        guard sourceImage != nil else { return }
        canvasZoom = 1
        refreshPreview()
        statusMessage = "画布已适合窗口：100%"
    }

    func setCanvasZoom(_ zoom: Double) {
        guard sourceImage != nil,
              Self.canvasZoomLevels.contains(where: { abs($0 - zoom) < 0.001 }) else { return }
        canvasZoom = zoom
        refreshPreview()
        statusMessage = zoom == 1
            ? "画布已适合窗口：100%"
            : "画布缩放：\(canvasZoomDescription)"
    }

    @discardableResult
    func loadFromClipboard(_ pasteboard: NSPasteboard = .general, automatically: Bool = false) -> Bool {
        do {
            try loadImage(ClipboardService.readImage(from: pasteboard))
            let revision = PasteboardRevision(pasteboard)
            lastObservedPasteboardRevision = revision
            lastLoadedPasteboardRevision = revision
            hasPendingClipboardImage = false
            statusMessage = automatically ? "已自动载入剪贴板图片" : "已从剪贴板载入图片"
            return true
        } catch {
            statusMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func observeClipboard(
        _ pasteboard: NSPasteboard = .general,
        forceCurrent: Bool = false
    ) -> ClipboardObservationResult {
        let revision = PasteboardRevision(pasteboard)
        if !forceCurrent, revision == lastObservedPasteboardRevision { return .unchanged }
        lastObservedPasteboardRevision = revision
        if revision == lastWrittenPasteboardRevision || revision == lastLoadedPasteboardRevision {
            return .ignoredOwnOrLoadedImage
        }
        guard pasteboard.canReadObject(forClasses: [NSImage.self]) else {
            hasPendingClipboardImage = false
            return .ignoredNonImage
        }
        switch clipboardAutoLoadMode {
        case .off:
            hasPendingClipboardImage = false
            return .disabled
        case .emptyCanvas where sourceImage != nil:
            hasPendingClipboardImage = true
            statusMessage = "检测到新的剪贴板图片，可选择替换当前图片"
            return .pendingReplacement
        case .emptyCanvas, .alwaysReplace:
            return loadFromClipboard(pasteboard, automatically: true) ? .loaded : .ignoredNonImage
        }
    }

    func loadPendingClipboardImage(_ pasteboard: NSPasteboard = .general) {
        _ = loadFromClipboard(pasteboard)
    }

    func dismissPendingClipboardImage() {
        hasPendingClipboardImage = false
        statusMessage = "已忽略本次剪贴板图片"
    }

    func updateClipboardAutoLoadMode(_ mode: ClipboardAutoLoadMode) {
        guard mode != clipboardAutoLoadMode else { return }
        clipboardAutoLoadMode = mode
        defaults.set(mode.rawValue, forKey: clipboardAutoLoadModeKey)
        if mode == .off {
            hasPendingClipboardImage = false
        }
        statusMessage = "剪贴板自动载入：\(mode.displayName)"
        clipboardModeChangeHandler?()
    }

    func openImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "选择需要添加水印的图片"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadImage(at: url)
    }

    func loadImage(at url: URL) {
        guard let image = NSImage(contentsOf: url) else {
            statusMessage = "无法读取图片：\(url.lastPathComponent)"
            return
        }
        loadImage(image)
        statusMessage = "已载入：\(url.lastPathComponent)"
    }

    func loadImageData(_ data: Data) {
        guard let image = NSImage(data: data) else {
            statusMessage = "拖入的内容不是可读取图片"
            return
        }
        loadImage(image)
        statusMessage = "已载入拖放图片"
    }

    func importCustomLogo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .gif, .tiff, .webP]
        panel.allowsMultipleSelection = false
        panel.message = "选择自定义 Logo 图片"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let image = NSImage(contentsOf: url) else {
            statusMessage = "无法读取 Logo 图片：\(url.lastPathComponent)"
            return
        }
        _ = setCustomLogo(image: image, fileName: url.lastPathComponent)
    }

    @discardableResult
    func setCustomLogo(image: NSImage, fileName: String = "Logo") -> Bool {
        do {
            let data = try WatermarkRenderer.normalizedLogoPNG(image: image)
            workingTemplate.brand = .custom
            workingTemplate.customLogoPNG = data
            statusMessage = "已嵌入自定义 Logo：\(fileName)"
            return true
        } catch {
            statusMessage = "Logo 导入失败：\(error.localizedDescription)"
            return false
        }
    }

    func generateAndCopy(to pasteboard: NSPasteboard = .general) {
        do {
            let output = try renderCurrentOutput()
            let changeCount = try ClipboardService.writeImage(output, to: pasteboard)
            recordClipboardWrite(pasteboard, changeCount: changeCount)
            statusMessage = isWatermarkEnabled
                ? "已生成并复制，可直接粘贴 · \(sourcePixelDescription)"
                : "已复制无水印原图 · \(sourcePixelDescription)"
            NSSound(named: "Tink")?.play()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func quickApplyDefaultToClipboard(_ pasteboard: NSPasteboard = .general) throws -> NSImage {
        try quickApplyTemplateToClipboard(id: defaultTemplateID, pasteboard: pasteboard)
    }

    func quickApplyTemplateToClipboard(
        id: UUID,
        pasteboard: NSPasteboard = .general
    ) throws -> NSImage {
        flushPersistence()
        let source = try ClipboardService.readImage(from: pasteboard)
        let output = try renderForQuickApply(source: source, templateID: id)
        let changeCount = try ClipboardService.writeImage(output, to: pasteboard)
        recordClipboardWrite(pasteboard, changeCount: changeCount)
        let templateName = templates.first(where: { $0.id == id })?.name ?? "所选模板"
        statusMessage = "已用“\(templateName)”快速生成并复制"
        return output
    }

    func renderForQuickApply(source: NSImage, templateID: UUID) throws -> NSImage {
        guard let template = templates.first(where: { $0.id == templateID }) else {
            throw QuickApplyError.templateNotFound
        }
        return try WatermarkRenderer.render(source: source, template: template)
    }

    func exportImage() {
        do {
            let output = try renderCurrentOutput()
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.png, .jpeg]
            panel.nameFieldStringValue = "watermarked.png"
            panel.canCreateDirectories = true
            panel.message = isWatermarkEnabled ? "导出带水印的扁平图片" : "导出当前无水印原图"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            let format: ImageOutputFormat = url.pathExtension.lowercased().hasPrefix("jp") ? .jpeg : .png
            let data = try WatermarkRenderer.encode(image: output, format: format)
            try data.write(to: url, options: .atomic)
            statusMessage = "已导出：\(url.lastPathComponent)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func saveCurrentAsTemplate() {
        let alert = NSAlert()
        alert.messageText = "复制当前模板"
        alert.informativeText = "把当前模板的全部设置复制为新模板。当前图片不会保存。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        let field = NSTextField(string: workingTemplate.name + " 副本")
        field.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        _ = saveCurrentAsTemplate(named: field.stringValue)
    }

    @discardableResult
    func saveCurrentAsTemplate(named rawName: String) -> UUID? {
        flushPersistence()
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            statusMessage = "模板名称不能为空"
            return nil
        }

        var template = workingTemplate.clamped()
        template.id = UUID()
        template.name = name
        template.isBuiltIn = false
        templates.append(template)
        persistenceEnabled = false
        selectedTemplateID = template.id
        workingTemplate = template
        persistenceEnabled = true
        persistLibrary()
        statusMessage = "已保存模板：\(name)"
        return template.id
    }

    func createCustomTemplate() {
        let alert = NSAlert()
        alert.messageText = "新建 Logo + 文字模板"
        alert.informativeText = "先创建独立模板，再选择 Logo、输入文字和调整样式，不会修改当前模板。"
        alert.addButton(withTitle: "创建")
        alert.addButton(withTitle: "取消")
        let field = NSTextField(string: suggestedCustomTemplateName())
        field.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        _ = createCustomTemplate(named: field.stringValue)
    }

    @discardableResult
    func createCustomTemplate(named rawName: String) -> UUID? {
        flushPersistence()
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            statusMessage = "模板名称不能为空"
            return nil
        }

        var template = workingTemplate.clamped()
        template.id = UUID()
        template.name = name
        template.brand = .custom
        template.text = ""
        template.customLogoPNG = nil
        template.isBuiltIn = false
        templates.append(template)
        persistenceEnabled = false
        selectedTemplateID = template.id
        workingTemplate = template
        persistenceEnabled = true
        persistLibrary()
        statusMessage = "已新建模板，请选择 Logo 并输入文字"
        return template.id
    }

    func setSelectedAsDefault() {
        setDefaultTemplate(id: selectedTemplateID)
    }

    func setDefaultTemplate(id: UUID) {
        guard let template = templates.first(where: { $0.id == id }) else { return }
        guard id != defaultTemplateID else { return }
        flushPersistence()
        defaultTemplateID = id
        defaults.set(id.uuidString, forKey: defaultTemplateKey)
        statusMessage = "已设为快捷默认模板：\(template.name)"
    }

    func deleteSelectedTemplate() {
        guard canDeleteSelectedTemplate else {
            statusMessage = "内置模板不可删除，可以另存为自定义模板"
            return
        }
        let deletingID = selectedTemplateID
        let wasDefault = defaultTemplateID == deletingID
        persistenceTask?.cancel()
        templates.removeAll { $0.id == selectedTemplateID }
        let fallback = templates.first { $0.id == DefaultTemplates.xWLZHID } ?? DefaultTemplates.all[0]
        persistenceEnabled = false
        isWatermarkEnabled = true
        selectedTemplateID = fallback.id
        workingTemplate = fallback
        persistenceEnabled = true
        if wasDefault {
            defaultTemplateID = fallback.id
            defaults.set(fallback.id.uuidString, forKey: defaultTemplateKey)
        }
        persistLibrary()
        statusMessage = "已删除用户模板"
    }

    func clearCanvas() {
        sourceImage = nil
        previewImage = nil
        isWatermarkEnabled = true
        canvasZoom = 1
        dragStartPosition = nil
        statusMessage = "已清空当前图片与水印画布，模板设置已保留"
    }

    func removeCurrentWatermark() {
        guard sourceImage != nil else {
            statusMessage = "请先载入图片"
            return
        }
        guard isWatermarkEnabled else { return }
        isWatermarkEnabled = false
        dragStartPosition = nil
        refreshPreview()
        statusMessage = "已移除当前水印，原图和模板设置已保留"
    }

    func addSelectedWatermark() {
        guard sourceImage != nil else {
            statusMessage = "请先载入图片"
            return
        }
        guard !isWatermarkEnabled else { return }
        isWatermarkEnabled = true
        refreshPreview()
        statusMessage = "已添加所选水印：\(workingTemplate.name)"
    }

    func toggleCurrentWatermark() {
        if isWatermarkEnabled {
            removeCurrentWatermark()
        } else {
            addSelectedWatermark()
        }
    }

    func updateHotKey(_ configuration: HotKeyConfiguration) {
        guard configuration.hasRequiredModifier else {
            statusMessage = "快捷键必须包含 ⌘、⌥ 或 ⌃"
            return
        }
        guard hotKeyRegistrationHandler?(configuration) == true else {
            statusMessage = "快捷键 \(configuration.displayName) 注册失败，原快捷键继续有效"
            return
        }
        hotKeyConfiguration = configuration
        configuration.save(to: defaults)
        statusMessage = "全局快捷键已更新为 \(configuration.displayName)"
    }

    func resetHotKey() {
        updateHotKey(.default)
    }

    func reportInvalidHotKey() {
        statusMessage = "快捷键必须包含 ⌘、⌥ 或 ⌃，按 Esc 可取消录制"
    }

    func adoptStartupHotKeyFallback(_ configuration: HotKeyConfiguration) {
        hotKeyConfiguration = configuration
        configuration.save(to: defaults)
        statusMessage = "已保存的快捷键发生冲突，已恢复为 \(configuration.displayName)"
    }

    func reportStartupHotKeyFailure() {
        statusMessage = "全局快捷键注册失败，请在右侧重新设置；菜单栏功能仍可使用"
    }

    func flushPersistence(showStatus: Bool = false) {
        persistenceTask?.cancel()
        persistenceTask = nil
        guard persistenceEnabled else { return }
        persistCurrentTemplate(showStatus: showStatus)
    }

    private func loadImage(_ image: NSImage) {
        isWatermarkEnabled = true
        canvasZoom = 1
        sourceImage = image
        refreshPreview()
    }

    private func recordClipboardWrite(_ pasteboard: NSPasteboard, changeCount: Int) {
        let revision = PasteboardRevision(name: pasteboard.name, changeCount: changeCount)
        lastWrittenPasteboardRevision = revision
        lastObservedPasteboardRevision = revision
        hasPendingClipboardImage = false
    }

    private func refreshPreview() {
        guard let sourceImage else {
            previewImage = nil
            return
        }
        do {
            let previewLimit = min(6_000, max(1_200, Int((1_200 * canvasZoom).rounded())))
            previewImage = if isWatermarkEnabled {
                try WatermarkRenderer.renderPreview(
                    source: sourceImage,
                    template: workingTemplate,
                    maxPixelDimension: previewLimit
                )
            } else {
                try WatermarkRenderer.renderSourcePreview(
                    source: sourceImage,
                    maxPixelDimension: previewLimit
                )
            }
        } catch {
            previewImage = nil
            statusMessage = error.localizedDescription
        }
    }

    func renderCurrentOutput() throws -> NSImage {
        guard let sourceImage else { throw ClipboardError.noImage }
        if isWatermarkEnabled {
            return try WatermarkRenderer.render(source: sourceImage, template: workingTemplate)
        }
        return try WatermarkRenderer.renderSource(source: sourceImage)
    }

    private func scheduleAutomaticPersistence() {
        guard persistenceEnabled else { return }
        persistenceTask?.cancel()
        persistenceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            self?.persistCurrentTemplate(showStatus: true)
        }
    }

    private func persistCurrentTemplate(showStatus: Bool) {
        guard let index = templates.firstIndex(where: { $0.id == selectedTemplateID }) else { return }
        var persisted = workingTemplate.clamped()
        persisted.id = selectedTemplateID
        persisted.isBuiltIn = templates[index].isBuiltIn
        templates[index] = persisted
        workingTemplateWithoutScheduling(persisted)
        persistLibrary()
        if showStatus {
            statusMessage = "模板设置已自动保存"
        }
    }

    private func workingTemplateWithoutScheduling(_ template: WatermarkTemplate) {
        persistenceEnabled = false
        workingTemplate = template
        persistenceEnabled = true
    }

    private func persistLibrary() {
        do {
            try repository.saveLibrary(TemplateLibraryState(
                templates: templates,
                lastSelectedTemplateID: selectedTemplateID
            ))
        } catch {
            statusMessage = "保存模板失败：\(error.localizedDescription)"
        }
    }

    private func suggestedCustomTemplateName() -> String {
        let base = "我的 Logo 水印"
        let existingNames = Set(templates.map { $0.name.lowercased() })
        guard existingNames.contains(base.lowercased()) else { return base }
        var suffix = 2
        while existingNames.contains("\(base) \(suffix)".lowercased()) {
            suffix += 1
        }
        return "\(base) \(suffix)"
    }

    private static let canvasZoomLevels = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 3, 4, 5, 7.5, 10]
}

enum ClipboardObservationResult: Equatable {
    case unchanged
    case disabled
    case ignoredNonImage
    case ignoredOwnOrLoadedImage
    case pendingReplacement
    case loaded
}

private struct PasteboardRevision: Equatable {
    let name: NSPasteboard.Name
    let changeCount: Int

    init(_ pasteboard: NSPasteboard) {
        name = pasteboard.name
        changeCount = pasteboard.changeCount
    }

    init(name: NSPasteboard.Name, changeCount: Int) {
        self.name = name
        self.changeCount = changeCount
    }
}

private enum QuickApplyError: LocalizedError {
    case templateNotFound

    var errorDescription: String? { "所选水印模板已不存在，请重新选择" }
}
