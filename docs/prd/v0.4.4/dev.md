# WatermarkFlow v0.4.4 开发记录

## 核心实现

- `ClipboardService` 使用 `NSPasteboard.readObjects` 提取本地文件 URL，并通过 Uniform Type Identifiers 验证普通文件是否符合图片类型。
- 本地文件路径先于 `NSImage(pasteboard:)` 判断，防止 AppKit 在多文件剪贴板中静默采用第一个图片。
- `readImage` 同步支持原生图片和本地图片文件；`readImageResolvingWebContent` 在此基础上仅对“没有图片”继续执行 HTML 单图回退。
- `canReadImage` 为后台观察提供无网络的轻量判定，只接受恰好一个本地图片文件。

## 应用链路

- `EditorViewModel.observeClipboard` 改用统一的 `canReadImage`，因此现有三种自动载入策略自然支持 Finder 文件。
- 主窗口“从剪贴板载入”和 AppDelegate 菜单动作统一调用 `loadFromClipboardResolvingRichContent`。
- 成功状态统一为“已从剪贴板载入图片”，不再把所有主动来源误称为网页图片。

## 数据与兼容性

- 版本升级到 `0.4.4`，构建号升级到 `15`。
- 模板 schema 保持 `4`，不修改模板文件、用户默认模板、快捷键或剪贴板策略。
- 本地图片文件只读解码，512 MB 上限独立于网页图片 64 MB 上限。

## 测试

- 核心测试以真实临时 PNG 文件写入隔离剪贴板，验证 `public.file-url`、识别结果和像素尺寸。
- 核心测试写入两个图片文件，验证自动载入拒绝并且主动读取抛出多文件错误。
- 核心测试验证非图片文件、文件夹与超过 512 MB 的稀疏图片文件均被拒绝。
- 应用自检验证单个本地图片文件在空画布策略下自动载入为正确尺寸。
