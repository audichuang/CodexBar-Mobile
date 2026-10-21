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
