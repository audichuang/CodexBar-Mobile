# 077 — Reset credit 到期时间详情与日历提醒（iOS 2.10.0 + Mac 0.76.0.2）

Status: `done`（代码、测试、文档与版本号完成；PR #195；Mac draft release 与 iOS TestFlight 见 03-testing）
Date: 2026-10-18

## 需求（用户确认，2026-10-18）

1. iPhone 显示更详细的 reset credit 记录：每一次可兑换的 reset 各自的到期日期与时刻。
2. iPhone 可以把 reset credit 的到期时间自动写进日历。
3. 本轮只做 reset credit 到期提醒；Claude / Codex 的每周重置不进日历（经常被重置，进日历会很乱）。
4. credit 提前用掉（例如原本 22 号到期，20 号就用了）→ 日历里未来那条事件要自动删掉。
5. 先更新 iOS、Mac 仍是旧版时不能出任何问题；更新说明里写明 Claude / Grok 需要新版 Mac。

## 调研结论

### 各家 reset credit 的数据来源（2026-10-18 本机实测 + 代码审计）

| Provider | Mac 数据 | 每次 credit 的到期时间 | 旧 Mac 是否已同步到 iPhone |
|---|---|---|---|
| Codex | OAuth `wham/rate-limit-reset-credits`，`CodexRateLimitResetCreditsSnapshot`（含已兑换记录） | 每个 credit 的 `expires_at`（可为空） | 是：`ProviderUsageSnapshot.codexResetCredits`（iOS 1.15.0 / Mac 0.37.2.1 起） |
| Claude | Web / OAuth usage 响应的 `cedar_ember`，`ClaudeRateLimitResetCreditsSnapshot`（只保留到期时间，grant ID 从不解码） | 每个 grant 的 `ends_at`，`resets_left` 次共用同一到期时间 | 否：live-only，同步层还过滤掉了 `Limit Reset Credits` 明细行 |
| Grok | grok.com billing RPC `GetRemainingResets`，`GrokRateLimitResetCreditsSnapshot`（token ID 不进快照） | 每个 token 必有的到期时间（epoch 秒） | 否 |

本机实测：Claude `1 available`，到期 `2026-10-22 09:00 PDT`；接口时间为 ISO-8601，精确到秒。

### 关键难点："确定没有" 与 "不知道"

删除提前用掉的 credit 需要 Mac 能说清楚"现在确定一个都没有了"。上游原实现里 Claude、Grok 两家在"没有可用 credit"和"没读到 / 读失败 / 数据源不支持"时都返回 `nil`，无法区分。用户只有 1 次 credit 时，用掉后恰好落在这种情况。

## 设计

### 1. 同步字段（Shared，向后兼容）

- 新增 `SyncResetCreditInventory { expirations: [Date?], updatedAt: Date }`，挂在 `ProviderUsageSnapshot.resetCreditInventory`（`decodeIfPresent`，nil 不编码）。
- 只给 Claude、Grok 填；Codex 继续用已有的 `codexResetCredits`（旧 Mac 也有）。
- 语义：字段存在 = 这台 Mac 在 `updatedAt` 时刻确认的完整可用列表（可以为空数组 = 确定一个都没有）；字段缺失 = 不知道（旧 Mac、CLI 数据源、读取失败、上限保护触发等）。
- 只同步到期时间，不同步 grant / token ID（ID 是兑换凭据，保持上游的安全边界）。
- `Limit Reset Credits` 明细行的过滤保持不变（旧 iPhone 继续看不到这一行，新 iPhone 用结构化字段渲染）。
- 旧 iPhone + 新 Mac：未知 key 被忽略，界面无变化。新 iPhone + 旧 Mac：Claude / Grok 没有该字段 → 不显示新卡片、不写日历，Codex 照常。
- CloudKit：只在既有 `DeviceProviderSnapshot.payload` opaque JSON 内新增可选 key，`NO_DEPLOY`。

### 2. Mac 端区分 "确定为空" 与 "不知道"

- Claude：`ClaudeLimitResetStatusResponse.snapshot` 在 `eligible: true` 且解码成功、但没有可用 grant 时返回**空列表快照**（原为 nil）；有 grant 因格式错误被丢弃时快照标记为不完整（`isComplete = false`，同步字段里也带上），iPhone 只新增、不删除；`eligible` 缺失 / false（服务端说明了 `ineligible_reason`，可能只是请求来源不被支持）、块缺失、超过上限仍返回 nil。菜单与 CLI 对空列表本来就不显示（`LimitResetCreditsPresentation.make` 与 `detailSections` 遇空返回空），用户可见行为不变。
- Grok：`GetRemainingResets` 请求成功（即使 0 个 token）时快照任务返回空列表快照；请求失败且沿用旧缓存时仍按旧规则（空 → nil）。菜单与明细同样遇空不显示。
- 同步层 `SyncCoordinator.mapResetCreditInventory` 按 provider 映射，到期时间按 `updatedAt` 过滤掉已过期的。

