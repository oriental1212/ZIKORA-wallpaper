# 需求追踪矩阵

> 实施时在“证据”列填写测试名、截图、日志或人工验收记录。状态仅允许：planned / implemented / tested / manual-pass / deferred / blocked。

## 1. 全局与首次引导

| 需求 | 任务 | 测试/证据建议 | 状态 |
|---|---|---|---|
| REQ-GLOBAL-001～005 | P06-05、P07-01 | `WindowLifecycleCoordinatorTests` 覆盖登录启动隐藏、导航恢复与统一退出；`AppShellView` 使用持久化导航；红色关闭按钮真机项 deferred | tested |
| REQ-GLOBAL-006～010 | P05-01、P07-05/06、P06-04 | `WallpaperCommandCenterTests` 覆盖共享更新/本地换图/失败解锁；`MenuBarCommandRouterTests` 覆盖窗口/设置/退出路由；不可逆确认由 Sources/Library 确认框实现 | tested |
| REQ-ONB-001～003 | P07-02～04 | Onboarding 保存复用 `SaveSourceUseCase`/`EvaluateSourceInputUseCase`，草稿由 `UserDefaults` 恢复；首次启动 UI smoke 需真机 | implemented |

## 2. Dashboard 与 Sources

| 需求 | 任务 | 测试/证据建议 | 状态 |
|---|---|---|---|
| REQ-DASH-001～008 | P07-05/06 | `WallpaperCommandCenterTests` 覆盖真实 Update/Next 共享状态；`DashboardView` 展示真实 current、进度、失败与空态；视觉状态包人工项 deferred | tested |
| REQ-SRC-001～006 | P03-02、P08-01 | `ManageSourcesUseCasesTests` 覆盖完整列表、启停不改计划及重开恢复；`SourcesViewModelTests` 覆盖停用来源仍显示、计划选项移除、同步时间/状态展示与删除清理 | tested |
| REQ-SRC-007～011 | P03-01/02/05、P08-02/03 | `EvaluateSourceInputUseCaseTests`、`ManageSourcesUseCasesTests`、`TestSourceConnectionUseCaseTests` 覆盖输入/重复确认、证明失效、连接编排、超时映射、临时文件清理和旧测试取消；`SourceFormViewModelTests` 覆盖 inline validation、连接测试、重复 URL 确认、编辑 URL 强制重测和请求竞态取消 | tested |
| REQ-PLAN-001～007 | P03-03、P08-04 | `WeeklyPlanUseCaseTests` 覆盖七日固定顺序、启用选项、独立保存/回滚、首次默认、停用/缺失引用和 today 映射；`SourcesViewModelTests` 覆盖逐日即时保存与计划刷新 | tested |
| REQ-DEF-001～005 | P03-04、P08-05、P05-03 | `DefaultResolutionTests` 覆盖计划优先、缺失/停用/最终失败兜底、同源不重试、单次兜底、禁用 default 拒绝及 actual/usedDefault 记录；`SourcesViewModelTests` 覆盖默认来源更新与显示状态 | tested |

## 3. Library、Detail、Settings

| 需求 | 优先级 | 任务 | 测试/证据建议 | 状态 |
|---|---|---|---|---|
| REQ-LIB-001～007 | P0 | P04-05、P09-01/02 | `LibraryViewModelTests` 覆盖倒序、缺文件、本地刷新、current 标记与搜索；`ThumbnailPipelineTests` 覆盖 1,000 条缩略图并发/取消 | tested |
| REQ-DETAIL-001～004 | P1 | P09-03、P06-06 | `WallpaperDetailView` 提供设为当前、Finder、删除确认与当前删除禁用；Finder 安全由 `FinderCacheDirectoryServiceTests` 覆盖 | tested |
| REQ-SET-001～006 | P0 | P05-06/07、P09-06 | `SettingsViewModelTests` 覆盖设置持久化与清理估算；轮播策略由 `RotationSchedulerTests`/`WallpaperSelectionPolicyTests` 覆盖 | tested |
| REQ-STORE-001～006 | P0 | P04-06/07、P09-07 | `SettingsViewModelTests` 覆盖清理估算；`CleanupWallpapersUseCaseTests` 覆盖 current 保护、执行顺序与失败报告 | tested |

## 4. Menu Bar、获取、失败与模式

