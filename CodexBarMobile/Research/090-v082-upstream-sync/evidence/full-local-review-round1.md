# 完整独立本地 Code Review — 第一轮

日期：2026-10-28。审查者：mac_merge_review 子 agent；只读源码审查，未改 tracked 文件、未编译、未运行 UI/重型测试、未接触 live provider/真实 Keychain，未 push/创建 PR/发布。

## 结论

本轮发现 2 项可复现的 Cursor→iOS 语义/金额遗漏，已交主 agent 并独立复审其修复代码；当前源码层面两项已解决，暂未发现其他可操作阻塞问题。修复后的编译及 Cursor/V082 回归尚待主 agent 执行，因此本报告不宣称本地质量 gate 或最终交付已通过。完整 Mac worker1 测试仍在运行，Duo 的设备交互验证由另一独立 agent 负责；发布产物尚未生成，产物后审计必须补齐。

## 审查对象和来源

- 分支：`upstream-sync/v0.82.0-mobile.3.3.0`。
- 比较基线：`bdfb510853270c1ebf6b9d6f5ccbb289a2634db1`。
- 开始 HEAD：`2e51c676f3da02c981bce4ab518401aebd14e9c3`；开始 tracked binary diff SHA256：`2872aab3a78a3c30eb6b286abb32634c6a43041c6bf8a2a47ff21a9917b55856`。
- 结束 HEAD：`9ea3595e4c6adf13adb3fff2d1d509ae76bae5b2`；结束 tracked binary diff SHA256：`7708c680dae55f8b7513b4432c20cadeefa2838b35de0e65d307a94ad911c856`。
- 工作区候选（包含允许的新源码、测试及 Research evidence）逐文件 SHA256 记录：`full-local-review-round1-source-end.json`，文件 SHA256 `b5090bb8643d4083ee6827e59822383f4b9ed0003c611210b7153ad63c82cf13`；共 755 个新增/修改/删除路径。
- 对照正式 upstream v0.82.0：`7749f7b94ae8f1b84b9ffb2046643cec810f4078`；上游合并提交 `2f4e6a4baa6f8a4b9d00fa3870eac074aae661c8`。审查 merge conflict decisions、相对 upstream 保留的 fork 差异，以及后续已提交和未提交候选。
- 排除无关未跟踪 `error.log`、`work/`。报告与 manifest 只写 BuildScratch。工作区在审查期间由主 agent 修改，开始/结束 manifest 都保留，后续变更不能自动继承本报告。

审查方法为完整 diff/变更清单审计、手工冲突路径与关键调用链检查、对照上游实现及真实/合成 fixture、旧新读写消费者和发布输入检查。未对全部上游新增行做逐行证明；上游未改动代码以精确 upstream 对照及集成接口/新增功能专项为主要检查方式。本轮不是只审 bridge，也不以 Research/06 的分类本身代替源码结论。

## 本轮发现及修复状态

### R1 — P2：Cursor 统一订阅的周池错误标成 Total

**原问题位置：** 修复前 `Sources/CodexBar/Sync/SyncCoordinator.swift:1200–1221`。Core 的 `CursorStatusProbe.toUsageSnapshot` 将统一 X Subscription 的 10080 分钟 shared weekly pool 提升为 primary，并清除 legacy monthly breakdown；该 RateWindow 没有显式 label/title。Mac `CursorProviderDescriptor.primaryLabel(snapshot:)` 会返回 Weekly，但原桥接仅使用静态 `metadata.sessionLabel=Total`。iOS `ProviderWindowLabel.localized` 将 Total 直接本地化，app/sidebar/widgets 不会根据 period 自动纠正。

**复现依据：** `Tests/CodexBarTests/CursorSandUsageTests.swift` 的 sanitized X Subscription summary + unified Sand response；`CursorUnifiedWeeklyPresentationTests` 已证实上游 Mac Weekly 语义。

**修复复审：** `SyncCoordinator.syncPrimaryRateWindow` 由生产 builder 调用，Cursor fallback 使用 `CursorProviderDescriptor.primaryLabel`，原始 `label ?? title ?? fallback` 优先级保留；legacy 非 unified 快照仍为 Total。CursorSandUsageTests 以同一上游 fixture 参数化 true/false，断言 label/percent/reset。源码修复通过；重编和执行待主 agent 回填。

