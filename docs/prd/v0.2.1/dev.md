# WatermarkFlow v0.2.1 开发与验收

## 代码变更

- `WatermarkRenderer.normalizedLogoPNG`：Logo 限幅、等比缩放和 Alpha 保持。
- `EditorViewModel.importCustomLogo`：统一使用规范化 Logo 数据。
- `AppDelegate.validateMenuItem`：空画布菜单禁用。
- `BUILD_NUMBER`、`build-app.sh`、`test-all.sh`：版本与文档联动门禁。

## 回归范围

- 三个内置模板和用户模板。
- 模板自动保存、位置恢复、默认模板和快捷键恢复。
- 文字、X、YouTube、自定义 Logo、透明 PNG。
- 横图、竖图、大图和 64×64 小图。
- 剪贴板、PNG/JPEG 导出、画布清空和进程重启。
- 深色、浅色、关于窗口、作者和网站链接。
- arm64、x86_64、签名、压缩包和 SHA-256。

## 已知发布限制

本机没有 Developer ID Application 身份，二进制只能 ad-hoc 签名。GitHub Release 可供安装，但首次打开可能需要 Finder 的 Control 点击“打开”。
