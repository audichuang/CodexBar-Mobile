# Spend Dashboard readiness 失败独立诊断

日期：2026-10-28。独立局部review agent `mac_merge_review`。只读诊断；未修改tracked文件，未编译，未启动重型并发测试，未访问真实Keychain/provider。只创建本报告及隔离窄复现日志。

## 判断

`mac-review-fixes-2.log` 是真实失败：383 tests / 38 suites / 31 issues / 124.744s，不能标为通过。日志显示38个Swift Testing suites一起启动，其大量MainActor测试一起延迟到54–56秒后完成；随后5秒readiness/release watchdog集中到期，触发一连串timedOut、closed、CancellationError先后顺序变化。

本次使用**同一已编译二进制**，只选47项相关测试，以repo直接runtime的`--no-parallel`顺序运行，全部通过，6.378s。该证据支持“全suite并发负载下的MainActor调度/工作拥塞，随后测试watchdog级联”的诊断，**没有复现持久产品死锁或新Core/Shared/Kimi/Copilot桥接缺陷**。但没有失败瞬间的线程栈/采样，无法确认究竟哪个同步工作阻占MainActor最长，不能将并发参数视为已证明的唯一原因。

目前无依据修改生产控制器/timeout以获得绿灯。正确下一步是主任务的完整worker1 gate，而不是再次并发启动整个SpendDashboard集合。

## 环境与输入

- cwd真实路径：`/Volumes/StudioSSD/Projects/working/apple/CodexBar`；HEAD `2e51c676f3da02c981bce4ab518401aebd14e9c3`，另有主任务开发dirty diff。
- StudioSSD挂载、UUID `9D5FE511-B66C-4765-BB8F-61E5ACB3969D`、scratch可写检查通过。
- 已读取并source `Scripts/test_environment.sh`，清除继承凭证，启用CODEXBAR_SUPPRESS_TEST_KEYCHAIN_ACCESS与session/file isolation。
- 直接runtime环境通过`direct_swift_test_groups.runtime_environment`生成，独立HOME/CFFIXED_USER_HOME、英文locale、所选Xcode27.1 framework paths；TMPDIR显式SSD `.../Upstream082/review-tmp`。
- 二进制：`.build/out/Products/Debug/CodexBarTests.xctest/Contents/MacOS/CodexBarTests`，mtime `2026-10-28T14:11:23-0700`，size `597021696`。未重新编译，包含本轮最新桥接字段测试。
- 14:18只读load averages为18.98/23.81/74.50；这是窄复现时附近数据，不能作为原14:11失败时的完整资源轨迹。

## 原日志可核对的现象

`mac-review-fixes-2.log:890–945`：38个suites一起启动，随后大量test一起启动。不是repo full gate的“一个child中顺序执行test”模式。

| 原现象 | 对诊断的意义 |
| --- | --- |
| V082 Soniox、monthly quota、expectedUsed、Copilot等简单MainActor断言耗时54–56s，均最终通过 | 它们自身没有5秒等待或长计算，说明共同MainActor执行延迟，不能将每一项超时归为独立业务死锁 |
| gate readiness tolerates a delayed producer，仅Task.sleep2s却到57.776s报timedOut | 测试正常生产者/观察者恢复执行之前，真实5秒期限早已过期 |
| SourceConcurrency多项在同一个57.776s边界报timedOut | 共享执行资源拥塞形态，非各自稳定独立的确定性输入错误 |
| 后续closed代替CancellationError、timedOut代替closed | watchdog抢先关闭gate之后的级联错误，与测试主线程何时获得执行机会有关 |
| shared publication停留codex-current:0，期望1；等待函数30s也到期 | observation回调和测试主体均排队；不能只看这条差异就认定sourceRevision没有发布实现 |
| 全运行最终124.744s自行结束 | 不是无限不返回的死锁；仍然可能有过长同步执行，需完整串行gate与失败时栈采样排除 |

## 具体测试等待链

`Tests/CodexBarTests/SpendDashboardSourceConcurrencyTests.swift:936–975`：`SpendDashboardTestSignal`在MainActor上工作。`wait`在960行先计算真实ContinuousClock deadline，965行创建MainActor watchdog。若MainActor在其后长时间得不到运行，watchdog重新执行时该deadline已过，即立即timedOut。

`SpendDashboardPendingLoads.load`（1029–1043）默认5秒releaseTimeout，收到timedOut会记录issue并close gate；`waitForPendingCount`（1046–1057）默认5秒且出错同样close。于是后续已挂起producer收到closed、晚到producer被拒，取消路径可能不再是预期的CancellationError。这些辅助类型的容错/收尾行为是在按代码运行，而不是业务控制器天然发生死锁。

