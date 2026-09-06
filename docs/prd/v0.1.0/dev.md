# WatermarkFlow v0.1.0 技术开发文档

## 技术架构

- Swift Package Manager 管理源码和测试，不依赖第三方库。
- `WatermarkCore`：模板模型、JSON 存储、Core Graphics 渲染、剪贴板读写。
- `WatermarkFlowApp`：SwiftUI 编辑器、AppKit 窗口与菜单栏、Carbon 全局快捷键。
- 最低系统版本 macOS 13，构建兼容 Apple Silicon 和 Intel 源码编译。

## 数据模型

`WatermarkTemplate` 保存 UUID、名称、品牌类型、文字、三种 RGBA 颜色、透明度、相对高度、归一化位置、旋转角度和可选自定义 Logo PNG 数据。

内置模板由代码生成并使用稳定 UUID。用户模板以 JSON 写入：

```text
~/Library/Application Support/com.wlzh.WatermarkFlow/templates.json
```

默认模板 UUID 写入 `UserDefaults`。用户模板文件采用原子写入。

## 渲染管线

1. 将 `NSImage` 解析为像素级 `CGImage`。
2. 创建与原图像素尺寸一致的 sRGB RGBA 位图上下文。
3. 绘制原图。
4. 根据相对高度和文字宽度计算水印胶囊布局。
5. 将归一化左上坐标转换为 Core Graphics 坐标，应用旋转和总透明度。
6. 绘制阴影、背景、品牌图标、自定义 Logo 和文字。
7. 生成 `NSImage`，按需要编码 PNG 或 JPEG。

## 剪贴板契约

读取使用 `NSImage(pasteboard:)`，兼容系统支持的位图和文件表示。写入时同时声明 PNG 与 TIFF，保证聊天、浏览器、Office 和图像应用的粘贴兼容性。写入前清空 general pasteboard。

## 会话边界

ViewModel 内保留原始 `NSImage` 和当前 `WatermarkTemplate` 值。任何编辑只更新模板参数并重新预览，不修改原图。复制、导出和快捷处理只生成临时扁平结果。应用不序列化原图和当前会话。

## 文件清单

- `Sources/WatermarkCore/Models.swift`：颜色、位置、品牌和模板。
- `Sources/WatermarkCore/DefaultTemplates.swift`：三套默认模板。
- `Sources/WatermarkCore/WatermarkRenderer.swift`：渲染与编码。
- `Sources/WatermarkCore/TemplateRepository.swift`：持久化。
- `Sources/WatermarkCore/ClipboardService.swift`：剪贴板边界。
- `Sources/WatermarkFlowApp/EditorViewModel.swift`：编辑状态与命令。
- `Sources/WatermarkFlowApp/EditorView.swift`：界面和拖放。
- `Sources/WatermarkFlowApp/AppDelegate.swift`：菜单栏、窗口和菜单命令。
- `Sources/WatermarkFlowApp/GlobalHotKey.swift`：Carbon 快捷键。
- `Sources/WatermarkFlowApp/main.swift`：应用入口和自检入口。

## 版本与构建

单一发布版本记录在 `VERSION`，同时写入 App `CFBundleShortVersionString`。构建脚本生成 `dist/WatermarkFlow.app` 并进行 ad-hoc 签名。测试脚本验证 Swift 测试、Release 构建、真实剪贴板往返、Info.plist 版本和签名。

应用元数据固定记录作者 `X @wlzh` 和网站 `https://869hr.uk`，并在关于窗口、Info.plist 与 README 中保持一致。

## 风险与处理

- 超大图片渲染产生瞬时内存压力：仅在参数变化和输出时生成，不保存历史位图。
- 自定义 Logo 数据过大：导入时统一编码为 PNG，`v0.1.0` 不做云同步。
- 全局快捷键冲突：菜单栏始终提供等价命令；注册失败不阻塞主编辑器。
- 无正式签名：限定本机安装，后续版本增加 Developer ID 和 notarization。
