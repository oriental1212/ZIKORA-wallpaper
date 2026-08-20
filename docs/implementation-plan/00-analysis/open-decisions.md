# 开工前待决策清单

> 规则：Gate 项未关闭前，不得固化相关生产实现。可用协议、Fake 或 Spike 前进，但不得把临时假设埋入持久化 schema 或 entitlement。

| ID | 级别 | 问题 | 默认建议 | 影响 |
|---|---|---|---|---|
| DEC-001 | Gate | 最低 macOS 版本是否确为 26.5 | 核对目标用户与分发环境后设置；当前数值会极度限制兼容范围 | API 可用性、测试矩阵、发布 |
| DEC-002 | Gate | 设计系统以根 DESIGN 还是 Vivid Lumina 为主 | 采用本计划的混合裁决：原生骨架 + Vivid 色彩/材质 + Apple 克制原则 | 所有 UI |
| DEC-003 | Gate | 持久化方案 | 若最低系统允许，优先 SwiftData；用 Repository 隔离以便测试与迁移 | P02 及以后 |
| DEC-004 | Gate | 沙盒下远程 URL 网络权限 | 只添加必要的 outgoing client entitlement，并做真机沙盒 Spike | P04 |
| DEC-005 | Gate | 桌面壁纸 API 在目标系统/沙盒/多 Space 下的行为 | 使用 AppKit 最小 Spike 验证所有 `NSScreen`、部分失败和重启恢复 | P06 |
| DEC-006 | Gate | Menu Bar 使用 `MenuBarExtra` 还是 AppKit status item | 首选 SwiftUI `MenuBarExtra`；若状态/窗口控制受限再桥接 AppKit | P06/P07 |
| DEC-007 | Gate | “退出”时未完成下载/原子写入的处理 | 取消网络任务、等待短时安全点、保留可恢复任务记录，不阻塞无限期 | P04/P06 |
| DEC-008 | Gate | Library 图片名称来源 | V1.0 默认显示来源快照 + 日期；不从 URL 或图像内容虚构标题 | P09 |
| DEC-009 | Gate | 直接图片 URL 是否允许认证 query | 允许请求但 UI/日志必须脱敏；不保存额外凭据 | P03/P04 |
| DEC-010 | Gate | HEIC/WebP 在目标系统的解码与落盘策略 | 保留原格式，ImageIO 实测；不可解码则明确失败 | P04 |
| DEC-011 | Design | Logo/AppIcon 源资产 | 补矢量或高分辨率母版及完整 AppIcon 资产，不直接把截图当最终图标 | P01/P10 |
| DEC-012 | Design | 缺失页面是否补高保真稿 | 高风险流（Onboarding、Source Sheet、Menu Bar、确认框）先补；其余采用系统组件规范 | P07–P09 |
| DEC-013 | Product | P1 是否进入首次发布 | 默认 P0 先发布，P1 使用独立 feature gate/里程碑 | P09/P10 |
| DEC-014 | Product | 诊断日志保留周期/容量 | 默认滚动文件或统一日志，不记录完整 query；具体容量发布前确认 | P10 |
| DEC-015 | Product | 手动立即更新是否允许默认源失败后再次点按 | 允许；每次只一个任务，并通过 UI 防抖/互斥，不污染自动次数 | P05/P07 |
| DEC-016 | QA | 如何模拟跨日、时区、睡眠和网络恢复 | 注入 Clock/Calendar/EventSource，自动测状态机；真机做最终系统事件验收 | P01/P05/P10 |

## 2026-08-18 实施进展

| ID | 当前状态 | 证据/下一步 |
|---|---|---|
| DEC-001 | 已接受 macOS 14 | [ADR-0001](decisions/ADR-0001-platform-baseline.md)：Debug/Release 已统一为 14.0 |
| DEC-002 | 已接受为实施基线 | [ADR-0003](decisions/ADR-0003-native-design-system.md) |
| DEC-003 | 已接受 | [ADR-0002](decisions/ADR-0002-persistence.md)：使用 SwiftData + Repository；P00 Spike 已通过 |
| DEC-004 | 已接受最小权限 | [ADR-0004](decisions/ADR-0004-network-and-image-validation.md)：仅 outgoing client；生产管线签名验证归 P04 |
| DEC-005 | 已接受 API 基线 | [ADR-0005](decisions/ADR-0005-system-integration.md)：系统状态变更型人工验证归 P06 |
| DEC-006 | 接受 `MenuBarExtra` 优先 | 编译验证通过；生产阶段保留 AppKit 回退边界 |
| DEC-007 | 接受有界取消与持久化恢复 | 生产实现和故障注入在 P04/P06 验证 |
| DEC-008 | 接受“来源快照 + 日期” | 不从 URL 或图片内容虚构名称 |
| DEC-009 | 建议接受 query + 脱敏 | 待生产 URL 测试覆盖 |
| DEC-010 | 部分验证 | SDK 支持四类读取；真实 HEIC/WebP 损坏 fixture 尚待补齐 |

决策记录索引见 [decisions/README.md](decisions/README.md)。

## 决策记录模板

关闭一项时追加以下记录，不删除原问题：

```text
Decision: DEC-xxx
Date:
Owner:
Status: accepted / rejected / superseded
Choice:
Reason:
Alternatives considered:
Affected tasks/files:
Migration or rollback:
```