`SpendDashboardPublicationTests.waitUntil`使用30秒墙钟+2ms异步sleep。MainActor拥塞超过30秒，同样会在回到测试时看到旧revision并记录timeout；日志本身没有区分“观察回调晚执行”与“未注册回调”，需要窄复现。

许多SpendDashboard suites带`@MainActor`；部分带`@Suite(.serialized)`只约束该suite内部，不会自动串行其它37个suites。给一两个suite加serialized不能等价替代完整运行器的`--no-parallel`。

## 同二进制串行窄复现

使用选中Xcode的`swiftpm-testing-helper --test-bundle-path <binary> --filter <下列集合> --no-parallel --testing-library swift-testing`，外层使用repo `ci_swift_test_by_suite.run_command`保留owned-process追踪和120秒总上限。

| Suite / selection | 实际结果 |
| --- | --- |
| KimiGiftBalanceTests 全部2tests | PASS，0.068s |
| SpendDashboardDetailStabilityTests 全部13tests | PASS，0.048s |
| SpendDashboardPublicationTests 的 shared source observation 失败selection | PASS，2.061s |
| SpendDashboardSourceBatchTests 全部4tests，含7account cancellation与参数化batch | PASS，0.264s |
| SpendDashboardSourceConcurrencyTests 全部20tests，含5秒/20ms gate、取消/关闭顺序、owner替换、forced builder、顺序恢复 | PASS，3.924s |
| V082MobileBridgeTests 全部7tests | PASS，0.010s |

合计：47 tests / 6 suites PASS，6.378s，退出0。日志：`review-spend-serial.log`（本报告同目录）。没有修改测试时间、数据、releaseTimeout、生产函数或expected error来取得该结果。

新桥接专项实际结果：

- Copilot无duration的calendar month period：PASS 0.001s。
- Kimi gift expiresAt经生产bridge且Mac展示字符串保留：PASS 0.004s。
- Soniox prepaid/invoice独立spend与observed balance组合：PASS 0.001s。
- plugin三个标准窗口title与named extra优先级：PASS 0.002s。
- monthly quotaLimit/quotaUnit及复制保留：PASS 0.001s。
- generic progress expectedUsed数值单位：PASS 0.001s。
- 无已验证身份的新provider按device隔离：PASS 0.001s。

附加源码核对：Core `ProviderDetailSection.Row.expiresAt`、Shared tolerant optional expiresAt、Kimi gift row赋值和SyncCoordinator mapDetails贯通。Shared坏optional容错没有将有效usage/progress整体丢弃。该局部检查不替代iOS新旧wire、Kimi Reader或完整UI gate。

## 必要动作与最小修改建议

1. **当前必要动作是改执行方式，不是改产品代码**：继续主任务既定`TMPDIR=<SSD> bash Scripts/test.sh --direct-workers 1`。repo `Scripts/direct_swift_test_groups.py:155–157`已经明确传`--no-parallel`。保留全量discovery/selection完整性与原始失败记录。
2. 以后的“focused”回归也应使用直接runtime的no-parallel，或给repo runner增加从已发现inventory选择pattern的明确入口；不要默认把大filter丢给SwiftPM后就假定suite之间已串行。增加入口如有实施应保留inventory、隔离、deadline与cleanup合同，不能漏测。
3. **暂不建议改动**`SpendDashboardController`、Source的ownership/revision逻辑、`SpendDashboardTestSignal`的closed/cancelled expected或5秒生产者releaseTimeout；窄复现已经验证这些路径正常。将watchdog一律改60秒会掩盖测试无法及时释放producer的问题，也不解决MainActor拥塞。
4. 若worker1仍失败，应在具体selection单独保存MainActor线程栈/阶段耗时，确定是同步扫描、store/config初始化、锁还是未观察状态，再对真实阻塞点修改；不能仅凭本次bulk失败调整业务模型。由于本次禁止重型复跑，没有重跑整383项并发集合来制造第二次压力。
5. 原31个issues还包含其它未在本47项窄复现里覆盖的CatchUp/LocalHistory/controller selection；完整gate必须覆盖它们。不能把这份诊断视为38suites全通过。

## 产物边界与记忆

这份报告是失败诊断和局部review证据，不构成最终完整候选clean review。按codex-memory-capture评估，没有新增长期用户偏好；具体本轮测试证据保存在Research/本报告，不写记忆。
