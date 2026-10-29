# 完整候选独立本地 Code Review — 第二轮（源码阶段）

审查者：final_candidate_review，2026-10-28。只读产品源码、Git diff 和证据；只写 BuildScratch 报告，没有修改仓库、运行构建/测试、操作设备、访问真实账号/Keychain 或 push。

## 结论

本轮发现 **1 项本轮新增 P2 数据来源语义缺陷**，含后续漏消费者；主 agent 已完成源码修复并经独立补审。另发现 1 项基线既存 fleet 门控错误，以及新增异步参数测试的共享 fixture 竞争，均已修正源码。目前 **0 项未解决源码 finding**；执行结果、当前提交与产物仍待收拢，不能提前标完整本地质量 gate clean。下文保留发现时的证据与修复历程。

本报告覆盖完整候选的变更清单、官方保留关系、fork 集成及关键功能调用链，不能替代还在进行的系统 Widget、最终 iOS/旧系统/iPad 回归、签名产物后审与最终当前提交复审。既有完成结果不自动覆盖审查期间或之后的新修改。

## 来源与逐路径清单

- 基线 `bdfb510853270c1ebf6b9d6f5ccbb289a2634db1`；官方 release `7749f7b94ae8f1b84b9ffb2046643cec810f4078`。
- 开始 HEAD `725746684f87120046f26b9d1ab343a17871604d`；dirty diff SHA256 `7cbf6b8c1497195eb48375f20466a4659a793e068377b6ebd57cbce7db2d0748`。
- 结束 HEAD `82cd093d1780b0540308a9e4029ae9d400e5401c`；dirty diff SHA256 `ea4f1ed87041937b28355c93dfb75278bbaa754e69666cc510eb7be69567abf9`。
- 结束时 754 个 tracked 变更路径，其中 599 个与官方 v0.82 对应路径字节相同（包括上游目录移动后删除的旧路径），155 个保留 fork/新增差异；另有本轮未提交 Research evidence。
- `final-local-review-round2-source-start.json` / `final-local-review-round2-source-end.json` 记录每个新增、修改、删除路径的 SHA256、官方一致性与审查类别；无关 `error.log` / `work/` 排除。
- 主 agent 在审查中提交了测试/格式收尾，并修改 fleet 门控；不是一个完全静止的 checkout。结束 manifest 不能自动视为每个后来变化都经重新审核。

## R2-F1 — P2 原始发现：OpenCode 来源记录成本被误标为本 App 的价目表估算

**位置与路径：** `Sources/CodexBarCore/Providers/OpenCode/OpenCodeLocalHistoryAdapter.swift:929` 产出 `sourceRecorded: true`，其金额来自来源记录（包含明确 $0），并通过本轮新增 ambient Codex opt-in 合入 daily report。`CostUsageFetcher.swift:845` 的 fresh snapshot 与 `:1531` 的 cached snapshot 仍无条件使用 `.listPriceEstimate`；相关 native/Pi 副本也使用同一假定。`CostUsageModels.swift:301–304` 的 `windowSummary` 只读取该 snapshot enum，不识别窗口内 `sourceRecorded` rows。`SyncCoordinator` 将其映射到已有 SyncCostProvenance，`CodexBarMobile/.../ProviderDetailView.swift:726–729` 因而给来源记录的窗口显示 “List-price equivalent — not a billing receipt.”。

**触发与影响：** 开启本轮新 OpenCode local history 选项后，若选定窗口只有 OpenCode 记录成本，或来源记录与 Codex list-price 行混合，这段说明错误声称所有金额由本 App 的模型价目表换算。明确记录的零金额总值没有丢失；问题是用户可见的来源/估算解释失真。没有把这一问题夸大成重复计费或真实账单金额错误。

**修复验收：** 让窗口来源判定识别来源记录，不简单把 OpenCode 记录冒充 vendor billing。验证 recorded-only（含 $0）、priced-only、mixed、不同日期范围、fresh/cached，以及 Mac→Sync→iOS 实际说明的含义。若增加 wire 字段，保留旧 reader 容错并更新兼容证据；也可采用明确、保守且准确的既有 contract。这是原始发现时的验收要求；后续修复状态见末尾补审记录。

## R2-O1 — 基线既存 fleet 开关门控（本轮采纳修复）

