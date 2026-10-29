# Round 2 修复后的 Mac 受影响复测选择审计

日期：2026-10-28。只读调用链/测试/现成discovery审查；未修改源码、未编译或运行测试。此为复测计划，不是复测通过证据。

## 建议

建议用production directrunner重编译后执行 **102个现成selections**；按上次inventory对应1254个method IDs（新增测试后实际数量必须以新discovery为准）。此前1845完整库存中，其余 **1743 selections** 可沿用已有组合证据，前提是最终source freeze后没有额外影响它们的变更。不是同一最终binary全量PASS。

精确全名清单：`round2-affected-mac-selections.txt`；分类、留存清单、旧完整gate proof hash和当前source hashes：`round2-affected-mac-selection-plan.json`。所有102名称均与原实际discovery核对存在，未猜测试文件名等于suite名。

| 类别 | selections |
| --- | ---: |
| core-window-fresh-cache | 9 |
| opencode-native-cache-publication | 6 |
| pi-accounting-native-cache | 15 |
| dashboard-state-aggregation-publication | 34 |
| sync-wire-builtin-plugin | 11 |
| cli-summary-and-remote | 9 |
| menu-overview-window-consumers | 12 |
| existing-vendor-cost-nonregression | 6 |

可用--direct-workers1、--group-size4，继续production prepare_runtime完整method校验、ownership/独立HOME与Keychain隔离、--no-parallel。选择4只是为这批含较慢publication fixtures的受影响复测避免12suite共享180s的重复timeout；不放宽产品/测试deadline、不改变production runner。无需再启动全1845或未改解析器/凭证/TTY重型矩阵。

## 为什么这些属于受影响调用链

- **Central producer：** `CostUsageFetcher.tokenSnapshot` 被fresh本地scan、native/inclusive Pi accounting、缓存恢复、remote/vendor report等共同调用。扫描already-parsed daily rows提升.sourceRecorded是中心变化，不是仅OpenCode单一UI；需要CostUsageFetcher三个suite、OpenCodeLocalHistory四suite、Pi native/accounting/cache以及old vendor路径回归。
- **Window semantics：** `CostUsageTokenSnapshot.summary(forLastDays:)` 与syncWindowSummary现在从实际entry window判断provenance，涉及日/周/月/MTD/All、零金额和nil的区别。CostProvenance、CostUsageTokenSnapshotDaySelection、CostUsageWindowSummary、CostReportingPeriod与coverage suites必须纳入，而不是只测“30日snapshot改名”。
- **Dashboard/菜单/CLI：** 新enum case进入SpendDashboardModel聚合、Settings的文案、Overview/菜单consumer及CLI text/JSON。在ordinary SpendDashboard suites基础上纳入CostHistoryChartMenuView、InlineCostHistoryCalendar/DashboardLabel、MenuCardCost*、OverviewSpendSummary、StatusMenuTests和CLICost系列。`StatusMenuOverviewSpendTests.swift`实际是`extension StatusMenuTests`，所以真实selection是`CodexBarTests.StatusMenuTests`，不是不存在的StatusMenuOverviewSpendTests。
- **Builtin与plugin wire：** sync enum映射和window summary共用，但generic builtin投影、plugin cost-only投影、fallback/metered alignment、per-account cost ownership各有入口。SyncProviderMapper、SyncCostIsEstimated、SyncCoordinator、SyncModel、V082、ClaudeTokenAccountCost及三个plugin mapper契约suite一起覆盖；不能只用custom plugin fixture替代builtin生产路径。
- **Remote/多源含义：** RemoteCodexCosts、OpenCodexIncompleteUsage/UsageFanOut与PiSharedRootMerge纳入，是因为同一个summary/enum走跨source/远程transport或native+inclusive合并；它们是本地stub/file测试，不是执行真实remote/live账号。
- **Fleet UI：** `.disabled`从Mobile iCloud开关纠正为macFleetSyncEnabled，CloudSyncSettings+PreferencesPaneSmoke和source audit足以确认命名空间/编译不回退；其本身不要求重新跑Mac fleet所有网络与CloudKit写入。实际checkbox可用性若作为UI验收，需在后续synthetic Mac smoke检查syncCanRun、fleet/mobile四种开关组合，不应把普通settings model test当作已经点过UI。

## 精确分类中的关键现成suite

完整名单以TXT/JSON为准，下列是最重要的入口：

