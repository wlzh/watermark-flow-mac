# 安装与卸载

## 本机安装

```bash
cd /Users/m/document/QNSZ/project/watermark-flow-mac
./scripts/install-local.sh
```

脚本会执行 Release 构建、生成 `.app` 包、写入版本信息、ad-hoc 签名，然后安装到 `/Applications/WatermarkFlow.app`。

## 从 GitHub Release 安装

1. 从 [Releases](https://github.com/wlzh/watermark-flow-mac/releases) 下载当前版本的 `WatermarkFlow-v0.4.0-macos-universal.zip` 和 `SHA256.txt`。
2. 解压后把 `WatermarkFlow.app` 移到“应用程序”。
3. 当前版本尚未进行 Apple notarization。首次启动如果被 Gatekeeper 拦截，在 Finder 中按住 Control 点击应用并选择“打开”。
4. 高级用户可先用 `shasum -a 256` 对照 `SHA256.txt` 验证下载完整性。

## 启动

```bash
open /Applications/WatermarkFlow.app
```

应用以菜单栏模式运行。关闭编辑窗口不会退出应用，可从菜单栏重新打开。

## 权限

正常剪贴板读写与 Carbon 全局快捷键不需要辅助功能权限。默认快捷键为 `⌥⌘W`，可在编辑器右侧录制其他组合键；注册冲突时应用会保留原快捷键。菜单栏命令始终可用。

默认剪贴板策略为“仅空画布自动载入”：窗口可见时轮询系统剪贴板，空画布直接载入图片，已有图片时只提示替换，不会静默覆盖。可在“快捷操作”切换为关闭或始终自动替换。非图片内容会被忽略，应用自己生成的图片不会被重复载入。

## 卸载

退出应用后删除：

```bash
rm -rf /Applications/WatermarkFlow.app
rm -rf "$HOME/Library/Application Support/com.wlzh.WatermarkFlow"
defaults delete com.wlzh.WatermarkFlow 2>/dev/null || true
```

第二、三条命令会同时删除用户模板、快捷默认模板、剪贴板策略和快捷键设置。

## 分发限制

当前 Release 使用 ad-hoc 签名，提供 Apple Silicon 与 Intel 双架构应用，但不能建立 Apple 的开发者信任链。面向非技术用户进行低摩擦分发前，仍需 Apple Developer ID Application 签名和 notarization。

## 开源许可

源码和安装包均附带 MIT License。安装包内许可文件位于 `WatermarkFlow.app/Contents/Resources/LICENSE.txt`。
