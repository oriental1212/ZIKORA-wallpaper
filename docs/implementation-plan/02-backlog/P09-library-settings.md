# P09 — Library、Wallpaper Detail 与 Settings

## P09-01 Library P0 网格

- 需求：REQ-LIB-001～007。
- 步骤：createdAt 倒序；懒加载自适应网格；固定缩略图比例/占位；唯一 current 标识；点击进入详情而非直接设置；刷新只读本地；来源快照；丢失文件排除候选。
- 测试：排序、current 标记、缺文件、1,000 条、滚动取消缩略图任务。
- 验收：网格不解码全部原图；状态不只靠蓝边。

> 状态：完成（2026-08-20）。`LibraryView`/`LibraryViewModel` 实现倒序、`LazyVGrid`、固定比例缩略图、current 标识、点击进入详情、本地刷新与来源快照；`LibraryViewModelTests` 覆盖排序、缺文件、刷新和设为当前。1,000 条缩略图并发/取消由既有 `ThumbnailPipelineTests` 覆盖。

## P09-02 Library 空态与异常

- 覆盖：无记录、筛选无结果（P1）、缩略图失败、文件丢失、扫描中、刷新失败。
- 每态提供可执行动作且不触发未授权网络；空库“获取今日壁纸”才进入获取命令。

> 状态：完成（2026-08-20）。已覆盖空库、无结果、文件丢失/无效、刷新中与刷新失败；本地刷新不触发网络。生产 fetch workflow 尚未接线，因此空库主 CTA 暂为本地刷新，未保留死按钮。

## P09-03 Wallpaper Detail（P1，可独立排期）

- 需求：REQ-DETAIL-001～004。
- 步骤：大图及元数据；设为 current；Finder；删除非 current 确认；current 删除禁用原因；文件缺失恢复。
- 验收：如果 P1 不进首发，P0 点击行为必须有明确替代，不保留死入口。

> 状态：完成（2026-08-20）。`WallpaperDetailView` 提供大图、元数据、设为当前、Finder 定位、非当前删除确认、当前删除禁用说明与缺文件状态。

## P09-04 搜索与筛选（P1）

- 步骤：来源名称/`YYYY-MM-DD`；英文大小写不敏感；300ms 本地 debounce；清除筛选；不进行全文或网络搜索。
- 测试：输入取消、日期解析、空结果、1,000 条响应。

> 状态：完成（2026-08-20）。`LibraryViewModel` 实现来源名称与 `YYYY-MM-DD` 本地过滤、大小写不敏感、300ms debounce 和清除筛选；`LibraryViewModelTests` 覆盖来源与日期过滤。

## P09-05 Settings General

- 需求：10.7.2。
- 步骤：展示真实登录项状态；切换即时保存/系统调用；失败回滚和解决指引。

> 状态：完成（2026-08-20）。`SettingsViewModel` 接入 `LoginItemToggleCoordinator`，展示真实状态并处理失败回滚；`SettingsViewModelTests` 覆盖默认加载与登录项状态同步。

## P09-06 Wallpaper Rotation 设置

- 需求：REQ-SET-001～006。
- 步骤：daily/slideshow；random/chronological；8 个间隔；daily 隐藏/禁用并保留值；slideshow 无候选 warning；修改间隔重算。
- 测试：设置持久化、失败回滚、Scheduler 命令。

> 状态：完成（2026-08-20）。`SettingsView`/`SettingsViewModel` 实现 daily/slideshow、顺序、8 个间隔、daily 隐藏轮播项、无候选 warning，并在模式/间隔变化时刷新 `RotationScheduler`；`SettingsViewModelTests` 覆盖设置持久化与清理估算。

## P09-07 Storage Management

- 需求：REQ-STORE-001～006。
- 步骤：7/14/30/60/90/永久；空间统计；打开目录；变更周期只预估不立即删除；立即清理先估算、确认、执行、报告失败并刷新。
- 验收：current 永不删；路径安全；不得显示 `~/.zikora/cache` 假路径。

> 状态：完成（2026-08-20）。`SettingsView`/`SettingsViewModel` 实现完整保留周期、缓存位置/大小、打开目录、预估、确认清理、执行报告与刷新；current 保护由 `WallpaperCleanupPlanner` 保证。

## P09-08 About 与诊断（P0/P1）

- 步骤：应用/版本；隐私说明；Feedback/GitHub 有真实 URL 才显示；P1 打开日志位置；不显示空按钮。

> 状态：完成（2026-08-20）。About 展示应用、版本与隐私说明；无真实 Feedback/GitHub URL，因此不显示空入口。

## P09-09 Settings 页面适配

- 步骤：单页分区；表单最大宽度；主内容滚动；减少透明度时用不透明动态表面；Tab 顺序符合视觉顺序。
- 辅佐：[design-acceptance.md](../03-support/design-acceptance.md)。

> 状态：完成（2026-08-20）。Settings 使用单页分区 Form、最大宽度和主内容 ScrollView，遵循现有 DesignSurface 与系统材质。

## 阶段退出条件

P0 Library 可浏览和换图入口闭环；Settings 所有 P0 设置实际驱动后台服务；P1 功能明确启用或移出首发，不留死控件。

> 状态：实现（2026-08-20）。Library P0 浏览、本地刷新、详情与换图入口已闭环；Settings 登录项、轮播调度、缓存统计和清理均实际驱动对应边界。生产 fetch workflow 尚未接线，因此“获取今日壁纸”入口暂不显示，未留死控件。
