# 发布与人工验收清单

> P10 状态（2026-08-20）：自动化命令与审计已完成并记录于下方；P10-09 代码实现与自动化验证已完成，UI 视觉/菜单栏截图及真机人工项待发布环境执行；带签名沙盒真机矩阵、UI smoke、archive/sign/notarization 与 AppIcon 母版仍待发布环境执行。

## 1. 构建信息

记录：commit、版本、构建号、Xcode、macOS、硬件、签名身份、是否沙盒、测试数据集。

## 2. 安装与首次使用

- [ ] 全新安装进入 Onboarding。
- [ ] 中途退出后恢复步骤。
- [ ] 非图片/超时/离线不能完成，但可恢复。
- [ ] 成功后来源分配七天 + default，默认设置正确。
- [ ] 首次任务成功或失败均有完整状态，不崩溃。

## 3. 日常主链路

- [ ] 启动当天只自动获取一次。
- [ ] 立即更新可重复请求但防双击并发。
- [ ] 换一张只使用本地、零网络。
- [ ] 默认源在规定三种情况兜底且只一次。
- [ ] 当前壁纸在失败时不变化。

## 4. 生命周期

- [ ] 关闭主窗口后 Menu Bar 和后台继续。
- [ ] Menu Bar 可打开主窗/Settings、更新、换图、退出。
- [ ] 登录启动不弹主窗口。
- [ ] 真正退出取消任务且无残留进程。
- [ ] 睡眠同日/跨日与唤醒行为正确。
- [ ] 网络恢复/时区变化/时间回拨不重复风暴。

## 5. 系统集成

- [ ] 单屏设置成功。
- [ ] 多屏同图；部分失败提示准确。
- [ ] 显示器拔插后下一操作正常。
- [ ] Finder 打开/定位只访问管理目录。
- [ ] 登录项开关与系统设置一致，失败会回滚。

## 6. 数据与缓存

- [ ] 重启后来源、计划、设置、current、retry 恢复。
- [ ] 相同 Hash 只保存一份物理文件。
- [ ] 7/14/30/60/90/永久边界正确。
- [ ] current 过期仍保护。
- [ ] 立即清理先估算确认，部分失败可报告。
- [ ] 文件缺失排除轮播，孤儿文件不自动误删。

## 7. UI 与可访问性

- [ ] Dashboard/Sources/Library/Settings 与批准结构一致。
- [ ] App Shell、Dashboard、Sources、Library、Settings 使用 Vivid Lumina 语义色与克制玻璃材质。
- [ ] 菜单栏中文显示“立即更新”“换一张”“打开仪表盘”“设置”“退出”，失败状态不显示 key。
- [ ] Electric Blue `#007AFF` 作为唯一主交互色，无默认系统灰残留。
- [ ] 800/1000/1280 窗口可用。
- [ ] 全部关键状态和确认框已检查。
- [ ] VoiceOver、键盘、focus、Increase Contrast 通过。
- [ ] Reduce Transparency/Motion 通过。
- [ ] 无英文残留、空按钮、虚构链接或演示来源误植。

## 8. 性能

- [x] Release 构建空闲 CPU 接近 0%（实测 0.0%）。
- [ ] 空闲内存低于 80 MB（实测 93–104 MB，超目标，原因与复测见 [p10-performance-baseline.md](p10-performance-baseline.md)）。
- [x] 1,000 条 Library 可浏览，无一次性全图解码（`ThumbnailPipelineTests`）。
- [x] 下载 50MB 上限流式生效（`URLSessionImageDownloaderTests`）。
- [x] 无高频日期轮询、目录扫描或 Menu Bar 动画（代码审阅 + 实测 CPU）。

## 9. 隐私、权限与发布资产

- [x] entitlement 仅保留必要能力（App Sandbox + 网络出站；已移除未使用的用户选择文件与 App Groups）。
- [x] 隐私说明与真实网络/本地行为一致（详见 [privacy-and-security-audit.md](privacy-and-security-audit.md)）。
- [x] 日志 URL query 已脱敏且使用 OSLog 统一轮转。
- [ ] AppIcon/Logo 使用批准母版和完整尺寸（DEC-011 待补，未用截图冒充）。
- [x] bundle ID、team、signing、notarization 未被意外修改（本次仅移除未使用 entitlement；notarization 未执行）。
- [x] 无密钥、token、个人路径或测试隐私数据。

## 10. 最终命令记录

逐条写入“命令 / 日期 / 环境 / 结果 / 日志位置”：

- focused unit tests；
- full unit tests；
- Debug build；
- Release build；
- UI smoke（如有）；
- archive/sign/notarize（发布环境）；
- `git diff --check`。

未执行的命令必须注明原因与责任人，不得留空后宣称发布通过。

## P10 已执行命令

- `./scripts/test`：177 项 / 46 套件通过，Debug，`CODE_SIGNING_ALLOWED=NO`。
- `ZIKORA_CONFIGURATION=Release ./scripts/build`：通过，Release，`CODE_SIGNING_ALLOWED=NO`。
- `./scripts/check`：通过（Debug 全量测试 + Release 构建）。
- Release 启动 `ps` 采样：CPU 0.0%，RSS 93–104 MB。
- `git diff --check`：通过。

未执行：UI smoke（含 800/1000/1280 截图）、archive/sign/notarization、签名沙盒真机矩阵；原因是当前环境无发布签名身份/GUI 人工验收环境，需发布负责人执行。
