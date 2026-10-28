# Mac / Shared 合并独立局部审查

日期：2026-10-28。审查者：独立本地 agent `mac_merge_review`。这是开发中的局部审查，**不能替代最终完整候选审查，也不构成发布批准**。

## 范围与来源

- fork 基线：`bdfb510853270c1ebf6b9d6f5ccbb289a2634db1`。
- 上游目标：官方 `v0.82.0` / `7749f7b94ae8f1b84b9ffb2046643cec810f4078`。
- 核心合并：`2f4e6a4baa6f8a4b9d00fa3870eac074aae661c8`；审查结束时 HEAD：`c7b11c28e8474294fb0eb924a5d0a62996a74633`，另有主 agent 正在修复的工作区差异。
- 已读取 AGENTS.md、docs/development-quality.md、Research090 的00/01/02，核对相对 fork 基线的 Shared/SyncCoordinator 增量和相对上游的冲突保留。
- 源审查覆盖：RateWindow/ProviderPluginSnapshotMapper/Shared optional metadata、SyncCoordinator 数据构建与真实调用、四个新provider插件/descriptor、Command Code session/catalog/fetch/cache/fan-out、成本报告 provenance/isEstimated/cache parser兼容、quota warnings、Mac fleet/mobile设置分离、fork CI与打包plist关键差异。
- 只写本报告及隔离测试日志，没有修改受跟踪文件，没有执行真实 Keychain、provider live probe、CloudKit或外部通信。
- StudioSSD mount / UUID / symbolic link / realpath / scratch可写检查通过。

## Findings

### F1 — P1：Soniox 余额与无预算月支出未进入 iOS

初始位置：`Sources/CodexBar/Sync/SyncCoordinator.swift` 的预算构造（约1260）、`mapProviderAmount` switch（约1579）。

`soniox.ts` 把月支出、可选正预算和预付余额保存在 providerCost，details 只含结算方式及预算0说明。预算桥接要求 limit>0，而金额 switch 没有 soniox。因此 budget=0 时月支出、余额均丢失；正预算时仍丢失余额。没有预算的常见账户在iPhone只剩 Prepaid/Invoice billing=USD 与 $0预算说明。

建议使用既有 providerAmount 携带独立预付余额（包括0、负数），既有预算携带正预算支出；无预算同时有余额时需通过既有details保留月支出，不能用一个值覆盖另一个。invoice无预算可使用spend金额。余额周期不能继承月支出 `This month`，宜用已有 `Prepaid balance`；spend的This month需核对ProviderAmountCard的四语映射。测试应覆盖 prepaid/invoice × budget0/positive × used0/positive × balance nil/negative/zero/positive，并验证observedAt。

**处理状态**：已即时告知主 agent。审查结束时工作区已有 Soniox amount/details 修复与32组合新测试，仍待完整调用路径测试、周期语义/本地化复查和编译复测；本报告不据此声称该项最终通过。

### F2 — P2：插件自定义窗口标题被默认回退标签覆盖

初始位置：SyncCoordinator `syncRateWindow` 约802，`mapPluginProviderUsageSnapshot` 约953–968。

helper 使用 `label ?? window.title`，真实插件调用总传非nil的additionalWindowLabel，因此v0.82支持的primary/secondary/tertiary自定义title都不能到达iOS。Mac UserPluginQuotaPresentation明确优先title；初始新测试label:nil绕过了真实路径。

**处理状态**：主 agent 已在三个真实插件调用及第一方三槽调用优先显式label/title，保留NamedRateWindow.title优先，并补真实mapPluginProviderUsageSnapshot的三个槽+extra断言。代码路径复查符合预期；编译/运行证据仍由主任务收口。

### F3 — P2：Token-account catalog固定集合未纳入 Command Code，必需单测失败

初始位置：`Tests/CodexBarTests/TokenAccountSyncCoverageTests.swift` 约39–88。

上游新Command Code descriptor通过tokenAccountSupport加入动态catalog，但fork回归哨兵expected仍停在38项。实际隔离执行 `source Scripts/test_environment.sh; swift test --skip-build --filter TokenAccountSyncCoverageTests`，3 tests中1项失败，报告 added=["commandcode"]；动态catalog与SyncCoordinator覆盖相等的测试通过。

证据：`/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/Upstream082/review-token-catalog.log`。此命令使用现有已编译测试二进制，验证的是修复前哨兵，不能作为修复后的结果。

**处理状态**：主 agent 已有意更新为39项及commandcode；需重新编译复测。Command Code生产数据路径源审查显示动态catalog → shouldFetchAllTokenAccounts → token override/manual/web → co-resident snapshots → SyncCoordinator token UUID record key可达，没有发现额外fan-out实现缺陷。建议补fork专项 fan-out桥接验证，不只依赖上游HTTP/session测试。

## 其他核对结论与边界

- Trae CN、abliteration.ai、Chatbox没有Soniox式providerCost遗失：它们所有额度、余额、使用量明细都在generic details；primary/secondary、expiry经现有桥接。无重置证据的聚合池未虚构reset。
- 新四provider在没有已验证身份时按device隔离；Command Code按已保存token account UUID隔离；没有把license/API key作为身份写入wire。
- Shared新增quotaLimit/quotaUnit/expectedUsed为可选opaque JSON，坏optional不会抛弃有效usage/progress。balanceDescription复制保留额度元数据。
- 上游sourceRecorded与fork isEstimated合并共存；报告累加保留source provenance key；fork predecessor parser hash兼容集合保留已发布0.79 hash；creator-account revision原位采用代码保留历史与检查点。未发现本次冲突新增的成本owner/clear重复计费缺陷，但本次没有执行完整成本历史回归，不能据源审查称全量测试通过。
- Mac fleet新观察器使用macFleetSync属性，与Mobile开关分离；CloudSync旧record field代码审计未见新增schema字段。正式CloudKit审计仍必须以最终diff/最近published基线完成。
- CI fork trigger与guard、package_app的fork Sparkle key/feed/Mobile版本/Production约束与上游SUAutomaticallyUpdate共存。README另外独立审查不由本报告替代。
- 本报告未覆盖实际UI/Duo/真实四设备同步、签名公证/draft、iOS最终实现、最终PR head的完整独立review。

## 审查结束的工作区文件指纹

- `Sources/CodexBar/Sync/SyncCoordinator.swift`: `34ce1eeee39a607173f1df9cd6ac9abe5346e1f1aa283bdc319ea8fc7c020745`
- `Tests/CodexBarTests/V082MobileBridgeTests.swift`: `398bc0151bd3ef9cd5b36534e3e5e842ced65ee27976aea9d5ba430f3e659ca5`
- `Tests/CodexBarTests/TokenAccountSyncCoverageTests.swift`: `aba36f7f108b740631d3e4b6fe53573b4b653cee9e8616e0de3bba68ee2765b7`

这些指纹只说明审查结束时看到的开发中修复输入；后续源码和测试仍可能变化，最终clean报告必须重新绑定完整候选。

按 codex-memory-capture 评估：这次局部缺陷与修复证据归本轮Research和本报告，没有新增需要写入长期记忆的用户偏好，不写记忆。