| 需求 | 任务 | 测试/证据建议 | 状态 |
|---|---|---|---|
| REQ-MENU-001～007 | P06-04 | `MenuBarCommandRouterTests`、`WallpaperCommandCenterTests`、`MenuBarCommandsView` 接线覆盖 Update/Next/打开/设置/退出；Menu Bar 真机项 deferred | tested |
| 自动触发 12.1 | P05-02、P06-03 | `DailyFetchCoordinatorTests` 事件风暴合并 + `WorkspaceSystemEventProviderTests` 通知映射 | tested |
| 自动流程 12.2 | P02-05、P05-01/02、P04 | `WallpaperFetchWorkflowUseCaseTests` 成功/失败/兜底/去重全链路 + `PrepareDailyFetchRecordUseCaseTests` 幂等 | tested |
| 手动更新 12.3 | P05-05 | `FetchModePolicyTests` manual 独立 + `WallpaperCommandCenterTests` 共享命令 + 工作流 manual 失败不改自动次数 | tested |
| 响应验证 12.4 | P04-01/02 | `URLSessionImageDownloaderTests` 超时/重定向/50MB/取消 + `ImageIOImageValidatorTests` MIME/magic/解码/损坏 | tested |
| 去重 12.5 | P04-03、P02-05 | `DeduplicateWallpaperUseCaseTests` 内容 Hash 去重/变更/复用关联 + 每日任务键幂等 | tested |
| 自动重试 13.1 | P02-05、P05-03 | `RetryPolicyTests` + `WallpaperFetchWorkflowUseCaseTests` 30m/2h/第 3 次默认源 + `PersistentRetryScheduler` 到期恢复 | tested |
| 健康状态 13.2 | P05-04、P03-02 | `ManageSourcesUseCasesTests` 单次失败不累计/三日 warning/成功清零 + `SourceHealthSettlementCoordinatorTests` 每日唯一结算 | tested |
| 失败保护 13.3 | P04/P05 | `WallpaperFetchWorkflowUseCaseTests` 离线/超时/默认源失败 + `SetCurrentWallpaperUseCaseTests` current 保护 + 原子文件与恢复测试 | tested |
| 每日/循环/顺序/换图 14.1～14.4 | P05-05～07 | `RotationSchedulerTests` 单任务/无候选/睡眠恢复 + `WallpaperSelectionPolicyTests` 顺序/随机/current 保护 + `WallpaperCommandCenterTests` 本地换图 | tested |

## 5. 缓存与系统集成

| 需求 | 任务 | 测试/证据建议 | 状态 |
|---|---|---|---|
| 缓存目录 15.1 | P04-04/07 | `AtomicWallpaperFileStoreTests` 路径逃逸/symlink/根目录校验 + `FinderCacheDirectoryServiceTests` 仅管理目录 reveal | tested |
| 清理时机/过期/一致性 15.2～15.4 | P04-06、P02-06 | `MaintainWallpaperFilesUseCaseTests` + `CleanupWallpapersUseCaseTests` 覆盖 missing/current missing、未知文件保留、过期边界与失败报告 | tested |
| REQ-SYS-001～004 | P06-01、P02-04 | `SetCurrentWallpaperUseCaseTests` 全成功/部分成功/全失败 current 事务；AppKit 多屏真机 deferred | tested |
| 登录启动 16.2 | P06-02、P09-05 | `SMAppLoginItemManagerTests` 状态/失败回滚 + `SettingsViewModelTests` 登录项同步；登录真机 deferred | tested |
| 睡眠/唤醒 16.3 | P05-07、P06-03 | `RotationSchedulerTests` 睡眠暂停/唤醒恢复 + `WorkspaceSystemEventProviderTests`/`DailyFetchCoordinatorTests` 事件合并；系统睡眠真机 deferred | tested |
| 日期/时区 16.4 | P02-01/05、P05-02、P06-03 | `DomainValueTests` DST/时区 + `PrepareDailyFetchRecordUseCaseTests` 时区变更/跨日归档；系统时区真机 deferred | tested |

## 6. 非功能需求

| 需求 | 任务 | 验证 | 状态 |
|---|---|---|---|
| NFR-PERF-001～005 | P04-05、P10-02 | Release 实测 CPU 0.0%、RSS 93–104 MB（超 80 MB 目标已记录）；`ThumbnailPipelineTests` 1,000 条；无高频 timer/扫描 | tested |
| NFR-NET-001～004 | P04-01、P05-02/03 | `DailyFetchCoordinatorTests` 无网络/去重/事件合并 + `URLSessionImageDownloaderTests` 超时/重定向/上限 | tested |
| NFR-STAB-001～004 | P02、P04、P05、P10-03 | 双后端事务/回滚/并发、数据库恢复、原子写入、工作流故障注入均通过；真机崩溃矩阵 deferred | tested |
| NFR-SEC-001～005 | P01-03、P04、P10-06 | `DiagnosticsTests` URL 脱敏 + 文件 containment 测试 + [privacy-and-security-audit.md](../03-support/privacy-and-security-audit.md) | tested |
| NFR-A11Y-001～005 | P01-04、P07～P10 | `DesignSystemTests` 状态不只靠颜色/Reduce Motion；图标 label/help 与 DesignSurface 降级已实现；VoiceOver/system prefs 真机 deferred | tested |

## 7. 原型差异 D-01～D-10 的任务落点

| 差异 | 落点 |
|---|---|
| D-01 无本地目录源 | P08-01 验收、P10-06 权限审阅 |
| D-02 七天计划 | P03-03、P08-04 |
| D-03 默认源三类兜底 | P03-04、P05-03 |
| D-04 搜索 P1 | P09-04 |
| D-05 保留周期完整值 | P09-07 |
| D-06 刷新/更多有行为 | P07-05、P08-06、P09 |
| D-07 统一“立即更新” | P01-05、共享命令 |
| D-08 统一“换一张” | P01-05、P05-06 |
| D-09 Menu Bar P0 | P06-04 |
| D-10 缺失页面/状态 | P00-03、P07～P09 |
