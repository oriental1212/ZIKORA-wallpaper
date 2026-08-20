# P10-09 UI 视觉对齐与菜单栏中文本地化补收

日期：2026-08-20  
状态：已完成代码实现与自动化验证；UI 截图/真机人工验收待发布环境执行  
归属阶段：P10  
关联执行卡：[P10-quality-release.md](../02-backlog/P10-quality-release.md)

## 1. 目标

在既有功能测试和发布候选基础上，补收用户验收中发现的两类 UI 问题：

1. 菜单栏在中文系统下仍显示英文，失败状态可能直接显示字符串 key。
2. 当前 UI 使用默认 macOS 系统灰色，与 `prototype/` 中 Vivid Lumina 浅蓝玻璃风格不一致。

## 2. 需求与依据

需求：

- `REQ-MENU-001～007`
- `REQ-DASH-001～008`
- `REQ-SRC-001～011`
- `REQ-LIB-001～007`
- `REQ-SET-001～006`
- `NFR-A11Y-002 / 004 / 005`
- 需求规格说明书第 20 章 UI 视觉与适配要求

依据：

- [Vivid Lumina 设计令牌](../../../prototype/vivid_lumina/DESIGN.md)
- [Dashboard 原型](../../../prototype/dashboard_vibe_update/code.html)
- [Sources 原型](../../../prototype/sources_vibe_update/code.html)
- [Library 原型](../../../prototype/library_vibe_update/code.html)
- [Settings 原型](../../../prototype/settings_vibe_update/code.html)
- [设计审阅](../00-analysis/design-and-prototype-audit.md)
- [ADR-0003 原生设计系统](../00-analysis/decisions/ADR-0003-native-design-system.md)
- [视觉、交互与状态验收](design-acceptance.md)

## 3. 范围约定

- 采用 macOS 原生交互骨架，不逐像素复刻 HTML 原型。
- 采用 Vivid Lumina 颜色和轻量玻璃材质，但保留 Reduce Transparency、Reduce Motion、高对比度降级。
- 不引入 Plus Jakarta Sans 或 Inter，继续使用系统字体。
- 不使用装饰性渐变、大面积 glow 或重阴影。
- 主交互色统一为 Electric Blue `#007AFF`。
- 不重写业务 ViewModel 或 Use Case。
- 不修改持久化 schema、签名、entitlements 或最低系统版本。

## 4. 任务拆解

### T1 修复菜单栏中文本地化

相关文件：

- `ZIKORA-wallpaper.xcodeproj/project.pbxproj`
- `ZIKORA-wallpaper/App/MenuBarCommandsView.swift`
- `ZIKORA-wallpaper/Resources/Localizable.xcstrings`

步骤：

1. 将项目 `knownRegions` 增加 `zh-Hans`。
2. 修复菜单栏失败/通知文案，使用 `LocalizedStringKey` 而不是 `rawValue`。
3. 核对菜单栏所有入口均使用已存在的本地化 key。

验收：

- 中文系统下显示“立即更新”“换一张”“打开仪表盘”“设置”“退出”。
- 失败或无候选状态不显示类似 `error.network-unavailable.title` 的原始 key。

### T2 对齐 Vivid Lumina 设计令牌

相关文件：

- `ZIKORA-wallpaper/DesignSystem/Tokens/DesignTokens.swift`
- `ZIKORA-wallpaper/DesignSystem/Tokens/DesignSurface.swift`
- `ZIKORA-wallpaper/Assets.xcassets/AccentColor.colorset/Contents.json`

步骤：

1. 建立 Vivid Lumina 语义颜色：
   - `background` `#f9f9ff`
   - `surface` `#ffffff` 或等价浅色表面
   - `elevatedSurface` `#f1f3fe`
   - `primaryAction` `#007AFF`
   - `primaryContainer` `#0070eb`
   - `secondary` `#005ab3`
   - `primaryText` `#181c23`
   - `secondaryText` `#414755`
   - `separator` `#c1c6d7`
   - `focus` `#007AFF`
   - `glassSurface` 半透明白
   - `glassBorder` 半透明白边框
2. 调整 `DesignSurface`，侧栏、工具栏和卡片使用克制玻璃材质。
3. 同步 `AccentColor` 资源。
4. 保留系统暗色、高对比和 Reduce Transparency 分支。

验收：

- 页面不再以默认系统灰为主色。
- Electric Blue 成为唯一主交互色。
- 关闭透明度时仍有足够不透明的可读表面。

### T3 调整 App Shell 侧栏

相关文件：

- `ZIKORA-wallpaper/App/AppShellView.swift`

步骤：

1. 保留 `NavigationSplitView` 原生结构。
2. 将侧栏背景改为浅色玻璃材质。
3. 当前导航项使用 Electric Blue 圆角选中态。
4. 未选中项使用低对比文字和浅色 hover 状态。
5. ZIKORA 品牌区保持简洁，不加入未定义英文副标题。

验收：

- 四个一级页面在 800、1000、1280 宽度下均可用。
- 当前页面选中态明确，不依赖颜色单独表达。

