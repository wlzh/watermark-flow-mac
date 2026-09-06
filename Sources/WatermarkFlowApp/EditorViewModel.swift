import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers
import WatermarkCore

@MainActor
final class EditorViewModel: ObservableObject {
    @Published private(set) var sourceImage: NSImage?
    @Published private(set) var previewImage: NSImage?
    @Published private(set) var templates: [WatermarkTemplate]
    @Published var selectedTemplateID: UUID
    @Published var workingTemplate: WatermarkTemplate {
        didSet { refreshPreview() }
    }
    @Published var statusMessage = "复制图片后载入，或把图片拖到左侧"

    private let repository: TemplateRepository
    private let defaults: UserDefaults
    private let defaultTemplateKey = "defaultTemplateID"
    private var dragStartPosition: NormalizedPoint?

    init(
        repository: TemplateRepository = TemplateRepository(),
        defaults: UserDefaults = .standard
    ) {
        self.repository = repository
        self.defaults = defaults

        let users = (try? repository.loadUserTemplates()) ?? []
        let loadedTemplates = DefaultTemplates.all + users
        templates = loadedTemplates

        let savedID = defaults.string(forKey: defaultTemplateKey).flatMap(UUID.init(uuidString:))
        let initial = loadedTemplates.first { $0.id == savedID } ?? DefaultTemplates.all[0]
        selectedTemplateID = initial.id
        workingTemplate = initial
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

    func selectTemplate(id: UUID) {
        guard let template = templates.first(where: { $0.id == id }) else { return }
        selectedTemplateID = id
        workingTemplate = template
        statusMessage = "已载入模板：\(template.name)"
    }

    func setPosition(x: Double, y: Double) {
        workingTemplate.position = NormalizedPoint(x: x, y: y).clamped()
    }

    func updateWatermarkDrag(translation: CGSize, canvasSize: CGSize) {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }
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
              let data = try? WatermarkRenderer.encode(image: image, format: .png) else { return }
        workingTemplate.brand = .custom
        workingTemplate.customLogoPNG = data
        statusMessage = "已载入自定义 Logo：\(url.lastPathComponent)"
    }

    func generateAndCopy() {
        do {
            let output = try requireRenderedImage()
            try ClipboardService.writeImage(output)
            statusMessage = "已生成并复制，可直接粘贴 · \(sourcePixelDescription)"
            NSSound(named: "Tink")?.play()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func quickApplyDefaultToClipboard() throws -> NSImage {
        let source = try ClipboardService.readImage()
        let template = templates.first { $0.id == defaultTemplateID } ?? DefaultTemplates.all[0]
        let output = try WatermarkRenderer.render(source: source, template: template)
        try ClipboardService.writeImage(output)
        statusMessage = "已用“\(template.name)”快速生成并复制"
        return output
    }

    func exportImage() {
        do {
            let output = try requireRenderedImage()
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.png, .jpeg]
            panel.nameFieldStringValue = "watermarked.png"
            panel.canCreateDirectories = true
            panel.message = "导出带水印的扁平图片"
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
        selectedTemplateID = template.id
        workingTemplate = template
        persistUserTemplates()
        statusMessage = "已保存模板：\(name)"
    }

    func setSelectedAsDefault() {
        defaults.set(selectedTemplateID.uuidString, forKey: defaultTemplateKey)
        statusMessage = "已设为快捷处理默认模板：\(workingTemplate.name)"
    }

    func deleteSelectedTemplate() {
        guard canDeleteSelectedTemplate else {
            statusMessage = "内置模板不可删除，可以另存为自定义模板"
            return
        }
        templates.removeAll { $0.id == selectedTemplateID }
        let fallback = DefaultTemplates.all[0]
        selectedTemplateID = fallback.id
        workingTemplate = fallback
        if defaultTemplateID == selectedTemplateID {
            defaults.set(fallback.id.uuidString, forKey: defaultTemplateKey)
        }
        persistUserTemplates()
        statusMessage = "已删除用户模板"
    }

    private func loadImage(_ image: NSImage) {
        sourceImage = image
        refreshPreview()
    }

    private func refreshPreview() {
        guard let sourceImage else {
            previewImage = nil
            return
        }
        do {
            previewImage = try WatermarkRenderer.render(source: sourceImage, template: workingTemplate)
        } catch {
            previewImage = nil
            statusMessage = error.localizedDescription
        }
    }

    private func requireRenderedImage() throws -> NSImage {
        guard sourceImage != nil else { throw ClipboardError.noImage }
        if let previewImage { return previewImage }
        throw WatermarkRenderError.outputCreationFailed
    }

    private func persistUserTemplates() {
        do {
            try repository.saveUserTemplates(templates.filter { !$0.isBuiltIn })
        } catch {
            statusMessage = "保存模板失败：\(error.localizedDescription)"
        }
    }
}
