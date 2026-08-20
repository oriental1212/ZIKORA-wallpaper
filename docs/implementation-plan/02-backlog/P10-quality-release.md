# P10 — 稳定性、性能、可访问性与发布

## P10-01 需求回归与追踪收口

- 步骤：逐项更新追踪矩阵为 implemented/tested/manual/deferred；每个 P0 requirement 有证据；P1 明确版本；缺陷链接到需求。
- 验收：无“页面看起来有了”但后台规则未验收的条目。
- 辅佐：[requirements-traceability.md](../03-support/requirements-traceability.md)。

> 状态：完成（2026-08-20）。`requirements-traceability.md` 已按 implemented/tested/manual-pass/deferred 收口；生产获取链路、共享命令、去重、重试、默认源、文件事务和隐私安全均补充了自动化证据。签名沙盒与真机人工项如实标记为 deferred/manual，不虚报通过。

## P10-02 性能与资源基线

- 需求：NFR-PERF。
- 场景：空闲 10 分钟 CPU；30–60/80MB 内存目标；1,000 张 Library；50MB 拒绝；Hash/解码/扫描主线程；长期 Menu Bar；缩略图滚动。
- 交付：设备/系统/构建配置/测量工具/结果；超标原因和处理。
- 验收：无高频 timer/目录扫描/图标动画；不能只凭感觉宣称轻量。

> 状态：完成（2026-08-20），含一项已记录的超标。Release 构建实际启动后采样 5/15/25 秒：CPU 均为 0.0%，RSS 93–104 MB。无高频 timer、目录扫描或图标动画；1,000 条缩略图测试通过。RSS 超过 80 MB 目标，原因与复测步骤记录在 [p10-performance-baseline.md](../03-support/p10-performance-baseline.md)。

## P10-03 稳定性故障注入

- 场景：离线、超时、损坏图、HTTP 错、磁盘不足、只读目录、删除失败、数据库打开失败、应用在下载/写入/设置壁纸时退出、事件风暴。
- 验收：current 保持、无半文件、重启恢复、无崩溃/忙重试。
- 辅佐：[test-matrix.md](../03-support/test-matrix.md)。

> 状态：完成（2026-08-20）。新增 `WallpaperFetchWorkflowUseCaseTests` 5 项，覆盖成功链路、离线重试、手动失败不污染自动计数、第三次失败默认源兜底一次、内容去重复用；`DailyFetchCoordinatorTests` 覆盖事件风暴合并，`SetCurrentWallpaperUseCaseTests` 覆盖全失败/部分失败 current 保护，`AtomicWallpaperFileStoreTests`/`PersistenceRecoveryTests` 覆盖原子写入、路径逃逸与数据库恢复。

## P10-04 时间与生命周期真机矩阵

- 场景：启动、登录启动、关闭窗口、退出、睡眠同日/跨日、时区变更、时间回拨、网络恢复、轮播睡眠多个间隔、多显示器部分失败。
- 交付：每场景日期、构建、结果、日志摘要（不含敏感 URL）。

> 状态：自动化部分完成（2026-08-20）。生产获取工作流、`PersistentRetryScheduler`、系统事件流、共享 `WallpaperCommandCenter`、Dashboard/Menu Bar 接线均已落地并有 177 项测试。登录启动、关闭仅隐藏、睡眠/时区/多屏真机矩阵仍需在签名沙盒构建上执行，状态为 deferred/manual。

## P10-05 可访问性

- 需求：NFR-A11Y。
- 步骤：VoiceOver；Full Keyboard Access；Tab/Space/Enter；focus ring；高对比；Increase Contrast；Reduce Transparency/Motion；图标 label/help；动态状态 announcement；缩放/窄窗口。
- 验收：状态不只靠颜色；图片浮层对比可读；动画偏好生效。

> 状态：代码与自动化验收完成（2026-08-20）。图标按钮带 label/help，`DesignSurface` 实现 Reduce Transparency 降级，`DesignMotion` 实现 Reduce Motion，`StatusBadge` 同时使用 SF Symbol 与文字；`DesignSystemTests` 覆盖状态不只靠颜色和 Reduce Motion。VoiceOver/Full Keyboard Access/Increase Contrast 真机检查需人工执行，未虚报为通过。

## P10-06 隐私与安全审阅

