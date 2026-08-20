# P00 — 决策冻结与风险 Spike

## 阶段目标

把会改变 schema、API 可用性、权限和视觉系统的假设在编码前变成可验证结论。

## P00-01 冻结平台与发布范围（Gate）

> 状态：完成。最低版本确认为 macOS 14，Debug/Release 已统一。

- 需求：NFR 全域、DEC-001。
- 步骤：确认目标用户系统分布；核对 26.5 是否误设；列出候选最低版本下 SwiftData、MenuBarExtra、ServiceManagement API 可用性；决定 availability 策略。
- 交付：更新 [open-decisions.md](../00-analysis/open-decisions.md) 的 DEC-001；形成最低系统测试矩阵。
- 验收：Debug/Release 一致；未为兼容性随意改变 bundle ID 或 signing。
- 辅佐：[source-baseline.md](../00-analysis/source-baseline.md)、[test-matrix.md](../03-support/test-matrix.md)。

## P00-02 冻结持久化与迁移策略（Gate）

> 状态：完成。采用 SwiftData + Repository；save/reopen Spike 已通过。

- 需求：18、NFR-STAB-001。
- 步骤：用全部实体和约束验证 SwiftData 可表达性；确认唯一 Hash、可空来源、current 唯一性如何事务化；设计 schema version、首次建库和损坏恢复；确定 Repository 边界。
- 交付：ADR + 小型 schema Spike（若进入代码阶段）；迁移测试方案。
- 验收：不依赖 View/全局 context；DailyFetchRecord 可重启恢复。
- 辅佐：[architecture-blueprint.md](../01-architecture/architecture-blueprint.md)、[data-and-state-machines.md](../01-architecture/data-and-state-machines.md)。

## P00-03 冻结视觉系统与缺失资产计划（Gate）

> 状态：已形成并接受原生 macOS + 克制 Vivid Lumina 基线；缺失资产保留任务。

- 需求：20、24、NFR-A11Y。
- 步骤：确认混合设计裁决；输出 SwiftUI 语义 token 表；确认系统字体；指定减少透明度/动态效果降级；给缺失 10 类设计资产安排 owner；重新导出 Dashboard PNG；补 logo/AppIcon 母版。
- 交付：设计决定记录、token 表、页面状态包计划、资产清单。
- 验收：禁止根 DESIGN 和 Vivid Lumina 同时被开发者各取一套；所有交互色有动态/高对比方案。
- 辅佐：[design-and-prototype-audit.md](../00-analysis/design-and-prototype-audit.md)、[design-acceptance.md](../03-support/design-acceptance.md)。

## P00-04 网络与图片格式 Spike（Gate）

> 状态：基线完成。仅 outgoing client 已获批准并落地；HEIC/WebP 和完整生产管线 fixture 归 P04。

- 需求：10.2.4、12.4、NFR-NET/SEC。
- 步骤：在沙盒下验证 outgoing network；用重定向、无 Content-Length、错误 MIME、伪图片、超 50MB、JPG/PNG/HEIC/WebP fixture 验证 URLSession + ImageIO；确认流式中止方案。
- 交付：兼容表、错误分类、必要 entitlement 提案（不直接扩大权限）。
- 验收：上限在下载过程中生效；不执行 HTML/JS/JSON；日志不泄露 query。
- 辅佐：[test-matrix.md](../03-support/test-matrix.md)、P04。

## P00-05 macOS 系统 API Spike（Gate）

> 状态：基线完成。API 编译与只读探测通过；状态变更型签名/人工验证经确认归 P06。

- 需求：11、16、REQ-GLOBAL-001～003。
- 步骤：验证所有屏幕设置、部分失败、Space 行为；验证关闭窗口隐藏和重新激活；验证登录项成功/拒绝；验证 Menu Bar 命令与打开 Settings；验证睡眠/唤醒/时区通知来源。
- 交付：API 选择 ADR、人工复现步骤、已知限制。
- 验收：在开启 App Sandbox 的签名构建验证；不通过关闭沙盒掩盖问题。
- 辅佐：[release-checklist.md](../03-support/release-checklist.md)、P06。

## 阶段退出条件

- DEC-001～008 至少有明确 accepted 或带 owner/期限的风险接受；
- 权限和签名变更单独列出并获确认；
- 视觉 token 与缺失资产策略可供 P01/P07 使用；
- 所有 Spike 均有可复现输入和结论，不把实验代码直接当生产实现。

## 阶段结果（2026-08-18）

P00 已关闭。DEC-001～008 均有已接受基线或明确后续验证阶段；最低 macOS 14 和仅出站客户端权限已获用户确认。系统壁纸与登录项的状态变更型验证不在 P00 执行，保留为 P06 人工验收。
