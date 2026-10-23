# 缓存与跨版本兼容验证

状态：`in-progress` · 2026-10-22。以下是本轮替代验证计划与覆盖边界；实际测试命令、结果及 `.xcresult` 由 `03-testing.md` 记录，不能仅凭测试文件存在宣称通过。

## 为什么适用

本轮只改 iOS，不改变 Mac writer、Shared Codable、CloudKit schema 或 server records，但新增设备本地账号/窗口观测和偏好，并改变旧快照的显示。因此适用 [`docs/ios-sync-compatibility-testing.md`](../../../docs/ios-sync-compatibility-testing.md) 的缓存、跨版本显示门禁。

基线 old iPhone 为 iOS 3.2.0 (250)，源码 `d90e42daef7f54611c7fba7c043452b7125f7436`。new 为本分支 iOS 3.2.0 (251)。本轮没有 new Mac 发布；下表 Mac old/new 表示可选字段较少的旧格式 fixture 与当前格式 fixture，不冒称两版真实 Mac 已安装并运行。

## 轻量替代方法

测试位于 [`UsageQuotaCompatibilityTests.swift`](../../CodexBarMobileTests/UsageQuotaCompatibilityTests.swift)，Swift Testing 参数化执行 16 个 case；不创建 SQLite，不连接 CloudKit、KVS、Keychain 或真实 provider，不读取 `.standard` defaults。

- 两个 writer 使用不同 deviceID、不同 per-install accountRecordKey；它们报告相同的两个稳定账号，但时间与额度不同。断言最新观测胜出、两个账号不合并；同一组输入反转顺序也必须得到相同额度。
- old writer 使用冻结的 build-250 字段子集 DTO 输出 fixture；额度仍由 primary 原生槽位承载，无 id/label/period，rateWindows 为空。current writer 使用真实 Shared encoder、显式 windowID、period 与动态 rateWindows。两种格式表达同一稳定账号/窗口，验证兼容回退，而非根据版本字符串分支。
- old reader 先经同一份冻结 DTO 进行字段读取/重编码，再进入当前 `SnapshotCache` 和 `ProviderSnapshotMerger`；new reader 直接使用当前 decoder，并拥有新的 `UsageQuotaOverviewStore`。冻结 DTO 只覆盖本测试使用的字段，已对照 build-250 的 `Shared/Models/UsageSnapshot.swift`；**它不是旧 App 的完整 decoder 或旧二进制执行**。
- iPhone A 走全量 per-provider fetch，并保留旧 legacy zone fixture；iPhone B 从旧快照冷启 hydrate，先断言没有污染 per-provider bucket，再按相反 writer 顺序消费 delta。两份缓存、持久化字典与 store 独立创建，没有共享的 reader 状态。
- 每个 reader 都检查 fetch 失败参数 `nil` 保留内容、重复全量刷新、删除最新 writer 后回退、权威空 fetch、恢复 delta。new reader 还检查选择 UUID/绑定/颜色/顺序重启后保留、账号消失时不误绑、恢复时不丢选择。
- 两个账号故意携带相同且明显不同于当前额度的 provider 级 `utilizationHistory`。new store 必须各只有一条直接收到的最新账号观测；重复抓取、回退旧观测、空与恢复均不得把共享历史导入或重复采样。
- 图表的生产调用使用 `rawDeviceSnapshots`，按未归档设备管理项目的 `sourceDeviceIDs` 筛选；兼容 reader 传入各自 `cache.buildDeviceSnapshots()` 的原始 writer 来源。`deviceSnapshots` 已折叠设备 alias，不能将它当成原始证据；legacy 无 deviceID 的快照须按 `DeviceSnapshotResolver.deviceKey(for:)` 匹配。逐 window 选择原始观测值与真实 capture；不能将合并账号的总体 source clock 套到其它 writer 补充的窗口上。额外 regression 覆盖只有旧 A 提供的 scoped window：新 B 的 native quota 更新后，该 extra 仍保持 A 的旧时间、陈旧状态和无预测，且不能拉长有效横轴。
- 既有 Usage 与 Summary 的合法偏好 bytes 作为 sentinel 保留，改色、排序、reconcile 后逐字节比较，并重新解码。新 archive 只写 `usageQuotaOverview.v1`，不污染另一个 reader，也不进入 wire。此处验证注入的持久化协议与 key 隔离，不宣称验证 iOS 真机 defaults 文件系统行为。

未来/损坏 schema 的 `isReadOnly`、原 bytes 保留、reset/duration 切段、局部观测容量/身份隔离由 `UsageQuotaOverviewTests` 负责，兼容 suite 不重复实现相同断言。完整集成后还须检查这些专项测试实际执行结果。

## 16 个独立组合

