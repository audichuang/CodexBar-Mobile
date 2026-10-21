# 循环 review 证据

Status: `in-progress`；Mac阶段阻塞0，iOS修复/最终review待执行。

## 范围

- 自查 origin/mobile-dev → merge，并对照 v0.79.0，保留fork CI/release/CloudKit/versioning/README。
- 使用独立review agent（只读，不共写文件、不运行真实provider/Keychain），对Mac合并、bridge、cache和旧iOS合同循环审查。
- 没有push/PR，不能把本地review叫作GitHub exact-head clean review；未来merge/tag/live仍须仓库PR gate。

## Mac五轮根因审查

1. P1：parser predecessor遗漏已发布fork hash；P1：mapped Claude cost绕过current-scope验证。已修并测试。
2. adapter slot跨Mac/slot重用身份、workspace同邮箱、source selection与scanner scope不同、tcr无active、单账号precedence/无snapshot错误卡。按来源所有权整体调整，非堆叠菜单特判。
3. 独立cost owner不能算额外quota账号；Shared isProviderLevelCostEnvelope扩展。旧reader展示限制进入矩阵。
4. nil不是withdrawal，旧CWL是machine-wide。根因审计写入01：本轮Mobile拒绝scoped history，Mac完整支持；统一clear合同、同keytombstone、说明文案，不让scoped daily污染旧ledger。
5. 按最终合同复审Mac阻塞0；iOS fromLedger clear回填列入下一阶段。

Reviewer第4轮曾怀疑hasUsableSignal遗漏clear；实际基线已包含costSummaryCleared=true，第5轮已纠正，不为错误finding改代码。

## 独立 iOS contract 审查

- 找到fromLedger、TokenActivity.series、source-device ledger aggregation三处clear回填；以“不删ledger、仅抑制撤回来源、普通nil保留fallback”为一套修复设计。
- Shared成本owner分类已被Usage/widget通用过滤接线，费用仍统计；需补两quota+一owner count/cost回归。
- 新provider四语路由、动态meter名保留、window标签和severity完整/teaser/VoiceOver计划已明确。
- 发现Future AGI/Munito第一方mapper不会复用custom-plugin设备隔离，nil身份会落legacy跨Macbucket。修复833483854只为这两个新provider补device fallback，并保留requested key、Wayfinder和其他provider行为。独立复审实际diff阻塞0。
- 833483854后的冻结wire矩阵（含新provider双Mac两账号）通过；Mac新helper定向测试将在当前full regression结束后运行。

## 尚待闭环

Mac完整测试终态、Macdraft、iOS实现/测试与最终diff review均未完成，不能提前声称Goal done。

## 全量回归暴露的测试隔离

全量第28组的 Claude onlyOnUserAction characterization 连续失败。独立只读审查确认 runner 显式 CODEXBAR_DISABLE_KEYCHAIN_ACCESS=1 合法触发上游 cold-profile owner CLI fallback，原测试未固定其所需的 enabled gate。测试增加已有 withBackgroundKeychainAccess task override，凭证读取仍通过 isolated memory/file/keychain stub 与底层 test safety。产品 guard 不改。最终全量使用标准 Scripts/test.sh 的 CODEXBAR_SUPPRESS_TEST_KEYCHAIN_ACCESS=1，不把“禁止真实SecItem”混同于产品的“用户禁用Keychain”开关。

## Mac draft流程独立审查

8111cb956 + make_appcast scratch diff静态审查阻塞0：draft-no-tag-push跳过tag/push/旧draft删除，只创建fork draft，target mobile-dev占位并记录local SHA；不会进入finalize。版本172.1.2.10.0单调递增，Production entitlement保留。make_appcast复制ZIP暂存从/tmp改至已验证SSD BuildScratch；实际签名命令显式export RELEASE_STAGE_BASE与widget root，不依赖默认/tmp。

## 新provider身份根因修订复审

独立review重新核对Munito实际plugin→mapper→sync record key：组织ID存在，前次把“未提取”当成“没有ID”已纠正。当前同组织跨Mac/不同组织/改名/缺ID合同无实现阻塞，wire不含API key。ID trim/NFC/case/长ID区别与实际全snapshot publication补测均通过。当前新provider不支持tokenAccountSupport；未来若增加该能力，显式requested keys优先的边界需重新设计，不能把本轮验证扩大到尚不存在的多token路径。

## 最终Mac实现review

原Mac reviewer独立检查staged tree `8f3b05e6f4f9151b0571a2f040e569206fa57bf2`，剩余实现阻塞0；组织身份、实际push测试、架构guard特定reason与旧anchor迁移均认可，没有放宽守卫。完整回归随后160/160 first-pass通过。下一阶段为打包与iOS，不能把本地review扩称未来GitHub exact-head gate通过。
