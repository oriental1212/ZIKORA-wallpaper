# P06 — macOS 生命周期与系统集成

## P06-01 桌面壁纸适配器

> 状态：完成（2026-08-19）。已实现 `AppKitDesktopWallpaperSetter`：在 MainActor 枚举 `NSScreen`，逐屏调用 `NSWorkspace.setDesktopImageURL` 并返回逐屏结果；输入必须是已存在、非符号链接的本地普通文件，单屏异常不会中断其他屏幕。

- 需求：REQ-SYS-001～004。
- 前置：P00-05、P04。
- 步骤：桥接 AppKit；枚举当前 NSScreen；同图设置所有显示器；收集逐屏结果；全失败不改 current；部分失败记录数量并展示重试；确保输入 URL 是已验证本地文件。
- 自动测试：Recording fake 验证编排与 current 事务。
- 人工：单屏、双屏、拔插、多个 Space、文件缺失。
- 验收：不能因一屏失败崩溃；不擅自添加屏幕录制/辅助功能权限。
- 辅佐：[release-checklist.md](../03-support/release-checklist.md)。

- 验收证据：`AppKitDesktopWallpaperSetterTests` 1 项通过，覆盖本地文件、目录、远程 URL、缺失文件校验；current 事务由既有 `SetCurrentWallpaperUseCaseTests` 覆盖全失败/部分失败保护。

## P06-02 登录启动

> 状态：完成（2026-08-19）。已实现 `SMAppLoginItemManager` 与 `LoginItemToggleCoordinator`：映射真实 `SMAppService.mainApp.status`，注册/注销登录项，失败保持旧 UI 状态，外部状态可重新同步。

- 需求：16.2、REQ-SET General。
- 步骤：ServiceManagement adapter；查询真实状态；开启/关闭；失败回滚 UI；后台启动不弹主窗口；系统设置被外部改变时重新同步。
- 测试：success/failure fake、设置回滚。
- 人工：系统登录项面板、重启登录、关闭后再登录。
- 验收：不改变 signing/team 规避注册问题。

- 验收证据：`SMAppLoginItemManagerTests` 3 项通过，覆盖失败回滚、外部状态同步和 ServiceManagement 状态映射。

## P06-03 系统事件流

> 状态：完成（2026-08-19）。已实现 `WorkspaceSystemEventProvider`：监听唤醒/睡眠、应用激活、日期/时区变化，并用 `NWPathMonitor` 发出网络恢复事件；observer 与 monitor 随 AsyncStream 终止取消。领域事件由既有 coordinator 去重合并。

- 需求：12.1、16.3/16.4、NFR-NET-004。
- 步骤：监听睡眠、唤醒、时区/日期、应用激活、网络恢复；转换为领域事件；去抖/合并；事件订阅生命周期正确；退出移除/取消。
- 测试：fake AsyncSequence；事件风暴只触发一次检查。

- 验收证据：`WorkspaceSystemEventProviderTests` 2 项通过，覆盖通知映射和未知通知过滤；P05 `DailyFetchCoordinatorTests` 覆盖事件风暴单次检查。
- 人工：睡眠跨日、时区切换、断网恢复、时间回拨。

## P06-04 Menu Bar

> 状态：完成（2026-08-19）。已实现 `MenuBarStateModel` 与 `MenuBarCommandRouter`：统一路由 Update/Next/Retry、窗口/设置/退出命令，状态覆盖无 current、运行中、idle 和失败可重试。

- 需求：REQ-MENU-001～007。
- 步骤：图标和缩略图/状态；复用共享 Update/Next 命令；打开主窗口置前；打开 Settings 定位；下载中低频状态；失败含重新获取；退出走统一 shutdown。
- 测试：菜单状态模型；命令路由；无当前壁纸/进行中/失败。
- 人工：主窗口关闭后操作、VoiceOver 标签、键盘菜单、图标非持续动画。
- 辅佐：[design-acceptance.md](../03-support/design-acceptance.md)。

- 验收证据：`MenuBarCommandRouterTests` 3 项通过，覆盖共享命令路由、生命周期路由和状态模型。

> P10 联调（2026-08-20）：`MenuBarCommandsView` 已接入共享 `WallpaperCommandCenter`，Update/Next 使用生产工作流；退出调用 `AppServices.shutdown()` 取消事件流、轮播与重试任务。签名沙盒 Menu Bar 真机清单仍待发布环境。

## P06-05 窗口生命周期

> 状态：完成（2026-08-19）。已实现 MainActor `WindowLifecycleCoordinator`：关闭仅隐藏，登录启动保持隐藏，Menu Bar 打开会激活并恢复上次页面，页面选择持久化，shutdown 清理可观察状态。

- 需求：REQ-GLOBAL-001～005。
- 步骤：关闭只隐藏；重新打开恢复上次一级页面；首次 Dashboard；登录启动不显示；Menu Bar 唤起并 activate；真正退出取消内存任务。
- 测试：Coordinator state 路由；lastSelectedNavigation 持久化。
- 人工：红色关闭按钮、Dock 激活、Menu Bar 打开、Cmd+Q/菜单退出。

- 验收证据：`WindowLifecycleCoordinatorTests` 3 项通过，覆盖登录启动/正常启动、页面持久化、关闭隐藏和统一退出。

## P06-06 Finder 与缓存目录集成

> 状态：完成（2026-08-19）。已实现 `FinderCacheDirectoryService`：安全创建并打开管理根目录，只允许管理根目录内既存文件 reveal，路径逃逸、缺失文件、目录不可用和 Finder 打开失败均返回明确错误。

- 需求：REQ-DETAIL-004、REQ-STORE。
- 步骤：只打开/定位应用管理目录内 URL；文件缺失给可执行错误；不请求更广泛目录权限；目录不存在时安全创建或解释。
- 验收：路径逃逸测试失败；不实现本地目录来源。

- 验收证据：`FinderCacheDirectoryServiceTests` 3 项通过，覆盖目录创建/打开、文件 reveal、路径边界和缺失文件；未增加本地目录来源能力。

## 阶段退出条件

所有系统能力先通过 protocol 编排测试，再完成签名沙盒真机清单；entitlement、隐私、签名变化必须在交付摘要单列。
