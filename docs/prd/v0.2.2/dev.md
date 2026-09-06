# WatermarkFlow v0.2.2 开发记录

## 代码变更

- `WatermarkRenderer`：新增 `renderSource` 和 `renderSourcePreview`，统一使用可选模板的底层渲染路径。
- `EditorViewModel`：新增会话级 `isWatermarkEnabled`、移除、添加、切换及按当前状态输出逻辑。
- `EditorViewModel`：新增 25% 至 1000% 缩放档位、百分比状态和适合窗口重置。
- `EditorView`：右键菜单、模板区和底部工具栏增加动态水印操作；画布增加缩放控件与双向滚动区域。
- `AppDelegate`：文件菜单增加动态水印操作，“显示”菜单增加缩放快捷键，并纳入空画布菜单校验。
- `WatermarkFlowTests` 与 `SelfTest`：覆盖 source-only 渲染、移除恢复、模板替换和空画布状态。

## 兼容性

模板 JSON schema 不变，不迁移现有用户数据。版本更新后继续读取原有模板覆盖值、用户模板、最后选择和快捷键配置。

## 版本同步

`VERSION`、`BUILD_NUMBER`、`AppVersion`、Info.plist、README、CHANGELOG、PRD、测试报告和 Release 文件名统一为 `0.2.2 (6)`。