`PreferencesICloudSyncPane.swift:46` 的 Mac fleet 子选项容器原来以手机同步 `iCloudSyncEnabled` 控制 enabled 状态，而主开关、Refresh、设备行为使用 `macFleetSyncEnabled`。关闭 Mobile/开启 fleet 时不能编辑 snapshots、Show accounts 等项；反向设置又会允许无效子选项。该行与 bdf 基线旧目录文件完全一致，不能归因于上游 merge 新增。

主 agent 选择纳入修复，因为本轮新增菜单栏 fleet fallback 会受影响。结束前已独立读回 `.disabled(!self.syncCanRun || !self.settings.macFleetSyncEnabled)`，保留 availability/update 约束，不主动开启 secrets 或 fleet。源码修正合理；相关 test/build/lint 结果尚待主 agent 提供。

## 已检查领域

| 领域 | 实际检查与结论 |
| --- | --- |
| 完整 merge 与来源 | 对照 v0.82 全变更清单、第二 parent 与官方 release/75 条 impact audit；599 个启动时 official-equal 路径做字节保留/引用审计，未以旧 fork 回退上游功能。不是所有官方新增行逐行证明 |
| Shared / Sync | optional quotaLimit/unit、expectedUsed、expiresAt 的构造/编码/坏 optional 容错；生产 builder/copy/projection 链、plugin 三槽 title/id、Cursor Weekly/legacy/uncapped spend、Soniox balance/spend 双通道及时间戳，未见新的字段丢失 |
| provider / 账号 | 新四 provider 描述器/插件、Kimi gifts/monthly、Command Code token support、dynamic fanout catalog、AccountIdentityComputer 与 per-device keys；不以 token/license 作跨设备身份，旧 append-only 订阅顺序保留 |
| cost / cache | 新 OpenCode scope gate/只读来源/recorded $0/provenance key；Cowork request_id 去重、lower-bound coverage、fork parser predecessor/version/hash 与 owner/估算链；本轮 F1 如上 |
| Mac Settings/fleet | 对目录移动做 basename 唯一匹配后的旧新差异审阅，保留 mobile pane 与 macFleet 命名空间；Liquid Glass 新旧系统分支、About/acknowledgements历史、独立 Sparkle checks/install；O1 如上 |
| Mac 其他新功能 | Cursor encrypted auth 的 ACL preflight + background gate/no-UI query、subprocess 单次close、plugins session teardown、credential CLI 保留 unrelated config、会话检查与 bounded source、native monthly target；未执行真实账户探测 |
| iOS | DailyAllowanceTarget 本地日历/午夜/未来reset/单位/零与unknown；Kimi machine expiry/动态名/旧日期不猜；expected marker+可访问说明，AX fallback 与 adaptive 容器未被整体改写 |
| 语言与版本 | catalog semantic diff 17 新项、0 既有语义修改/0 删除，均有 en/zh-Hans/zh-Hant/ja；单3.3 release block、五 targets3.3(261)、Mac0.82.0.1/175.1/Mobile3.2/Sparkle175.1.3.2.0，无提前宣称3.3已交付 |
| CI / README / release | fork fast-PR/heavy-postmerge invariant，新增 Linux smoke 与 linker stack；README先保fork后单独事实适配+hash；package SUAutomaticallyUpdate 是上游新策略默认。实际 draft/签名/公证/appcast/Archive尚待产物后审 |
| 测试 / evidence | 新 metadata/target/Kimi tests、Duo active-display/short-landscape 合同、保留失败证据、16-case frozen real model+pure merger 脚本及 source hash；诚实标 substituted，未当实体CK/APNs/SwiftData收敛。已知 mode-test弱断言由主 agent 正在修补，不把正在完成的gate冒充新PASS |

## 后续复审入口

1. 修复并验证 R2-F1，给出新的源码/实际测试与 iOS consumer 结果。
2. 收拢 O1 验证，以及 Widget 真正 mode 改变、关闭、再开持久化的界面读回；仅旧 test 返回 green 不足以证明。
3. 收拢最终 Mac 组合库存覆盖说明、opt-in skip 及 iOS 全量/旧系统/iPad；不声称全部 method body 或四设备实测。
4. Mac no-tag draft 与 iOS local Archive 生成后，补审 source/hash、versions、Production entitlements、签名/公证、ZIP/dSYM、候选 appcast 与占位 draft target，确认后续修改是否影响产物输入。
5. 最终完整当前候选重新审查并记录 commit；本报告不授权 push，也不替代 GitHub current-head review/gate。

## 记忆收尾

