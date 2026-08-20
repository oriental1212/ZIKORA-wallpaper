# P05 — 每日调度、重试与展示模式

## P05-01 全局获取 Orchestrator

> 状态：完成（2026-08-19）。已实现 `FetchOrchestrator` actor 与可注入 `WallpaperFetchWorkflow`：所有获取入口共享 in-flight 任务，失败后可重新触发，进度阶段和触发原因具有明确类型边界。

- 需求：REQ-GLOBAL-006～008、NFR-STAB-004。
- 步骤：actor 串行化所有获取；合并并发触发；输出共享进度和结果；串联解析来源→下载→校验→Hash→提交→系统设置→成功记录→清理。
- 测试：多入口同时点击、系统事件竞态、取消、任一步失败。
- 验收：同一时刻最多一个任务；当前壁纸失败保护成立。

- 验收证据：`FetchOrchestratorTests` 2 项通过，覆盖并发合并、串行互斥与失败恢复。

## P05-02 自动触发与每日幂等

> 状态：完成（2026-08-19）。已实现 `DailyFetchChecker` 与 `AutomaticFetchTriggerCoordinator`：系统事件统一映射到 `checkToday(reason:)`，slideshow 直接跳过网络 workflow，当天 automatic 成功记录幂等短路，事件风暴共享一次检查。

- 需求：12.1/12.2、16.3/16.4。
- 步骤：系统事件只调用 `checkToday(reason:)`；daily 才联网；查询成功记录；本地已有 current 时必要恢复；不使用分钟轮询。
- 测试：启动/唤醒/网络恢复事件风暴、当天成功、跨日、回拨、时区变化、slideshow 无网络。

- 验收证据：`DailyFetchCoordinatorTests` 3 项通过，覆盖事件合并、当天成功与 slideshow 零 workflow 调用。

## P05-03 自动重试与持久化恢复

> 状态：完成（2026-08-19）。已实现 `AutomaticRetryPolicy` 与 `PersistentRetryCoordinator`：第 1 次失败 +30 分钟、第 2 次 +2 小时、第 3 次仅单次默认源兜底，策略写入 `nextRetryAt`，恢复只读取到期任务。

- 需求：13.1。
- 步骤：失败 1→+30m，失败 2→+2h，失败 3→停止并最多兜底一次；nextRetryAt 持久化；重启到期恢复；跨日取消；manual 不计数。
- 测试：固定 Clock 推进，无 sleep；默认源失败不成链；计划/默认相同。
- 验收：没有任意 `Task.sleep` 驱动的脆弱长等待；重试任务不会重复创建。

- 验收证据：`RetryPolicyTests` 2 项通过，使用固定日期验证间隔、单次兜底和持久化到期恢复；没有用长等待驱动测试。

## P05-04 连续失败健康计数

> 状态：完成（2026-08-19）。已实现 `SourceHealthSettlementCoordinator`：仅自然日结算事件增加失败天数，同一来源同一天只结算一次，成功立即清零。

- 需求：13.2。
- 步骤：定义“当日失败”结算点；成功清零；连续三天 warning；手动成功如何影响当日结算需按 P00 决定并测试。
- 验收：不因单次临时错误错误累加“天”。

- 验收证据：`SourceHealthSettlementCoordinatorTests` 2 项通过，覆盖每日唯一结算和成功清零。

## P05-05 每日模式与手动立即更新

> 状态：完成（2026-08-19）。已实现 `FetchModePolicy` 与 `ManualWallpaperUpdateUseCase`：daily 受当天成功门控，manual 使用独立任务记录并绕过今日成功，不增加 automatic 次数；同 Hash current 返回复用提示语义。

- 需求：12.3、14.1。
- 步骤：manual 绕过今日成功；先计划后 default；相同 current Hash 复用并提示；失败不改 current；手动换本地壁纸不重开今日任务。

- 验收证据：`FetchModePolicyTests` 3 项通过，覆盖 daily/manual 隔离、同 Hash current 复用和 manual 任务记录。

## P05-06 循环候选与选择策略

> 状态：完成（2026-08-19）。已实现 `WallpaperSelectionPolicy`：只选择 available 文件，随机池排除 current 并在有替代项时排除上一项，chronological 稳定旧→新，manual daily 新→旧。

- 需求：14.2～14.4、REQ-SET-002～006。
- 步骤：只取有效本地文件；random 排除 current；chronological 旧→新 + ID 稳定；daily 手动换一张按新→旧；无/单候选行为。
- 测试：0/1/N 候选、删除 current 保护、相同时间稳定排序、随机不连续重复。

- 验收证据：`WallpaperSelectionPolicyTests` 3 项通过，覆盖无效文件过滤、0/1/N 候选、current 保护、稳定排序与随机防连续重复。

## P05-07 Rotation Scheduler

> 状态：完成（2026-08-19）。已实现 `RotationScheduler` actor：只持有一个低频 Task，设置变化/睡眠唤醒会重算，候选为空时停止且不空转；候选和应用边界均为注入依赖，轮播不访问网络层。

- 步骤：actor 只持有一个低频 Task；修改间隔后重算；睡眠暂停、唤醒重算不补播；Library/清理变化刷新候选；无候选不空转。
- 测试：Manual Clock、取消、设置连续变化、睡眠跨多个间隔。
- 辅佐：[data-and-state-machines.md](../01-architecture/data-and-state-machines.md)。

- 验收证据：`RotationSchedulerTests` 3 项通过，覆盖单任务与 refresh、无候选停止、睡眠暂停/唤醒恢复；测试使用注入 sleeper 和 `Task.yield`，无真实长等待。

## 阶段退出条件

时间相关测试全部使用注入 Clock/Calendar；获取和轮播互斥/共享状态明确；循环模式测试可证明零网络调用。
