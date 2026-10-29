# CloudKit 代码审计 — v0.82 候选

日期：2026-10-28。最终产品源码冻结 `a36c6b110da3d994c8bba6bbcfa777627efa42ff`。对比 published 的最终 Shared、Mac Sync、Core Sync/CostUsageFetcher/Vendored CostUsage、iOS ProviderSnapshotMerger diff SHA256 `21132490e9bee1eabff72085324298ff065a18c914c0364314e2533331e9924d`。这是明确路径集合的代码审计锚；签名产物另验。

基线：最新 published `v0.79.0.1-mobile.3.1.0`（GitHub Releases 本次回读，2026-10-22T05:42:03Z）；不是旧 draft。

结论：**NO_DEPLOY（代码审计）**。

- 对比 published 到当前工作区，Shared/iCloud、Scripts/cloudkit、CloudSyncEngine.swift、SyncModels.swift 均为零 diff；没有新增直接 CKRecord type/field/index/predicate/subscription schema。
- Shared 的 quotaLimit/quotaUnit/Progress.expectedUsed/Row.expiresAt 是 optional JSON，容错 decodeIfPresent，nil 不编码，位于既有 DeviceProviderSnapshot.payload 里；providerPayloadVersion 保持1，不触发全量格式重写。
- QuotaProviderList 尾部四个新 ID 只扩展用户运行时 private zones/subscriptions，仍使用已部署 QuotaTransition 类型与字段；不把 zone 实例当 Dashboard schema。
- Soniox与Cursor补充金额/支出、Kimi机器expiry和插件 title/pace 使用既有 providerAmount/details/rateWindows；没有把密钥、Cookie、Mac hooks 或远程请求明细加入 wire。
- 来源成本新增 `SyncCostProvenance.sourceRecorded` 是既有 JSON 字段的新 raw value；旧 iOS decoder 已把未知 raw value 降为 unknown，金额与模型数据保留。新 reader 在两 Mac 合并中优先保留来源记录含义，unknown 继续保守优先。`compatibility-4` 的16组合覆盖新/旧双向读取与两 writer 反序合并、显式金额0，全部仍为 substituted。Mac fleet 的 UsageSnapshot 自定义 decode 将 `costUsage=nil`，该 live-only 成本元数据不进入 fleet snapshot wire；没有新增 schema version 或直接CK字段。
- 源码打包/iOS entitlements 保持 Production；签名产物实测应在04与iOS Archive记录补充，源码不等于签名结果。

命令：git diff v0.79.0.1-mobile.3.1.0 -- Shared/iCloud Scripts/cloudkit Sources/CodexBar/Sync/CloudSyncEngine.swift Sources/CodexBarCore/Sync/SyncModels.swift；逐项审阅 UsageSnapshot/QuotaProviderList/SyncCoordinator diff。

未调用 Production schema export、deploy 或真实 CloudKit 数据库读写。该结论不证明 APNs、网络传播和双手机缓存收敛；16组合 substituted 证据及风险见03。

本轮路径集合：`Shared`、`Sources/CodexBar/Sync`、`Sources/CodexBarCore/Sync`、`Sources/CodexBarCore/CostUsageFetcher.swift`、`Sources/CodexBarCore/Vendored/CostUsage`、`CodexBarMobile/CodexBarWidgetShared/ProviderSnapshotMerger.swift`。用 `git diff v0.79.0.1-mobile.3.1.0 -- <上述路径>` 的原始UTF-8输出计算SHA256。iOS本地Archive App/Push/Widgets已独立确认Production；Mac待签名包核对。
