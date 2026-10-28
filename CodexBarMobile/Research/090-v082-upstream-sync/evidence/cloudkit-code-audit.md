# CloudKit 代码审计 — v0.82 候选

日期：2026-10-28。HEAD `c7b11c28e8474294fb0eb924a5d0a62996a74633`，另有工作区修改；所审 payload/mapper diff SHA256 `127af19e7fc644a0490496a3f3a0a564ca639ab6669291caf2d231411aa4fcf7`。最终 review 修复后需重新核查。

基线：最新 published `v0.79.0.1-mobile.3.1.0`（GitHub Releases 本次回读，2026-10-22T05:42:03Z）；不是旧 draft。

结论：**NO_DEPLOY（代码审计）**。

- 对比 published 到当前工作区，Shared/iCloud、Scripts/cloudkit、CloudSyncEngine.swift、SyncModels.swift 均为零 diff；没有新增直接 CKRecord type/field/index/predicate/subscription schema。
- Shared 的 quotaLimit/quotaUnit/Progress.expectedUsed 是 optional JSON，容错 decodeIfPresent，nil 不编码，位于既有 DeviceProviderSnapshot.payload 里；providerPayloadVersion 保持1，不触发全量格式重写。
- QuotaProviderList 尾部四个新 ID 只扩展用户运行时 private zones/subscriptions，仍使用已部署 QuotaTransition 类型与字段；不把 zone 实例当 Dashboard schema。
- Soniox 补充金额/支出和插件 title/pace 使用既有 providerAmount/details/rateWindows；没有把密钥、Cookie、Mac hooks 或远程请求明细加入 wire。
- 源码打包/iOS entitlements 保持 Production；签名产物实测应在04与iOS Archive记录补充，源码不等于签名结果。

命令：git diff v0.79.0.1-mobile.3.1.0 -- Shared/iCloud Scripts/cloudkit Sources/CodexBar/Sync/CloudSyncEngine.swift Sources/CodexBar/Sync/SyncModels.swift；逐项审阅 UsageSnapshot/QuotaProviderList/SyncCoordinator diff。

未调用 Production schema export、deploy 或真实 CloudKit 数据库读写。该结论不证明 APNs、网络传播和双手机缓存收敛；16组合 substituted 证据及风险见03。
