# 测试矩阵

## 1. 测试分层

| 层 | 主要对象 | 不应依赖 |
|---|---|---|
| Domain 单测 | LocalDay、策略、状态机、选择、清理判断 | UI、磁盘、网络、真实时间 |
| Application 单测 | Use Case 编排、幂等、回滚、共享命令 | 真实系统 API |
| Infrastructure 集成 | 临时 store、fixture HTTP、ImageIO、文件事务 | 公网、个人目录 |
| ViewModel/UI 状态 | 状态映射、按钮可用性、导航 | 真实下载/壁纸 |
| 真机人工 | 壁纸、Menu Bar、登录项、睡眠/唤醒、多屏 | 模拟器结论 |
| 性能 | idle、1,000 条、缩略图、Hash/解码 | Debug Preview 体感 |

## 2. 核心场景表

| 场景 | 自动 | 人工 | 关键断言 |
|---|---|---|---|
| 首次启动无配置 | 是 | UI smoke | 进入引导，不显示空白 Dashboard |
| 首来源未测试 | 是 | 是 | 不能继续/完成 |
| 完成引导 | 是 | 是 | 7 天 + default + 默认设置原子保存 |
| 同日多触发 | 是 | 否 | 只执行一次自动请求 |
| 手动立即更新 | 是 | 是 | 绕过当日成功，不增自动次数 |
| 两入口并发点击 | 是 | 是 | 只有一个全局任务，入口同步禁用 |
| 自动失败 1/2/3 | 是 | 否 | +30m/+2h/停止并一次 default |
| 进程重启待重试 | 是 | 是 | 当天到期恢复，跨日丢弃 |
| default 与计划相同 | 是 | 否 | 不重复请求 |
| 相同内容不同 URL | 是 | 否 | 单物理文件、记录关联 |
| Hash 与 current 相同 | 是 | 是 | 不重复保存，给明确提示 |
| 循环模式事件 | 是 | 是 | 0 个网络调用 |
| random N>1 | 是 | 否 | 不连续 current |
| chronological | 是 | 否 | 旧→新、ID 稳定、末尾循环 |
| 睡眠跨多个间隔 | 是 | 是 | 不补播，唤醒重算 |
| current 过期 | 是 | 是 | 永不清理 |
| 删除文件失败 | 是 | 是 | 元数据保留，报告失败 |
| 路径逃逸 | 是 | 否 | 删除被拒绝并记录安全错误 |
| 多屏部分失败 | Fake 是 | 是 | 记录数量、可重试、策略一致 |

## 3. HTTP/图片 fixture

必须具备本地可重复 fixture：

- 200 JPG、PNG、HEIC、WebP；
- 204/404/500；
- 1～5 次重定向与重定向环；
- 慢响应和超时；
- 无 Content-Length 的 50MB+ 流；
- 声称 image 实际 HTML/JSON；
- 声称 text 实际有效图片（根据最终安全策略断言）；
- magic bytes 有效但尾部损坏；
- 0×0/无法解码；
- 两 URL 返回完全相同字节；
- 同 URL 两次返回不同字节。

fixture 服务只监听 loopback、随机端口，测试结束释放，不依赖公网。

## 4. 时间矩阵

使用固定 Calendar/TimeZone/Clock：

- 23:59:59 → 00:00:00；
- 夏令时跳变（即使主要用户不在 DST 区，也要保证 Calendar 正确）；
- Asia/Shanghai → America/Los_Angeles 切换导致本地日变化；
- 系统时间回拨到同一本地日；
- 重启时 retry 未到期/已到期/已跨日；
- Monday–Sunday 每一天来源映射；
- retention `>` 边界：恰好 N 天不删，超过 N 天删除（按规格公式确认）。

## 5. 文件一致性矩阵

- 元数据与文件都存在；
- 元数据有、文件无；
- 文件有、元数据无；
- current 元数据有、文件无；
- 原子移动前失败；
- 原子移动后、元数据提交前中断；
- 删除文件成功、删记录失败；
- 目录只读/磁盘不足；
- symlink 或 `..` 试图离开管理根目录。

每种情况必须定义启动维护时的恢复结果，不只测试报错。

## 6. UI 状态矩阵

对 Dashboard、Source Card/Form、Library、Settings、Menu Bar 分别覆盖：

default、loading、success、empty、offline、error、disabled、warning、missing configuration；交互控件补 focus/active；减少透明度/动态效果为横向组合。

## 7. Canonical 命令

最低系统为 macOS 14。P01 已将命令固化为非交互脚本：

```bash
./scripts/test
./scripts/build
./scripts/check
```

`scripts/check` 是 CI 等价入口：先运行完整 Debug 测试，再执行 Release 构建。可用 `ZIKORA_DERIVED_DATA` 覆盖默认临时产物位置，完整参数见仓库 [scripts/README.md](../../../scripts/README.md)。

真机系统集成不能以 `CODE_SIGNING_ALLOWED=NO` 结论替代，应使用正常签名的沙盒构建另行验证。
