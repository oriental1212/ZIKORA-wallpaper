# 新增来源即时同步与页面布局问题评估

> 状态：待审阅，暂未开始编码（2026-08-26）
>
> 范围：新增来源后的即时同步、窗口窄宽防遮挡、Library/来源网格布局、Library 详情返回、搜索操作和 Sources 工具栏精简。

## 1. 评估结论

本次问题分为两类：

1. **数据流时效性**：来源保存成功后，当前链路只写入来源并刷新 Sources 页面，没有立即启动该来源的壁纸抓取。因此“同步成功”和 Library/Dashboard 出现新壁纸要等自动触发、手动切换或其他事件发生。
2. **SwiftUI 容器与固定尺寸不一致**：根视图声明的 `minWidth: 800` 不能保证 `NavigationSplitView` 的侧栏和 detail 同时满足内容最小宽度；Dashboard 的 hero 内容和 Sources/Library 的网格又各自采用了会压缩或自适应的布局策略，窄窗口时因此出现侧栏被挤压、右侧内容裁切或卡片尺寸变化。

建议先按 P0 处理即时同步和窗口防遮挡，再按 P1 处理详情返回、搜索操作和网格布局统一。所有改动保持现有 SwiftUI + ViewModel + Application Use Case 架构，不新增第三方依赖，不调整 entitlement、签名或持久化 schema。

## 2. 现状证据与根因

### 2.1 新来源同步延迟

相关位置：

- `ZIKORA-wallpaper/Features/Sources/SourceFormViewModel.swift`
  - `performSave()` 调用 `SaveSourceUseCase` 后设置 `savedSourceID` 并执行 `onSaved`。
  - 该回调只负责 Sources 页面聚焦并调用 `SourcesViewModel.load()`，没有 fetch command 或 workflow 入口。
- `ZIKORA-wallpaper/Features/Sources/SourcesView.swift`
  - `onSaved` 仅执行 `model.focusSource(id:)` 与页面数据重载。
- `ZIKORA-wallpaper/App/AppServices.swift`
  - 已有生产 `WallpaperFetchWorkflowUseCase`、`FetchOrchestrator` 和共享 `WallpaperCommandCenter`，说明同步能力已经存在，但来源保存链路没有接入。
- `ZIKORA-wallpaper/Application/Fetch/WallpaperFetchWorkflowUseCase.swift`
  - 当前 workflow 根据当天计划来源/默认来源解析抓取对象；普通 `manualUpdate` 并不保证抓取“刚刚新增的来源”。

因此不能简单地在保存后调用现有 Dashboard 的 `updateNow()`，否则新增来源未被设为当天计划或默认来源时，仍可能抓取旧来源。实现阶段应增加一个**针对指定 SourceID 的即时抓取入口**，或在现有 workflow 中以显式 source override 方式扩展任务上下文，并继续复用现有下载、校验、哈希、原子落盘、健康状态和记录机制。

### 2.2 Dashboard 窄窗口遮挡

相关位置：

- `ZIKORA-wallpaper/ContentView.swift` 仅声明 `.frame(minWidth: 800, minHeight: 560)`。
- `ZIKORA-wallpaper/App/AppShellView.swift` 侧栏只声明 `.frame(minWidth: 190)`，但没有明确 `NavigationSplitView` 的列宽策略，也没有在实际 `NSWindow` 内容尺寸上设置下限。
- `ZIKORA-wallpaper/Features/Dashboard/DashboardView.swift` 的 hero 以 `maxWidth: .infinity` 展开，并在窄宽度用 `ViewThatFits` 改成纵向按钮；这只能改变内部排列，不能阻止 split view detail 被压缩到不足以显示的宽度。

根因是“视图局部最小宽度”没有转换成“窗口内容区最小宽度”，且 sidebar/detail 两列没有共享一个可计算的宽度契约。修复应同时覆盖窗口尺寸、split view 列宽和 Dashboard 内部最小可用宽度，避免只提高某一个子视图的 frame 导致另一侧继续被挤压。

### 2.3 Library 详情、网格和搜索

相关位置：

- `ZIKORA-wallpaper/Features/Library/LibraryView.swift`
  - 详情通过 `.sheet(item:)` 展示，`WallpaperDetailView` 只有内容区，没有显式的返回按钮。
  - 网格使用 `GridItem(.adaptive(minimum: 180, maximum: 260))`，卡片宽度会随可用宽度变化，符合“自适应尺寸”而非本次要求的固定卡片尺寸。
  - 搜索为输入即过滤，没有显式“搜索”和“重置”操作。
