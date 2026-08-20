# P08 — Sources 完整 UI

## P08-01 来源列表与卡片状态

- 需求：REQ-SRC-001～006。
- 步骤：显示全部来源；名称、脱敏截断 URL、开关、同步时间/状态、编辑；复制完整 URL 时明确反馈；状态含 never/loading/success/offline/failed/warning/disabled。
- 验收：状态有文字/图标，不只颜色；停用卡不消失；运行中共享命令状态一致。

> 状态：完成（2026-08-20）。`SourcesView` 与 `SourceCardView` 展示全部来源、七种健康状态、安全 URL、复制反馈、启停与编辑；`SourcesViewModelTests` 覆盖停用仍显示且从计划选项移除。

## P08-02 Add/Edit Source Sheet

- 需求：REQ-SRC-007～011。
- 步骤：字段与 inline validation；测试连接；成功预览/尺寸/格式/大小；取消不保存；重复 URL 确认；编辑 URL 强制重测；保存后定位卡片。
- 交互态：default/focus/active/disabled/loading/error/success；hover 仅桌面辅助，不承担信息。
- 测试：ViewModel + use case；测试请求竞态和取消。

> 状态：完成（2026-08-20）。`SourceFormSheet` 与 `SourceFormViewModel` 接入 inline validation、连接测试与预览元数据、重复 URL 确认、编辑 URL 强制重测、取消不保存、保存后定位；`SourceFormViewModelTests` 覆盖 happy path、重复 URL、编辑重测和连接测试竞态取消。

## P08-03 删除来源确认

- 步骤：显示来源名称、受影响星期、是否 default；确认后删除；历史壁纸保留；失败保持 UI/数据一致。
- 验收：无空确认文案；不可逆动作必须明确；删除后计划显示未设置。

> 状态：完成（2026-08-20）。删除确认展示来源、受影响星期与 default；`SourcesViewModelTests` 覆盖删除清计划/default；历史壁纸保留由既有 `ManageSourcesUseCasesTests` 覆盖。

## P08-04 七天 Weekly Plan

- 需求：REQ-PLAN-001～007。
- 步骤：完整 Monday–Sunday 的中文映射；每行启用来源 + 未设置；今天标记；即时保存、失败回滚；停用引用警告；窄窗口保持可读。
- 验收：不得只实现原型五天；选择器键盘可用。

> 状态：完成（2026-08-20）。`WeeklyPlanSection` 实现 Monday–Sunday 中文映射、今天标记、启用来源 + 未设置选择、即时保存/回滚与停用/缺失警告；`SourcesViewModelTests` 覆盖即时保存，`WeeklyPlanUseCaseTests` 覆盖回滚与引用状态。

## P08-05 Default Source

- 需求：REQ-DEF-001～005。
- 步骤：只列启用来源 + 未设置；解释三种兜底；停用/删除警告；保存失败回滚；不在 UI 造多级来源链。

> 状态：完成（2026-08-20）。`DefaultSourceSection` 仅列启用来源 + 未设置，展示三类兜底说明与停用/删除警告；`SourcesViewModelTests` 覆盖默认来源更新与显示状态。

## P08-06 页面级工具栏与状态

- 步骤：“添加壁纸源”为上下文主操作；刷新/更多不得是空按钮；刷新含义要明确（本地状态刷新或立即更新，按规格统一）；侧栏立即更新共享状态。
- 辅佐：[design-and-prototype-audit.md](../00-analysis/design-and-prototype-audit.md)、[design-acceptance.md](../03-support/design-acceptance.md)。

> 状态：完成（2026-08-20）。工具栏主操作、刷新、更多均已接入实际行为；AppShell 不再叠加冗余标题工具栏；刷新明确为本地状态重载。

## 阶段退出条件

来源 CRUD、七天计划、default、连接测试和全部健康状态在 UI 闭环；删除/停用不会制造悬空崩溃。

> 状态：完成（2026-08-20）。来源 CRUD、七天计划、default、连接测试和全部健康状态已在 UI 闭环；删除/停用通过既有 Use Case 清引用，无悬空崩溃。Debug 构建通过，聚焦测试 9 项通过。
