# 建议架构与模块边界

> 本文件是实施建议，不覆盖需求规格。P00 完成后可调整命名，但应保持依赖方向和可测试边界。

## 1. 架构目标

- SwiftUI 负责呈现与用户意图，不直接执行网络、文件删除或系统壁纸调用；
- Application/Use Case 层编排一次业务动作；
- Domain 层表达规则和状态机，不依赖 SwiftUI/AppKit/SwiftData；
- Infrastructure 层实现网络、持久化、文件、系统事件和 macOS API；
- 同一“立即更新/换一张”命令由主窗口、侧栏和 Menu Bar 复用；
- 所有时间、随机、网络、文件和系统 API 都可替换，以便确定性测试。

## 2. 依赖方向

```text
Features/UI
   ↓ user intent / view state
Application (Use Cases, Coordinator)
   ↓ protocols
Domain (models, policies, state machines)
   ↑ implementations
Infrastructure (SwiftData, URLSession, FileManager, AppKit, ServiceManagement)
```

UI 不得反向 import 具体 SwiftData model context 来实现业务规则。Infrastructure 不得依赖具体 View。

## 3. 建议源代码结构

```text
ZIKORA-wallpaper/
├── App/
│   ├── ZIKORAWallpaperApp.swift
│   ├── AppEnvironment.swift
│   ├── AppCoordinator.swift
│   └── AppLifecycleDelegate.swift
├── Domain/
│   ├── Models/
│   ├── Policies/
│   ├── StateMachines/
│   ├── Errors/
│   └── Protocols/
├── Application/
│   ├── Sources/
│   ├── Fetching/
│   ├── Scheduling/
│   ├── Rotation/
│   ├── Storage/
│   └── Settings/
├── Infrastructure/
│   ├── Persistence/
│   ├── Networking/
│   ├── Files/
│   ├── WallpaperSystem/
│   ├── SystemEvents/
│   ├── LoginItem/
│   └── Diagnostics/
├── Features/
│   ├── AppShell/
│   ├── Onboarding/
│   ├── Dashboard/
│   ├── Sources/
│   ├── Library/
│   ├── Settings/
│   └── MenuBar/
├── DesignSystem/
│   ├── Tokens/
│   ├── Components/
│   └── Assets/
└── Resources/
    └── Localizable.xcstrings
```

测试目录镜像 Domain/Application/Infrastructure/Features；不要为了测试把生产符号全部改成 `public`。

## 4. 核心协议建议

名称可以调整，但以下边界不可缺失：

| 协议 | 责任 | 测试替身 |
|---|---|---|
| `SourceRepository` | 来源 CRUD、健康状态 | In-memory repository |
| `ScheduleRepository` | 七天计划与默认来源 | In-memory schedule |
| `WallpaperRepository` | 元数据、Hash 查询、current 原子切换 | In-memory wallpaper store |
| `DailyFetchRepository` | 每日幂等、尝试次数、重试恢复 | In-memory records |
| `SettingsRepository` | 用户设置持久化 | In-memory settings |
| `ImageDownloading` | 受限下载到临时文件 | Scripted downloader |
| `ImageValidating` | MIME、magic bytes、大小、解码、尺寸格式 | Fixture validator |
| `WallpaperFileStore` | 原子移动、安全删除、空间统计 | Temporary directory store |
| `DesktopWallpaperSetting` | 为屏幕设置壁纸 | Recording fake |
| `SystemEventProviding` | 启动/唤醒/日期/时区/网络事件 | Async event stream fake |
| `RetryScheduling` | 持久化下一执行时间并触发检查 | Manual scheduler |
| `LoginItemManaging` | 注册/移除登录项 | Result-configurable fake |
| `Clock` / `CalendarProviding` | 当前时间、本地日、星期 | Fixed clock/calendar |
| `RandomSelecting` | 随机候选 | Deterministic selector |

### P01-02 实施记录（2026-08-19）