### 3. iPhone 日历逻辑（`ResetCreditCalendarPlanner`，纯逻辑，可单测）

- 观测输入：合并后的每张 provider 卡片（同一账号多台 Mac 已合并），Codex 取 `codexResetCredits`（`status == available` 且未过期），Claude / Grok 取 `resetCreditInventory`；字段缺失的卡片不参与本次对账（保留已有事件）。Codex 出现未知状态、或列出的可用数少于报告的数量时，视为"不完整"：只新增、不删除。
- 日历读取每台 Mac 自己的原始快照（任何合并之前；跳过已归档的 Mac，设备别名组的成员映射到同一台 Mac，因为别名组的合并快照也会跨账号合并）：合并后的卡片可能把几个账号并成一张（共用邮箱或组织、几个都没有身份的账号），却只带其中一个账号的库存，不能用。
- 账号范围只由这一条数据决定，所有设备算出同一个值（不依赖本机历史）：真实邮箱身份（Codex 再加组织身份：个人与团队工作区可能同一邮箱；Claude 不加，因为它的组织身份只在部分数据源出现）→ 记录 key（token 账号；标签不算身份）→ 没有账号身份的 provider（Grok）的主账号邮箱 → 这台 Mac 本身。单独的组织身份不作为范围（同一团队的成员共用）。同一台 Mac 内仍冲突的条目不进日历。同一账号出现在多台 Mac 上时得到多条同范围观测，按"只接受更新的观测"取最新。
- 原则：各台 Mac 上报不一致时，最多把一个账号算成两个（可能重复提醒，旧的那条到期后不再更新），绝不把两个账号算成一个（那样会互删事件）。
- 事件 key = `provider | 账号身份 | 到期时间`；同一账号同一时刻多次 credit 合并成一条事件，标题带次数。
- 单调规则：每个账号记录已应用的最新观测时间（观测时间比 iPhone 当前时间快 5 分钟以上的，说明那台 Mac 时钟偏快，无法与其他 Mac 排序，整条忽略直到真实时间追上；水位线即使账号暂时没有数据也保留 60 天），不比它新的整条观测直接忽略。旧 Mac 或缓存里更早的数据不能把已用掉的 credit 加回来，也不能删掉更新观测里还在的。合并器对 Codex 也改为按 credit 自己的读取时间取最新。
- 提前用掉：更新的完整观测里某个未来 key 消失 → 删除对应日历事件。删除发生在 iPhone 上的 CodexBar 更新数据时（打开 App 后）。
- 已过期的事件保留在日历里作为历史，不删；状态记录在过期 30 天后清理。
- 事件带不含邮箱的 URL 标记 `codexbar://reset-credit/<SHA-256 前 16 字节>`，按它查找：EventKit 标识变化、同一 iCloud 日历上另一台设备建的事件、两台设备同时写出的重复事件，都会被接管或清理；去重时所有设备都保留最早创建的那条。已存在的可写"CodexBar"日历会被复用。
- 开关打开期间，事件或整个日历不见了就重建（另一台设备关闭开关、或标识变化，都不应让本机提醒悄悄停掉）；关闭开关 → 删除未来事件和状态记录（删除失败的保留下来，下次开启时重试），保留日历本身；过去事件不动。
- Demo / Mock 数据、单测宿主和 UI 测试启动永不写日历。

### 4. 日历事件

- 写入独立日历 "CodexBar"（优先 iCloud 源，其次默认日历所在源，最后本地）。
- 事件：到期前 30 分钟到到期时刻的时间块；标题如 "Claude reset credit expires"（多次时 "2 Claude reset credits expire"）；备注写账号与到期时刻。
- 提醒：到期前 1 天、到期前 1 小时。
- 权限：iOS 17 `requestFullAccessToEvents`（删除 / 更新自己创建的事件需要读权限）；`NSCalendarsFullAccessUsageDescription` 四语言。

### 5. 界面

- Provider 详情页：通用 `ResetCreditsCard`（Codex、Claude、Grok），显示可用次数与每次 credit 的到期日期 + 时刻 + 相对时间；替换原 `CodexResetCreditsCard`。
- 设置 → 新增"日历提醒"页：开关、权限状态、上次同步结果、说明 "Claude 与 Grok 需要 Mac CodexBar 0.76.0.2 或更新版本；Codex 可用旧版 Mac"。

## 版本

- iOS `2.10.0 (243)`（2.9.0 (242) 仍在审核，不改动）。
- Mac `MARKETING_VERSION=0.76.0.2`，`BUILD_NUMBER=169.2`，`MOBILE_VERSION=2.10.0`，Sparkle `169.2.2.10.0`；上游仍为 v0.76.0（上游 v0.77.0 不在本轮范围）。

## 文档

- [03-testing.md](03-testing.md) — 测试与 16 组合兼容矩阵证据
