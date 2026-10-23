# 3.2.0 (253) 测试与兼容验证

状态：`done`（工程本地验收）；在线 CR 与分发回执由下述发布证据目录另行记录。

## 验证对象与范围

- 对象：Usage 顶部 Remaining Quota 仅呈现真实账号/窗口观测，删除未来预测，保留缺测与重置边界，并修改 iOS 本地观测历史的有界保留方式。
- 最终 reviewed head / merge / archive source：待实际 CR 与发布完成后填写。版本 3.2.0 (253) 已在全部五个 project target 配置；开发签名安装包与 App Store 分发 archive 必须分别记录来源。
- 本次没有新 Mac binary，不改 CloudKit wire/schema。由于 iOS 本地缓存和跨版本读法变更，`docs/ios-sync-compatibility-testing.md` 的 16 组合门禁适用；`NO_DEPLOY` 不代表兼容验证不适用。
- 本轮只会取得单台 iPhone Air 的真实安装与数据观察；不能写成实体两台 Mac × 两台 iPhone 全矩阵通过。普通 iPhone/Duo 完整 App 截图的模拟 fixture 必须明确标注，不能冒充真实账户历史。

## 已存在的本轮证据

以下证据来自 `/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/QuotaObservedHistory`，不是旧 TF 252 的验证。

| 编号 | 证据 | 已确认结果 | 限制 |
|---|---|---|---|
| F1 | `final-model.xcresult`、`final-model.log` | 43 个 Swift Testing tests / 4 suites 通过；其中 `two writers converge through independent full and cold delta readers without sharing preferences` 的 16 cases 全通过 | 初始本地修正证据；后续最终版本结果见下表 |
| F2 | `verified.xcresult`、`verified.log` | 两个渲染 XCTest 通过，52 个 production component/editor 状态；普通 iPhone 原生 search/legend/rotation UI 测试通过 | 不替代实际 Duo 展开两姿态，也最终周轴已重跑生产渲染，见下表 |
| F3 | `localization-formats.log`、`localization-audit.log` | 格式测试 6/6；四语全部 translated，523 source keys 存在 | 最终版本文档/新测试合入后仍记录最终适用检查 |

早期 `final-local.log` 的连续周期测试曾失败，后续 F1 中该项已修复重跑；保留失败证据，不把它当成通过。现有 16-case fixture 的 old reader 是针对 build 250 相关 wire 字段的冻结 DTO 投影，不是运行旧版 App binary。针对 252 本地 archive 解码/roundtrip 的新测试已在全量 unit 中单列通过，未用此 wire 投影替代。

## 16 组合兼容矩阵

替代原因：本补丁不发布新 Mac，两个 writer 的新旧 wire 能力由 fixture 模拟；本轮未运行四实体设备的全部 16 种安装与后台状态组合。两个 reader 各用独立 cache 和 dictionary-backed persistence，分别走 full fetch、cold delta、相反接收顺序、删除/恢复和重启。矩阵每行均为 `substituted`，即使最终自动测试全绿，也不能改写为实体 `pass`。

R1（所有行共同剩余风险）：替代测试未验证真实 CloudKit 网络时序、两台实体 iPhone 静默推送/后台唤醒、iCloud 权限或真实旧版二进制往返。单 Air 实测只补充本机读取和显示，不消除以上风险。旧/新 reader 的本地缓存往返另由 252/253 archive 测试覆盖其明确断言范围。

