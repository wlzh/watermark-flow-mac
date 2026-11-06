# WatermarkFlow v0.4.6 开发记录

## 剪贴板读取（WatermarkCore/ClipboardService.swift）

- `readImage(from:)` 在本地文件 URL 抛出 `unreadableImageFile` 时，回落 `NSImage(pasteboard:)` 读取原生像素数据；无原生数据时保持原错误。`unreadableImageFile` 文案改为“复制的图片文件已失效，请重新复制图片”。
- 多文件（`multipleImageFiles`）不做回落：`NSImage(pasteboard:)` 会自行挑选第一个文件，可能给错误的图片加水印。
- 新增 `clipboardAccessDenied` 错误：macOS 15.4+ 且通用剪贴板 `accessBehavior == .alwaysDeny` 时，替代“没有可读取的图片”的误报。

## 快速生成链路（WatermarkFlowApp/AppDelegate.swift）

- `performQuickApply` 失败时在主窗口弹出 `NSAlert` 警告框说明原因（`isPresentingQuickApplyError` 防叠加），状态区文案加“快速生成失败：”前缀。
- 处理中重复触发时更新状态区提示并记录日志，不再静默返回。
- 新增 `os.Logger`（subsystem `com.wlzh.WatermarkFlow`，category `quickapply`）：开始时记录模板名、changeCount、剪贴板类型与访问策略，结束时记录成功或失败原因，可用“日志”App 事后排查。

## 版本

- 版本升级到 `0.4.6`，构建号升级到 `17`；模板 schema 保持 `4`。

## 测试

- 新增回归测试：文件 URL 与 TIFF 像素共存、文件删除后仍按原生像素读取且尺寸不变；仅剩失效文件 URL 时仍报 `unreadableImageFile`。
- 核心测试 34 项全部通过，既有 HTML、多文件、超大文件测试不受影响。
