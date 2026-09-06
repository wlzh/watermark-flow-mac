# WatermarkFlow

WatermarkFlow 是一个轻量的原生 macOS 菜单栏水印工具。复制图片后，可以直接套用默认模板，也可以在非破坏式编辑会话中调整水印，再把合成结果复制回系统剪贴板。

- 作者：[X @wlzh](https://x.com/wlzh)
- 网站：[https://869hr.uk](https://869hr.uk)
- 开源许可：[MIT License](LICENSE)

## 当前功能

- 从剪贴板、拖放或文件导入图片
- 文字、X、YouTube 和自定义 Logo 水印
- 自由拖动位置，调整颜色、透明度、大小和旋转角度
- 三个内置模板：`X · @wlzh`、`X · @gxjdian`、`YouTube · 短裤AI分享`
- 保存自定义模板并设置默认模板
- 菜单栏可从全部模板中任选一个快速生成并复制
- 一键生成并复制 PNG，或导出 PNG/JPEG 文件
- 可录制并保存全局快捷键；默认 `⌥⌘W`，用于处理剪贴板图片
- 当前图片的水印可单独移除并恢复；切换模板会直接替换当前水印，不会叠加
- 大图画布支持 `− / 百分比 / +` 缩放和滚动查看，范围为 25% 至 1000%，`⌘0` 恢复适合窗口
- 画布右键或底部按钮可清空当前图片，模板和色值不会被删除
- 当前会话内保留原图和水印参数，输出为扁平图片
- 所有模板参数和最后选中的模板自动保存，重启或处理下一张图片时继续沿用
- 自动适配 macOS 深色/浅色模式；大图使用轻量预览，输出保持原始像素

## 系统要求

- macOS 13 或更高版本
- Apple Silicon 或 Intel Mac
- 从源码构建需要 Swift 5.10 或更高版本

## 构建、测试和安装

```bash
./scripts/test-all.sh
./scripts/install-local.sh
```

默认安装到 `/Applications/WatermarkFlow.app`。本机没有 Developer ID 时，构建脚本使用 ad-hoc 签名。

普通用户可从 [GitHub Releases](https://github.com/wlzh/watermark-flow-mac/releases) 下载 Universal macOS 压缩包。当前包尚未使用 Developer ID 签名和 Apple notarization，首次启动需按[安装文档](docs/INSTALL.md)操作。

本项目提供零第三方依赖的 Swift 自动化测试可执行文件，适配只有 Apple Command Line Tools、未安装完整 Xcode 的构建环境。

## 使用

1. 启动 WatermarkFlow，菜单栏出现水滴印章图标。
2. 复制一张图片，在编辑器中点击“从剪贴板载入”，或直接拖入图片。
3. 选择模板并调整参数；在预览图上拖动即可改变位置。
4. 需要检查大图细节时，使用画布右上角 `− / 百分比 / +` 缩放，放大后滚动查看其他区域。
5. 如果选错，可点击“移除水印”，再添加所选水印或切换模板直接替换。
6. 点击“生成并复制”，回到聊天或发布应用粘贴。
7. 高频操作可直接使用已设置的快捷键；也可从菜单栏子菜单选择任意模板快速处理。
8. 需要更换快捷键时，在右侧“快捷操作”点击录制框并按下新组合键。

详细说明见 [安装文档](docs/INSTALL.md)、[v0.2.3 PRD](docs/prd/v0.2.3/prd.md) 和 [v0.2.3 测试报告](docs/testing/v0.2.3-test-report.md)。

## 开源许可

WatermarkFlow 使用 [MIT License](LICENSE)。Copyright (c) 2026 wlzh。
