# 数据模型与状态机辅佐文件

## 1. 持久化实体

### WallpaperSource

必须字段：`id`、`name`、`url`、`isEnabled`、`createdAt`、`updatedAt`、最近请求状态/时间、脱敏错误、连续失败天数。

约束：

- 名称 trim 后 1–50；同名允许但提示；
- URL 仅 http/https；重复 URL 需确认；
- URL 改动会使连接测试证明失效；
- 删除来源不级联删除 Wallpaper；
- 健康状态是结果数据，不由 View 临时拼装。

### P03-02 实施记录（2026-08-19）

- 来源保存由 `SaveSourceUseCase` 重新执行 P03-01 的验证、连接证明和重复 URL 门禁；新增初始化健康字段，编辑保留创建时间及健康历史，并返回已保存实体作为后续 UI 定位标识。
- 启停只更新来源自身，不修改星期/default 引用；停用状态持久化，重新启用恢复原计划关系且不触发下载。
- 来源删除在 Repository 单事务内清除周计划、默认来源、每日任务与 Wallpaper 的 source ID，并保留 `sourceNameSnapshot`；事务同时返回来源名称、受影响星期和 default 标记供确认/结果展示。
- 健康更新区分请求失败与“当日失败已结算”：只有后者累计天数，成功立即清零；自然日唯一结算由 P05-04 的调度层负责。

### Wallpaper

必须字段与规格一致。建议额外区分“物理图片”与“获取事件”：同一 Hash 只有一个物理文件，但每日任务可引用同一 Wallpaper。

约束：

- `contentHash` 唯一；
- `localPath` 保存应用根目录下相对路径；
- `sourceNameSnapshot` 在来源删除后仍可显示；
- current 只能有一个，且仅在系统设置成功后切换；
- 文件缺失时标异常并排除候选。

### WeeklySchedule

七个可空来源 ID + 一个可空默认来源 ID。不存在 ID 按“未设置”读取；停用引用保留并显示警告；删除引用显式置空。

### P03-03 实施记录（2026-08-19）

- `PrepareWeeklyPlanUseCase` 将持久化计划和来源列表投影为固定周一至周日的行；行状态明确区分未设置、可用、已停用和已删除来源，不由 View 临时推断。
- 可选项只包含启用来源并隐含一个 `nil` 的“未设置”选择；停用/缺失来源不能被新分配，但旧引用仍可被读取并呈现警告。
- 仅在计划尚不存在且恰有一个启用来源时初始化七天；已有计划（包括全空计划）不会被后续来源变化重写，default source 仍由 P03-04/P07 的独立流程管理。
- 单日更新持久化成功后才返回新计划；失败抛出携带原计划的 `scheduleSaveFailed`，供 UI 恢复旧值，取消则保持 `CancellationError` 语义。
- today 标记只依赖注入的 `Clock` 和 `CalendarProviding`，通过 `LocalDay` 的固定 Gregorian 映射避免 locale 改变星期序号。

### P03-04 实施记录（2026-08-19）

- `ResolveSourceUseCase` 是无副作用的来源决策边界：启用且未最终失败的计划来源优先；计划来源缺失、停用或最终失败时，仅选择一个不同且启用的 default；无候选时返回明确的 `noCandidate`，不递归或重复尝试。
- `UpdateDefaultSourceUseCase` 在保存 default 前重新读取来源并拒绝不存在/停用来源；允许显式清空 default，仅更新 `WeeklySchedule.defaultSourceID` 与时间戳，保存失败保留旧计划语义。
- 解析结果通过复制 `DailyFetchRecord` 写入 `actualSourceID` 与 `usedDefaultSource`，不会改变调用方持有的原始记录；P05-03 负责将此决策接入获取重试状态机。

### UserSettings

默认值必须集中定义，不能分散在 View、数据迁移和 Onboarding：登录启动 true、daily、30 天、random、30 分钟、onboarding 未完成。

### DailyFetchRecord

这是幂等与恢复的关键实体。`localDate` 应是明确的本地日值，而非把 Date 任意截断；必须记录 planned/actual source、状态、自动尝试次数、是否兜底、nextRetryAt、错误和 wallpaper 引用。

建议唯一约束：`localDate + taskKind`。手动立即更新可记录单独 attempt/event，但不覆盖自动次数。

### P02-02 实施记录（2026-08-19）

- 生产持久化基线为 `ZIKORASchemaV1`（1.0.0），由 `ZIKORAMigrationPlan` 显式列出；后续字段变化必须新增 schema 版本与 migration stage，不直接改写已发布版本语义。
- 五类 SwiftData 实体只保存 Foundation 标量和稳定 raw value；Domain/Application 不依赖 SwiftData 类型。
- `Wallpaper.contentHash` 与 `DailyFetchRecord.taskKey` 使用唯一属性；current 仍是跨行事务不变量，归 P02-04 实现。
- 来源、计划、壁纸和每日记录之间使用可选 UUID 与 `sourceNameSnapshot`，不使用 cascade relationship；P02-03 删除来源时负责显式清理计划引用，历史壁纸不删除。
- `Wallpaper.relativePath` 的写入入口接受 `ManagedRelativePath`，拒绝绝对路径、空组件、反斜杠和 `.`/`..` 逃逸。

### P02-04 实施记录（2026-08-19）

