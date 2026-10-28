# iOS / Shared 独立局部审查

日期：2026-10-28。审查者：独立本地 agent `ios_candidate_review`。本审查只读产品代码，不代替最终完整候选 Code Review、测试、Duo 或发布 gate。

## 来源和范围

- 分支：`upstream-sync/v0.82.0-mobile.3.3.0`；fork基线 `bdfb510853270c1ebf6b9d6f5ccbb289a2634db1`；HEAD `c7b11c28e8474294fb0eb924a5d0a62996a74633` 加持续开发中的工作区。
- 审查输入指纹：`ios-candidate-review-source.json`，SHA256 `8898fd8b0ed70bb28f034ebbc3a8ffaf48aeb32adbbee49cbbbbb006aa5a35c4`。审查期间主线程已陆续修复发现的问题；指纹是报告时源码快照，不宣称整个时段源码静止。
- 已读 AGENTS、development-quality、Research090的00/01/02/03/06，按apple-workflow-skills的Apple UI与Duo规则审查。
- 覆盖iOS/Shared完整base-to-working diff，新增DailyAllowanceTarget、metadata/render专项测试、4provider语义和配色、release notes、五target版本以及生成项目。追踪到Mac provider原始输出、SyncCoordinator、Shared Codable、ProviderSnapshotMerger和QuotaPace/Widget消费合同。
- 验证了StudioSSD挂载/UUID、working symlink和repo realpath；只在BuildScratch写本报告和来源清单。未运行或终止主线程构建/测试，没有触碰真实Keychain、账号、CloudKit、推送、PR或发布。

## Findings

### F1 — P2：每日target的已知额度单位没有读端本地化

发现时位置：`CodexBarMobile/CodexBarMobile/Models/DailyAllowanceTarget.swift` 的 `text(locale:)` 非ISO货币分支（原55–56行）。直接拼接 `self.unit`，导致英语Mac发送Notion的 `quotaUnit="credits"` 或月预算 `currencyCode="Credits"` 时，中文/日文target虽翻译整句，单位仍英文。上游Notion插件明确输出credits，Mac的UsagePaceText则对credits/requests专门翻译。这违反本轮四语的用户文案合同。

**状态**：已即时反馈。报告时主线程已补已知credits/requests/tokens/points映射，未知自定义单位原样保留；已增加四语单测，仍须当前源码的复测。曾提醒新测试不应对技术术语tokens强制要求翻译后不同于英文，因为原catalog四语均合法使用tokens。

### F2 — P2：Kimi新明细继续使用Mac语言和日期，赠送余额跨到期仍显示可用

发现时位置：`Sources/CodexBarCore/Providers/Kimi/KimiUsageSnapshot.swift:195–211`、`CodexBarMobile/CodexBarMobile/Models/ProviderDetailRowPresentation.swift:25–36`，以及 `ProviderDetailLocalization.localizedValue` 的provider switch。

Kimi赠送行只在producer的updatedAt过滤过期，发送 `Expires <Mac本机日期字符串>`，未提供机器expiry。iOS原来只对Claude cloud-credit做expiry处理；kimi经generic路径原样传value/secondary并固定isExpired=false。因此英语Mac→中文/日语iPhone会出现“25% used”与“Expires Oct…”；手机保存snapshot后跨过expiry、Mac未刷新时仍保持剩余额度条。新的四语Kimi标签翻译不能解决数值文案和期限状态。

**状态**：已反馈并确认主线程采用最小合同修复：Core/Shared Row可选expiresAt、makeRow helpers和mapDetails转发；Kimi使用原始ISO expireTime解析结果，同时保留Mac secondaryValue原外观；iOS按kimi+Bonus credits或monthly稳定row ID重建本地化比例和到期状态。报告时这条源码链已可见，尚未以编译和新冻结缓存/跨语言测试验收，不宣称最终通过。

最小合同检查要点：

1. Core Row的init/CodingKeys/decode及两个makeRow helper均转发expiresAt；Shared使用容错optional解码和finite过滤；nil时旧payload形状保持。
2. KimiCreditBalance只有feature/type/ratios/expireTime/displayName，没有gift ID，不要从密钥或显示日期构造账号身份。monthly两行已有 `kimi-monthly-code` / `kimi-monthly-other`；progress.used/total足够重建“used”，gift用其补数重建“left”，不解析Mac显示字符串。
3. 无机器expiry的旧行保留已知文本，不猜Mac语言日期/时区。新字段需补old/new反向解码和16组合替代证据，最终CloudKit代码审计指纹也要更新；仍是既有opaque payload，不能因此声称生产schema已deploy。
4. native Kimi合同不要求同步扩张JS插件API；若没有JS生产者，原plugin mapper通过默认nil即可。