- `AppEnvironment` 由 App 根场景创建一次，通过 SwiftUI environment 传入；未来主窗口和 `MenuBarExtra` 必须注入这一引用，不得各自调用 `live()`。
- `Clock`、`CalendarProviding`、`UUIDGenerating`、`RandomSelecting` 均为异步 `Sendable` 边界，测试可使用固定或顺序实现，不通过 sleep/全局状态控制结果。
- Repository 协议先使用关联类型定义 CRUD/事务能力，避免在 P01 用 `Any`、字典或临时 DTO 固化 P02 模型；P02 的 `SourceID`、`LocalDay` 和正式实体将直接成为关联类型。
- network/file/system 协议只表达高层输入输出，不向 View 暴露 `URLSession`、`FileManager`、`NSWorkspace` 或 persistence context。
- P01 的 in-memory Repository 位于测试 target；P02 会在正式领域模型落地后补齐约束、排序、迁移和事务测试。

### P02-03 实施记录（2026-08-19）

- Repository 协议已由 P01 关联类型占位收敛为 `WallpaperSource`、`WeeklySchedule`、`Wallpaper`、`DailyFetchRecord`、`UserSettings` 五类具体 Domain 值模型；协议仍不暴露 SwiftData。
- `SwiftDataRepositoryStore` 是单一 `@ModelActor`，所有 fetch/save/delete 与跨实体来源删除在其串行 executor 上执行；不把 `ModelContext` 交给 Application 或 MainActor。
- `InMemoryRepositoryStore` 位于生产模块并实现同一协议组合，用于 Preview、测试和未来安全恢复场景；初始化与写入同样检查 Hash/task key 冲突。
- 来源删除事务清除计划、壁纸和每日记录中的来源 ID，同时保留壁纸记录、物理文件信息及 `sourceNameSnapshot`。
- `RepositoryError` 只暴露实体、操作和稳定分类，不向上层泄露数据库错误文本或潜在敏感字段值。

## 5. 并发模型

- UI/View State 与 AppCoordinator：`@MainActor`；
- 全局 Fetch Orchestrator：actor，保证同一时间最多一个获取任务；
- 持久化访问：通过单一 repository 隔离上下文；
- 文件写入/Hash/图片解码：异步执行，结果回主 actor；
- Rotation scheduler：actor 持有单一 Task，设置变化时取消并重建；
- 系统事件：合并为串行事件流，事件只触发“检查”，不直接创建并发下载；
- 退出：取消拥有的 Task；临时文件通过 `defer` 或恢复清理策略处理。

不得以 `Task.detached` 绕过 actor 诊断，也不得用 `@unchecked Sendable` 静音。

## 6. Apple Framework 建议

| 能力 | 首选 | 备注 |
|---|---|---|
| UI | SwiftUI，必要处桥接 AppKit | 保持当前生命周期 |
| 持久化 | SwiftData（待 DEC-003） | Repository 隔离 schema |
| 网络 | URLSession | 限制超时、重定向、流式大小 |
| 图片探测 | ImageIO / UniformTypeIdentifiers | 同时校验声明与实际内容 |
| Hash | CryptoKit SHA-256 | 对完整内容稳定去重 |
| 壁纸 | `NSWorkspace` + `NSScreen` | 需真机 Spike |
| 登录项 | ServiceManagement | 不改签名配置规避失败 |
| Menu Bar | SwiftUI `MenuBarExtra`，必要时 AppKit | 状态共享同一 coordinator |
| 日志 | `Logger` / OSLog | URL query 脱敏 |
| 网络状态 | `NWPathMonitor` | 只触发合并检查，不作为请求成功依据 |

不建议 V1.0 引入第三方网络、数据库、图片缓存或调度库。

## 7. 工程 target 建议

最低可行配置：

- 现有 App target；
- 一个 Unit Test target，覆盖 Domain/Application/Infrastructure 的可替换边界；
- 可选 UI Test target，仅覆盖 Onboarding 和关键导航烟测，不承担系统壁纸/登录项验证。

如果拆 Swift Package 会显著增加初期工程复杂度，可先保留单 target + 目录边界；当 Domain 稳定且构建时间/复用价值明确时再模块化。