- `ZIKORA-wallpaper/Features/Library/LibraryViewModel.swift`
  - `setSearchText` 通过 300ms debounce 直接修改 `filteredWallpapers`，没有“待搜索文本”和“已应用查询”两个状态。

需要先确定卡片固定尺寸，再根据可用宽度计算能容纳的列数；列数变化时换行，卡片自身不缩放。搜索 UI 可以保留 debounce 作为输入体验，也可改为显式提交；本次建议采用“输入框 + 搜索按钮提交 + 重置按钮清空并恢复全量”的明确状态，避免按钮与实时过滤状态互相矛盾。

### 2.4 Sources 网格和重复的 More

相关位置：

- `ZIKORA-wallpaper/Features/Sources/SourcesView.swift` 的来源网格使用 `GridItem(.adaptive(minimum: 420, maximum: 420))`，`SourceCardView` 又固定为 `420 × 156`。卡片尺寸本身已固定，但列数/可用宽度的契约没有集中管理，需与 Library 使用同一套“固定 item 尺寸、按列数换行、左上对齐”的规则。
- `ZIKORA-wallpaper/Features/Sources/SourceCardView.swift` 的卡片固定宽高和内部 `ViewThatFits` 应保留；窗口变窄时应改变列数，而不是改变卡片宽度或让首列偏移。
- `SourcesView.swift` 工具栏同时有独立的新增、刷新按钮，以及包含同样操作的 `sources.more` 菜单。按需求删除 More 菜单，保留已有的新增和刷新入口。

## 3. 建议实施方案

### P0-A：保存来源后即时抓取指定来源

1. 在应用层为“抓取指定来源”定义最小、可测试的入口。优先复用现有 `WallpaperFetchWorkflowUseCase` 的下载/校验/落盘流程，避免复制一套同步逻辑。
2. 任务上下文携带 `requestedSourceID`（或等价的显式来源解析参数），保存来源成功后由 `SourcesView`/专用 coordinator 发起异步任务。
3. 保存流程与抓取流程解耦：来源保存成功即可关闭表单并显示“已添加/正在同步”；抓取完成后通过共享状态或页面刷新使新壁纸立即出现在 Library，并更新来源的 `lastFetchStatus`、`lastFetchAt` 和错误信息。
4. 继续由 `FetchOrchestrator` 串行化任务；若已有自动/手动抓取正在执行，不启动重复任务，改为复用当前任务结果或在当前任务结束后刷新页面。
5. 失败要显示可恢复的来源级错误，不回滚已经成功保存的来源；取消、网络失败、图片校验失败和重复内容都沿用现有错误映射。
6. 需要补充：指定来源成功、指定来源失败、并发抓取、重复内容、保存成功但抓取失败，以及 Library 在抓取完成后及时重载的测试。

### P0-B：建立真实窗口最小尺寸契约

1. 将窗口内容区最小宽度按“侧栏最小宽度 + detail 最小宽度 + split 间距/边界”计算，建议初始值约为 `1,080`，最小高度约为 `650`；最终数值以人工截图验证为准。
2. 在 `NavigationSplitView` 上声明稳定的 sidebar 列宽（建议 210–240 范围），detail 保证最小可用宽度；不要只依赖根 `frame(minWidth:)`。
3. 若 SwiftUI 声明不足以约束实际窗口，增加现有 AppKit 生命周期中的最小 `NSWindow.contentMinSize` 设置，并确认不会影响菜单栏唤起、窗口恢复和首次引导窗口。
4. Dashboard hero 在 detail 最小宽度下保持完整显示：信息与按钮允许纵向排列，但不使用会把右侧内容推出可视区域的固定横向布局；外层滚动区域继续负责高度方向滚动。
5. 验收宽度至少覆盖：最小宽度、比最小宽度大 80、常规宽度和超宽窗口；确认侧栏完整、hero 右边缘不裁切、按钮可点击。

### P1-A：统一固定尺寸网格规则

抽取一个轻量的布局计算规则（可先作为 UI 层私有 helper，不引入大范围设计系统改造）：

```text
availableWidth → floor((availableWidth + spacing) / (itemWidth + spacing)) → max(1, columnCount)
```

