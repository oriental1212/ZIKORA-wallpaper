# 资料基线、范围与仓库现状

## 1. 来源优先级

本计划按以下顺序裁决冲突：

1. `ZIKORA-wallpaper_需求规格说明书_V1.0.md`：功能、状态、验收与 V1.0 范围的直接依据；
2. `prototype/*/code.html` 与有效 `screen.png`：页面层级、视觉比例和控件位置；
3. `prototype/vivid_lumina/DESIGN.md`：原型实际采用的颜色、字体、圆角和玻璃材质；
4. 根 `DESIGN.md`：克制、摄影优先、单一蓝色交互色和系统字体等补充原则；
5. `ZIKORA-wallpaper_PRD_V1.0.md`：规格说明书未覆盖时回查，不反向覆盖已裁决条目；
6. macOS 人机界面惯例与仓库约束。

任何实现若改变上述裁决，应先在 [open-decisions.md](open-decisions.md) 记录新决定、原因、日期和影响任务。

## 2. V1.0 边界

### P0

- 远程图片直链来源的增删改、启停和测试；
- 周一至周日计划与单一默认来源；
- 每日获取、三次自动尝试、一次默认来源兜底；
- 内容 Hash 去重、原子落盘、缓存过期清理；
- 每日/循环两种模式，随机/时间顺序与规定间隔；
- 所有显示器使用同一壁纸；
- 登录启动、Menu Bar、关闭窗口后后台继续；
- Dashboard、Sources、Library、Settings 主框架；
- 关键 Loading/Success/Empty/Offline/Error/Disabled/Warning/Missing 状态。

### P1（与 P0 隔离）

- Library 搜索/筛选；
- Wallpaper Detail 完整元数据、Finder 定位和删除；
- 打开诊断日志位置；
- 规格中标注 P1 的增强能力。

### 明确不做

本地目录源、RSS/HTML/JSON 解析、动态壁纸、AI 生成、账号/云同步、多显示器独立策略、收藏评分、来源优先级链和 iCloud Sync。

## 3. 仓库现状

| 项 | 当前状态 | 实施影响 |
|---|---|---|
| 工程 | `ZIKORA-wallpaper.xcodeproj` | 无 workspace、无 SwiftPM 依赖 |
| Scheme/Target | `ZIKORA-wallpaper` / App + `ZIKORA-wallpaperTests` | P01 已建立 Unit Test target |
| 生命周期 | SwiftUI `App` + `WindowGroup` | Menu Bar、关闭隐藏、系统事件需补生命周期协调层 |
| UI | `ContentView` 模板 | 无已有架构可迁移，需先建壳与设计系统 |
| 语言设置 | `SWIFT_VERSION = 5.0` | 不得擅自切 Swift 6；需保持现有 approachable concurrency 设置 |
| Actor 设置 | `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` | 后台服务必须明确隔离，避免把 Hash/磁盘/解码放到主 actor |
| 最低系统 | `MACOSX_DEPLOYMENT_TARGET = 14.0` | P00 已确认；Debug/Release/Test 一致 |
| 沙盒 | `ENABLE_APP_SANDBOX = YES` | 网络、缓存、Finder、壁纸设置须在沙盒下逐项验证 |
| 文件访问 | 无用户选择文件 entitlement（2026-08-20 已移除原 `ENABLE_USER_SELECTED_FILES = readonly`） | V1.0 不实现本地目录来源 |
| 数据层 | 无 | 需决定 SwiftData/Core Data/其他方案 |
| 测试 | Swift Testing Unit Test target | P01-01 已建立无网络/真实系统依赖的 smoke test |
| 依赖 | 无第三方依赖 | 计划默认只使用 Apple frameworks |
| 本地化 | English/简体中文 String Catalog | P01-05 已建立统一术语与错误消息键 |

工程使用 `PBXFileSystemSynchronizedRootGroup`，在同步目录内新增 Swift 文件通常会自动进入 target；仍应通过 `xcodebuild` 验证 target membership，不应机械重写 `project.pbxproj`。

## 4. 当前验证结果

已执行：

```bash
xcodebuild -project ZIKORA-wallpaper.xcodeproj -list
```

结果：成功识别一个 target 和一个 scheme。

已执行基线 build：

```bash
xcodebuild \
  -project ZIKORA-wallpaper.xcodeproj \
  -scheme ZIKORA-wallpaper \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/zikora-wallpaper-plan-derived \
  CODE_SIGNING_ALLOWED=NO \
  build
```

首次在受限沙盒内运行时，命令失败于 Swift Preview 宏插件无法写编译缓存（`sandbox_apply: Operation not permitted`）。随后使用相同源码和参数在获批的沙盒外构建环境重跑，结果为 `BUILD SUCCEEDED`。这确认当前源码基线可构建，首次失败属于执行环境限制。

P00 隔离 Spike 也已执行：

```bash
swift run \
  --package-path Spikes/P00 \
  --scratch-path /tmp/zikora-p00-spikes \
  P00Spikes
```

结果：SwiftData save/reopen、来源删除后的历史保留、ImageIO 校验、流式大小上限及 macOS 系统 API 编译检查全部通过。签名沙盒网络、实际设置桌面壁纸和登录项注册仍属于人工验证，未由只读 Spike 代替。

P01 CI 等价入口也已执行：

```bash
ZIKORA_DERIVED_DATA=/tmp/zikora-p01-check-derived ./scripts/check
```

结果：18 项 Swift Testing 测试全部通过，随后 Release 无签名构建成功。Xcode 仅报告未链接 AppIntents 时跳过元数据提取的预期警告；未修改签名、entitlement 或依赖。

## 5. 需求规模判断

这是一个“后台状态机 + 文件一致性 + macOS 系统集成 + 多页面 UI”的完整应用，不适合先做四张静态页面再补逻辑。主风险由高到低为：

1. 获取任务幂等、重试恢复和并发互斥；
2. 文件/元数据一致性与安全删除；
3. 睡眠、唤醒、跨日、时区和网络恢复事件；
4. 桌面壁纸、多显示器、登录项与窗口/Menu Bar 生命周期；
5. 原型缺失状态与视觉系统冲突；
6. 1,000 张历史图片下的缩略图、内存和滚动性能。

因此关键路径先完成领域和系统 Spike，再接入正式 UI。
