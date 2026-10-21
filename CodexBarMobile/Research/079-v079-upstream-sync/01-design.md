# 合并、桥接与 iOS 设计

Status: `ready`；用户 Goal 已确认。

## Mac 合并

完整 merge v0.79.0，保留功能/安全/性能修改：Claude Desktop/tcr/config-directory/单账号预测、Gemini App、Future AGI、Munito、配额选择/Spend/多账号 Overview、token 账号编辑、HTTP server/CLI cache、Claude Cowork/增量缓存、OpenCode Go v2/CLI、Grok billing、Antigravity ordinary quota、Cursor monthly spend、Vercel personal budget、ILS、SVG 插件图标/severity、widget 进程修复及 deadline/内存/CPU/Linux 修复。

冲突逐 hunk 审计。README 先完整保留 fork，再独立核对上游新增 Future AGI/Munito/Linux 集成是否适用于 fork；不机械换 hash。AGENTS、release pipeline、签名/容器/Production、fork CI 双层触发与版本规则保留。禁止移植上游 release 自动发布 workflow 造成意外发布。

## Mac→iOS 数据审计

逐项核对现有 ProviderUsageSnapshot、ProviderUsageEnvelope、mapper、details 和成本历史。新 provider 尾部添加 quota zone 注册，补身份/金额映射和 mock；复用当前 quota/budget/details/cost 字段。插件 severity 若缺失，需要 optional Codable wire 字段和旧读者兼容测试；图标不把未校验 SVG 直接交给 iOS。Gemini App 的窗口复用当前主/次窗口。Claude、Antigravity、Cursor、Vercel 的数据修复经已有窗口/预算/详情通道传递。凭证、路径、token、cookie 不进入 wire。Mac 配置管理与菜单操作不虚构 iOS 控制功能。

## iOS

Future AGI / Munito 品牌、generic quota/spend/details 和四语；新增语义 detail label/value 本地化，保留未知自定义插件文本。必要时支持 severity 图标/颜色与可访问性。新增字段用 decodeIfPresent 或未知值回退，不提升 wire version。沿用已覆盖的卡片类型并明确检查 PreviewData。既有 Duo 布局不重构。

## 验证计划

- Mac swift build、lint、完整隔离 test.sh、多账号/多设备、关键上游和 fork mapper/parser/cache 回归。
- CloudKit 对比最近 published fork tag，查 record types/直接字段/index/predicate/subscription，Production entitlements，给出 NO_DEPLOY 或需用户授权的 DEPLOY_REQUIRED。
- iOS xcodegen、Simulator/Release 编译和完整单测，特别 WidgetSnapshotBuilderTests；只改数据而不改 widget rendering 不触发真实 widget 配置 gate。
- 16 个 2 Mac × 2 iPhone 组合逐格列出；不能实际组织四设备时使用冻结旧 wire、多 writer/reader/cache 合并 harness，标 substituted 和风险，不能称实体 PASS。
- 自查 + 独立 review，修复复测后重新 review，阻塞为零才完成。draft 绑定最终 Mac 源码，修 review 后若二进制输入变更需重打。

## 第四轮根因审计：Claude 成本来源合同

问题：上游新增 per-token-account config directory，但 Mobile 的 CWL/SwiftData 历史仍是 machine-wide、逐日 upsert。仅验证当前 publication 或新增 scope key，不能让旧 iOS 正确隔离目录；可能把 A 的 day1 和 B 的 day2 相加。

本轮选择：**Mobile 只继续接收原有 combined machine history，不发送 directory-scoped Claude cost**。Mac 原功能完整保留。启用映射目录或仍持有该目录的 publication 时，中央 mapper 发送 costSummaryCleared=true，并附可本地化的“在 Mac 查看账号专属成本”详情；主路径、token expansion、adapter cost owner 都遵循同一判断。未配置映射时，只有当前有效 combined publication 才被同步。其余 provider 不受影响。

