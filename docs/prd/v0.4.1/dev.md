# WatermarkFlow v0.4.1 开发记录

## 实现

- 新增 `MouseWheelZoomMonitor`，通过透明 `NSViewRepresentable` 将 AppKit 滚轮事件限定到 SwiftUI 画布区域。
- 本地事件监视器同时校验当前窗口和视图边界，只消费已识别为鼠标垂直滚轮的事件。
- `hasPreciseScrollingDeltas` 为 `true` 的事件按触控板处理并原样返回；横向分量不小于纵向分量时同样透传。
- 使用系统提供的 `scrollingDeltaY` 判定方向，继承用户的 macOS 滚动方向偏好。
- 监视视图离开窗口或销毁时移除事件监视器，避免重复注册和生命周期泄漏。
- `EditorViewModel.zoomWithMouseWheel` 复用现有 `zoomIn`、`zoomOut` 与图片存在性保护，不引入第二套缩放状态。
- 新增 `CanvasDragMonitor`，命中单个水印渲染边界时复用既有水印拖动；命中图片其他区域且内容溢出时直接约束并更新 `NSScrollView` 可视原点。
- `WatermarkRenderer.singleWatermarkBounds` 复用真实文字和图标排版数据，并计入旋转后的外接矩形，避免整张图片都被误判为水印拖动区。
- 画布平移只改变滚动容器的瞬时视口，不写入模板、图片或持久化配置。

## 兼容性

- 模板 schema 保持 4，不迁移或重写用户模板。
- 输出渲染器、剪贴板、模板保存和快捷生成路径不变。
- 支持范围仍为 macOS 13 及以上，Universal `arm64` / `x86_64`。

## 测试策略

- 纯函数验证鼠标上下方向、精细滚动排除、横向滚动排除和零位移排除。
- ViewModel 验证实际相邻档位路由、25%/1000% 边界和空画布无副作用。
- 核心测试验证水印命中边界与旋转结果；应用自检验证水印优先、图片平移、未放大和图片外部事件分类。
- 完整测试脚本继续覆盖核心渲染、持久化、安装包元数据、架构、签名和许可证。
