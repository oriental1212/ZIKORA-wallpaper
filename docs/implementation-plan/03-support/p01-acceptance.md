# P01 验收记录

> 结论：通过  
> 日期：2026-08-19  
> 范围：P01-01～P01-06

## 交付证据

| 任务 | 主要交付 | 自动验收 |
|---|---|---|
| P01-01 | Swift Testing target、共享 scheme、Domain smoke test | 主 scheme 能发现并运行测试 |
| P01-02 | `AppEnvironment`、runtime/service/repository 协议、Preview 与 in-memory Fake | 固定日期/日历/UUID/随机值及共享环境测试 |
| P01-03 | 错误 taxonomy、恢复动作、用户消息、日志 facade、URL 脱敏 | 全部 15 个错误码映射与日志脱敏测试 |
| P01-04 | SwiftUI 语义令牌、基础组件、八态 Preview gallery | 间距/圆角、Reduce Motion、非纯颜色状态测试 |
| P01-05 | English/简体中文 String Catalog、合法图片 fixture 与清单 | 术语、消息键、ImageIO、重复内容 Hash 测试 |
| P01-06 | `scripts/build`、`scripts/test`、`scripts/check` | Debug build、完整测试、Release build |

## 已执行命令

```bash
ZIKORA_DERIVED_DATA=/tmp/zikora-p01-all-derived ./scripts/build
ZIKORA_DERIVED_DATA=/tmp/zikora-p01-all-derived ./scripts/test
ZIKORA_DERIVED_DATA=/tmp/zikora-p01-check-derived ./scripts/check
jq empty ZIKORA-wallpaper/Resources/Localizable.xcstrings ZIKORA-wallpaperTests/Fixtures/Images/manifest.json
git diff --check
```

结果：Debug build 成功；18 项测试（8 个 suite）全部通过；CI 等价脚本完成同一测试套件与 Release build。String Catalog/fixture manifest 可解析，最终 diff 无空白错误。

## 环境与安全说明

- 受限执行环境会阻止 Xcode Preview 宏插件启动；保持源码不变并在获批的非沙箱进程运行同一命令后通过。
- 测试不访问公网、个人目录、真实壁纸服务、Apple ID 或个人 Keychain。
- 没有新增第三方依赖，没有修改 entitlement、签名、bundle identifier 或最低系统版本。
- 签名沙盒下的网络、真实桌面壁纸和登录项行为仍按计划属于 P06 真机验收，不由 P01 的无签名构建代替。
