# WatermarkFlow v0.1.2 开发与验收

## 实现

- `AppVersion` 统一维护作者名称、作者主页和产品网站。
- `AboutView` 使用 `Link` 渲染作者和网站。
- `Info.plist` 增加 `AuthorURL`。
- `test-all.sh` 校验安装包中的作者名称、作者主页和产品网站。

## 发布门禁

- Swift 测试全通过。
- Release 构建和自检通过。
- `AuthorURL` 元数据验证通过。
- 本机覆盖安装和进程检查通过。
- Git 提交、`v0.1.2` 标签与远程分支一致。