- `SetCurrentWallpaperUseCase` 是系统调用与持久化事务之间的 Application 边界；UI、下载流程和 P06 AppKit 实现不得绕过它直接调用 `markCurrent`。
- 全部显示器成功：提交唯一 current，返回成功数量；部分成功：同样提交新 current，并返回成功/失败数量供 UI 显示警告；全部失败或没有显示器：不提交。
- 任务在系统调用开始前或返回后被取消时不提交数据库 current；系统 API 可能已产生的外部部分效果由结果警告/后续重试收敛，数据库不会产生多个 current。
- 目标已经是 current 时不重复调用系统边界，但仍执行一次 `markCurrent` 事务，以修复旧库或异常状态中的重复 current 标记。

### P02-05 实施记录（2026-08-19）

- `DailyFetchRecord.taskKey(for:taskKind:)` 是唯一任务键生成入口，格式稳定为 `<ISO LocalDay>|<FetchTaskKind raw value>`；调用方不自行拼接。
- `PrepareDailyFetchRecordUseCase` 从注入的 Clock 与 Calendar 计算系统本地日，并通过 `DailyFetchRepository.prepareRecord` 在 actor 隔离的单次事务中查找或创建，重复或并发事件得到同一条记录。
- 准备某个本地日任务时，其他本地日仍处于 `retryScheduled` 的自动任务会归档为 `failed` 并清除 `nextRetryAt`，保留已有 attempt count、错误和历史关联；跨日不补发。
- manual 与 automatic 使用不同 task kind，因此手动立即更新不会读取或增加 `automaticAttemptCount`。P02 只提供持久化与到期判断，30 分钟/2 小时/第 3 次兜底等策略仍由 P05-03 负责。

## 2. 获取任务状态机

```text
idle
  └─ trigger → checking
checking
  ├─ 非 daily / 今日已成功 → finished(no-op)
  ├─ 无有效计划 → resolvingDefault
  └─ 有效计划 → downloading(planned)
downloading
  ├─ response invalid → failedAttempt
  └─ valid temp file → hashing
hashing
  ├─ duplicate → reusing
  └─ new → committingFile
reusing / committingFile
  └─ setDesktop → applying
applying
  ├─ 全部失败 → failedAttempt（不切 current）
  ├─ 部分失败 → successWithWarning
  └─ success → succeeded
failedAttempt
  ├─ 自动次数 1 → retryScheduled(+30m)
  ├─ 自动次数 2 → retryScheduled(+2h)
  ├─ 自动次数 3 且可兜底 → downloading(default, once)
  └─ 其他 → failedForDay
succeeded
  └─ record success → cleanup → finished
```

不变量：

- 任一时刻最多一个全局获取任务；
- 错误不清除当前壁纸；
- 临时文件验证完成前不进入正式目录；
- 默认来源不递归、不与计划来源重复；
- 手动请求绕过“今日成功”，但不增加自动次数；
- 跨日废弃旧日 retry，不补发。

## 3. 来源连接测试状态机

```text
untested → testing → success(preview + fingerprint)
                 └→ failure(actionable reason)
success -- edit URL/name? --> untested
```

规格只要求 URL 修改使测试失效；Onboarding 还要求名称或 URL 修改后失效。为保持一致，建议采用更严格规则：任何会改变将保存配置身份的字段都使当前测试证明失效，并在 P00 确认。

保存按钮可用条件：新增/URL 改动时存在与当前输入 fingerprint 匹配的成功测试；仅改名称/启用状态时沿用已保存 URL 的有效性。

### P03-01 实施记录（2026-08-19）

- `SourceInputFingerprint` 由 trim 后名称与规范化 URL 构成，不包含启用状态；新增来源的测试证明必须匹配当前 fingerprint，名称或 URL 修改都会使证明失效。
- 编辑现有来源时，原 URL 未变化可只修改名称或启用状态而不重测；URL 变化后必须提供匹配当前完整输入的成功证明。
- 同名只产生可展示的警告 ID，不阻止保存；排除正在编辑的自身后，只要存在规范化后相同 URL，就输出显式确认阻塞。
- Application 用例返回完整 `SourceInputDecision` 与 `canSave`，View 不复制名称、URL、证明或重复确认规则。

## 4. 循环播放状态机

```text
disabled(daily)
  └─ switch slideshow → loadingCandidates
loadingCandidates
  ├─ 0 → suspendedNoCandidate
  ├─ 1 且为 current → waiting(no reset)
  └─ >=1 → waiting(nextFireAt)
waiting
  ├─ sleep → paused
  ├─ settings/library change → loadingCandidates
  ├─ manual next → selecting
  └─ interval reached → selecting
selecting → applying → waiting(recalculate)
paused -- wake --> loadingCandidates（不补播）
```

随机与顺序选择必须是纯策略，注入候选、current 和随机源即可单测。

## 5. 缓存清理事务

对每条候选执行：

1. 计算过期，但排除 current；
2. 解析并规范化相对路径；
3. 再次确认目标在应用管理根目录内；
4. 删除文件；
5. 仅文件删除成功后删除元数据；
6. 汇总成功/失败，不因单项失败终止全部；
7. 刷新空间统计和 Library。

孤儿规则：记录有、文件无 → 标异常并维护清理；文件有、记录无 → 不删除，只记录诊断。

## 6. 全局 UI 命令状态

`UpdateNowCommand` 和 `NextWallpaperCommand` 必须是共享状态：

- 侧栏、Dashboard、Toolbar、Menu Bar 观察同一 `isRunning/result`；
- 运行中所有入口同时禁用或显示进度；
- 成功后统一刷新 Dashboard/Sources/Library/Menu Bar；
- 失败结果包含用户可读原因与恢复动作；
- `NextWallpaper` 从不调用网络层。