### T4 对齐 Dashboard

相关文件：

- `ZIKORA-wallpaper/Features/Dashboard/DashboardView.swift`

步骤：

1. 当前壁纸作为主要视觉区域，使用较大的 Hero 高度和圆角裁切。
2. 图片内显示来源名称、日期和分辨率。
3. 主操作“立即更新”和“换一张”使用胶囊按钮。
4. 底部只保留“当前模式”和“今日来源”两个低噪音状态卡。
5. 下载中保留旧图片，加载状态不覆盖整个 Hero。

验收：

- Dashboard 与原型结构一致，图片优先。
- 图片浮层文字在浅色和深色图片上均可读。
- Update 和 Next 的语义、图标和加载状态明确不同。

### T5 对齐 Sources

相关文件：

- `ZIKORA-wallpaper/Features/Sources/SourcesView.swift`
- `ZIKORA-wallpaper/Features/Sources/SourceCardView.swift`
- `ZIKORA-wallpaper/Features/Sources/WeeklyPlanSection.swift`
- `ZIKORA-wallpaper/Features/Sources/DefaultSourceSection.swift`

步骤：

1. 来源卡片改为轻量玻璃卡片，突出名称、URL、开关和同步时间。
2. 保持所有来源可见，包括停用来源。
3. 周计划和默认源面板统一使用圆角玻璃表面。
4. 状态使用图标和文字共同表达。

验收：

- Sources 信息层级与原型一致。
- 停用、缺失、今日、默认源等状态清晰可辨。

### T6 对齐 Library

相关文件：

- `ZIKORA-wallpaper/Features/Library/LibraryView.swift`
- `ZIKORA-wallpaper/DesignSystem/Components/WallpaperThumbnail.swift`

步骤：

1. 网格项改为图片优先，来源名称和日期放在图片下方。
2. 当前壁纸使用 Electric Blue 描边和勾选标记，同时保留辅助标签。
3. 搜索框使用浅色胶囊样式。
4. 缩略图比例稳定，失败占位不引起网格跳动。

验收：

- Library 网格视觉与原型接近。
- 当前壁纸标记不依赖颜色单独表达。
- 1000 条记录场景下仍保持懒加载。

### T7 对齐 Settings

相关文件：

- `ZIKORA-wallpaper/Features/Settings/SettingsView.swift`

步骤：

1. 保留原生 `Form` 分区节奏。
2. 应用新的背景、分区、开关和主色。
3. “立即清理”继续作为破坏性操作，并保留二次确认。
4. About 区域保持无虚构链接和英文残留。

验收：

- Settings 与原型视觉一致但不牺牲 macOS 原生可访问性。
- 每日模式下的轮播相关设置隐藏或禁用逻辑不变。

### T8 验证与收口

步骤：

1. 运行 `./scripts/test`。
2. 运行 `ZIKORA_CONFIGURATION=Debug ./scripts/build`。
3. 如环境允许，运行 `./scripts/check`。
4. 在中文系统或 `AppleLanguages=zh-Hans` 场景检查菜单栏和主页面。
5. 运行 `git diff --check`。

验收：

- 现有业务测试通过。
- Debug 构建通过。
- 无签名、entitlement、最低系统版本或 bundle identifier 变更。
- 最终 diff 仅涉及视觉和本地化相关文件。

## 5. 交付物

- 更新后的设计 token 与材质实现。
- 四个一级页面及 App Shell 的视觉对齐结果。
- 菜单栏中文显示修复。
- 构建、测试和 `git diff --check` 结果。
- 如有条件，保留 800/1000/1280 三档截图。

## 6. 风险

- Vivid Lumina 玻璃材质若过度使用，可能影响可读性、性能和系统偏好一致性。
- 深色模式或高对比模式下需要额外验证。
- 菜单栏本地化依赖 Xcode 对 `zh-Hans` 的打包配置，需实际构建后确认。

## 7. 完成条件

- T1～T8 全部完成。
- [视觉、交互与状态验收](design-acceptance.md) 中的新增检查项通过。
- [发布与人工验收清单](release-checklist.md) 中的新增 UI/本地化检查项完成或明确标注未执行原因。
- `P10-quality-release.md` 中 P10-09 状态更新为完成，并记录真实命令和结果。

## 8. 已执行验证

- `ZIKORA_DERIVED_DATA=/tmp/zikora-p10-09-derived ./scripts/build`：Debug 构建通过。
- `ZIKORA_DERIVED_DATA=/tmp/zikora-p10-09-derived ./scripts/test`：177 项 / 46 套件通过。
- `ZIKORA_DERIVED_DATA=/tmp/zikora-p10-09-check-derived ./scripts/check`：Debug 测试通过，Release 构建通过。
- `jq empty ZIKORA-wallpaper/Resources/Localizable.xcstrings`：通过。
- `git diff --check`：通过。

未执行：800/1000/1280 截图、中文系统菜单栏真机检查和 Reduce Transparency/Motion 真机检查；原因与既有发布要求一致，需有 GUI/发布环境。
