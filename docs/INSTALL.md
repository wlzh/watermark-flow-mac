# 安装与卸载

## 本机安装

```bash
cd /Users/m/document/QNSZ/project/watermark-flow-mac
./scripts/install-local.sh
```

脚本会执行 Release 构建、生成 `.app` 包、写入版本信息、ad-hoc 签名，然后安装到 `/Applications/WatermarkFlow.app`。

## 启动

```bash
open /Applications/WatermarkFlow.app
```

应用以菜单栏模式运行。关闭编辑窗口不会退出应用，可从菜单栏重新打开。

## 权限

正常剪贴板读写与 Carbon 全局快捷键不需要辅助功能权限。若其他软件占用了 `⌥⌘W`，可使用菜单栏命令，不影响水印编辑功能。

## 卸载

退出应用后删除：

```bash
rm -rf /Applications/WatermarkFlow.app
rm -rf "$HOME/Library/Application Support/com.wlzh.WatermarkFlow"
defaults delete com.wlzh.WatermarkFlow 2>/dev/null || true
```

第二、三条命令会同时删除用户模板和默认模板选择。

## 分发限制

`v0.1.0` 使用 ad-hoc 签名，仅用于当前 Mac 本地安装测试。面向其他 Mac 分发时，应补充 Apple Developer ID Application 签名和 notarization。
