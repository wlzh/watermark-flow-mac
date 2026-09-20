# WatermarkFlow v0.4.5 开发记录

## 快捷键配置

- `HotKeyConfiguration.default` 改为 Control、Option、Command 与 W，对应 `⌃⌥⌘W`。
- 新增 `legacyDefault` 表示历史 `⌥⌘W`，只用于迁移判断。
- `load(from:)` 解码后若匹配旧默认，立即写回新默认并返回新值；其他有效配置原样返回。

## 界面与版本

- 恢复默认按钮从固定文字改为读取 `HotKeyConfiguration.default.displayName`，避免以后配置与界面再次分离。
- 版本升级到 `0.4.5`，构建号升级到 `16`；模板 schema 保持 `4`。
- README、安装说明、Changelog、版本文档和测试门禁同步更新。

## 测试

- 应用自检在隔离 `UserDefaults` 中保存旧默认，验证加载结果、显示文字和落盘值均为新默认。
- 既有自定义 `⇧⌘K` 保存与跨实例恢复测试继续通过，证明迁移范围没有扩大。
- 生产安装后检查用户模板文件哈希，快捷键迁移不得改写模板 JSON。
