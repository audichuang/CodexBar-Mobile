# 测试、兼容与证据

状态：`in-progress`；Mac编译、iOS专项、四语检查及offline兼容矩阵已通过其限定范围，完整回归/实包/UI仍待完成。

## 旧/新定义

- old Mac：最近published `v0.79.0.1-mobile.3.1.0`；old iOS：已发布3.2.0 (260)，ASC version→build关系只读回读绑定build ID c0e4d298-e201-471e-8625-1e79a667eb1f；源码使用已交付3.2基线bdfb51085（未重新下载商店二进制验证）。
- new Mac：本轮最终reviewed候选0.82.0.1；new iOS：3.3.0 (261)。实际commit/artifact hash将在完成后写入。
- 2 Mac × 2 iPhone gate适用：新增同步显示数据与optional metadata。

| Case | Mac A | Mac B | iPhone A | iPhone B | 结果 | 证据/风险 |
| ---: | --- | --- | --- | --- | --- | --- |
| 1 | old | old | old | old | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 2 | old | old | old | new | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 3 | old | old | new | old | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 4 | old | old | new | new | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 5 | old | new | old | old | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 6 | old | new | old | new | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 7 | old | new | new | old | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 8 | old | new | new | new | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 9 | new | old | old | old | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 10 | new | old | old | new | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 11 | new | old | new | old | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 12 | new | old | new | new | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 13 | new | new | old | old | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 14 | new | new | old | new | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 15 | new | new | new | old | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 16 | new | new | new | new | substituted | frozen old/new model + consumer；见下方范围与风险 |

## 本机预检

StudioSSD身份与路径检查通过；Xcode27.1/27A9275，SDK iOS27.1/macOS27.0。ASC只读确认3.2.0已发布、build260 VALID；未写入ASC、未执行Production schema export/deploy。没有以此证明真实CloudKit收敛或Duo通过。


## 已执行验证

| 项目 | 当前证据 |
| --- | --- |
| Mac compile | `mac-build-5.log`：swift build -j6，51.34秒；源码2f4e6a4ba对应的Mac/Shared产品输入 |
| iOS focused | `ios-focused-2.xcresult` / log：75 tests / 5 suites，0失败；含新metadata容错、daily target、provider订阅、WidgetSnapshotBuilder与旧详情回归 |
| 四语 | `ios-i18n.log`：所有xcstrings翻译完整，533个source keys齐全 |
| 16组合替代 | 16 masks、64独立reader读取、32 old/new真实pure consumer合并进程，全部验证通过；source/hash和逐组合操作见evidence/compatibility-*.json |

矩阵的old Shared来自当前已交付3.2源基线bdfb51085，与published Mac0.79.0.1的Shared逐文件diff为零；旧consumer来自同一3.2基线。两Mac分别mac-a/mac-b并提供独立device keys；两个phone分别执行独立reader进程，每次验证旧/新反向解码、roundtrip、optional quota units/expectedUsed、append-only订阅与两writer正反序。新provider无验证身份时按device保留两份，既有稳定Claude身份合并并取最新观察。

**为什么substituted：** 本轮本机没有可组织的2Mac×2iPhone四设备同步环境。替代的是生产模型与合并器的离线执行，不是实体设备CloudKit链路。未验证实际CK写入/推送投递、两台iPhone持久缓存收敛/SwiftData迁移、联网恢复和物理折叠。对应iOS store、cache、UI测试将另行记录；这些结果不能回写为16实体PASS。发现失败仍须修复并复跑。

## 第二阶段验证与局部review

- Mac focused：mac-focused.log，76 tests /9 suites全部通过；含4新provider、月target、Kimi、detail pace、mock回归。
- Mac bridge/Command Code：mac-bridge-3.log，105 tests /9 suites全部通过（源码在测试期间仍有Soniox周期/observedAt测试增强，最终由全量gate重新覆盖）。此前bridge-2因测试对非optional数组误用?.编译失败，已修，保留失败日志。
- iOS full unit：ios-full-unit.xcresult，1272 Swift Testing tests /84 suites通过，xcodebuild TEST EXECUTE SUCCEEDED；源对应新增功能首版，后续locale/AX修复单独复测。
- iOS新render专项：ios-v082-render.xcresult Passed，11 test definitions（含参数化共17runs），0fail；导出9张图片。图片审查发现ImageRenderer的ProgressView黄条是unsupported native control占位，撤回它对进度外观的证明；该组只能支持文本/计算测试。新UIHostingController窗口渲染复测启动为ios-v082-native-render.xcresult，结果待收拢。
- 同组图片暴露Kimi第一方allowlist缺失，Other features等未翻译，已补；日文AX3下预算金额及长quota标题拥挤，补自适应排布。新native图及交互仍需审查，不能沿用旧图通过结论。
- README局部独立审查0阻塞后有意适配已提交c7b11c28e。Mac/Shared局部review发现3项并修复：Soniox双金额通道、插件三槽标题、Command Code账号catalog；后者skip-build实测原失败已留review-token-catalog.log。报告在evidence，不替代最终完整candidate review。
- 全量SwiftLint原发现多项（主要是新测试参数格式、上游长文件/type）；未放宽规则，原行为拆CurrencyGroup extension和插件fixture helper，修复6个文件的SwiftLint复测0violations。完整lint-4与mac-full-tests仍在运行。
- CloudKit code audit：NO_DEPLOY，见evidence/cloudkit-code-audit.md；当前未export/deploy，signed包Production验证待产物。

### 原生设备进度（未验收）

本轮专用Duo27.1 `44FF07DE-FAD8-4670-B9D8-35542A3FE199` 已创建/boot，sim-use preflight三项通过。Device Hub Computer Use两次getApp超时；未重启/清空共享设备或其他任务进程。实际四姿态与跨姿态action尚未通过；不以boot或display枚举代替验收。普通iPhone QA为C4943B97-C088-4DD5-9EAF-A98110E7AE77，27.0。

## 后续待收拢（2026-10-28）

- 第二轮iOS局部审查4项：units、Kimi reader expiry/locale、动态gift名、Copilot无duration月份。修复已进入工作区，专项与compatibility-2正在执行；旧16组合报告没有expiresAt字段，尚不能证明最终wire完成。
- ios-v082-native-render.xcresult已成功，真实hosting替代黄条占位；之后又增加units/Kimi expiry与Copilot，当前新验证ios-v082-kimi-ui.xcresult，含普通iPhone导航、Summary点卡返回、Cost分享草稿旋转/取消。未提前标通过。
- lint-4失败不是产品格式：test_swift_test_process_cleanup的timeout-stubborn drain超过5秒及timeout-session fixture readiness超过10秒；保留原始trace，须诊断/复测，不当已知flake跳过。
- Mac full仍在进程中；AntigravityLocalScan 60000-row snapshot coverage/tokens首轮失败，后续runner重试与根因待定位。
- Device Hub经Computer Use native Force Quit恢复尝试后getApp仍超时；已核实真实path/版本，但fullpath getApp使CUA kernel超时重置，随后getState初始化也超时。没有收到有效Duo姿态证据，不冒充通过。用户要求代理自行使用Computer Use，后续代理继续处理，不要求用户手动操作。