- Core：CostProvenanceTests、CostUsageFetcherTests、CostUsageFetcherCacheSnapshotTests、CostUsageFetcherUnknownModelPricingTests、CostUsageTokenSnapshotDaySelectionTests、CostUsageWindowSummaryTests、CostReportingPeriodTests、CostUsageCoverageAggregationTests、CostUsageCoverageCompatibilityTests。
- OpenCode：OpenCodeLocalHistoryAdapter/Cursor/Publication/RegressionTests、OpenCodeGoTokenCostTests；fresh/cached与native/inclusive projection都要执行。
- Pi：PiProvider、PiNativeProjection、PiInclusiveRefresh、PiSharedRootMerge、PiFamilySession、PiSessionCostScope/Compatibility/Numeric/RefreshReliability/ScannerCacheWrite/V8Upgrade、PiWidgetFreshness、UsageStorePiHistoryScope及两个portable Pi cache suites。
- UI aggregation：所有现成SpendDashboard普通state/model/publication/controller/source suites；不额外打开SpendDashboardNativeProof/ScreenshotRender/LongRangeRender三个opt-in证明。StatusMenuTests中已有native opt-in函数仍保持禁用，不以返回/skip证明实际截图；真正需要的是该suite内ordinary Overview publication/calendar/filter消费者。
- Sync：SyncProviderMapperTests、SyncCostIsEstimatedTests、SyncCoordinatorTests、SyncModelTests、CloudSyncSettingsTests、ProviderArchitectureGatekeeperTests、V082MobileBridgeTests；plugin targets的ProviderPluginResult/SnapshotContract/CurrencyTests。
- CLI：CLICostTests、CLICostWindow/Calendar/ClaudeDetail/ProjectCoverageTests、AntigravityCLICostTests、CodexBarLinuxTests.RemoteCodexCostsTests。

## 新case仍需实质断言，不能只重跑旧tests

目前已看到的修复新增：CostProvenance零与非零2cases、window clip、mixed/unknown对照；OpenCodeLocalHistoryPublication fresh/cached provenance断言；SyncProviderMapper的currency×mixed/sourceRecorded参数化。它们必须在新binary运行，旧库存通过不能证明新case。

冻结复测输入前建议再加最小三处断言（可放现有suite，避免新建大型矩阵）：

1. **SpendDashboardModelTests**：带source-recorded0与priced row的snapshot/group，30日→sourceRecorded、7日排除旧recorded row→listPriceEstimate；同currency mixed sources聚合含recorded时标签不是vendor billing，零不消失。既有vendorMetered/listPriceEstimate/mixed/unknown输出保留原期望。这样真正进入本轮新switch分支和window recompute，不只编译enum穷举。
2. **CLICostTests**：同一synthetic window的JSON顶层/totals provenance与文本`includes source-recorded costs`一致，包含present0；切到不含recorded的week不沿用month的recorded标签。现有CLI字符串断言主要覆盖旧case，单独重跑不能证明新增suffix。
3. **SyncCostIsEstimatedTests或SyncCoordinatorTests**：经真实store/token snapshot→builtin同步路径生成costSummary/reportingPeriodSummary，断言.sourceRecorded与cost0保留，且未被误标vendorMetered/billing receipt。plugin参数化只证明custom path，不能代替builtin/account projection。

若最终实现允许sourceRecorded与vendor-metered来源同时混在一个snapshot，纯vendor子窗口也应有明确期望；不能为“old case unchanged”只测试整月mixed而漏掉排除recorded后的window。当前new case的含义是“含本地记录值”，不等于供应商账单，也不保证整窗没有list-price estimate；isEstimated与coverage仍按既有行语义独立计算，不能看到sourceRecorded就强行清成false。

## 可以保留的旧证据与必须补的外部gate

- 未改源码/公共依赖的auth、browser/Keychain、TTY/process cleanup、原始解析器容量/吞吐/SQLite压力、providerQuota/branding、无关SwiftUI/CI/release脚本继续沿用上次完整gate。CostUsageModels只改summary派生，未改raw parser/持久行结构，OpenCode/Pi针对cache与model row保留的测试已经覆盖本次入口，不需全raw parser benchmark重跑。
- 123个env-gated native/live proof仍是原报告中的skip边界；此次不主动开启真实账号、live provider或Keychain。重编全部targets负责enum穷举编译，但不替代新分支断言与实际UI smoke。
- Shared新raw enum case触发兼容gate：旧SyncCostProvenance decoder已有unknown fallback，源码审计支持老读者不因.sourceRecorded整包失败；仍必须重新跑更新后的frozen16组合，检查新Mac→old iPhone的unknown保底、新iPhone保留sourceRecorded、两Mac冲突/最新观察与0金额。iOS新的merger priority/文案及4语需要iOS专项新binary，本Mac selections不能替代。
- CloudKit仍是opaque payload内optional enum扩展，schema deploy结论须继续基于code audit；这不自动证明Production网络收敛或允许deploy。

## 交给production runner前后的完整性条件

1. 先完成上述新断言/其他review修复，再source freeze；完整新discovery与runtime产品库存匹配，不能使用已取消编译前的旧binary或旧--skip-build选择证明。
2. 在新discovery上选TXT的102名称，并加入任何本轮新增suite、受影响新method所在suite。不能因为静态清单来自旧1845而跳过新测试。留存1743只是当前建议分区；若新source/test/fixture触及它们，需重新分配。
3. retained suite的method inventory、测试/共享fixture与产品依赖保持不变；以old fullgate proof+本轮source diff和明示影响分析继承。旧binary hash和新binary/source hash分别记录，不能把整个old fullgate换标签叫新binary PASS。
4. 每个所选selection至少匹配一个method；所选新tests都有执行证据，0 unresolved fail；按production runner保留timeout/isolated recovery，不手动删除失败或宣称首遍通过。
5. Research记录“原完整gate + 本轮102受影响复测”组合证据，给实际新method数、skip、新build/source hash；最终完整candidate code review另行进行。
