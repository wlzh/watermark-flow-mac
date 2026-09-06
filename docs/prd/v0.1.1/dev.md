# WatermarkFlow v0.1.1 技术开发文档

## 存储结构

`templates.json` 从顶层数组升级为对象：

```json
{
  "schemaVersion": 1,
  "templates": [],
  "lastSelectedTemplateID": "UUID"
}
```

`templates` 保存内置模板覆盖值和用户模板。载入时以稳定 UUID 合并代码中的内置模板：已有覆盖优先，缺失模板使用出厂默认值，未知 UUID 作为用户模板保留。

## 迁移

读取顺序为新版 `TemplateLibraryState`、旧版 `[WatermarkTemplate]`、错误上抛。旧版数组中的用户模板原样合并；旧版意外包含的内置 UUID 作为覆盖值恢复。下一次保存自动写成新版结构。

## 自动保存

`EditorViewModel.workingTemplate` 变化后刷新预览并启动 250 ms debounce Task。任务执行时把当前编辑值写回 `templates`，连同最后选择 ID 原子写入 JSON。切换模板、设置快捷默认模板、删除模板和应用退出时取消 debounce 并同步保存。

## 数据一致性

- 保存前统一执行参数 clamp。
- 内置 UUID 的 `isBuiltIn` 始终强制为 `true`。
- 用户模板的 `isBuiltIn` 强制为 `false`。
- 重复 UUID 只保留第一次有效记录。
- 最后选择 ID 不存在时回退到 `X · @wlzh`。
