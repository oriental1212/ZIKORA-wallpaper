# 主任务总表与关键路径

## 1. 里程碑总表

| 阶段 | 目标 | 前置 | 主要交付 | 阶段门禁 |
|---|---|---|---|---|
| P00 | 冻结高风险决策与设计资产计划 | 无 | ADR/Spike 结论、范围基线 | Gate 决策有结论 |
| P01 | 建立工程、测试、设计令牌底座 | P00 核心结论 | 测试 target、依赖容器、Fake、资源骨架 | build + 测试反馈环可运行 |
| P02 | 建立可靠领域模型和持久化 | P01 | models、repositories、迁移/一致性测试 | 重启恢复与约束测试通过 |
| P03 | 完成来源、计划、默认源规则 | P02 | CRUD use cases、URL 验证、计划策略 | 领域验收通过，无 UI 依赖 |
| P04 | 完成安全下载与缓存事务 | P02/P03 | downloader、validator、hash、file store、cleanup | fixture/临时目录测试通过 |
| P05 | 完成每日调度、重试与轮播 | P02/P04 | 状态机、重试恢复、rotation actor | 时钟驱动场景测试通过 |
| P06 | 接入 macOS 系统能力 | P04/P05 | 壁纸、Menu Bar、登录项、事件、窗口生命周期 | 真机沙盒场景通过 |
| P07 | 交付应用壳、Onboarding、Dashboard | P01/P03–P06 | 主导航、引导、主状态页 | 新用户主链路可走通 |
| P08 | 交付 Sources 完整 UI | P03/P04 | 列表、Sheet、七天计划、默认源 | 全状态与键盘验收通过 |
| P09 | 交付 Library 与 Settings | P04–P06 | 网格、设置、缓存管理、P1 隔离 | P0 本地管理闭环 |
| P10 | 收敛性能、稳定性和发布 | 全部 | 回归、性能、隐私、发布清单、UI 视觉/菜单栏中文补收 | V1.0 验收全绿或有豁免 |

> 当前阶段状态：P08/P09 已完成；P10 自动化验收、性能与隐私审计已收口（2026-08-20）；P10-09 UI 视觉与菜单栏中文本地化补收已完成代码实现与自动化验证，UI 截图/真机人工验收待发布环境；签名沙盒真机与发布资产待执行，状态与证据见 [P10-quality-release.md](P10-quality-release.md)。

## 2. 关键路径

```text
DEC-001/003/004/005
 → P01 测试与依赖注入
 → P02 DailyFetchRecord + Repository
 → P04 安全下载/原子缓存
 → P05 获取状态机/重试恢复
 → P06 壁纸与生命周期真机接入
 → P07 Onboarding 首次任务
 → P10 发布验收
```

UI 页面不是关键路径起点。P07–P09 可在 P01 后使用 Fake 并行，但合并到主干前必须通过正式 Use Case。

## 3. 建议迭代切片

### Slice A：可验证垂直主链路

固定测试来源 → 安全下载 → Hash/原子保存 → Fake/Desktop wallpaper → 成功记录 → Dashboard 显示。先不做复杂页面，证明系统核心可行。

### Slice B：可靠自动化

七天计划 → 启动/唤醒检查 → 当日幂等 → 30m/2h 重试 → 默认源 → 重启恢复。

### Slice C：完整产品壳

Onboarding → Sources 配置 → Dashboard → Menu Bar → Settings。

### Slice D：本地资产治理

Library → 换一张 → 缩略图 → 清理 → 文件异常恢复。

### Slice E：发布硬化

长列表、磁盘不足、网络恢复、时区变化、多显示器部分失败、减少透明度/动态效果、隐私与资源占用。

## 4. 任务卡最小字段

每个实际 issue/PR 应从阶段文件复制：任务 ID、需求 ID、前置、输入、实现步骤、交付物、自动测试、人工验证、风险、完成条件。缺少任何一项不得标“完成”。

## 5. 每阶段辅佐文件包

| 阶段 | 执行卡 | 主要辅佐文件 |
|---|---|---|
| P00 | [P00-decisions.md](P00-decisions.md) | [资料基线](../00-analysis/source-baseline.md)、[设计审阅](../00-analysis/design-and-prototype-audit.md)、[待决策](../00-analysis/open-decisions.md) |
| P01 | [P01-foundation.md](P01-foundation.md) | [架构蓝图](../01-architecture/architecture-blueprint.md)、[DoD](../03-support/definition-of-done.md) |
| P02 | [P02-domain-persistence.md](P02-domain-persistence.md) | [数据与状态机](../01-architecture/data-and-state-machines.md)、[测试矩阵](../03-support/test-matrix.md) |
| P03 | [P03-sources-plan.md](P03-sources-plan.md) | [追踪矩阵](../03-support/requirements-traceability.md)、[数据与状态机](../01-architecture/data-and-state-machines.md) |
| P04 | [P04-download-cache.md](P04-download-cache.md) | [测试矩阵](../03-support/test-matrix.md)、[安全/一致性状态机](../01-architecture/data-and-state-machines.md) |
| P05 | [P05-scheduling-rotation.md](P05-scheduling-rotation.md) | [获取/轮播状态机](../01-architecture/data-and-state-machines.md)、[测试矩阵](../03-support/test-matrix.md) |
| P06 | [P06-system-integration.md](P06-system-integration.md) | [架构蓝图](../01-architecture/architecture-blueprint.md)、[发布人工清单](../03-support/release-checklist.md) |
| P07 | [P07-shell-onboarding-dashboard.md](P07-shell-onboarding-dashboard.md) | [设计验收](../03-support/design-acceptance.md)、[原型审阅](../00-analysis/design-and-prototype-audit.md) |
| P08 | [P08-sources-ui.md](P08-sources-ui.md) | [设计验收](../03-support/design-acceptance.md)、[追踪矩阵](../03-support/requirements-traceability.md) |
| P09 | [P09-library-settings.md](P09-library-settings.md) | [设计验收](../03-support/design-acceptance.md)、[测试矩阵](../03-support/test-matrix.md) |
| P10 | [P10-quality-release.md](P10-quality-release.md) | [DoD](../03-support/definition-of-done.md)、[发布清单](../03-support/release-checklist.md)、[追踪矩阵](../03-support/requirements-traceability.md)、[P10-09 UI 视觉对齐与菜单栏本地化](../03-support/p10-ui-visual-alignment.md) |

执行某一阶段时，必须同时更新其执行卡和辅佐文件中的状态/证据；辅佐文件不是只读附件。

## 6. 估算方式

本计划不虚构人天。执行团队可用 S/M/L 或 story point 估算，但需把 Spike、生产实现、测试和设计资产分别估算。系统 API 真机验证、数据迁移和异常测试不能隐藏在 UI 任务里。