按 codex-memory-capture 做了候选判断：本轮是 repo 内具体 review/验证记录，不额外写长期记忆或普通任务日志；未写 memory 文件。

## R2-F1 修复补审（第一版，未关闭）

主 agent 增加 Core/Shared `sourceRecorded` case，含义明确为包含来源记录的金额（可能混合估算），不是 vendor billing/receipt；central tokenSnapshot 识别 row 的 finite sourceRecorded cost、含明确零，entry cost 缺失不制造来源。fresh/cached/native/Pi 共用入口；windowSummary 在日期过滤后传 entries，priced-only 子窗口可以恢复 listPriceEstimate。CLI、Mac caption、iOS 四语说明及 Shared unknown fallback 已读回，设计合理。

补审还查到一个漏消费者：`CodexBarMobile/CodexBarWidgetShared/ProviderSnapshotMerger.swift:1293` 的 `mergedCostProvenance` 目前遇到 sourceRecorded + listPriceEstimate/vendorMetered/mixed 会回 `.mixed`，使两台 Mac 同账号合并后在 iOS 又显示 provider-reported 说明。已及时通知主 agent，仍属于 R2-F1 的未完成闭环；需在已有 unknown 保守规则之后、mixed 之前保留 sourceRecorded，并补正反序两 writer merge 及 frozen harness 的 merged cost provenance 断言。第一版 frozen harness 仅新增 decode reads 断言，不足以发现此合并问题。测试和实包尚未作为完成证据。

## R2-F1 修复补审（第二版，源码已解决，执行/产物待验）

已独立读回新 iOS pure merger 的优先级：缺失/unknown 保守规则保留，sourceRecorded 在 mixed 前返回，避免两 writer 把来源记录重新解释为 provider billing。V082SyncMetadataTests 增加 sourceRecorded 与 listPriceEstimate/vendorMetered/mixed/unknown/self 的两 writer 正反序合并，保留明确零金额；FrozenWireHarness 将 Mac A 设置为来源记录、Mac B 为价目表，并新增 merge 后 provenance 与零金额断言。四语 caption 不把来源记录描述成 vendor receipt。

完整搜索 CostProvenance/SyncCostProvenance 消费者后，核对 central fresh/cached/native/Pi tokenSnapshot、summary 实际日期窗口、Sync stable-window summary、SpendDashboard 新 case 及 CLI/Mac/iOS 文案，未发现继续遗漏。sourceRecorded case 可以表示包含来源记录的 mixed 窗口；旧 Shared 读取新 raw value 时降为 unknown，保留金额和既有字段。

当前 **R2-F1 的源码修复已解决，R2-O1 的源码修复已解决，0 新增未解决源码 finding**。这不是完整本地质量 gate clean：仍需主 agent 的适用测试/四语/16组合新输入结果，最终commit与产物后审。修复时 source snapshot 另存 final-local-review-round2-fix-source.json，保留之前阶段 manifest 和失败发现，不覆盖历史。

## CLI 与新增测试补审

root 发现的 CLI cost header/footnote 仍宣称 API-equivalent estimate，现仅对 sourceRecorded 改为包含来源记录/可能含估算/不是billing receipt，其他 case 保持原输出；makeOpenCodexCostPayload 的固定 list-price 保留，因为 OpenCodex 是不同来源，不合并 OpenCode local history。已核对真实 CLI renderCostText、makeCostPayload、liveHistoryLine 与新 recorded0/1.25 参数用例，语义一致。

已核对 SpendDashboard month 包含 recorded0、week 排除该日回到 priced 的用例，builtin Sync publisher 的来源参数化，以及 plugin 3 currencies × 2 provenance 的 Cartesian 参数，initializer参数顺序正确。

新增 async 参数用例原共用固定 UserDefaults suite，会在 await pushCurrentSnapshot 交错时互相 removePersistentDomain；@MainActor 不等于串行整段 async。已要求并独立读回 @Test(.serialized, arguments:...) 加 suite 的 provenance.rawValue 后缀，新增竞争消除。其他新参数用例为纯 value fixtures，无同类共享变更。真实 UserDefaults helper是基线既存，不把它误报成本轮新引入。

补审后仍是0未解决源码 finding；测试正在执行，签名产物与最终完整提交尚未到审，不能把此状态冒充发布完成或 push gate 已通过。

## 测试隔离、四语说明与 Widget 严格用例补审

