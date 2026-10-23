# Usage 剩余额度概览与 Cost 分组排序

状态：`done` · 2026-10-23 · iOS 3.2.0

> 2026-10-23 需求更正：本记录中的未来估算线解释有误，已由 [083 实际额度历史修正](../083-quota-observed-history/00-goal.md) 取代。Remaining Quota 仅展示真实损耗历史；预测另图，不属于本图。以下保留为既有版本实施及发布记录。

## 最终目标与授权

用户已确认剩余额度原型，并授权独立完成实现、本地 CR、跨屏幕验证、PR 线上 CR、合并与 TestFlight。此任务仅修改 iOS；不发布 Mac 或 App Store 正式版本。3.2 的发布说明保留此前 Summary Tab 大更新，合并本次功能。

## 确认的交互

- Usage 顶部同图展示最多 5 条用户选择的额度线。绑定 Provider → 稳定账号 → 额度窗口，支持 Session、Weekly 和动态模型专属窗口；每条可改颜色。同 Provider 默认相近颜色，继承现有 Usage 色系。
- 纵轴为剩余额度：上方 100%，下方 0%，每条从自己的当前剩余额度开始。细实线，保留真实观测的忙闲变化；没有证据时不人为添加波动。
- 横轴为当前日期到全部有效窗口中最远的重置日期，各条线只到自己的重置/耗尽边界。重新同步后自动延展。
- 图例默认折叠成一行，显示前两条与剩余数量；展开后显示账号、窗口、剩余比例和重置时间。原生导航和 Tab Bar 保留，浅深色继续使用 Usage/Cost 统一系统底色与灰色卡片。
- Provider 详情的普通多设备来源说明移至底部；真正失败或陈旧数据警告保留在数据附近。
- Cost 普通历史范围说明放底部；7 个整组支持用户排序，暂无数据只隐藏而不遗忘顺序。宽屏使用同一全局序列。

## Research 与数据诚信

既有 Mac `utilizationHistory` 是 provider 级共享历史，可能复制给多个账号；wire series 没有账号与稳定 windowID 的来源标识。本图不将其冒充账号历史。参考 `MobileQuotaBurndown` 的剩余值、校验和周期切段逻辑，复用 Summary 稳定身份解析与源观测时间，但独立维护有界的 iOS 本地观测和配置。

未来数据均是估算。足够的本地真实观测可以保留其快慢/停顿模式；历史不足只使用明确的均值估算或当前读数，绝不随机生成折线。过期、未知、阻塞或不可验证窗口不能伪装为实时可用数据。Demo 和测试存储隔离。

上游检索：`quota history chart` 无匹配 PR；`dashboard order` 命中成本周期对齐 PR #2295，但无可直接复用的多账号剩余额度概览/用户整组排序实现。Mac 不在本次修改范围。

## 分工与推进

| 角色 | 负责 |
|---|---|
| 主工程 | Usage 图表/编辑 UI、集成、四语、版本、验证、PR 与 TF |
| 数据工程 | 稳定账号/窗口绑定、本地采样、估算模型、持久化与单测 |
| 设计工程 | Cost 排序、来源说明位置、跨屏视觉验收 |
| 独立 Review | 数据真实性、身份隔离、缓存兼容及最终差异审查 |

遇到重复错误或设计矛盾先更新研究结论和方案，再继续实现。

- [x] 用户确认设计与完整交付授权
- [x] 账号历史来源与复用边界审计
- [x] 模型、持久化与图表集成
- [x] Cost/详情调整与四语发布说明
- [x] 单测、构建、独立本地 CR 并修完（包含额外身份历史 finding 修复与增量验证）
- [x] 小屏/大屏 iPhone、iPad、Duo 外屏/展开横竖屏、浅深色与动态字体验证
- [x] 缓存兼容 16 组合替代/实测证据及剩余风险记录
- [x] PR #208 exact-head Codex CR 清零，3 轮 / 0 unresolved，gate 通过并合并
- [x] 最终已审来源 Production entitlement Archive 与 Apple Distribution 本地 export 验证
- [x] Final CI：`39984321217` 成功
- [x] TestFlight：上传成功且 ASC `VALID` / `IN_BETA_TESTING`；Internal 既有自动访问权限与完整 3.2 四语 What to Test 已回读确认
- [x] Apple CDN 实际 152px 与 unmasked 1024px 图标已下载并人工验收

## 验收与证据

测试记录写入 `03-testing.md`，发布来源、commit、archive、ASC build 和状态写入 `04-release.md`。实际截图必须包含完整 App 栏位。不能把模拟器证据宣称为真机或 Production 多设备同步验证。

基线：`d90e42daef7f54611c7fba7c043452b7125f7436`（PR #207），iOS 3.2.0 (250)。本任务分支：`feature/usage-quota-overview`。

## 最终发布来源与验收

最终 reviewed source 为 `6cd449d8ba69628db9242bdef4cc9f71b5b8d875`，tree `332f57ee4b3095c0b3188409394e73777b1d2170`。PR #208 于 `2026-10-23T16:08:48Z` 合并为 `41dbf7cd313fc4c95007ab62c153a68c71d6bdff`，merge tree 与 reviewed source tree 一致。最终 clean receipt 为 `6369240831`，PR Fast Checks `39983809520` 成功。最新修复验证为 40 个 Swift Testing + 2 个 render + 1 个原生 UI，共 43 tests / 参数展开 60 passes，0 failures / 0 skips；不冒充全量重跑。

已审来源的 Archive、本地分发校验、直接上传与最终 CI 已成功。ASC 最终 build `edf84cdb-4cee-4f7e-874d-d90fde2c4cff` 已为 `VALID` / `IN_BETA_TESTING`；`groups.json` 确认 Internal 的既有自动全 build 访问，四语测试说明 exact readback、Apple CDN 两个实际图标人工验收均通过，验收完成于 `2026-10-23T16:17:08Z`。显式添加 Internal 返回 422，但没有阻断既有访问，也不记为新增分组成功；目标及本文状态更新为 `done`。最终 receipt 见 `04-release.md`。收尾文档分支为 `review/usage-quota-release-closeout`，不改变发布代码来源。
