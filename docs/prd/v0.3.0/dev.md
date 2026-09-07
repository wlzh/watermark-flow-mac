# WatermarkFlow v0.3.0 开发记录

## 代码变更

- `Models.swift`：新增 `WatermarkLayoutMode`、`layoutMode`、`tileDensity` 和兼容解码。
- `TemplateRepository.swift`：模板 schema 升级为 2。
- `WatermarkRenderer.swift`：抽取可复用徽章布局与绘制函数，新增错列满屏循环。
- `EditorView.swift`：排版区新增布局分段按钮、密度滑杆和模式说明。
- `EditorViewModel.swift`：满屏模式拦截位置拖动。
- 核心测试与应用自检：覆盖迁移、持久化、密度覆盖差异、4K 输出和拖动隔离。

## 参数定义

- 密度范围：1–10，整数步进。
- 默认密度：5。
- 间距倍数：密度 1 时 2.9，密度 10 时 1.4，线性插值。
- 行错位：奇数行偏移水平步长的 50%。

## 版本同步

`VERSION`、`BUILD_NUMBER`、`AppVersion`、Info.plist、README、CHANGELOG、PRD、测试报告和 Release 文件名统一为 `0.3.0 (8)`。
