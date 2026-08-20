# P03 — 壁纸源、每周计划与默认源领域

## P03-01 输入验证与连接测试证明

> 状态：完成（2026-08-19）。已建立不依赖 UI 的 `EvaluateSourceInputUseCase`：名称统一 trim 并限制 1～50 字符，URL 仅接受带有效 host 的 http/https 且规范化 scheme/host，国际域名与 query 保留；判定结果同时输出同名警告、重复 URL 确认阻塞、连接证明是否匹配及最终 `canSave`。

- 需求：9.3、10.2.3、REQ-SRC-007～010。
- 步骤：名称 trim/长度；http(s) URL；重复 URL 确认信号；定义 input fingerprint 和测试证明；编辑 URL 后失效。
- 测试：空白、非法 scheme、国际域名/query、同名、同 URL、编辑/取消。
- 验收：保存条件由 use case 判定，不由按钮自行推断。
- 验收证据：`EvaluateSourceInputUseCaseTests` 5 项通过；覆盖名称空白/50 字符边界、非法 scheme、国际域名/query、scheme/host 大小写规范化、同名允许警告、同 URL 必须确认、新增来源证明与当前名称/URL 指纹绑定、编辑仅名称/启用可沿用、编辑 URL 强制重测，以及取消/评估不写 Repository。
- 辅佐：[data-and-state-machines.md](../01-architecture/data-and-state-machines.md)。

## P03-02 Source CRUD 与健康状态

> 状态：完成（2026-08-19）。已建立来源列表、新增/编辑、启停、删除和健康状态 application use case；保存入口复用 P03-01 判定并返回已保存实体供 UI 定位。删除事务返回受影响星期/default 摘要，清理计划、默认来源、任务引用和历史壁纸的 source ID，同时保留壁纸来源名称快照。

- 需求：REQ-SRC-001～011、13.2。
- 步骤：新增/编辑/启停/删除；维护最近请求状态与失败天数；启停不改计划；删除显式清计划/默认引用但保留壁纸。
- 测试：停用/重启、删除影响星期、删除 default、成功重置失败天数、连续三天警告。
- 验收：无悬空引用崩溃；历史来源快照可显示。
- 验收证据：`ManageSourcesUseCasesTests` 5 项场景通过；CRUD、删除和健康状态同时覆盖内存与 SwiftData 后端，另覆盖停用后磁盘重开、重新启用保留计划、删除预览及原子清引用、历史快照保留、单次失败不累计天数、连续三日 warning、成功清零。`RepositoryStoreTests` 继续验证任务引用同步清理。
- 边界：`dailyFailureSettled` 只接受“当日全部尝试已失败”的结算事件；按自然日保证只结算一次的调度编排归 P05-04。

## P03-03 七天计划

> 状态：完成（2026-08-19）。已建立固定 Monday～Sunday 的 `WeeklyPlanSnapshot`、启用来源选项、停用/缺失引用状态与注入时钟生成的 today 标记；首次且仅有一个启用来源时创建七天默认计划，已存在的空计划不会因来源变化被静默改写。

- 需求：REQ-PLAN-001～007。
- 步骤：固定星期顺序；只列启用来源 + 未设置；即时保存失败回滚；唯一有效来源的首次默认；今天标记使用注入 Calendar。
- 测试：七天独立保存、停用保留引用、删除置空、时区/locale 不改变星期映射。
- 验收证据：`WeeklyPlanUseCaseTests` 6 项场景通过；首次唯一来源七天初始化、七日独立持久化、未设置选择、停用/缺失引用显示、不可用来源拒绝、旧计划不重复初始化、保存失败携带原计划回滚，以及时区/locale today 映射均已覆盖；初始化、逐日保存和引用状态同时覆盖内存与 SwiftData 后端。删除置空由 P03-02 的双后端删除事务测试覆盖。

## P03-04 默认来源解析策略

> 状态：完成（2026-08-19）。已实现默认来源设置校验与纯解析器：仅启用来源可被设为 default；计划来源缺失、停用或最终失败时最多选择一次不同的启用 default，不递归、不重复尝试；解析结果可无副作用地写入每日任务的 actual source 与 usedDefault 标记。

- 需求：REQ-DEF-001～005。
- 步骤：定义纯函数 `resolveSource`；覆盖未配置/不存在/停用/最终失败；同源不重试；一次任务只兜底一次；记录 actual source 和 usedDefault。
- 测试：`DefaultResolutionTests` 6 项通过，覆盖计划优先、缺失/停用/最终失败兜底、同源不重试、无计划单次兜底、禁用 default 拒绝，以及任务记录写入不修改原值。
- 验收证据：`ResolveSourceUseCase`、`UpdateDefaultSourceUseCase` 与 `SourceResolution`；聚焦测试 `DefaultResolutionTests`。
- 辅佐：[requirements-traceability.md](../03-support/requirements-traceability.md)。

## P03-05 连接测试用例编排

> 状态：完成（2026-08-19）。已建立 `TestSourceConnectionUseCase` 与 actor 隔离的 `SourceConnectionTestCoordinator`：先复用来源输入校验，再串联 downloader、validator、预览元数据和带当前输入 fingerprint 的连接证明；统一映射超时/网络/响应错误，取消时清理临时文件。

- 需求：10.2.4。
- 前置：P04 的 downloader/validator protocol 可先 Fake。
- 步骤：校验→请求→大小→类型→解码→预览元数据；映射超时、HTTP、非图片、解码失败、过大；取消旧测试避免结果串线。
- 验收：输入变化后旧请求结果不能解锁新输入保存。

- 验收证据：`TestSourceConnectionUseCaseTests` 3 项通过，覆盖完整 pipeline/preview 与 fingerprint、非法 URL 不发请求、超时映射、临时文件清理，以及第二次测试取消第一次并阻止旧输入结果回写。

## 阶段退出条件

已满足（2026-08-19）：不依赖 UI 即可完成来源、计划、默认来源和连接测试主规则；`EvaluateSourceInputUseCaseTests`、`ManageSourcesUseCasesTests`、`WeeklyPlanUseCaseTests`、`DefaultResolutionTests` 与 `TestSourceConnectionUseCaseTests` 均通过，删除/停用/兜底组合有双后端或纯 application 测试覆盖。
