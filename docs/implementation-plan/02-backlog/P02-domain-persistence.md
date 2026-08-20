# P02 — 领域模型与持久化

## P02-01 实现值类型与枚举

> 状态：完成（2026-08-19）。已建立 `SourceID`/`WallpaperID`/`DailyFetchRecordID`、受验证的 ISO `LocalDay`、Monday-first `Weekday`、设置/获取/健康/格式枚举及集中默认值；持久化 raw value 与 UI 文案解耦。

- 需求：18 全章。
- 步骤：定义 SourceID/WallpaperID、LocalDay、模式、顺序、间隔、保留策略、获取/健康状态、格式和错误 code；把默认值集中定义。
- 测试：本地日/星期、时区边界、枚举持久化值、默认设置。
- 验收：不依赖 SwiftUI；持久化 raw value 不随中文文案变化。
- 验收证据：`DomainValueTests` 9 项通过；覆盖上海/洛杉矶本地日边界、DST 星期计算、非法日期解码、ID Codable、稳定 raw value、默认设置、来源健康状态和图片扩展名。
- 辅佐：[data-and-state-machines.md](../01-architecture/data-and-state-machines.md)。

## P02-02 建立持久化 schema 与迁移版本

> 状态：完成（2026-08-19）。已建立五实体 `ZIKORASchemaV1`、`ZIKORAMigrationPlan` 与磁盘/in-memory 容器工厂；Hash、实体 ID 和每日 task key 使用唯一属性，来源关联使用可选 ID/名称快照而非级联 relationship。

- 需求：18.1～18.5、NFR-STAB-001。
- 步骤：映射五类实体；建立 Hash 唯一查询、关系删除规则、相对路径；定义 schema version；添加空库初始化和 reopen 测试。
- 验收：来源删除不删历史壁纸；悬空引用安全；重启后 retry/current/settings 恢复。
- 验收证据：`PersistenceSchemaTests` 6 项通过；覆盖空库建表、V1 版本清单、唯一 Hash/task key、磁盘 reopen、来源删除保留历史、current/retry/settings/schedule 恢复及路径逃逸拒绝。
- 辅佐：[open-decisions.md](../00-analysis/open-decisions.md) DEC-003。

## P02-03 实现 Repository

> 状态：完成（2026-08-19）。五类 Repository 已收敛为具体 Domain 值模型契约；`SwiftDataRepositoryStore` 使用 `@ModelActor` 串行持久化，`InMemoryRepositoryStore` 使用 actor 提供同契约实现，调用方不接触 `ModelContext`。

- 步骤：实现 Source/Schedule/Wallpaper/DailyFetch/Settings repository；定义事务边界；提供 in-memory 实现；错误可分类。
- 测试：CRUD、回滚、并发序列、查询排序、文件异常标记。
- 验收：Application 不接触具体 persistence context；MainActor 隔离不导致后台 I/O 卡 UI。
- 验收证据：`RepositoryStoreTests` 对 SwiftData/in-memory 两后端执行同一契约，覆盖五类 CRUD、Hash/task key 冲突回滚、20 路并发保存、确定性排序、来源删除事务、文件异常标记、缺失实体和损坏 raw value 分类错误。

## P02-04 current 唯一性事务

> 状态：完成（2026-08-19）。`SetCurrentWallpaperUseCase` 先调用逐屏系统壁纸边界，再按结果提交 `WallpaperRepository.markCurrent`：至少一屏成功才切换，全部失败/无显示器/取消均保留旧 current；同图幂等并修复重复标记。

- 需求：REQ-DETAIL-001、15.4、REQ-SYS-004。
- 步骤：仅在系统壁纸调用成功后事务化清除旧 current、设置新 current；处理无旧记录、同图、部分屏幕失败策略。
- 测试：成功/失败/中断时最多一个 current；失败时旧 current 保留。
- 验收证据：`SetCurrentWallpaperUseCaseTests` 9 项通过，核心场景同时覆盖 SwiftData/in-memory；包括全成功、全失败、部分成功、无显示器、无旧 current、同图、事务失败、系统成功后持久化失败与 continuation 驱动取消。
- 辅佐：[test-matrix.md](../03-support/test-matrix.md)。

## P02-05 DailyFetchRecord 幂等与恢复

> 状态：完成（2026-08-19）。`PrepareDailyFetchRecordUseCase` 使用注入的 Clock、Calendar 与 UUID，在 Repository actor 的单次事务内按规范化 `LocalDay + taskKind` 键查找或创建记录；创建当前本地日任务时归档其他日期未完成的自动 retry，手动任务使用独立 task kind 且自动次数始终从 0 开始。

- 需求：12.2、12.5、13.1、18.5。
- 步骤：按 LocalDay + taskKind 查找/创建；保存 automaticAttemptCount/nextRetryAt；跨日归档旧 retry；区分 manual attempt。
- 测试：重复事件不重复下载、进程重启、时区改变、手动不污染自动次数。
- 验收证据：`PrepareDailyFetchRecordUseCaseTests` 7 项通过；核心持久化场景同时覆盖 SwiftData/in-memory，包括 20 路并发触发只生成一条记录、重复事件保留已完成记录、时区改变后旧 retry 归档、次日手动事件归档旧自动 retry、manual/automatic 隔离、同日到期判断，以及磁盘 store 重开后恢复 attempt count 与 nextRetryAt。实际下载次数的端到端断言归 P04/P05 获取编排测试。

## P02-06 数据维护与损坏恢复

> 状态：完成（2026-08-19）。应用启动后会对 SwiftData 壁纸记录和托管目录执行一次低频一致性维护：缺失文件标记为 `missing`、重新出现的文件恢复为 `available`，未知文件仅报告且不会自动删除；数据库无法打开时进入安全恢复页，可重试或显式确认后先归档原库及 sidecar、再创建空库。

- 需求：15.4、NFR-STAB。
- 步骤：检测记录/文件不一致；对数据库打开失败定义安全错误页/恢复方案；不自动删除未知文件。
- 验收：损坏或缺失数据不会崩溃；诊断可定位但不泄露敏感信息。
- 验收证据：`MaintainWallpaperFilesUseCaseTests` 与 `PersistenceRecoveryTests` 6 项通过；覆盖 missing/current missing/文件恢复、未知文件保留、symlink 逃逸忽略、SwiftData 重开保持维护结果、打开失败安全状态，以及显式恢复先归档后建空库。日志仅记录稳定事件和错误码，不写底层数据库错误或绝对路径。

## 阶段退出条件

所有实体、Repository、幂等记录和 current 事务有确定性单测；关闭并重开 store 后结果一致。

> 阶段验收：通过（2026-08-19）。重跑 `DomainValueTests`、`PersistenceSchemaTests`、`RepositoryStoreTests`、`SetCurrentWallpaperUseCaseTests`、`PrepareDailyFetchRecordUseCaseTests`、`MaintainWallpaperFilesUseCaseTests`、`PersistenceRecoveryTests` 共 43 项，全部通过；覆盖全部五实体、双 Repository 后端、current 与每日幂等事务，以及磁盘关闭重开后的 current/retry/settings/schedule/维护状态一致性。