### F3 — P2：Kimi赠送包动态名称会被语义字典误翻译

位置：`CodexBarMobile/CodexBarWidgetShared/ProviderDetailLocalization.swift` 新增kimi到firstPartyProviderIDs，通用localized guard原129–135行；Kimi giftDetails原203–205行。

gift row.label来自服务返回的balance.displayName，不是固定UI语义；Bonus credits未有context保护。赠送包名若恰为 `Plan`、`Monthly` 或 `Other features`，日文读端会把真实名称改为プラン、毎月或その他の機能。与文件中保护动态grant/model/account名称的既有政策相冲突，也与本轮“动态标签保留原样”的设计不同。

**状态**：已反馈；主线程已告知补了动态名称保护和Plan对照测试，尚待当前源码复测。建议在kimi+Bonus credits的row-label context中，只让默认fallback `Bonus credits` 走固定语义本地化，其他赠送包名原样；section标题仍正常翻译。补“名为Plan的gift”与“默认Bonus credits”的对照测试即可，无需为了该项增加wire。

### F4 — P2：Copilot无duration月度窗口没有每日target

位置：`Sources/CodexBarCore/Providers/Copilot/CopilotProviderDescriptor.swift:65–67`、`CopilotUsageFetcher.swift:183–188`、`CopilotBudgetWebFetcher.swift:631–639`，以及 `SyncCoordinator.syncRateWindow` 和 `DailyAllowanceTarget.init(window:)`。

monthlyWindowSentinelMinutes是43200，Kimi、Command Code等使用该值，可被读端28…31天规则识别；Soniox有正预算时经This month budget路径计算，没有预算即没有allowance，不显示target是正确的。但Copilot的capability明确为inferredMonthlyDuration=windowDurationMissing，producer月度窗口的windowMinutes与period均nil。Mac monthlyTargetMetrics通过capability识别该月额度，桥接只原样发period，手机只看period.monthly或28…31天duration，因此同一Copilot月额度在Mac有每日target而iPhone丢失。

**状态**：已即时反馈主线程，待修复/验证。建议桥接端在显式period缺失且provider descriptor的usesInferredMonthlyDuration(window)为true时，使用已有period.monthly；保留显式period和原windowMinutes，不能把真实日历月改成固定30天。另一可行方案是读端带providerID复用同等可信的period规则。补真实Copilot wire形状的target正例及无reset负例。此项不需要新schema或新wire字段。

## 未发现额外阻塞的覆盖面

- quotaLimit/quotaUnit及Progress.expectedUsed均optional、nil缺省；坏optional不会丢有效使用率或进度。expectedUsed范围与Core的0…total一致。Shared未提升payloadVersion，旧reader按未知键忽略。
- 日历dayCount与上游实现相同，含今天、午夜reset不额外计次日；DateComponents按日历而非秒数，因此设计可跨DST。旧月度payload回退百分比、unknown/expired/blocked/placeholder不造target。仍建议补明确DST和有/无reset预算case，以强化关键新功能证据。
- Codex固定30天已有QuotaPace真实duration分支；没有被本轮误判成weekly。Kimi blocked投影刻意不携带原始allowance，避免把不同池的额度混用。
- Soniox独立balance/unbounded-spend、其他3家generic details和device-scoped identity的iOS消费链可达；没有把余额/月累计用量并入会话Cost总数。
- 新4provider的QuotaProviderList是尾追加，既有前缀/zone命名不变。ProviderSnapshotMerger保留原观察的窗口和details，不将新optional fields无条件用旧观察覆盖。既有账号、cost owner/clear、cache和widget数据模型未被本轮重写。
- 五个项目targets均3.3.0(261)，生成项目有新模型/测试引用，最低iOS17未提升。3.2.0旧notes仍在同一block，只降Latest；3.3.0新增一个block。
- Localizable.xcstrings重复键检查为0；本轮新增语义/feature文案有四语translated值。动态插件label本身继续verbatim。
- AX header改动限定quota/budget内部排列；没有新增按型号/屏幕尺寸缓存、重写Duo导航、自动选中账号或修改分享草稿状态。

## 不能由本报告证明的gate

没有执行当前候选的完整测试、Archive/签名、Mac draft、真实多设备CloudKit或Duo姿态交互。主线程的既有1272单测和native render日志是有来源的阶段证据，后续源码已变化，需相应复测；报告不把render图片存在当成无裁切验收。本次共发现4项，前三项已进入主线程修复（仍待最终验证），Copilot月target遗漏已追加反馈。当前还不是可push的最终clean候选，必须补测试、全候选独立review及后续PR exact-head gate。

按codex-memory-capture判断：发现属于本轮数据合同和本地化修复，证据应留在Research，不新增长期记忆或任务日志。