这不是把缺陷留给以后：避免在当前版本写入不兼容的历史数据，明确声明该上游功能的 iOS 支持边界；若将来支持 scoped history，必须独立设计旧读者隔离和 ledger source migration，再允许 scoped数据上wire。当前不新增 scope字段或CloudKit schema。

Adapter 的 combined history使用独立稳定device cost owner，clear时保留同key tombstone。`hasUsableSignal` 在基线已包含 costSummaryCleared=true，无需修改；旧读者也可通过普通details接收说明。新 Usage/widget通过isProviderLevelCostEnvelope过滤成本账号。实际16组合的历史store/UI限制仍需如实报告。

## iOS消费端补充验收

- Clear必须在source-device/provider聚合之前抑制local-cost旧行，之后dashboard和TokenActivity也拒绝clear回填；不删除持久ledger。同一device另有有效combined owner时保留它，另一Mac有效金额不得被全局clear误删。普通nil没有撤回含义。
- Future AGI meter display_name/display_unit是动态API内容，不把碰巧名为Balance/Session的meter强制本地化。Munito已知Today/This month金额中的`of`与stopped-until日期在消费端本地化，动态organization/region/tier/status未知值原样保留。
- severity仅warning/critical添加符号+系统颜色+四语可访问性，normal/nil/unknown保留旧观感。full与teaser共用presentation，不用颜色单独表达异常。
- 使用生产ProviderDetailsView/Teaser的native render attachment检查四语/Light-Dark/长文本；它只证明静态布局，不当作VoiceOver实际朗读或真实CloudKit同步证据。

## 未发布 iOS 内容合并

Research078记录3.0.0(245)仅本地验证，2.10.0(243)为既有VALID beta，正式App Store当时2.9.0。新train准备3.1.0(246)，将未发布3.0的日历+Duo highlights/说明合入同一个3.1条目，不把3.0伪造为已发布历史。Mac companion沿用最近已提供的2.10 beta，与已发布Mac tag一致；3.1未上传不提前写入Mac配套版本。此处依据repo发布记录，无新增ASC上传或credential请求。

## 身份合同根因复核（不是继续加fallback补丁）

- Head: 23d678f1b + identity/specificity working diff。
- Repeated finding pattern: nil标识会跨Mac合并不同账号；只按device隔离又会把同一组织算成两份。
- Root design/requirements problem: 新provider的身份能力必须根据实际API字段决定，不能把“旧AccountIdentityComputer未提取”当作“来源未提供”。
- Revised approach: Future AGI只提供plan，无已验证ID，仍device fallback。Munito plugin经真实mapper保留organization.id到identity.accountID；sync record key使用其trim+NFC+case-preserving SHA256，同org跨Mac相同，不同org/改名保持正确；ID缺失时才device fallback。显式requested key保留。通用record identity已有旧reader支持，不加wire/schema，不把组织名或API key当身份。新增同org跨Mac/异org同Mac/改名/无ID单测，并在iOS真实merger测去重与不串号。

## iOS迁移窗口的成本权威性

独立复查发现旧quota-owner记录在Mac两次成功清理前可与新Claude独立cost owner共存；新owner clear不能被旧summary覆盖，新owner summary不能与旧summary重复计费。消费者在每台设备内先按provider publication timestamp选取权威成本：独立owner更新或同时间时优先；用户关闭adapter后，明确更新的legacy summary可回切，并抑制滞留owner。额度、账号、预算、sourceReport保持完整。SwiftDataBridge在incoming keys/迁移/upsert之前使用同一成本视图；有效owner出现时迁移旧history，clear时只隐藏、不删除。aggregate按设备与provider抑制withdrawn来源，dashboard/activity跳过clear；普通nil保留历史fallback。新copy/helper放iOS WidgetShared，不改Mac二进制输入。增加legacy→独立→legacy、clear/restore、两Mac四quota、预算与raw ledger保留测试。
