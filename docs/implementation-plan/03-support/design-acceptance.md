# 视觉、交互与状态验收

## 1. 锁定的方向

- 信息架构服从需求规格和四套原型；
- 视觉采用原生 macOS 骨架、浅色 Vivid Lumina 材质、单一 Electric Blue 交互色；
- 菜单栏默认中文，不直接显示本地化 key；
- 页面颜色不得退化为默认系统灰；
- Dashboard 与 Library 摄影优先，Sources 与 Settings 信息可读优先；
- SF 系统字体，不额外捆绑 Plus Jakarta Sans/Inter；
- 玻璃、阴影、渐变和 hover 都是可删的装饰，不能损害性能/可访问性。

## 2. Token 验收

必须建立并只使用语义 token：

- color：background/surface/elevated/glass/text/secondaryText/primary/error/warning/success/focus/border；
- 主交互色使用 Electric Blue `#007AFF`，浅色背景基线使用 `#f9f9ff`，表面和分隔线使用 Vivid Lumina 语义色；
- typography：pageTitle/sectionTitle/body/label/caption/monospacedMetadata；
- spacing：4pt 或 8pt 一致尺度；
- radius：control/card/pill，不随页面临时发明；
- material：sidebar/toolbar/card + reduceTransparency fallback；
- motion：press/stateChange/progress + reduceMotion fallback。

不允许 SwiftUI 页面散落原型 hex、随意 shadow 或每页不同圆角。

## 3. 通用控件八态

对 Button、Toggle、Picker、TextField、Search、Card Action 明确：

1. default；
2. hover（只辅助鼠标，不承载唯一信息）；
3. focus（可见 focus ring）；
4. active/pressed；
5. disabled（含原因/help）；
6. loading（防重复提交）；
7. error（文字 + 恢复动作）；
8. success（安静、可被辅助技术感知）。

macOS 原生控件已提供的状态优先沿用，不为追求网页外观重画完整控件行为。

## 4. 页面验收

### App Shell

- 侧栏与一级导航稳定；主内容独立滚动；
- 侧栏当前导航项使用 Electric Blue 选中态，未选中项保持低对比；
- 当前页面可被 VoiceOver 识别；
- 800/1000/1280 宽无横向滚动或裁切；
- toolbar 低频动作在窄宽度合理收纳，不出现重复两套主操作。

### Dashboard

- 当前壁纸占主要视觉面积，等比裁切且不变形；
- 浮层文字在任何图片上可读；
- 下载中保留旧图片；
- Update 与 Next 的语义/图标/状态明确不同；
- 兜底来源明确标注。

### Sources

- 全部来源可见，停用不消失；
- 七天完整；今天、停用引用、缺失引用可区分；
- URL 显示安全截断，复制反馈明确；
- 连接测试进度和错误不会挤乱表单布局。

### Library

- current 同时有描边/图标/辅助标签；
- 缩略图比例稳定，失败占位不导致网格跳动；
- 1,000 条仍懒加载；
- 单击不意外更换系统壁纸。

### Settings

- 表单行对齐、最大宽度适宜；
- daily 时 rotation 子项隐藏/禁用含解释；
- destructive “立即清理”视觉与普通操作区分且二次确认；
- About 不显示无目标链接。

### Menu Bar / Onboarding / Dialog

- 使用 macOS 熟悉的菜单与对话框语法；
- Menu Bar 中文文案为“立即更新”“换一张”“打开仪表盘”“设置”“退出”，失败状态不显示 key；
- Menu Bar 下载状态不高频动画；
- Onboarding 主操作顺序清晰，可返回/恢复；
- 确认框明确对象和后果。

## 5. 可访问性与系统偏好

- 图标按钮有 accessibility label 和 help/tooltip；
- 状态使用文字或图标，不只靠颜色；
- Full Keyboard Access 下 Tab 顺序等于视觉顺序；
- focus ring 对比明显且不动画延迟；
- Reduce Transparency 时玻璃换为足够不透明的动态表面；
- Reduce Motion 时移除 hover 放大/位移，仅保留必要淡入或系统默认；
- Increase Contrast 下 border/文字仍可辨；
- 图片 metadata 浮层达到可读对比。

## 6. 内容真实性

- 原型中的 Bing/NASA/Unsplash/Pexels/Reddit、图片标题与缓存大小均是演示数据，不得当作默认生产事实；
- 无真实链接时不显示 Feedback/GitHub；
- 无设计母版时不把失败占位或截图冒充最终品牌资产；
- 所有中文术语服从规格第 5 章。
