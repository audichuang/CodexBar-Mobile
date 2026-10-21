# 测试与兼容证据

Status: `in-progress`；以下只记录实际完成的证据，Mac完整测试/lint、draft、iOS gate仍待完成。

## CloudKit Production schema 审计

- 对比最近 published fork tag `v0.76.0.2-mobile.2.10.0`；Shared/iCloud/CloudConstants.swift 零 diff，providerPayloadVersion 保持1。
- CK recordType/直接字段/index/predicate/subscription 写法无新增；severity 在现有 DeviceProviderSnapshot.payload opaque JSON 内，adapter 只是既有记录的更多实例，两个 provider 只是既有状态 zone 的运行时实例。
- Mac package_app.sh 与 iOS entitlement 都显式 Production。无需 Dashboard deploy；结论 **NO_DEPLOY**。未执行 Production schema 写入，未把代码审计声称为 live schema export。

## 2 Mac × 2 iPhone 兼容矩阵

- old Mac：published 0.76.0.2；old Shared/consumer 源码从该 release tag 冻结。mobile-dev 3.0.0 的 Shared 与该 tag 零 diff。new 是当前工作分支。
- CoreDevice 实时 inventory：两个 iPhone tunnel connected，另一个 unavailable；本轮未组织可分别切换 old/new 的两台 Mac + 两台 iPhone完整环境，因此所有组合采用替代验证，没有实体 PASS。
- 替代路径：tools/check_frozen_wire.py 编译新旧 Shared 与真实 ProviderSnapshotMerger，各 writer 独立 deviceID、reader 独立进程，验证64次读取/roundtrip和32次双 writer正反顺序合并；新 provider、Gemini额度、Claude identity、plugin severity 兼容。
- 限制：这个 harness 不运行 SwiftData / iCloud / APNs /后台/真实UI，不验证系统缓存/推送收敛、真实账户或网络异常。adapter身份、删账号、scope guard还需定向单测和 iOS merger tests 补足。

| Case | Mac A | Mac B | iPhone A | iPhone B | Result | Evidence | Notes |
|---:|---|---|---|---|---|---|---|
| 1 | old | old | old | old | substituted | compat/matrix-wire.json mask=0；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 |
| 2 | old | old | old | new | substituted | compat/matrix-wire.json mask=1；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 |
| 3 | old | old | new | old | substituted | compat/matrix-wire.json mask=2；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 |
| 4 | old | old | new | new | substituted | compat/matrix-wire.json mask=3；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 |
| 5 | old | new | old | old | substituted | compat/matrix-wire.json mask=4；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 旧 iOS 可能多显示一张无额度 Claude 本地成本卡；新 metadata 被忽略但基础金额/额度可读。 |
| 6 | old | new | old | new | substituted | compat/matrix-wire.json mask=5；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 旧 iOS 可能多显示一张无额度 Claude 本地成本卡；新 metadata 被忽略但基础金额/额度可读。 |
| 7 | old | new | new | old | substituted | compat/matrix-wire.json mask=6；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 旧 iOS 可能多显示一张无额度 Claude 本地成本卡；新 metadata 被忽略但基础金额/额度可读。 |
| 8 | old | new | new | new | substituted | compat/matrix-wire.json mask=7；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 |
| 9 | new | old | old | old | substituted | compat/matrix-wire.json mask=8；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 旧 iOS 可能多显示一张无额度 Claude 本地成本卡；新 metadata 被忽略但基础金额/额度可读。 |
| 10 | new | old | old | new | substituted | compat/matrix-wire.json mask=9；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 旧 iOS 可能多显示一张无额度 Claude 本地成本卡；新 metadata 被忽略但基础金额/额度可读。 |
| 11 | new | old | new | old | substituted | compat/matrix-wire.json mask=10；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 旧 iOS 可能多显示一张无额度 Claude 本地成本卡；新 metadata 被忽略但基础金额/额度可读。 |
| 12 | new | old | new | new | substituted | compat/matrix-wire.json mask=11；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 |
| 13 | new | new | old | old | substituted | compat/matrix-wire.json mask=12；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 旧 iOS 可能多显示一张无额度 Claude 本地成本卡；新 metadata 被忽略但基础金额/额度可读。 |
| 14 | new | new | old | new | substituted | compat/matrix-wire.json mask=13；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 旧 iOS 可能多显示一张无额度 Claude 本地成本卡；新 metadata 被忽略但基础金额/额度可读。 |
| 15 | new | new | new | old | substituted | compat/matrix-wire.json mask=14；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 旧 iOS 可能多显示一张无额度 Claude 本地成本卡；新 metadata 被忽略但基础金额/额度可读。 |
| 16 | new | new | new | new | substituted | compat/matrix-wire.json mask=15；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 |

