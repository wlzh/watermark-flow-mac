import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WatermarkCore

struct EditorView: View {
    @ObservedObject var viewModel: EditorViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppTheme { AppTheme(colorScheme: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(theme.border)
            HSplitView {
                canvasPanel
                    .frame(minWidth: 560)
                inspector
                    .frame(minWidth: 300, idealWidth: 320, maxWidth: 350)
            }
            Divider().overlay(theme.border)
            if viewModel.hasPendingClipboardImage {
                clipboardBanner
                Divider().overlay(theme.border)
            }
            footer
        }
        .frame(minWidth: 900, minHeight: 620)
        .background(theme.background)
        .foregroundStyle(theme.textPrimary)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("WatermarkFlow")
                    .font(.custom("Avenir Next Heavy", size: 25))
                Text("图片归你，标记来源")
                    .font(.custom("Avenir Next Medium", size: 11))
                    .tracking(1.2)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(viewModel.sourcePixelDescription)
                    .font(.custom("Avenir Next Demi Bold", size: 12))
                Text(viewModel.statusMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.accent)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    private var canvasPanel: some View {
        ZStack {
            theme.canvas
            if let image = viewModel.previewImage {
                GeometryReader { geometry in
                    let viewport = CGSize(
                        width: max(1, geometry.size.width - 44),
                        height: max(1, geometry.size.height - 44)
                    )
                    let fitted = aspectFitRect(imageSize: image.size, container: viewport).size
                    let zoomed = CGSize(
                        width: fitted.width * viewModel.canvasZoom,
                        height: fitted.height * viewModel.canvasZoom
                    )
                    let content = CGSize(
                        width: max(geometry.size.width, zoomed.width + 44),
                        height: max(geometry.size.height, zoomed.height + 44)
                    )

                    ScrollView([.horizontal, .vertical]) {
                        ZStack {
                            Image(nsImage: image)
                                .resizable()
                                .interpolation(.high)
                                .frame(width: zoomed.width, height: zoomed.height)
                                .shadow(color: .black.opacity(0.34), radius: 20, y: 8)

                            if viewModel.workingTemplate.layoutMode == .single {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .frame(width: zoomed.width, height: zoomed.height)
                                    .gesture(
                                        DragGesture(minimumDistance: 3)
                                            .onChanged { value in
                                                viewModel.updateWatermarkDrag(
                                                    translation: value.translation,
                                                    canvasSize: zoomed
                                                )
                                            }
                                            .onEnded { _ in viewModel.endWatermarkDrag() }
                                    )
                            }
                        }
                        .frame(width: content.width, height: content.height)
                    }
                    .overlay(alignment: .topTrailing) {
                        zoomControls
                            .padding(12)
                    }
                }
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(theme.accent)
                    Text("拖入一张图片")
                        .font(.custom("Avenir Next Demi Bold", size: 19))
                        .foregroundStyle(.white)
                    Text("或从剪贴板、文件中载入")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
        .contextMenu {
            Button {
                viewModel.toggleCurrentWatermark()
            } label: {
                Label(
                    viewModel.isWatermarkEnabled ? "移除当前水印" : "添加所选模板水印",
                    systemImage: viewModel.isWatermarkEnabled ? "eye.slash" : "eye"
                )
            }
            .disabled(viewModel.sourceImage == nil)

            Divider()

            Button(role: .destructive) {
                viewModel.clearCanvas()
            } label: {
                Label("清空图片与水印画布", systemImage: "trash")
            }
            .disabled(viewModel.sourceImage == nil)
        }
        .onDrop(of: [UTType.fileURL.identifier, UTType.image.identifier], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 0) {
            Button(action: viewModel.zoomOut) {
                Image(systemName: "minus")
                    .frame(width: 28, height: 26)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.canvasZoom <= 0.25)

            Divider().frame(height: 18)

            Menu {
                ForEach(viewModel.canvasZoomOptions, id: \.self) { zoom in
                    Button {
                        viewModel.setCanvasZoom(zoom)
                    } label: {
                        if abs(viewModel.canvasZoom - zoom) < 0.001 {
                            Label("\(Int(zoom * 100))%", systemImage: "checkmark")
                        } else {
                            Text("\(Int(zoom * 100))%")
                        }
                    }
                }
            } label: {
                Text(viewModel.canvasZoomDescription)
                    .monospacedDigit()
                    .frame(minWidth: 48, minHeight: 26)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("选择缩放比例；100% 为适合窗口")

            Divider().frame(height: 18)

            Button(action: viewModel.zoomIn) {
                Image(systemName: "plus")
                    .frame(width: 28, height: 26)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.canvasZoom >= 10)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(theme.textPrimary)
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border))
        .shadow(color: .black.opacity(0.22), radius: 8, y: 3)
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sectionTitle("模板")
                Picker("", selection: Binding(
                    get: { viewModel.selectedTemplateID },
                    set: { viewModel.selectTemplate(id: $0) }
                )) {
                    ForEach(viewModel.templates) { template in
                        Text(
                            template.id == viewModel.defaultTemplateID
                                ? "\(template.name) · 快捷默认"
                                : template.name
                        )
                        .tag(template.id)
                    }
                }
                .labelsHidden()
                .controlSize(.large)

                Button("＋ 新建 Logo + 文字模板") { viewModel.createCustomTemplate() }
                    .buttonStyle(outlineButtonStyle)

                HStack(spacing: 8) {
                    Circle()
                        .fill(
                            viewModel.sourceImage == nil
                                ? theme.textSecondary
                                : (viewModel.isWatermarkEnabled ? theme.accent : theme.textSecondary)
                        )
                        .frame(width: 7, height: 7)
                    Text(
                        viewModel.sourceImage == nil
                            ? "载入图片后应用所选水印"
                            : (viewModel.isWatermarkEnabled ? "当前水印已显示" : "当前图片无水印")
                    )
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Button(viewModel.isWatermarkEnabled ? "移除" : "添加所选水印") {
                        viewModel.toggleCurrentWatermark()
                    }
                    .buttonStyle(outlineButtonStyle)
                    .disabled(viewModel.sourceImage == nil)
                }

                Divider()
                sectionTitle("内容")
                Picker("图标类型", selection: $viewModel.workingTemplate.brand) {
                    ForEach(WatermarkBrand.allCases, id: \.self) { brand in
                        Text(brand.displayName).tag(brand)
                    }
                }
                TextField("水印文字", text: $viewModel.workingTemplate.text)
                    .textFieldStyle(.roundedBorder)

                if viewModel.workingTemplate.brand == .custom {
                    HStack {
                        Button(viewModel.workingTemplate.customLogoPNG == nil ? "选择 Logo 图片…" : "更换 Logo 图片…") {
                            viewModel.importCustomLogo()
                        }
                        .buttonStyle(outlineButtonStyle)
                        Spacer()
                        Text(customLogoStatus)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(
                                viewModel.workingTemplate.customLogoPNG == nil
                                    ? theme.warning
                                    : theme.textSecondary
                            )
                    }
                } else if viewModel.workingTemplate.customLogoPNG != nil {
                    HStack(spacing: 8) {
                        Text("已嵌入的自定义 Logo 当前未显示")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.warning)
                        Spacer()
                        Button("启用 Logo") { viewModel.workingTemplate.brand = .custom }
                            .buttonStyle(outlineButtonStyle)
                    }
                }

                Divider()
                sectionTitle("排版")
                Picker("布局", selection: $viewModel.workingTemplate.layoutMode) {
                    ForEach(WatermarkLayoutMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if viewModel.workingTemplate.layoutMode == .tiled {
                    valueSlider(
                        title: "平铺密度",
                        value: $viewModel.workingTemplate.tileDensity,
                        range: 1...10,
                        step: 1,
                        label: "\(Int(viewModel.workingTemplate.tileDensity.rounded())) 级"
                    )
                    Text("满屏参数独立保存；切回单个会恢复单个模式设置")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textSecondary)
                } else {
                    Text("单个参数独立保存；切到满屏会恢复满屏模式设置")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textSecondary)
                }

                Divider()
                sectionTitle("\(viewModel.workingTemplate.layoutMode.displayName)样式")
                HStack {
                    labeledColorPicker("文字", keyPath: \.activeForegroundColor)
                    labeledColorPicker("背景", keyPath: \.activeBackgroundColor)
                    labeledColorPicker("图标", keyPath: \.activeAccentColor)
                }
                Picker(
                    "自动对比",
                    selection: $viewModel.workingTemplate.activeContrastMode
                ) {
                    ForEach(WatermarkContrastMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                if viewModel.workingTemplate.activeContrastMode != .off {
                    Picker(
                        "对比强度",
                        selection: $viewModel.workingTemplate.activeContrastStrength
                    ) {
                        ForEach(WatermarkContrastStrength.allCases, id: \.self) { strength in
                            Text(strength.displayName).tag(strength)
                        }
                    }
                    Text("按水印所在区域自动适配；手动颜色仍保留，关闭后恢复")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textSecondary)
                }
                valueSlider(
                    title: "透明度",
                    value: $viewModel.workingTemplate.activeOpacity,
                    range: 0.05...1,
                    label: "\(Int(viewModel.workingTemplate.activeOpacity * 100))%"
                )
                valueSlider(
                    title: "大小",
                    value: $viewModel.workingTemplate.activeRelativeHeight,
                    range: 0.035...0.3,
                    label: "\(Int(viewModel.workingTemplate.activeRelativeHeight * 1000) / 10)%"
                )
                valueSlider(
                    title: "旋转",
                    value: $viewModel.workingTemplate.activeRotationDegrees,
                    range: -180...180,
                    label: "\(Int(viewModel.workingTemplate.activeRotationDegrees))°"
                )

                if viewModel.workingTemplate.layoutMode == .single {
                    Text("快速位置")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                    positionGrid
                }

                Divider()
                sectionTitle("模板管理")
                HStack {
                    Button("复制当前模板") { viewModel.saveCurrentAsTemplate() }
                        .buttonStyle(outlineButtonStyle)
                    Button(viewModel.isSelectedTemplateDefault ? "已是快捷默认" : "设为快捷默认") {
                        viewModel.setSelectedAsDefault()
                    }
                        .buttonStyle(outlineButtonStyle)
                        .disabled(viewModel.isSelectedTemplateDefault)
                }
                Button("删除用户模板") { viewModel.deleteSelectedTemplate() }
                    .buttonStyle(outlineButtonStyle)
                    .disabled(!viewModel.canDeleteSelectedTemplate)

                Divider()
                sectionTitle("快捷操作")
                Picker(
                    "快捷默认模板",
                    selection: Binding(
                        get: { viewModel.defaultTemplateID },
                        set: { viewModel.setDefaultTemplate(id: $0) }
                    )
                ) {
                    ForEach(viewModel.templates) { template in
                        Text(template.name).tag(template.id)
                    }
                }
                Picker(
                    "剪贴板图片",
                    selection: Binding(
                        get: { viewModel.clipboardAutoLoadMode },
                        set: { viewModel.updateClipboardAutoLoadMode($0) }
                    )
                ) {
                    ForEach(ClipboardAutoLoadMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                HStack(spacing: 8) {
                    Text("快捷默认模板快捷键")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    HotKeyRecorderView(
                        configuration: viewModel.hotKeyConfiguration,
                        onChange: viewModel.updateHotKey,
                        onInvalid: viewModel.reportInvalidHotKey
                    )
                    .frame(width: 126, height: 28)
                }
                Button("恢复默认 ⌥⌘W") { viewModel.resetHotKey() }
                    .buttonStyle(outlineButtonStyle)
            }
            .padding(20)
        }
        .background(theme.surface)
    }

    private var positionGrid: some View {
        let points: [(String, Double, Double)] = [
            ("↖", 0.14, 0.12), ("↑", 0.5, 0.12), ("↗", 0.86, 0.12),
            ("←", 0.14, 0.5), ("•", 0.5, 0.5), ("→", 0.86, 0.5),
            ("↙", 0.14, 0.88), ("↓", 0.5, 0.88), ("↘", 0.86, 0.88)
        ]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                Button(point.0) { viewModel.setPosition(x: point.1, y: point.2) }
                    .frame(maxWidth: .infinity, minHeight: 28)
                    .buttonStyle(outlineButtonStyle)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("从剪贴板载入") { viewModel.loadFromClipboard() }
                .buttonStyle(outlineButtonStyle)
            Button("打开图片…") { viewModel.openImage() }
                .buttonStyle(outlineButtonStyle)
            Button("导出文件…") { viewModel.exportImage() }
                .buttonStyle(outlineButtonStyle)
                .disabled(viewModel.sourceImage == nil)
            Button(viewModel.isWatermarkEnabled ? "移除水印" : "添加所选水印") {
                viewModel.toggleCurrentWatermark()
            }
            .buttonStyle(outlineButtonStyle)
            .disabled(viewModel.sourceImage == nil)
            Button("清空画布") { viewModel.clearCanvas() }
                .buttonStyle(outlineButtonStyle)
                .disabled(viewModel.sourceImage == nil)
            Spacer()
            Text(footerHint)
                .font(.system(size: 11))
                .foregroundStyle(theme.textSecondary)
            Button("生成并复制") { viewModel.generateAndCopy() }
                .buttonStyle(PrimaryButtonStyle(accent: theme.accent, foreground: theme.onAccent))
                .disabled(viewModel.sourceImage == nil)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(theme.background)
    }

    private var clipboardBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard.fill")
                .foregroundStyle(theme.accent)
            Text("检测到新的剪贴板图片")
                .font(.system(size: 11, weight: .semibold))
            Text("当前画布不会被自动覆盖")
                .font(.system(size: 11))
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Button("忽略") { viewModel.dismissPendingClipboardImage() }
                .buttonStyle(outlineButtonStyle)
            Button("载入并替换") { viewModel.loadPendingClipboardImage() }
                .buttonStyle(PrimaryButtonStyle(accent: theme.accent, foreground: theme.onAccent))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(theme.surface)
    }

    private var footerHint: String {
        if viewModel.sourceImage == nil {
            return "等待载入图片"
        }
        if !viewModel.isWatermarkEnabled {
            return "选择其他模板可直接替换"
        }
        if viewModel.workingTemplate.layoutMode == .tiled {
            return "满屏平铺 · 密度 \(Int(viewModel.workingTemplate.tileDensity.rounded())) 级"
        }
        return "拖动可定位 · 模板修改自动保存"
    }

    private var customLogoStatus: String {
        guard let data = viewModel.workingTemplate.customLogoPNG else { return "尚未选择 Logo" }
        return "已嵌入 · \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))"
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.custom("Avenir Next Heavy", size: 11))
            .tracking(1.4)
            .foregroundStyle(theme.textSecondary)
    }

    private func labeledColorPicker(
        _ title: String,
        keyPath: WritableKeyPath<WatermarkTemplate, RGBAColor>
    ) -> some View {
        VStack(spacing: 5) {
            ColorPicker("", selection: Binding(
                get: { Color(nsColor: viewModel.workingTemplate[keyPath: keyPath].nsColor) },
                set: { color in
                    viewModel.workingTemplate[keyPath: keyPath] = RGBAColor(nsColor: NSColor(color))
                }
            ), supportsOpacity: true)
            .labelsHidden()
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func valueSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double? = nil,
        label: String
    ) -> some View {
        VStack(spacing: 3) {
            HStack {
                Text(title)
                Spacer()
                Text(label).monospacedDigit().foregroundStyle(theme.textSecondary)
            }
            .font(.system(size: 11, weight: .medium))
            if let step {
                Slider(value: value, in: range, step: step)
                    .tint(theme.accent)
            } else {
                Slider(value: value, in: range)
                    .tint(theme.accent)
            }
        }
    }

    private var outlineButtonStyle: OutlineButtonStyle {
        OutlineButtonStyle(
            foreground: theme.textPrimary,
            fill: theme.controlFill,
            border: theme.border
        )
    }

    private func aspectFitRect(imageSize: CGSize, container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = item as? URL
                }
                guard let url else { return }
                DispatchQueue.main.async { viewModel.loadImage(at: url) }
            }
            return true
        }
        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
            guard let data else { return }
            DispatchQueue.main.async { viewModel.loadImageData(data) }
        }
        return true
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    let accent: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Avenir Next Demi Bold", size: 13))
            .foregroundStyle(foreground)
            .padding(.horizontal, 18)
            .frame(minHeight: 34)
            .background(accent.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct OutlineButtonStyle: ButtonStyle {
    let foreground: Color
    let fill: Color
    let border: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(foreground.opacity(configuration.isPressed ? 0.68 : 0.92))
            .padding(.horizontal, 10)
            .frame(minHeight: 30)
            .background(fill.opacity(configuration.isPressed ? 0.7 : 1))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(border))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
