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
                    let rect = aspectFitRect(imageSize: image.size, container: geometry.size)
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .shadow(color: .black.opacity(0.34), radius: 20, y: 8)

                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .gesture(
                            DragGesture(minimumDistance: 3)
                                .onChanged { value in
                                    viewModel.updateWatermarkDrag(
                                        translation: value.translation,
                                        canvasSize: rect.size
                                    )
                                }
                                .onEnded { _ in viewModel.endWatermarkDrag() }
                        )
                }
                .padding(22)
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

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sectionTitle("模板")
                Picker("", selection: Binding(
                    get: { viewModel.selectedTemplateID },
                    set: { viewModel.selectTemplate(id: $0) }
                )) {
                    ForEach(viewModel.templates) { template in
                        Text(template.name).tag(template.id)
                    }
                }
                .labelsHidden()
                .controlSize(.large)

                Divider()
                sectionTitle("内容")
                Picker("品牌", selection: $viewModel.workingTemplate.brand) {
                    ForEach(WatermarkBrand.allCases, id: \.self) { brand in
                        Text(brand.displayName).tag(brand)
                    }
                }
                TextField("水印文字", text: $viewModel.workingTemplate.text)
                    .textFieldStyle(.roundedBorder)

                if viewModel.workingTemplate.brand == .custom {
                    Button("选择 Logo 图片…") { viewModel.importCustomLogo() }
                        .buttonStyle(outlineButtonStyle)
                }

                Divider()
                sectionTitle("颜色")
                HStack {
                    labeledColorPicker("文字", keyPath: \.foregroundColor)
                    labeledColorPicker("背景", keyPath: \.backgroundColor)
                    labeledColorPicker("图标", keyPath: \.accentColor)
                }

                Divider()
                sectionTitle("排版")
                valueSlider(
                    title: "透明度",
                    value: $viewModel.workingTemplate.opacity,
                    range: 0.05...1,
                    label: "\(Int(viewModel.workingTemplate.opacity * 100))%"
                )
                valueSlider(
                    title: "大小",
                    value: $viewModel.workingTemplate.relativeHeight,
                    range: 0.035...0.3,
                    label: "\(Int(viewModel.workingTemplate.relativeHeight * 1000) / 10)%"
                )
                valueSlider(
                    title: "旋转",
                    value: $viewModel.workingTemplate.rotationDegrees,
                    range: -180...180,
                    label: "\(Int(viewModel.workingTemplate.rotationDegrees))°"
                )

                Text("快速位置")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                positionGrid

                Divider()
                sectionTitle("模板管理")
                HStack {
                    Button("另存模板") { viewModel.saveCurrentAsTemplate() }
                        .buttonStyle(outlineButtonStyle)
                    Button("设为默认") { viewModel.setSelectedAsDefault() }
                        .buttonStyle(outlineButtonStyle)
                }
                Button("删除用户模板") { viewModel.deleteSelectedTemplate() }
                    .buttonStyle(outlineButtonStyle)
                    .disabled(!viewModel.canDeleteSelectedTemplate)

                Divider()
                sectionTitle("快捷操作")
                HStack(spacing: 8) {
                    Text("默认模板快捷键")
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
            Button("清空画布") { viewModel.clearCanvas() }
                .buttonStyle(outlineButtonStyle)
                .disabled(viewModel.sourceImage == nil)
            Spacer()
            Text("拖动可定位 · 模板修改自动保存")
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
        label: String
    ) -> some View {
        VStack(spacing: 3) {
            HStack {
                Text(title)
                Spacer()
                Text(label).monospacedDigit().foregroundStyle(theme.textSecondary)
            }
            .font(.system(size: 11, weight: .medium))
            Slider(value: value, in: range)
                .tint(theme.accent)
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
