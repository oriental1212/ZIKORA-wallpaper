# P01 — 工程与质量底座

## P01-01 建立测试 target 与命令

> 状态：完成。已采用 Swift Testing，加入共享 scheme、Domain smoke test、fixture 目录，并通过无签名 CLI test。

- 需求：所有可测试需求。
- 前置：P00-01。
- 步骤：新增 Unit Test target；沿用选定的 XCTest 或 Swift Testing，不混用风格；加入第一个纯 Domain 测试；配置 scheme test；记录无签名 CLI 命令。
- 交付：测试 target、smoke test、测试 fixture 目录。
- 验收：空白 checkout 可运行 build/test；测试不依赖个人目录、网络或真实系统壁纸。
- 辅佐：[test-matrix.md](../03-support/test-matrix.md)、[definition-of-done.md](../03-support/definition-of-done.md)。

## P01-02 建立依赖容器与测试替身

> 状态：完成。已建立 runtime/repository/network/file/system 协议、`AppEnvironment`、Preview 固定依赖、顺序 Fake 与五类 in-memory Repository 基础；App 根场景注入同一环境引用。

- 步骤：定义 Clock、Calendar、UUID、Random、Repositories、network/file/system protocols；生产依赖从 AppEnvironment 组装；Preview/Test 使用 in-memory Fake；确保同一实例共享给主窗口和 Menu Bar。
- 交付：`AppEnvironment`、协议与 Fake 基础。
- 验收：View 不直接创建 URLSession/FileManager/NSWorkspace；测试可固定日期、星期和随机结果。
- 辅佐：[architecture-blueprint.md](../01-architecture/architecture-blueprint.md)。

## P01-03 错误、日志与用户消息骨架

> 状态：完成。已建立 15 类稳定错误码、恢复动作、本地化用户消息、统一操作提示、分类日志 facade 与 URL 脱敏，并以参数化测试覆盖全部错误映射。

- 需求：17、21、NFR-SEC-004。
- 步骤：建立 domain error code、可恢复动作和用户消息映射；Logger category；URL 脱敏；统一操作结果/提示模型。
- 交付：错误 taxonomy、日志 facade、错误到文案映射测试。
- 验收：不只抛字符串；底层错误不直接显示给用户；日志不含二进制或完整敏感 query。
- 辅佐：[design-acceptance.md](../03-support/design-acceptance.md)。

## P01-04 设计令牌与基础组件

> 状态：完成。已按根 `DESIGN.md` 和 ADR-0003 建立原生 SwiftUI 语义令牌、材质环境分支、Button/StatusBadge/EmptyState/AsyncContent/Thumbnail，以及八态 Preview gallery；状态均有图标或文本通道。

- 需求：20、NFR-A11Y。
- 步骤：实现语义颜色、字体、间距、圆角、材质、focus ring、motion duration；基础 Button/StatusBadge/EmptyState/AsyncContent/Thumbnail；为 Reduce Transparency/Motion 提供环境分支。
- 交付：DesignSystem 目录和 Preview/测试样例。
- 验收：无页面内散落 hex；状态不只依赖颜色；图标按钮有 label/help；不引入自定义 Web 字体。
- 辅佐：[design-and-prototype-audit.md](../00-analysis/design-and-prototype-audit.md)、[design-acceptance.md](../03-support/design-acceptance.md)。

## P01-05 本地化与可测试资源

> 状态：完成。已建立 English/简体中文 String Catalog，并加入仓库内生成、带许可清单的有效/损坏/伪 MIME/重复内容图片 fixture；fixture 仅属于测试 target。

- 步骤：建立中文 String Catalog；统一“立即更新”“换一张”等术语；准备合法小图片、损坏图片、伪 MIME、重复内容 fixture；fixture 只进测试 target。
- 交付：本地化骨架、fixture 清单。
- 验收：生产 UI 不硬编码中英混杂；测试 fixture 无版权/隐私问题。
- 辅佐：规格第 5/17 章、[test-matrix.md](../03-support/test-matrix.md)。

## P01-06 CI/本地反馈脚本或文档

> 状态：完成。已提供 `scripts/build`、`scripts/test`、`scripts/check` 及受限环境诊断；脚本从任意目录定位仓库、禁用签名、使用可覆盖的临时 DerivedData，并保留真实失败码。

- 步骤：确定 canonical build/test 命令与 DerivedData 位置；若新增脚本，必须非交互、失败码准确；记录 Preview 宏在受限环境可能失败的诊断方式。
- 交付：README/脚本、首个绿灯记录。
- 验收：不依赖 GUI、Apple ID 或个人 Keychain。

## 阶段退出条件

> 状态：通过（2026-08-19）。测试 target、依赖替换、日志错误、设计 token、本地化与 fixture 均可用；`ZIKORA_DERIVED_DATA=/tmp/zikora-p01-check-derived ./scripts/check` 已完成 18 项测试和 Release 无签名构建。完整证据见 [p01-acceptance.md](../03-support/p01-acceptance.md)。