### R2 — P2：Cursor 无上限按需消费未进入 iOS payload

**原问题位置：** 修复前 `Sources/CodexBar/Sync/SyncCoordinator.swift:1284–1294` 的 budget `limit>0` guard，以及 `mapProviderAmount` 未包含 Cursor。上游 sanitized X Subscription fixture 明确存在 individual onDemand used=447 cents、limit=null 和 team limit=0；Core 保留 `providerCost.used=4.47, limit=0, period=Monthly`。budget 被过滤，providerAmount 为 nil，统一周池又不保留旧 extra/details，iPhone 会完全丢失该独立按需金额。

**修复复审：** `.cursor` 接入 existing kind=spend 的 `limit<=0` 分支；正上限仍仅走 budget，避免重复卡片。CursorSandUsageTests 检查真实 fixture 的 4.47/Monthly/observedAt；V082MobileBridgeTests 覆盖真实 zero 清除及正 limit 不重复。源码修复通过；重编和执行待主 agent 回填。

以上两项已在本轮阅读后修复，不作为“后续再处理”的遗留项。执行证据仍需闭环；若复测失败需重新打开。

## 覆盖范围和检查结论

| 领域 | 具体审查 | 源码结论及边界 |
| --- | --- | --- |
| 上游合并与 fork 冲突 | remerge conflict 文件清单，RateWindow/UsageSnapshot、UsageStore 重命名文件、provider mapper、CostUsageStore、README、CI、package/release/appcast 冲突 | 未发现上游功能被整体回退。README 先保留 fork 后以 c7b11c28e 独立事实更新；不是修改 hash 掩盖上游替换 |
| Mac/Core 功能 | 新 Soniox/TraeCN/Abliteration/Chatbox；Cursor 周池与月费用；Kimi totals/gifts；Command Code saved-cookie 多账号；plugin title/expectedUsed；upstream 新 CLI credential/Cursor encrypted auth 的集成 | 两项 Cursor 缺陷如上；其余无新发现。Cursor SafeStorage allowPrompt=true 仍经 ACL preflight + BrowserCookieAccessGate，background 不直接变成可交互 secret read；仅读源码/隔离测试实现，无真实 Keychain 查询 |
| 账户/设备与双同步系统 | AccountIdentityComputer、SyncCoordinator account keys/identity override、TokenAccountSupportCatalog、TokenAccounts fan-out、FleetAccounts observation | 四新 provider 缺验证身份按 device 隔离；不使用 API key/license 当账户。Command Code 动态 catalog 包含新支持。重命名的 AccountRefreshPolicy 方法保留在 TokenAccounts，fork iCloud fan-out 保留；Mac fleet 用 macFleetSync*，未误接 Mobile iCloud 开关 |
| cost/cache/ownership | sourceRecorded + isEstimated provenance；Cowork/dedup/unpriced lower bound；parser compatible predecessor 集合/ownership revision adoption；Codex/OpenCode opt-in publication scope | 保留 fork provenance 和 published parser predecessor，按原 owner hydration 后提升 revision；OpenCode ambient Codex 合并与 opt-in scope 一致，非无条件双计；无新的数据完整性问题发现 |
| Shared/wire/CloudKit | quotaLimit/unit、detail progress.expectedUsed、expiresAt 的 init/容错 decode/encode、所有 bridge copy/projection、old/new merger、provider append-only 列表 | 可选新 key，缺失/畸形 optional 不抹掉有效旧数据；expiresAt 保持 machine date，旧 payload 不猜本地日期。CK 源码结构审计 NO_DEPLOY 合理；未验证已签包 Production entitlement、Dashboard/网络 schema |
| iOS 与共享消费者 | DailyAllowanceTarget、UsageCard/BudgetProgress/ProviderDetails、Kimi reader/localization、ProviderWindowLabel、Widget/shared consumers、新 provider color/catalog、release notes/project versions | calendar-days 分母处理 midnight/DST，unknown/placeholder/blocker 抑制，单位/币种本地化；Kimi 过期余额不继续显示可用，动态 gift 名保留。新增内容未重写导航结构；无新源码阻塞发现 |
| Duo/普通布局及测试改动 | AX3 header/金额 fallback，AdaptiveReportPanes identifier-only change；DuoWorkspaceUITests 手势定位到 active window scroll ancestor、multi-screen screenshots、原生 fold/unfold 的实际 frame 断言 | 未发现新增产品滚动行为变更或测试绕过。原手势失败根因和真实交互结果由另一 agent 证明；该报告不以泛型 hosting render 替代 native Duo 结果 |
| 本地化/发布文本 | Source-key/canonical catalog、新 Kimi/单位/expected 文案、3.3.0 单 release block、4语言条目、Mac/iOS changelog | 轻量 source audit 当时 532 key 均存在；locale render/最终 lint 以主 agent 当前日志和输入 hash 为准，未新增 release notes 版本拆分 |
| 版本/CI/release 输入 | version.env、project.yml 五 targets、generated project、Sparkle feed/key/build/package plist、fork PR triggers/path gate、Mac draft/no-tag release流程 | Mac 0.82.0.1 / 175.1 / companion3.2.0，CFBundleVersion175.1.3.2.0；iOS3.3.0(261)。保留当前已交付 companion3.2；未提前声称 iOS3.3 已发布。PR 轻检查/merge heavy CI 模型保留，appcast 未改；SUAutomaticallyUpdate=true 是上游更新策略合入 |
| 测试完整性和隔离 | 全量失败的先前诊断、fixture TMPDIR 实际路径、watchdog vs suite contention、focused bridge tests、16-case harness 源码和来源 | prior isolation 报告保留，不将 knownflake 当豁免。最新完整 gate 仍待结果；没有用旧二进制通过证明新 Cursor 修复。16 case 全部诚实标 substituted，非实体 PASS |

