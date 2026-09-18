# WatermarkFlow v0.4.3 开发记录

## 核心解析

- `ClipboardService.readImageResolvingWebContent` 先调用 AppKit 原生图片解析，失败后才读取 HTML。
- HTML 解析逐个提取 `<img>` 标签的准确 `src` 属性，并以 `data-src` 作为缺失时的回退，避免把 `data-src` 误认为 `src`。
- 还原常见 HTML 实体，只接受一个唯一来源；支持 HTTPS 和 `data:image`，响应上限为 64 MB。
- 远程读取使用 15 秒超时并验证 HTTP 成功状态，最终仍以 `NSImage` 解码结果作为图片有效性门禁。

## 应用链路

- `EditorViewModel.quickApplyTemplateToClipboard` 改为异步，读取完成后继续使用既有模板渲染与剪贴板写回逻辑。
- `AppDelegate` 用单一 `Task` 管理快捷处理，任务存在时忽略重复触发，并在退出时取消。
- “从剪贴板载入”使用相同的主动解析接口；定时剪贴板监测保留同步原生图片路径，不主动联网。
- 状态栏闪烁增加代次保护，异步状态结束后始终恢复 WatermarkFlow 品牌图标。
- `AppDelegate` 新增动态默认模板子菜单，菜单项复用模板 UUID，选择后调用既有 `setDefaultTemplate` 持久化逻辑，并同步更新两个子菜单的勾选状态。

## 数据与兼容性

- 模板 schema 保持 4，无迁移。
- `VERSION` 升级到 0.4.3，构建号升级到 14。
- 最低系统与 Universal 架构要求不变。

## 测试

- 新增模拟 HTTPS 单图 HTML，验证实体还原、远程加载器调用和像素尺寸。
- 新增 HTML 多图拒绝测试，防止隐式选择错误图片。
- 应用自检验证默认模板子菜单包含全部动态模板、唯一勾选项和切换后的持久状态。
- 使用用户复现的飞书 HTML 现场验证真实 `src` 可读取为 1254×768 PNG。
