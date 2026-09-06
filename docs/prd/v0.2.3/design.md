# WatermarkFlow v0.2.3 设计

## 许可证来源

仓库根目录 `LICENSE` 是唯一许可文本源。构建脚本把该文件原样复制为 App 的 `Contents/Resources/LICENSE.txt`，不维护第二份手写内容。

## 界面与元数据

About 窗口显示可点击的“MIT License”，链接到公开仓库的 `LICENSE`。Info.plist 增加 `License = MIT`，保留现有作者、作者主页、网站和版权信息。

## 构建门禁

测试脚本验证 Info.plist 的许可值、包内文件存在性，并使用 `cmp` 保证包内文本与根目录一致。
