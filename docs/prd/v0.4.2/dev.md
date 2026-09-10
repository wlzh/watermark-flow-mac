# WatermarkFlow v0.4.2 开发记录

## 实现

- `scripts/generate-icon.swift` 使用 Core Graphics 按比例绘制背景、图片卡片、山景、光点、水印带和 W，并输出标准 10 文件 iconset。
- `BrandIcon.statusBarImage()` 使用 AppKit 矢量路径生成 18×18 point 单色图，设置 `isTemplate=true` 和无障碍描述。
- `AppDelegate` 使用品牌菜单栏图标，并将快速生成成功反馈从旧印章改为通用勾选。
- `AboutView` 直接读取 `NSApp.applicationIconImage`，避免图标实现漂移。
- 版本升级为 `0.4.2 (13)`；模板 schema 保持 4，无数据迁移。

## 测试策略

- 编译使用 warnings-as-errors。
- 应用自检验证菜单栏图标尺寸、模板属性、位图可生成性和无障碍描述。
- 构建门禁验证 `AppIcon.icns`、版本、构建号、Universal 架构、签名和 MIT License。
- 实际检查 1024px、32px App 图标，以及深色菜单栏和 About 窗口显示。
- 安装前后比较真实用户模板文件，保证升级不改写设置。