## 仍需完成的 gate / 证据

这些是当前阶段尚未产生的交付材料，不是以“0新 finding”消除的要求：

1. 主 agent 当前完整 Mac worker1 gate 及修复后重编 Cursor/V082/受影响 mapper 测试；保留失败与 narrow 诊断链。本轮没有重复启动重型 runner。
2. 最新 iOS UI/四语/AX 普通设备和 native Duo 结果（尤其 Cost/share reachable control、fold/unfold/rotation 后操作）；报告需记录实际 active display/frame 与失败尝试。
3. Research/03 对最终 commit/dirty/artifact source hash、真实测试结果及 substituted 16-case 风险的回填。离线矩阵证明模型/反序合并，不证明 CK 推送、持久 cache/SwiftData 迁移、断网恢复或四真实设备收敛。
4. Mac draft 包尚未生成：必须后审签名/notarization/staple、Production entitlement、embedded version/feed/key、ZIP/dSYM/appcast 输入和 source/artifact provenance；不能以源码 NO_DEPLOY 或 make脚本审查代替实包。
5. 新修复后的最终 complete candidate 重查、GitHub PR 当前 head Code Review 及 review gate。此次本地 review 不替代 PR review，也不授权 merge/tag/live release/TestFlight/schema deploy。

## 审查期间发生的候选变化

下列路径相对开始 manifest 有变化（已读当前源码/相关 diff；Research evidence 为阶段记录，不提升其事实强度）：

- `CodexBarMobile/CodexBarMobileUITests/DuoWorkspaceUITests.swift`
- `CodexBarMobile/Research/090-v082-upstream-sync/03-testing.md`
- `CodexBarMobile/Research/090-v082-upstream-sync/evidence/duo-cost-failure-review.md`
- `CodexBarMobile/Research/090-v082-upstream-sync/evidence/duo-input-routing.json`
- `CodexBarMobile/Research/090-v082-upstream-sync/evidence/duo-routing-retest-events.json`
- `CodexBarMobile/Research/090-v082-upstream-sync/evidence/duo-routing-retest-review.md`
- `CodexBarMobile/Research/090-v082-upstream-sync/evidence/mac-spend-readiness-review.md`
- `CodexBarMobile/Research/090-v082-upstream-sync/evidence/mac-test-failure-review.md`
- `CodexBarMobile/Research/090-v082-upstream-sync/evidence/v082-render-visual-review.md`
- `Sources/CodexBar/SpendDashboard/SpendDashboardModel+CurrencyGroup.swift`
- `Sources/CodexBar/Sync/SyncCoordinator.swift`
- `Tests/CodexBarTests/CursorSandUsageTests.swift`
- `Tests/CodexBarTests/V082MobileBridgeTests.swift`
