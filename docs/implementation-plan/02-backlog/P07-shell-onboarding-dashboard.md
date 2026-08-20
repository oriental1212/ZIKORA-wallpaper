# P07 — 应用壳、首次引导与 Dashboard

## P07-01 主应用壳与导航

- 需求：7、8.1、20。
- 步骤：NavigationSplitView/合适 macOS 容器；Dashboard/Sources/Library/Settings；固定侧栏、主内容滚动；恢复 lastSelectedNavigation；统一 toolbar command placement；最小窗口策略。
- 状态：正常、页面加载失败、数据层不可用。
- 验收：800/1000/1280 宽不裁操作；无中英混杂；键盘/VoiceOver 可导航。
- 辅佐：[design-acceptance.md](../03-support/design-acceptance.md)。

## P07-02 Onboarding 路由与恢复

- 需求：REQ-ONB-001～003。
- 步骤：无有效配置进入引导；持久化当前步骤/草稿策略；退出后恢复；已有有效配置不重复；未成功测试来源不可完成。
- 测试：首次/返回/中断/重启/已有配置/损坏草稿。

## P07-03 欢迎与首个来源

- 步骤：实现欢迎页；复用 P08 Source Form，而非复制验证；连接测试显示预览和元数据；输入变化失效；continue 状态。
- 验收：3 分钟内主路径可完成；失败可恢复；网络慢时可取消/反馈。

## P07-04 基础设置与首次任务

- 步骤：默认 login true/daily/30 days；首来源分配七天 + default；事务保存 onboarding complete；进入 Dashboard 后触发首次今日任务；保存失败不出现半完成配置。
- 测试：事务失败、首次任务失败仍可进入可恢复 Dashboard。

## P07-05 Dashboard 正常态

- 需求：REQ-DASH-001～006。
- 步骤：本地原图等比裁切；来源快照、获取时间；共享 Update/Next；当前模式/今日来源/兜底标记；更多菜单按可用性启停。
- 性能：预览使用适合显示尺寸的图，不无界解码全分辨率。
- 验收：图片焦点优先，状态卡仅保留必要信息。

## P07-06 Dashboard 异常与进度态

- 需求：REQ-DASH-007/008、17。
- 覆盖：无当前壁纸、下载中保留旧图、离线、缺少计划、来源错误、存储错误、无本地候选、部分屏幕失败。
- 每态：明确发生什么、恢复 CTA、按钮禁用原因、VoiceOver 状态通知。
- 测试：ViewModel 状态映射；共享命令防重复。

## P07-07 Dashboard 资产修复

- 步骤：重新从批准设计源导出有效 PNG；不得用 HTML 的远程演示图片作为生产资产；记录原型与实现差异。
- 验收：文件可被 `file`/Preview 正确识别；不提交失败占位为设计真相源。

## 阶段退出条件

全新用户可从欢迎到首次下载/失败恢复；已有用户打开 Dashboard；关闭窗口后 Menu Bar 主链路继续。

## 实施记录（2026-08-19）

### 已完成

- P07-01：`NavigationSplitView` 应用壳、Dashboard/Sources/Library/Settings 导航、窄窗口最小尺寸、主内容滚动、导航恢复、Menu Bar 入口。
- P07-02：引导完成标记与来源草稿恢复；启动成功后注入 `SwiftDataRepositoryStore`，已有有效配置不重复进入引导。
- P07-03：首来源连接测试复用 `TestSourceConnectionUseCase`；预览元数据、失败反馈、取消/输入变化失效和未测试不可继续。
- P07-04：默认设置、七天计划、默认来源和 onboarding complete 按保存顺序提交，保存失败不标记完成。
- P07-05/06 基线 UI：Dashboard 空态、更新中、无候选恢复提示及禁用态；Sources/Library/Settings 页面骨架。

### 自动查验证据

- `ZIKORA_DERIVED_DATA=/tmp/zikora-p07-01-derived ./scripts/build`：通过。
- `ZIKORA_DERIVED_DATA=/tmp/zikora-p07-02-derived ./scripts/build`：通过。
- `ZIKORA_DERIVED_DATA=/tmp/zikora-p07-04-derived ./scripts/test`：153 tests / 40 suites 通过。

### 尚需 P06/P10 联调

> 状态：已联调（2026-08-20）。P10 已接入生产 `WallpaperFetchWorkflowUseCase`、`FetchOrchestrator` 与共享 `WallpaperCommandCenter`；Dashboard 与 Menu Bar 的 Update/Next 使用同一生产命令，不再使用演示占位。首次真实下载、部分屏幕失败和系统级生命周期仍保留为 P10 签名沙盒人工验收项。