case 顺序与 canonical gate 一致，bit 依次为 Mac A / Mac B / iPhone A / iPhone B。每个组合都实际创建独立的两个 writer fixture 与两个 reader；new reader 才实例化新增 store。old/new 两者读取相同 wire 含义，区别是字段投影与本地功能能力，不是写一个版本标签后跑相同空断言。

| Case | Mac A fixture | Mac B fixture | iPhone A reader | iPhone B reader | 证据类型 |
|---:|---|---|---|---|---|
| 1 | old | old | old | old | substituted · 参数 0 |
| 2 | old | old | old | new | substituted · 参数 1 |
| 3 | old | old | new | old | substituted · 参数 2 |
| 4 | old | old | new | new | substituted · 参数 3 |
| 5 | old | new | old | old | substituted · 参数 4 |
| 6 | old | new | old | new | substituted · 参数 5 |
| 7 | old | new | new | old | substituted · 参数 6 |
| 8 | old | new | new | new | substituted · 参数 7 |
| 9 | new | old | old | old | substituted · 参数 8 |
| 10 | new | old | old | new | substituted · 参数 9 |
| 11 | new | old | new | old | substituted · 参数 10 |
| 12 | new | old | new | new | substituted · 参数 11 |
| 13 | new | new | old | old | substituted · 参数 12 |
| 14 | new | new | old | new | substituted · 参数 13 |
| 15 | new | new | new | old | substituted · 参数 14 |
| 16 | new | new | new | new | substituted · 参数 15 |

以上 `substituted` 是验证方式，不是测试成功结果。运行前/失败时不能填写 pass；`03-testing.md` 必须补充 16 个参数全部成功的执行证据，并保留 substituted 属性与下面的剩余风险。

## 能验证与不能宣称

可验证的是合成 wire 字段兼容、确定性的纯缓存/合并、独立本地配置、受限直接观测历史以及新增图表对旧快照的可解析性。本轮未安排两台真实 Mac 与两台真实 iPhone 的旧/新安装切换，采用 fixture/cache + 原生模拟器替代；这是证据缺口，不能将硬件覆盖写成实际 pass。

本方案不能验证 Production CloudKit schema、账户/容器权限、真实数据分布、订阅或 silent push 送达、后台时序、change token 失效重放、网络故障、跨设备传播延迟，或旧二进制完整 UI/解码行为。缓存纯函数接收的模拟 delta 不是服务器推送证据；字典持久化也不证明设备卸载/恢复、系统数据保护或 defaults 迁移行为。

旧 reader 不认识新增图表配置属于正常行为；图表偏好和历史不经 iCloud 同步，两台新 iPhone 可以有不同选择/颜色和各自的本地历史长度。它们应在读取同一组有效 writer 观测后收敛到相同当前额度，不能要求两机的估算曲线因本地历史不同仍完全一致。

发布前仍需独立完成原生跨屏渲染与交互 QA、四语/版本说明、Production entitlement/schema 变更审计、archive 来源和 TestFlight 可安装验证。无 Shared/schema 变更并不意味着做过真实 Production 同步测试；最终交付必须明确保留上述差别。

## 首轮替代验证发现与修复合同

首轮运行于 `UsageQuota-3.2.0-251/focused.xcresult`。case 10–12 的新 reader 发现：较旧 A 提供动态 `rateWindows` 的 30%/55%，较新 B 只提供 legacy primary 的 40%/60%。既有 `ProviderSnapshotMerger` 保留 A 动态窗口，却将 B 作为账号总体额度 source；如果新增 store 直接读合并后的 `rateWindows` 并使用账号 sourceCapturedAt，会把旧 A 的值记在新 B 的时间下。测试当前额度 primary 断言通过，journal 的 `[40,60]` 断言失败，揭示了窗口来源与总体来源不一致。

解决方法限定在新图：以原始 per-writer snapshot 对稳定账号与 windowID 解析证据，同时用于当前读数、观测记录、陈旧状态、估算和轴域。legacy primary/secondary 的 fallback windowID 与现代槽位对齐；较旧 writer 独有的 extra 使用其自己的 capture。找不到唯一原始来源时保守不生成历史/预测，不向旧数据借用新时间。既有 merger/Shared/Mac 显示语义保持原样，避免扩大本轮变更面。

canonical merged account 决定窗口是否仍存在、是否被全局额度阻塞、当前账号是否不可用；raw evidence 只能证明该既有窗口的数值与时间，不能提升 canonical 缺失或阻塞状态。Kimi 既有 capable-writer authority 继续约束其 source；较新 legacy writer 不能解除 authoritative monthly block。对应新图单测由数据工程补充，独立 review 检查显示、journal、轴域三处是否使用同一规则。

不能降低 `[40,60]` 断言或移除 legacy fixture 来让测试变绿。16 参数及 inherited-extra regression 需要在该修复集成后重新运行；首轮失败不得作为最终通过证据。
