# 原型与设计审阅

## 1. 审阅结论

产品应采用“macOS 原生交互骨架 + Vivid Lumina 浅色玻璃层级 + 根 DESIGN 的摄影优先与克制原则”，而不是逐像素复刻 HTML 原型。

目标体验：图片是主角；侧栏、工具栏和卡片作为低噪音控制层；Electric Blue 是唯一主交互色；系统减少透明度/动态效果时仍保持可读、可操作、低资源占用。

## 2. Hallmark 预检与自评

Hallmark · pre-emit critique：Philosophy 4 / Hierarchy 4 / Execution 4 / Specificity 5 / Restraint 4 / Variety 3。

本次不生成页面代码；Hallmark 对任务计划的实际影响是：

- 禁止把每页都做成同一种卡片堆叠；Dashboard、Sources、Library、Settings 必须有与任务相符的结构差异；
- 所有交互元素必须覆盖 default、hover、focus、active、disabled、loading、error、success，其中 macOS 不适用的视觉态仍要有等价的行为与辅助技术反馈；
- 视觉令牌先冻结，页面中不得临时发明颜色、字体、圆角和动画；
- 图片、指标和状态数据不得虚构为生产内容；
- 动画必须尊重 Reduce Motion，透明材质必须尊重 Reduce Transparency。

## 3. 输入资产状态

| 资产 | 可用性 | 用途/问题 |
|---|---|---|
| `dashboard_vibe_update/code.html` | 可用 | Dashboard 结构与控件依据 |
| `dashboard_vibe_update/screen.png` | 不可用 | 文件内容是 `<FIFE Image failed to fetch>`，需重导出 |
| `sources_vibe_update/screen.png` | 可用 | 来源卡片、周计划与默认源视觉参考 |
| `library_vibe_update/screen.png` | 可用 | 缩略图网格、选中态与搜索布局参考 |
| `settings_vibe_update/screen.png` | 可用 | 单页分区与控件密度参考 |
| `zikora_filled_logo/screen.png` | 部分可用 | 仅位图展示；缺 AppIcon 全尺寸和可缩放源资产 |
| Menu Bar / Onboarding / Sheet / Detail / 错误态 | 缺失 | P00/P07 前必须补设计或确认采用系统样式 |

## 4. 设计系统冲突裁决

| 轴 | 根 `DESIGN.md` | Vivid Lumina/原型 | V1.0 建议 |
|---|---|---|---|
| 字体 | SF Pro Display/Text | Plus Jakarta Sans + Inter | macOS App 使用系统 SF 字体；不引入 Web 字体依赖 |
| 主色 | `#0066CC` | `#007AFF` / `#0A84FF` | 以 `#007AFF` 语义主色为准，暗/高对比态使用系统动态色 |
| 表面 | 白/灰/近黑，几乎无阴影 | 透明白、模糊、蓝色光晕 | 轻量玻璃材质，静态卡片不堆叠重阴影 |
| 渐变 | 禁止装饰渐变 | 主按钮与背景存在渐变 | 主按钮优先纯色；渐变只可来自品牌图/壁纸内容 |
| 圆角 | 0/8/11/18/胶囊 | 全面圆角、胶囊 | 页面框架尊重 macOS，卡片中圆角，主操作可胶囊 |
| 动画 | 克制按压反馈 | `transition: all`、hover 放大/光晕 | 禁止 `transition all` 思路；只做必要 opacity/scale，窗口应用不过度 hover |
| 内容层级 | 摄影优先 | 玻璃面板覆盖彩色背景 | Dashboard/Library 图片优先，其余页使用安静系统背景 |

这是建议裁决，不等于替用户做最终品牌决定；必须在 P00-03 形成可签字的 Design Decision Record。

## 5. 页面结构提取

### Dashboard

- 固定侧栏 + 页面工具栏；
- 当前壁纸大图为主要面积；
- 图片元数据覆盖在图片内部；
- “立即更新”和“换一张”是并列但语义不同的主操作；
- 底部仅保留“当前模式”“今日来源”两个关键状态，避免仪表盘泛滥。

需修正：原型重复提供侧栏、工具栏和图片内操作，开发时应明确主次并确保同一命令共享状态；原型的渐变按钮、重阴影和大幅 hover 不直接照搬。

### Sources

- 来源卡片 → Weekly Plan → Default Source 的纵向信息架构正确；
- 规格要求显示全部来源，不使用会隐藏停用来源的“Active Sources”语义；
- 必须补周六、周日；
- `Local Collection` 不进入 V1.0；
- 卡片需补 never/loading/success/offline/failed/warning/disabled 状态。

### Library

- 顶部工具栏 + 自适应缩略图网格；
- 当前壁纸用描边、勾选图标和文字/辅助标签共同表示；
- 搜索属于 P1，P0 不应因此阻塞网格；
- 图片标题是原型演示数据，生产模型未定义自动命名策略，需 P00 决策。

### Settings

- General、Wallpaper Rotation、Storage Management、About 单页分区；
- 每日模式要隐藏/禁用顺序与间隔，并保留旧值；
- 保留周期必须补齐 7/14/30/60/90/永久；
- `~/.zikora/cache` 是错误示例，实际显示沙盒容器内的用户友好路径；
- “立即清理”必须先估算、确认，再执行，不能静默删除。

## 6. 必补设计稿/状态包

每项至少提供：正常、加载、空、错误、禁用、键盘焦点、减少透明度、窄窗口版本。

1. Onboarding 三步与中断恢复；
2. Add/Edit Source Sheet 与测试连接全过程；
3. 删除来源/壁纸、立即清理确认对话框；
4. Menu Bar 正常、下载中、失败、无壁纸；
5. Wallpaper Detail；
6. Dashboard 无当前壁纸、下载中、缺少计划、离线；
7. Sources 七天完整计划与来源健康状态；
8. Library 空态、缩略图失败、文件丢失、P1 搜索无结果；
9. Settings 注册登录项失败、无轮播候选、存储错误；
10. 720/800/1024/1280 宽窗口的重排规则。

## 7. 窗口与响应式建议

这是 macOS 桌面应用，不沿用网页的 320/375 手机断点。建议以实际窗口能力定义验收：

- 最小建议窗口：800 × 600；若产品要求更小，需单独设计；
- 800–999：侧栏允许紧凑化，工具栏低频动作收入菜单，网格减列；
- 1000–1279：标准两栏布局；
- ≥1280：限制内容最大宽度，避免设置表单无限拉长；
- 所有宽度不得出现主要操作被裁切、横向滚动或两套重复工具栏；
- 主内容滚动，侧栏和窗口级工具栏保持可访问。

