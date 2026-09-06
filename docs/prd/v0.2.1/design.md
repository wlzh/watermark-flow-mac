# WatermarkFlow v0.2.1 设计

## 菜单状态

`AppDelegate` 实现 `NSMenuItemValidation`。导出、生成和清空统一依据 `sourceImage != nil` 判定，确保主菜单与窗口按钮状态一致；剪贴板载入使用 `⇧⌘V`，避免覆盖文本编辑的普通粘贴。

## Logo 规范化

导入 Logo 后先读取真实像素尺寸。最长边大于 1024 时在 sRGB RGBA 上下文中按比例缩小，再编码为 PNG；不满足阈值时仅重新编码，不放大。模板仍保存 PNG 数据，因此现有 JSON schema 无需迁移。

## 版本门禁

`VERSION` 保存语义版本，`BUILD_NUMBER` 保存构建号。构建脚本把两者写入 App；测试脚本同时比对 App 自检输出、Info.plist、CHANGELOG、README、PRD、测试报告与两种 CPU 架构。

## 保持不变

水印位置继续以每个模板自己的归一化坐标保存。清空画布只清除当前 source/preview，不清除任何模板参数或快捷键。
