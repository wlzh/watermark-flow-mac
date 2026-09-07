# WatermarkFlow v0.3.1 设计

## 配置边界

`WatermarkTemplate` 保留原有顶层视觉字段作为单个模式配置，并新增 `tiledStyle: WatermarkVisualSettings` 作为满屏模式配置。`WatermarkVisualSettings` 包含：

- `foregroundColor`
- `backgroundColor`
- `accentColor`
- `opacity`
- `relativeHeight`
- `rotationDegrees`

模板名称、品牌、文字、自定义 Logo 为共享内容。`position` 只由单个模式使用，`tileDensity` 只由满屏模式使用。该边界既满足独立配置，也避免重复保存大体积 Logo 数据。

## 活动配置

`WatermarkTemplate` 提供六个可读写的 `active*` 计算属性。它们根据 `layoutMode` 路由到单个或满屏配置。编辑器所有视觉控件和渲染器只访问活动属性，因此切换模式会自然恢复目标配置，修改也不会泄漏到非活动配置。

## 迁移

模板库 schema 从 2 升级为 3。解码缺少 `tiledStyle` 的旧模板时，使用其原有共享视觉字段构造满屏配置：

- schema 2 的当前效果会同时成为单个和满屏的初始效果。
- schema 1 及更早模板仍先采用默认单个布局和 5 级密度，再复制视觉配置。
- 首次成功读取后立即原子写回完整 schema 3 数据，不依赖用户再次编辑。
- 高于当前版本的未知 schema 会拒绝加载且不写回，避免旧应用降级破坏新格式数据。

## 持久化与性能

现有模板级延迟自动保存机制无需增加新的存储通道。六个标量/颜色字段只带来少量 JSON 增量；渲染路径仍只创建一次徽章布局，满屏循环性能特征不变。
