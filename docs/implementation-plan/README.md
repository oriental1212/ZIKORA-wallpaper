# ZIKORA-wallpaper V1.0 实施任务清单

> 状态：P00–P09 已完成；P10 自动化验收与安全/性能审计收口（2026-08-20）；P10-09 UI 视觉与菜单栏中文本地化补收已完成代码实现与自动化验证，UI 截图/真机人工验收待发布环境；签名沙盒真机、archive/sign/notarization 与 AppIcon 母版待发布环境执行  
> 范围：MVP V1.0 规划与逐阶段实现  
> 依据：需求规格说明书、`prototype/` 原型与根目录 `DESIGN.md`

## 1. 如何使用本目录

本目录不是按页面罗列的愿望清单，而是可按依赖顺序执行的工程计划。每个任务都应具备：需求 ID、输入、实施步骤、交付物、测试点、完成条件和辅佐文件。

推荐执行顺序：

```text
P00 决策冻结
  → P01 工程与质量底座
  → P02 领域模型与持久化
  → P03 壁纸源与计划领域
  → P04 下载、校验与缓存
  → P05 调度、重试与切换
  → P06 macOS 生命周期与系统集成
  → P07 应用壳、引导与 Dashboard
  → P08 Sources 页面
  → P09 Library 与 Settings
  → P10 稳定性、可访问性与发布验收
```

阶段可以在其前置契约稳定后并行，但不得绕过阶段门禁。例如：UI 可以使用 Fake Repository 提前开发，但不能自行定义与领域契约冲突的数据结构。

## 2. 目录导航

### 分析基线

- [资料优先级、仓库现状与范围](00-analysis/source-baseline.md)
- [原型与设计审阅](00-analysis/design-and-prototype-audit.md)
- [待决策问题与默认建议](00-analysis/open-decisions.md)

### 架构辅佐

- [建议架构、模块边界与目录结构](01-architecture/architecture-blueprint.md)
- [数据模型与状态机](01-architecture/data-and-state-machines.md)

### 实施任务

- [主任务总表与关键路径](02-backlog/master-task-list.md)
- [P00 决策冻结](02-backlog/P00-decisions.md)
- [P01 工程与质量底座](02-backlog/P01-foundation.md)
- [P02 领域模型与持久化](02-backlog/P02-domain-persistence.md)
- [P03 壁纸源与每周计划](02-backlog/P03-sources-plan.md)
- [P04 下载、校验与缓存](02-backlog/P04-download-cache.md)
- [P05 调度、重试与展示模式](02-backlog/P05-scheduling-rotation.md)
- [P06 macOS 生命周期与系统集成](02-backlog/P06-system-integration.md)
- [P07 应用壳、首次引导与 Dashboard](02-backlog/P07-shell-onboarding-dashboard.md)
- [P08 Sources UI](02-backlog/P08-sources-ui.md)
- [P09 Library 与 Settings](02-backlog/P09-library-settings.md)
- [P10 质量与发布](02-backlog/P10-quality-release.md)

### 横向辅佐文件

- [需求追踪矩阵](03-support/requirements-traceability.md)
- [测试矩阵](03-support/test-matrix.md)
- [视觉、交互与状态验收](03-support/design-acceptance.md)
- [P10-09 UI 视觉对齐与菜单栏本地化](03-support/p10-ui-visual-alignment.md)
- [Definition of Done](03-support/definition-of-done.md)
- [发布与人工验收清单](03-support/release-checklist.md)
- [P01 验收记录](03-support/p01-acceptance.md)

## 3. 优先级和标记

| 标记 | 含义 |
|---|---|
| P0 | MVP 发布不可缺少；失败会破坏主链路、安全或后台可靠性 |
| P1 | 规格中明确的增强项；允许在 P0 稳定后实现 |
| Gate | 未完成前不得开始依赖阶段 |
| Spike | 有平台/API 风险，先做最小验证，不直接扩展为生产实现 |
| Manual | 无法完全自动化，必须保留人工复验记录 |

## 4. 全局完成原则

每个任务关闭前必须满足：

1. 相关需求 ID 已映射到代码、测试或明确的设计资产；
2. 错误、空态、加载、禁用、离线和恢复路径已覆盖；
3. 异步工作不阻塞主线程，任务可取消且不会并发重复执行；
4. 不扩大沙盒、签名、登录项或文件权限，除非 P00 已书面确认；
5. 先执行最窄测试，再执行主 scheme build，并审阅最终 diff；
6. 不以原型中的静态假数据替代业务规则；
7. 不把 P1 功能混入 P0 关键路径导致主链路延期。

## 5. 当前结论摘要

- P01 工程底座已经完成：AppEnvironment、协议/测试替身、错误与日志、原生设计系统、本地化和 fixture 均已落地。
- 需求规格说明书已经完成 PRD/原型冲突的大部分裁决，应作为功能真相源。
- 根 `DESIGN.md` 与 Vivid Lumina 原型存在视觉冲突，详见设计审阅；在正式 UI 开发前必须冻结最终设计令牌。
- Dashboard 的 `screen.png` 是文本占位而非有效 PNG，需重新导出；现阶段以 `code.html` 作为结构参考。
- Swift Testing target 与 `scripts/check` 反馈环已建立；P01 验收为 18 项测试和 Release 构建通过。
- 用户验收发现菜单栏中文显示与 Vivid Lumina 视觉仍需补收，已拆为 P10-09；代码实现与自动化验证已完成，证据见 [p10-ui-visual-alignment.md](03-support/p10-ui-visual-alignment.md)。
- App Sandbox 已启用，但网络客户端 entitlement 尚未在工程中显式确认；不得为“先跑起来”随意放宽沙盒。