当前 wire + pure merge 替代 gate：PASS（16/16）；完整同步 gate 仍待其余单测与风险汇总，不能据此声称实体矩阵或整轮发布完成。

## 命令与日志

- `swift build` 首次产品编译通过（v079-build.log，48.75秒）；后续 bridge/review改动需要最终重新编译。
- 中间测试编译暴露新增 fixture 的缺失 secondary 参数，已修复；不得计为测试通过。并发 build 的数据库锁只发生于一次独立检查，已改为串行 SwiftPM。
- 最终定向测试：v079-focused.log，运行中。
- lint 初次要求新 provider 文档生成，第二次发现 social.png cache token 不匹配（fork README先保留原字节导致）；已在主动事实审计后修复，最终 lint待重跑。
- 版本数字比较：evidence/version-plan.json，172.1.2.10.0 大于现有 appcast。
- upstream-checks.json 保存 tag b49d42eb5 的已完成 CI/release checks；没有触发 fork 远端 CI。

## Mac 最终定向 gate（ff931049f）

- `Scripts/test_fast.sh --filter 'SyncV079BridgeTests|ClaudeTokenAccountCostTests|CostUsageStoreTests|QuotaProviderListTests|MockProviderInjectorTests|AccountIdentity|MultiAccount|DualZoneReader'`：exit0。259项 / 18 suites + dashboard 11项 / 1 suite，全通过；包含新provider/metadata、adapter删slot两周期、tcr无active成本保留、scoped拒绝、cache原地迁移、多账号/多设备。
- `Scripts/lint.sh lint` 最终exit0（v079-lint-complete.log）：portable/CI/README/release guard、JS/TS、SwiftFormat、SwiftLint、所有catalog四语、433个iOS源key、parser版本/hash都通过。
- 完整 `Scripts/test.sh`：发现1791 test selections / 160 groups，运行中；未计为通过。
- 16组合harness在最终Shared合同重新运行：exit0，64 reads / 32 merges，新增cost clear-only envelope分类验证：新reader识别cost owner；旧reader保留但不识别分类，符合已披露额外卡风险。

## 新 provider 设备隔离（833483854）

- 独立review确认修复准确，SwiftLint严格检查exit0；frozen wire在此head重跑16/16，Future AGI/Munito由两writer时保留两个账号，旧reader同样读取既有accountRecordKey。
- matrix-wire.json / frozen-source-manifest.json已保存到evidence，绑定实际冻结源文件SHA256与harnessSHA256。
- 当前完整回归仍使用此前编译的481544bc7产品（旧provider路径未变）；新helper与两Mac不同组织内容的定向回归待随后执行，不将旧binary结果当新head全量。

## 最终回归补充（8111cb956）

- v079-policy-identity-tests.log：30 tests / 2 suites，exit0；覆盖最新新provider设备identity与Claude策略测试隔离。
- 首轮完整回归在第28组因测试未固定Keychain gate而失败；保留v079-all-tests.log，不计PASS。具体根因/修复见05。
- 最终全量改用仓库标准安全环境与双worker：`TMPDIR=.../v079/tmp bash Scripts/test.sh --direct-workers 2`，v079-all-tests-final.log。底层KeychainTestSafety仍禁止真实凭证读取。
- 上游检查快照30项中27 success / 3 skipped，无failure；依据ci-policy严格条件，**不把含skipped的快照声称为可复用的全部heavy CI通过**。未来获准merge时由Final CI脚本重新判断，必要时回退本fork完整矩阵；本轮未dispatch远端CI或push。
- 新Mac + 旧iOS的额外限制：旧CWL reader收到clear后可能仍回填以前combined历史。它不接收scoped金额，避免新目录历史混入；新iOS会在aggregate/dashboard/activity三层按来源抑制clear，保留原始历史供恢复。上述16组合wire替代不能验证旧SwiftData展示。

- v079-lint-policy.log：完整lint exit0，433 source keys齐全，parser version/hash、106 providers、fork policy/README等全部通过。