已复核 builtin sync 参数用例改用 InMemoryUserDefaults（缺失 key 无 Foundation search-domain fallback）、随机隔离 config 路径和 stub credential/token stores；SettingsStore 测试模式不启动 app-group migration。UsageStore 显式 .testing 不启动后台探测、plan history load 或 file-backed account hydration，并传入 synthetic HOME、contained widget URL、no-op reloader 和显式 synthetic deviceID。参数保留 serialized；没有继续扩大真实 defaults 域。testConfigStore 与 CostUsageTestEnvironment 的根由 runner 的 SSD TMPDIR 提供，真实执行环境仍由主 agent 的证据确认。

CLI 的固定日期 fixture 显式 UTC bucket，liveHistoryLine 调用归属 CLIRenderer；纯 value 参数不会共享变更状态。既有 3.3 details bullet 合并成本来源说明，四语均为 translated，两份 changelog 覆盖 fresh/cache/mixed/recorded-zero 与 fleet 独立门控，没有增加同 marketing version 的新 release block。

Widget opt-in 的严格源码已审：实际 AX row 定位、真实模式选项选择、配置值断言、关闭配置界面、重开持久化断言，并保存截图/AX。源码比旧固定坐标、弱成功判据充分；不将旧 141 秒假阳性沿用为证明。最新 98 秒 PASS 仍须结合独立截图读回才可作为实际系统验收，当前尚不在本 reviewer 的完成声明内。

本次补审仍为 **0 未解决源码 finding**。source manifest 为 final-local-review-round2-fix3-source.json；最终测试、最终完整 commit/diff、Mac draft/签名公证/iOS Archive 来源一致性仍待后审，不能提前标完整本地 gate clean。

## Remote SSH cost schema v1 前向兼容专项审计

按主 agent 请求回读 bdf 基线及当前 RemoteCodexCostFetcher / CLICodexHostCosts。旧 Core CostProvenance 是 raw String + synthesized Codable，仅认识 listPriceEstimate/vendorMetered/mixed/unknown；CodexHostCostWindow.provenance 直接使用该类型。若 schemaVersion=1 的 JSON 真包含 sourceRecorded，旧 client 会在 [CodexCostSummary] 解码阶段整体失败，并转换为 invalidReport；没有额外版本协商。这一潜在边界不能用新版 decoder 容错来替旧 binary 修复。

**现有生产路径没有可证实回归：** bdf/current SSH 命令均固定 summary-only/provider-native-only；current runCodexHostCosts 独立调用 public loadTokenSnapshot(includePiSessions:false)，该 public 入口没有 OpenCode opt-in 参数，scannerOptions 强制 includeOpenCodeLocalHistory=false，并不读取 app 的启用偏好。OpenCode readScope 在 flag=false 时为 nil；共用数据库的 retained read 要匹配 source scope，file aggregates 读取 nativeOnly:true；decodeCodexCache 跳过 belongsToOpenCodeLocalHistory，并在来源文件存在时从 native files 重建 days。mergingSource 在 source=nil 时直接返回 native report，previous native report 也由 native cache 生成。因此已存 OpenCode ambient rows 不会经 shared cache 混入现有 SSH native summary，也就不会输出新 raw case。

结论为 **0 新增可证实源码 finding**，不把假设未来接入 ambient snapshot 当作当前阻塞。未执行编译/测试；上述是调用链和缓存隔离源码证明。现有 OpenCode publication test 对 SpendDashboard/explicit-home 来源排除有所覆盖，但没有把旧 SSH decoder 对照测试视作已执行。可新增 native-after-ambient-publication 断言，保护此协议边界。

若未来将 CodexCostSummary(snapshot:) 用于 ambient/sourceRecorded snapshot，最小兼容方案是只在 schema1 transport 的自定义 encode 写 provenance=unknown，并新增 optional includesSourceRecordedCosts=true；新 decoder 按该 flag 恢复语义，旧 decoder 忽略新 key、保留金额和零值。不能使用 mixed/vendorMetered 冒充，也不能仅增加新 Core decoder fallback 或把 schemaVersion 提到2来声称旧 client兼容。当前未实施任何协议改动。源码指纹见 round2-remote-cost-forward-compat-source.json。

## Source-freeze a36c6b1 与 iOS 本地 Archive 后审

