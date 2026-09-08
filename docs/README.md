# WatermarkFlow 文档总览

## 当前基线

| 项目 | 当前值 | 权威来源 |
| --- | --- | --- |
| 应用版本 | `0.4.1` | [`VERSION`](../VERSION) |
| 构建号 | `12` | [`BUILD_NUMBER`](../BUILD_NUMBER) |
| 模板 schema | `4` | [`TemplateRepository.swift`](../Sources/WatermarkCore/TemplateRepository.swift) |
| 最低系统 | macOS 13 | [`Info.plist`](../Resources/Info.plist) 与 [`Package.swift`](../Package.swift) |
| 架构 | Universal `arm64` / `x86_64` | [`build-app.sh`](../scripts/build-app.sh) |
| 作者 | `X @wlzh` | [`AppVersion.swift`](../Sources/WatermarkCore/AppVersion.swift) |
| 网站 | `https://869hr.uk` | [`AppVersion.swift`](../Sources/WatermarkCore/AppVersion.swift) |
| 许可 | MIT | [`LICENSE`](../LICENSE) |
| 签名分发 | ad-hoc，未 notarize | [`INSTALL.md`](INSTALL.md) |

构建脚本会把 `VERSION` 和 `BUILD_NUMBER` 写入生成的 App；仓库中的 Info.plist 和 `AppVersion.swift` 也必须与其一致。当前用户使用说明以根目录 [`README.md`](../README.md) 为准。

## 当前版本文档

- [v0.4.1 PRD](prd/v0.4.1/prd.md)
- [v0.4.1 交互设计](prd/v0.4.1/design.md)
- [v0.4.1 开发记录](prd/v0.4.1/dev.md)
- [v0.4.1 实施计划](prd/v0.4.1/plan.md)
- [v0.4.1 测试报告](testing/v0.4.1-test-report.md)
- [v0.4.1 Release Notes](RELEASE_NOTES_v0.4.1.md)
- [安装、卸载和分发限制](INSTALL.md)
- [全部版本 PRD 索引](prd/README.md)
- [Changelog](../CHANGELOG.md)

## 文档规则

每个版本必须包含 `prd.md`、`design.md`、`dev.md`、`plan.md`、测试报告和 Release Notes。PRD 记录需求和验收标准，设计文档记录界面与交互，开发记录说明实现，计划仅记录任务状态，测试报告保存实际验证证据，Release Notes 面向安装用户。

Git 标签、仓库内 Release Notes 和 GitHub Release 是三种不同状态：标签用于固定源码版本；Release Notes 是版本说明文件；只有 GitHub Release 才代表仓库提供可下载资产。截至 2026-09-08，GitHub 保留安装资产的版本为 `v0.2.1`、`v0.3.1`、`v0.3.2`、`v0.4.0` 和 `v0.4.1`，均为公开 prerelease；其他历史版本仅保留 Git 标签和仓库内文档。

## 一致性检查

```bash
./scripts/check-docs.sh
./scripts/test-all.sh
```

`check-docs.sh` 使用 macOS 自带的 zsh、grep、find、Git 和 PlistBuddy，离线校验当前版本和构建号、每个 Changelog 版本的完整文档套件、当前缩放档位、作者与网站元数据，以及所有 Markdown 本地链接。GitHub Release 状态属于在线外部状态，应在发布测试报告中记录实际查询和远端资产校验结果。