| Case | Mac A | Mac B | iPhone A | iPhone B | Result | Evidence | Notes |
|---:|---|---|---|---|---|---|---|
| 1 | old | old | old | old | substituted | F1 case 1，16-case 测试通过 | R1；weekly-full-units.xcresult 全量通过 |
| 2 | old | old | old | new | substituted | F1 case 2，16-case 测试通过 | R1；weekly-full-units.xcresult 全量通过 |
| 3 | old | old | new | old | substituted | F1 case 3，16-case 测试通过 | R1；weekly-full-units.xcresult 全量通过 |
| 4 | old | old | new | new | substituted | F1 case 4，16-case 测试通过 | R1；weekly-full-units.xcresult 全量通过 |
| 5 | old | new | old | old | substituted | F1 case 5，16-case 测试通过 | R1；weekly-full-units.xcresult 全量通过 |
| 6 | old | new | old | new | substituted | F1 case 6，16-case 测试通过 | R1；weekly-full-units.xcresult 全量通过 |
| 7 | old | new | new | old | substituted | F1 case 7，16-case 测试通过 | R1；weekly-full-units.xcresult 全量通过 |
| 8 | old | new | new | new | substituted | F1 case 8，16-case 测试通过 | R1；weekly-full-units.xcresult 全量通过 |
| 9 | new | old | old | old | substituted | F1 case 9，16-case 测试通过 | R1；weekly-full-units.xcresult 全量通过 |
| 10 | new | old | old | new | substituted | F1 case 10，16-case 测试通过 | R1；weekly-full-units.xcresult 全量通过 |
| 11 | new | old | new | old | substituted | F1 case 11，16-case 测试通过 | R1；weekly-full-units.xcresult 全量通过 |
| 12 | new | old | new | new | substituted | F1 case 12，16-case 测试通过 | R1；weekly-full-units.xcresult 全量通过 |
| 13 | new | new | old | old | substituted | F1 case 13，16-case 测试通过 | R1；weekly-full-units.xcresult 全量通过 |
| 14 | new | new | old | new | substituted | F1 case 14，16-case 测试通过 | R1；weekly-full-units.xcresult 全量通过 |
| 15 | new | new | new | old | substituted | F1 case 15，16-case 测试通过 | R1；weekly-full-units.xcresult 全量通过 |
| 16 | new | new | new | new | substituted | F1 case 16，16-case 测试通过 | R1；weekly-full-units.xcresult 全量通过 |

## 253 当前版本验证

证据目录：`/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/QuotaObservedHistory-3.2.0-253`。

| 验证 | 实际结果 | 证据与边界 |
|---|---|---|
| Air 保留数据安装 | 3.2.0(253)，Release / Apple Development，Production | `air-final-install.json`；未卸载或清空数据，开发包不是 TF 分发包 |
| Air 真实读数 | Claude 三窗口、Codex Weekly 已持续保存可信读数 | `air-sampling-sanitized.json`；23:26 UTC 最终周轴实机显示23→30、刻度24→30，当前仅短期本地观测，未来留空 |
| Air 构建来源 | 实际构建前后 shipping bytes/modes 快照已保存 | `air-final-source-before.json`、`air-final-source-after.json`；提交后再与最终 reviewed head 验证，不声称开发包与TF二进制相等 |
| 全量 iOS unit | 1312 total / 1311 passed / 0 failed / 1 skipped | `weekly-full-units.xcresult`；唯一 skip 是需要真实授权的 EventKit calendar 集成；WidgetSnapshotBuilder、多账号、独立cache矩阵、252 DTO往返已覆盖 |
| 最终日期边界与渲染 | 40/40 passed | `final-axis-render.xcresult`；补充 DST 前拨/回拨七日期、超7天异常 reset；2个生产渲染测试含52状态 |
| 普通 iPhone 原生 App | 横竖屏、搜索、旋转、图例通过 | `phone-final.xcresult`；首屏完整图表/图例清除搜索与Tab Bar遮挡断言，原图在 `final-app-screenshots/` |
| Duo 展开竖屏 | 原生四Tab交互与首屏 chart/legend通过 | `duo-portrait-final.xcresult`，primary-1内屏原图2006×2852；容器渲染不替代此证据 |
| Duo 展开横屏 | 原生四Tab交互与首屏 chart/legend通过 | `duo-landscape-final.xcresult`；primary-1 内屏实际横屏，原生侧边 Tab Bar；已人工查看完整截图 |
| 本地 lint / 四语 | 通过 | `lint.log`、`weekly-localization.log`；0 SwiftLint violations，520 source keys齐全。最终3个Swift更改另经 repo SwiftFormat lint通过 |
| 独立本地 CR | clean | 两项周轴边界已修复并复核；无未处理实质finding |
| Mac / CloudKit diff | NO_DEPLOY | 对origin/mobile-dev，Sources/Tests/Shared/version.env无变化；3个source entitlements保持Production。未运行Mac live provider/Keychain探测或发布Mac |

## 兼容结论

16/16 替代验证通过，单 Air 真机补充已完成，完整实体矩阵未执行。冻结252本地archive DTO覆盖观察字段的未知可选key忽略、解码与往返，不能称为运行旧版binary。R1仍保留。最终CR/TF的真实状态与来源清单保存在发布证据目录，只有真实回执产生后才可宣称合并/上传完成。
