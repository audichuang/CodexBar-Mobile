# Mac 全量测试最终覆盖证据独立审查

日期：2026-10-28；范围仅为测试库存、续跑证据和变更归属，不是最终完整candidate/发布产物review。未修改tracked源码、未编译/运行测试或触碰live账号。

## 结论

组合证据覆盖完整的 **1845 selections**，映射到最终inventory全部 **16177个可发现method identifiers**；五阶段选择集合彼此不交，union无遗漏，0个空method selection。前序真正失败的suite均有修复后的后续通过证据。最终 `mac-full-tests-resume-4.log` 的395 selections/37groups完成，36组首遍通过，1组180s批次超时后12个selection逐一隔离通过，最终命令exit0与日志/runner控制流一致。

因此可以报告“本轮Mac测试完整库存已由组合执行证据覆盖，阻塞测试失败已闭环”。**不能报告**“同一最终二进制从头全量通过”或“16177个测试body全部实际执行”：日志中有123个唯一XCTest方法按环境条件skip，且存在下述原阶段artifact证据边界。签名/公证/实包与native视觉交付gate仍是独立要求。

## 分区证明

| 接受的日志阶段 | 接受的成功group来源数 | selections | 对应最终method IDs |
| --- | ---: | ---: | ---: |
| mac-full-tests-2.log | 61 | 692 | 6024 |
| mac-full-tests-resume.log | 46 | 506 | 4302 |
| mac-full-tests-resume-2.log | 14 | 168 | 1627 |
| mac-full-tests-resume-3.log | 7 | 84 | 724 |
| mac-full-tests-resume-4.log | 37 | 395 | 3500 |
| 合计 | 165组来源（含重新分组；不是原165组单次执行） | 1845 | 16177 |

原始前61通过组共有694 selections；其中 AlibabaTokenPlanSyncTests、ClaudeTokenAccountCostTests因primary mapper抽取而剔除并在resume1重跑，所以第一阶段只沿用692。后续分别新增506、168、84、395。各阶段无selection交集、无method交集。

持久coverage/runtime逐项核对：

- resume1：retained692 + remaining1153，104 groups。
- resume2：1198 +647，58 groups。
- resume3：1366 +479，44 groups。
- resume4：1450 +395，37 groups。

所有 `remaining_selections` 与runtime groups展开顺序、日志Selected group顺序完全一致；每份coverage引用的前序log SHA256真实匹配。后续每个runtime都保留完整method inventory，production prepare_runtime验证5个产品的XCTest/Swift Testing discovery集合与完整SwiftPM discovery一致。retained方法集合在相邻runtime间完全相同；未发生同名suite新增/删除method却错误沿用的情形。

本审查同时以production selection规则将最终inventory映射回接受集合：all method union=16177、missing=[]、overlap=0。这里的method是discovery标识；selection通常是一整个suite，也可能是top-level test函数，不等于一个测试。参数化cases、重试以及known-issue负向自测不能与selection或method数量混为一谈。

最终五个产品方法数：AdaptiveReplayCLI 4、AdaptiveReplayKit 74、CodexBarLinuxTests 517、CodexBarPluginTests 472、CodexBarTests Swift Testing14831 + XCTest279。所谓LinuxTests在此次证据中是Mac宿主执行该测试target，不据此宣称真正Linux/musl平台运行通过。

## 历史失败闭环

| 历史阻塞 | 修复与真正覆盖位置 |
| --- | --- |
| 初始worker1 group62 CatchUp路径归一化fixture | contained raw `./` lexical alias，未改生产symlink语义；resume1接受阶段覆盖CostUsageCatchUpCompletionTests，另focused Cursor/CatchUp/V082 29tests PASS |
| Cursor周池标题/无上限按需消费 | 生产primary helper与amount修复已在f3b87fa94；CursorSand、Alibaba/Claude调用回归在resume1，V082Bridge在resume4；不能用修复前旧binary证明这些修复 |
| resume1 group47旧Mock数量 | 120 current snapshots/125total/115unique对应4新provider；resume2接受阶段包含两个修复suite以及MockProviderInjectorTests；focused3Mock70tests PASS |
| resume2 group15 architecture exact基线 | 仅精确catalog更新/新增/删除stale occurrence；保留occ1 Codex/DeepSeek四ref、增加xAI/Grok独立尾段；resume3接受阶段重新覆盖，focused48tests PASS |
| resume3 group8 QuotaProviderList旧90/270 | 改为新增四provider后的94/282，未改共享生产list；resume4 group1执行修正suite并PASS |
| 更早Antigravity/Kiro/SpendDashboard失败诊断 | AntigravityLocalScan在初始接受阶段；KiroStatusProbeTests在resume1 group33，包含hard-stop和detached-child两个实际通过摘要；SpendDashboardPublication/SourceConcurrency在resume4接受阶段。旧失败日志均保留，不采用known-flake豁免 |