- Library：固定壁纸卡片宽度（建议沿用当前缩略图目标宽度附近的 240–260），固定缩略图比例；窗口宽度只影响列数。
- Sources：固定来源卡片 `420 × 156`；从左到右、从上到下排列，首列和首行锚定容器左上角。
- 两个页面都使用 `GeometryReader`/尺寸读取只计算列数，不改变 item 宽度；列数变化时由 `LazyVGrid` 换行。
- 对窄于单个 item 的 detail 内容，保留纵向滚动或让 detail 最小宽度生效，不能通过压缩 item 来“适配”。

### P1-B：Library 详情返回与搜索操作

1. 在 `WallpaperDetailView` 顶部增加明确的返回按钮（`chevron.left` + 本地化标题），调用现有 `dismiss`，同时保留 macOS sheet 原生关闭能力。
2. 在搜索框右侧增加“搜索”和“重置”按钮：搜索应用当前文本，重置清空文本并恢复全部壁纸；按钮在无效/无操作时有明确禁用状态。
3. ViewModel 分离 `searchInput` 与 `searchText`（或等价命名），为提交、重置、空结果和已应用查询补充单元测试。
4. 统一按钮触发的加载/刷新反馈，确保搜索操作不触发不必要的缩略图重建。

### P1-C：Sources 工具栏精简

删除 `sources.more` 菜单及其重复的新增/刷新菜单项，保留现有独立的新增和刷新按钮；不删除卡片内的编辑、删除和开关操作。

## 4. 验收标准

### 即时同步

- 新增来源保存成功后，表单立即关闭并显示进行中状态；无需切换壁纸、重启应用或等待下一次自动调度。
- 指定来源成功下载并落盘后，Library 能在本次任务结束后自动显示新壁纸，Sources 能显示成功时间和状态。
- 失败时来源仍保留，页面显示来源级错误；再次点击重试不会产生并发重复抓取。

### 窗口与布局

- 窗口不能缩小到遮挡侧栏或裁切 Dashboard hero 右侧内容；达到最小限制时侧栏仍完整可见。
- Library 壁纸卡片的宽高在窗口拖拉过程中保持不变，仅列数发生变化；不足一行时从下一行继续排列。
- Sources 卡片遵循相同排列方向，左上起始位置稳定，窗口变宽/变窄不改变卡片尺寸。
- Library 详情有可见且可访问的返回按钮。
- 搜索按钮执行搜索，重置按钮清空并恢复列表。
- Sources 页面不存在与独立按钮重复操作的 More 菜单。

## 5. 测试与验证计划

### 自动化

- 扩展 `ZIKORA-wallpaperTests/Application/`：指定来源任务上下文、并发去重、成功/失败状态结算。
- 扩展 `ZIKORA-wallpaperTests/Features/SourcesViewModelTests.swift`：保存后的刷新回调/状态刷新，以及来源失败不回滚。
- 扩展 `ZIKORA-wallpaperTests/Features/LibrarySettingsViewModelTests.swift` 或新增 Library 专用测试：搜索提交、重置、空结果和查询状态。
- 增加固定 item 宽度下的列数计算纯函数测试，覆盖单列、整除、余量不足和极窄宽度。
- 执行 `./scripts/test` 与 `./scripts/build`，再执行 `git diff --check`。

### 人工 UI 验收

- 启动应用后拖拉到最小宽度、最小宽度 + 80、常规宽度和宽屏，逐页检查 Dashboard、Library、Sources。
- 新增一个启用来源，观察保存反馈、Sources 健康状态、Library 新壁纸出现时间及 Dashboard 当前壁纸刷新。
- 反复拖拉窗口并滚动，确认无水平裁切、卡片跳动、首列/首行偏移和详情无法返回。

## 6. 待审阅决策

1. 新增来源后是否**无条件立即抓取该来源**，还是只有来源启用时抓取？
   - 已确认：启用来源立即抓取，禁用来源只保存不抓取。
2. 即时抓取成功后是否自动将该壁纸设为当前桌面？
   - 已确认：不自动将该壁纸设置为当前桌面，只加入图库。
3. Library 固定卡片宽度选 240、250 还是 260？
   - 已确认：采用本评估方案，当前实现取 `250`。
4. 最小窗口最终宽度是否接受约 1,080？
   - 已确认：接受，作为防止侧栏和 Dashboard 内容遮挡的最小窗口宽度。