- 步骤：检查 entitlement 最小化；日志/错误 URL query 脱敏；所有删除路径 containment；无账号/分析上传；隐私说明准确；测试/代码无密钥。
- 交付：entitlement diff、数据流说明、隐私清单。

> 状态：完成（2026-08-20）。移除了未使用的 `ENABLE_USER_SELECTED_FILES=readonly` 与 `REGISTER_APP_GROUPS=YES`，保留 App Sandbox 与网络出站客户端；日志 URL query 已脱敏，删除路径 containment 有测试覆盖，仓库无生产密钥。完整审阅见 [privacy-and-security-audit.md](../03-support/privacy-and-security-audit.md)。

## P10-07 视觉与文案验收

- 步骤：四主页面、Onboarding、Menu Bar、Sheet、Dialog、Detail；全部状态；800/1000/1280；中文术语；无空按钮；生产无假图片/假指标。
- 辅佐：[design-acceptance.md](../03-support/design-acceptance.md)。

> 状态：完成（2026-08-20）。Dashboard 已替换占位逻辑为真实当前壁纸与共享命令；Menu Bar Update/Next 不再为空动作；Onboarding/Settings/Sources/Library 的英文残留已改为中英 String Catalog 键并补齐简体中文。AppIcon/Logo 母版仍为已知缺失资产（DEC-011），未用截图冒充最终图标；800/1000/1280 视觉截图人工项待发布环境执行。
>
> 补充（2026-08-20）：用户复核后发现菜单栏中文显示和 Vivid Lumina 视觉仍需补收，转入 P10-09。

## P10-08 构建、测试与发布候选

- 步骤：Debug build、unit tests、Release build、必要 UI smoke、archive/sign/notarization（由有权限环境执行）；`git diff --check`；检查 bundle/signing 未被无意更改。
- 验收：命令和真实结果记录；环境未执行项明确列出，不虚报通过。
- 辅佐：[release-checklist.md](../03-support/release-checklist.md)、[definition-of-done.md](../03-support/definition-of-done.md)。

> 状态：自动化发布候选完成（2026-08-20）。`./scripts/check`（Debug 177 项 / 46 套件 + Release 构建）通过；`git diff --check`：通过。archive/sign/notarization 与 UI smoke 需要签名发布环境，未执行并已明确记录。

## P10-09 UI 视觉对齐与菜单栏中文本地化补收

- 需求：`REQ-MENU-001～007`、`REQ-DASH-001～008`、`REQ-SRC-001～011`、`REQ-LIB-001～007`、`REQ-SET-001～006`、`NFR-A11Y-002/004/005`。
- 前置：P10-07 已完成，但用户复核发现视觉和菜单栏本地化仍不达标。
- 输入：`prototype/` 中 Vivid Lumina 设计令牌与四套页面结构、当前 SwiftUI 实现。
- 步骤：见 [p10-ui-visual-alignment.md](../03-support/p10-ui-visual-alignment.md)。
- 交付：设计 token/材质更新、App Shell 与四个主页面视觉对齐、菜单栏中文修复、构建和测试结果。
- 自动测试：优先运行现有测试；视觉和本地化以人工/截图验收为主。
- 人工验证：中文系统下菜单栏、800/1000/1280 页面、Reduce Transparency/Motion、高对比。
- 风险：玻璃材质过度使用可能损害可读性或性能；深色模式需额外确认。
- 完成条件：T1～T8 全部完成，`design-acceptance.md` 与 `release-checklist.md` 新增项关闭，状态和命令真实记录。

> 状态：完成（2026-08-20）。代码实现与自动化验证已完成，UI 截图和真机人工验收仍需发布环境。详细任务和证据见 [p10-ui-visual-alignment.md](../03-support/p10-ui-visual-alignment.md)。

## 阶段退出条件

所有 P0 验收有自动或人工证据；已知限制和 P1 延期透明；权限、签名、迁移、隐私和性能有发布说明。

> 状态：收口中（2026-08-20）。P0 自动化证据与审计已完成；P10-09 代码实现与自动化验证已完成，UI 截图/真机人工验收仍待发布环境；签名沙盒真机矩阵、archive/sign/notarization 和 AppIcon 母版仍为发布环境待办，均已透明记录。性能实测 CPU 0.0%，内存 93–104 MB 已记录超标原因与复测要求。
