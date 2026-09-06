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
    @Published var statusMessage = "复制图片后载入，或把图片拖到左侧"
    @Published private(set) var hotKeyConfiguration: HotKeyConfiguration

    private let repository: TemplateRepository
    private let defaults: UserDefaults
    private let defaultTemplateKey = "defaultTemplateID"
    private var dragStartPosition: NormalizedPoint?
    private var persistenceTask: Task<Void, Never>?
    private var persistenceEnabled = false
    var hotKeyRegistrationHandler: ((HotKeyConfiguration) -> Bool)?

    init(
        repository: TemplateRepository = TemplateRepository(),
        defaults: UserDefaults = .standard
    ) {
        self.repository = repository
        self.defaults = defaults
        hotKeyConfiguration = HotKeyConfiguration.load(from: defaults)

        let library = (try? repository.loadLibrary())
            ?? TemplateLibraryState(templates: DefaultTemplates.all)
        let loadedTemplates = library.templates
        templates = loadedTemplates

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

    var defaultTemplateID: UUID {
        let saved = defaults.string(forKey: defaultTemplateKey).flatMap(UUID.init(uuidString:))
        return templates.contains { $0.id == saved } ? saved! : DefaultTemplates.xWLZHID
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
        guard isWatermarkEnabled, canvasSize.width > 0, canvasSize.height > 0 else { return }
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

    func loadFromClipboard() {
        do {
            try loadImage(ClipboardService.readImage())
            statusMessage = "已从剪贴板载入图片"
        } catch {
            statusMessage = error.localizedDescription
        }
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
        guard panel.runModal() == .OK,
              let url = panel.url,
              let image = NSImage(contentsOf: url),
              let data = try? WatermarkRenderer.normalizedLogoPNG(image: image) else { return }
        workingTemplate.brand = .custom
        workingTemplate.customLogoPNG = data
        statusMessage = "已载入自定义 Logo：\(url.lastPathComponent)"
    }

    func generateAndCopy() {
        do {
            let output = try renderCurrentOutput()
            try ClipboardService.writeImage(output)
            statusMessage = isWatermarkEnabled
                ? "已生成并复制，可直接粘贴 · \(sourcePixelDescription)"
                : "已复制无水印原图 · \(sourcePixelDescription)"
            NSSound(named: "Tink")?.play()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func quickApplyDefaultToClipboard() throws -> NSImage {
        try quickApplyTemplateToClipboard(id: defaultTemplateID)
    }

    func quickApplyTemplateToClipboard(id: UUID) throws -> NSImage {
        flushPersistence()
        let source = try ClipboardService.readImage()
        let output = try renderForQuickApply(source: source, templateID: id)
        try ClipboardService.writeImage(output)
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
        flushPersistence()
        let alert = NSAlert()
        alert.messageText = "保存水印模板"
        alert.informativeText = "输入模板名称。当前图片不会保存到模板中。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        let field = NSTextField(string: workingTemplate.name + " 副本")
        field.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            statusMessage = "模板名称不能为空"
            return
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
    }

    func setSelectedAsDefault() {
        flushPersistence()
        defaults.set(selectedTemplateID.uuidString, forKey: defaultTemplateKey)
        statusMessage = "已设为快捷处理默认模板：\(workingTemplate.name)"
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

    private static let canvasZoomLevels = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 3, 4, 5, 7.5, 10]
}

private enum QuickApplyError: LocalizedError {
    case templateNotFound

    var errorDescription: String? { "所选水印模板已不存在，请重新选择" }
}
