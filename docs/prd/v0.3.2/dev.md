# WatermarkFlow v0.3.2 开发记录

## 实现范围

- `EditorViewModel` 增加可测试的 `createCustomTemplate(named:)`、`saveCurrentAsTemplate(named:)` 和 `setCustomLogo(image:fileName:)`。
- 新建逻辑先持久化当前模板，再从其布局与样式创建独立 UUID 的用户模板，清空内容和 Logo，并固定进入自定义 Logo 类型。
- Logo 导入统一通过 `normalizedLogoPNG`，成功后嵌入模板 JSON，失败时更新状态消息。
- `EditorView` 增加专用创建入口、Logo 状态、隐藏 Logo 恢复入口及更明确的图标类型文案。
- `AppTheme` 增加深浅色警示色 token。

## 数据兼容

本版本不改变模板结构，继续使用 schema 3。已有自定义 Logo 字节不会被清理；如果当前图标类型不是 `custom`，界面会识别并提供启用入口。

## 测试覆盖

- 核心测试使用真实透明 PNG 创建 Logo + 文字模板，保存后重新读取并渲染。
- 应用自检覆盖专用新建、来源模板隔离、Logo 导入、文字、双布局参数、立即保存、重启恢复、复制和快速渲染。
- 既有剪贴板、缩放、满屏、迁移、快捷键、模板删除和 Universal 构建门禁继续执行。

## 版本同步

`VERSION`、`BUILD_NUMBER`、`AppVersion`、Info.plist、README、CHANGELOG、安装说明、PRD、测试报告和 Release 文件名统一为 `0.3.2 (10)`。
