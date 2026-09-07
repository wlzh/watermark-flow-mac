# WatermarkFlow v0.3.1 开发记录

## 代码变更

- `Models.swift`：新增 `WatermarkVisualSettings`、`tiledStyle` 和六个活动样式访问器，并为旧数据提供复制迁移。
- `TemplateRepository.swift`：模板 schema 升级为 3，旧数据首次读取后原子写回，未来 schema 拒绝降级覆盖。
- `WatermarkRenderer.swift`：文字、背景、图标、透明度、大小和旋转统一读取活动布局配置。
- `EditorView.swift`：布局选择前置，颜色与滑杆绑定活动配置，并明确标注“单个样式”或“满屏样式”。
- `SelfTest.swift`：验证两套参数自动保存、重启恢复和来回切换。
- 核心测试：增加配置隔离、活动配置渲染、schema 2 迁移和两套配置完整持久化覆盖。

## 兼容策略

保留既有顶层视觉字段作为单个配置，避免破坏旧 JSON 字段和调用方。`tiledStyle` 缺失时由解码器从顶层字段构造，因此 `v0.3.0` 中正在使用的满屏外观不会因升级丢失。

## 版本同步

`VERSION`、`BUILD_NUMBER`、`AppVersion`、Info.plist、README、CHANGELOG、PRD、测试报告和 Release 文件名统一为 `0.3.1 (9)`。
