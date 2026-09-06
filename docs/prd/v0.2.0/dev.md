# WatermarkFlow v0.2.0 开发与验收

## 模块变更

- `AppTheme.swift`：深浅模式语义色板。
- `HotKeyRecorderView.swift`：原生按键录制控件。
- `GlobalHotKey.swift`：快捷键配置、持久化编码和运行时重新注册。
- `AppDelegate.swift`：动态模板子菜单、清空菜单、快捷键菜单文案同步。
- `EditorViewModel.swift`：指定模板快速渲染、清空会话、快捷键更新和全分辨率输出。
- `WatermarkRenderer.swift`：受限分辨率预览与原图渲染分流。

## 数据与兼容性

- 模板 JSON schema 保持 `1`，无需迁移。
- 未保存快捷键的老版本用户自动使用 `⌥⌘W`。
- 快捷键配置损坏或缺少有效修饰键时回退默认值。
- 现有内置模板覆盖、自定义模板和最后选择状态保持兼容。

## 发布要求

- `VERSION`、`AppVersion`、`Info.plist`、README、CHANGELOG、PRD 和测试报告均为 `0.2.0 (4)`。
- `package-release.sh` 生成 Universal zip 与 `SHA256.txt`。
- Release 明确标注 ad-hoc 签名和未 notarize，不得宣称零提示安装。