框架summary中ProcessEnvironmentTests的14 known issues属于withKnownIssue刻意失败以验证环境脱敏，不能当未解决产品缺陷，也不能把历史真正failed suites隐藏成known issues。Python cleanup/lint不是这个Swift库存的一部分，需由full lint gate另证。

## 最终group26超时与12次隔离重跑

production runner按180s总group deadline执行12个UsageStore suites，批次到期。随后依照既定retry策略为每个selection开新contained worker，--no-parallel、独立HOME和测试隔离环境保持；未增加产品timeout或删除断言。

12个selection各恰好有一个独立执行命令和一个最终PASS摘要，报告tests分别为10/21/41/17/24/7/13/12/1/2/2/13（合计163个test definitions，非16177库存总数）。各隔离耗时35.957/6.442/38.339/43.560/1.622/65.300/32.069/0.461/0.108/0.113/3.621/0.437秒，均低于180s；这些耗时合计228.029秒，解释为什么把12个suite合成一个180s批次会超过预算。此证据支持标准runner的recovered状态，不支持将原超时擦成首遍PASS或证明并发压力场景没有风险。

## 源码、binary与skip边界

- f3b87fa94后Mac产品/Shared/runner/Package输入没有语义变更；后续主要是Mock/architecture/quota测试基线及Cursor test排版。architecture scanner的前置测试逻辑与resolveAnchorLine之后的算法同f3字节相同，未放宽窗口/过滤/断言。
- 最终测试后，SyncCoordinator.syncPrimaryRateWindow的syncRateWindow调用按一个参数一行排版；独立审阅diff，去掉空白的文件内容与f3完全一致，无参数/表达式变化。父线程计划重跑focused bridge/build/full lint；本报告不冒称它们已通过，也不要求为这处纯排版重跑完整库存。
- 4份持久runtime JSON有5个测试bundle SHA256：CodexBarTests记录4个不同构建hash，其余4bundle各1个hash。本审查重新流式hash当前5个debug测试binary，全部与resume4记录一致。它们是测试产物，不是签名release app。
- 初始 `mac-full-tests-2` 原temporary runtime已清理，未找到持久完整method清单和binary SHA；日志有完整selection清单、16176 method discovery校验和前61group成功摘要，配合已审查source/fix范围支持沿用692未受影响selections。这里不能升级为同一最终binary或完整forensic artifact证明。最终inventory新增的Cursor专项不在这692留存内。
- **123个唯一XCTest skip** 已列在proof JSON，均保留具体env gate原因；包含native/screenshot/signed-host证明，也包含LIVE_CLAUDE_TTY本机实探。选择它们并正常skip不等于执行了原生交互、截图或live provider。279个XCTest method中这123个body未在本库存链实际运行；需由相应专项/QA证据覆盖受影响的发布要求。未因计数覆盖而把真实Keychain/live探测偷偷打开。

## 证据与后续用途

小JSON证明：`mac-final-coverage-review-proof.json`，包含阶段集合hash、runtime/log SHA、失败闭环位置、12次重跑摘要、123个skip标识/原因、当前binary核对和source差异。完整selection/method名单沿用已持久runtime/coverage文件；辅助 `mac-final-coverage-audit.py` 仅做只读库存/日志计算，不运行Swift测试。

完整method inventory排序SHA256：`8818a3f79338742a35cbaf64c9c760db74cf4d24164e15996817f9cace6c1e44`。

此结论可回填Research/03的Mac测试库存阶段。后续完整candidate review、post-test排版focused/build/lint、签名实包Production entitlement/notarization/provenance，以及PR当前head review仍由各自gate确认；本报告未批准push/merge/release。