冻结 commit 为 a36c6b110da3d994c8bba6bbcfa777627efa42ff、tree 5d7f4cfa7a6b9fac841d6b92113652bfa2c76921；已读回 shipping/code/test/project.yml 对该提交无 dirty diff。相对上一补审 manifest 的源码变化仅 native-after-ambient cache 回归断言和 render fixture intrinsic-height 修正；另审 Scripts/release.sh 更新过时“每次push CI全量测试”的文案，仍要求独立完整本地测试证据，未改变实际发布行为。新增 native fixture 先写 ambient source cache、再调用 SSH 所用 public native-only API，检查来源行/主provenance/today/history均不变为sourceRecorded，断言覆盖设计准确；它的冻结后真实复编译/三suite delta执行尚待主 agent 收拢，未在本报告虚称已通过。

独立实际读回 iOS Archive：353 个 source input 的 SHA256 全部吻合冻结 commit 和当前文件（含 Shared symlink 原始target内容），205 个 shipping source/resource 文件均在manifest范围；generated project hash吻合。Archive 101文件逐一 size/hash吻合，没有额外文件；五 bundle 的二进制hash吻合，strict/deep codesign verify均成功，signature Team均3TUERHN53E，版本均3.3.0/261。App/Push/Widgets signed entitlements均Production；WidgetOptions只读AppGroup而不调CloudKit，framework不带执行entitlements，两者仍有有效Team签名。App arm64 UUID与dSYM同为DF54F795-6609-3905-B631-FBBAD26A1839。

archiveFileManifestSHA256 初看不等于格式化JSON文件字节hash，经核实精确匹配 Python json.dumps(parsedFiles).encode() 的序列化hash；内容锚有效，不是产物篡改或hash失效。已向主 agent建议明确算法/另存实际文件hash，独立proof同时记录这两者。

交付分类保持为 Apple Development 签名、本地 Archive、get-task-allow=true，尚未export/upload，不能把它称为App Store/TestFlight分发二进制。独立校验结果见 round2-ios-archive-independent-review.json。此次 **0 新增源码/实包finding**，仅manifest算法说明已反馈。Mac signed/notarized draft、quiet lint/build、最终doccommit/完整candidate后审与GitHub current-head gate仍待完成；没有提前给出完整local gate clean。

## 当前 Research / frozen harness / 文档与打包隔离方案补审

源码冻结后全部base→candidate路径清单继续追踪，当前shipping/code/test输入仍等于a36c6b1；未提交差异为Research/harness/docs收拢。已读回02/03/04/05、cloudkit code audit、versioning契约修正及frozen harness diff；19个compatibility manifest新旧源码hash与各自实际来源逐项吻合，harness hash吻合。16矩阵64独立读取/32pure merges log无失败，sourceRecorded→旧unknown/0金额/新旧反序合并断言准确，仍诚实限定substituted。newCommit=82cd093是执行时HEAD，实际dirty inputs由hash锚定且后来包含于a36；不能无说明把执行时head改成后来的commit。

真实 source-freeze delta log确认53 tests/3suites通过；proof fullMethodCount=16182、retainedSelectionCount=1743、retainedMethodCount=14923、retainedMethodsEqual=true。历史16177是早期库存而非新最终数。Mac最终102 affected selections/19groups和该delta均为serial SwiftPM；未把历史保留结果夸大为新single-binary全方法体执行。iOS archive manifest已补明确算法及实际文件hash，先前歧义消解。

release临时excludes方案经审查可接受：require_clean_worktree只看git status；Gitignore不隐藏tracked diff。root error.log/work不属于Swift target、ARTIFACT_INPUTS或包资源目录。允许单次子进程GIT_CONFIG_COUNT覆盖core.excludesFile，临时文件保留既有effective global ignore（含未配置时默认XDG/home文件）并仅追加根锚定/error.log及/work/；不改global/git/info排除规则，不移动/删/加入用户文件。须保留调用方既有GIT_CONFIG_COUNT条目；在Research/docs真实提交且tracked index/worktree clean后对比普通/临时status，隐藏集合精确等于两根路径与后代；其他变更仍失败。前后用户文件树path/type/symlink/size/content hash一致，普通status重新可见；artifact input manifest与ZIP清单不包含该用户数据。此处是方案审查，实际执行与前后证明待主 agent提供。

当前 **0 新增源码/Research契约finding**。03/04/05及CloudKit审计最终头部状态、当前来源锚仍待Mac打包后收拢；保留历史pending段不等于可在最终结论继续声称未完成。完整本地gate尚未宣告clean；待Mac签名公证/draft/appcast候选、quiet lint/build与最终doccommit后最后补审。逐路径指纹为final-local-review-round2-preship-source.json。
