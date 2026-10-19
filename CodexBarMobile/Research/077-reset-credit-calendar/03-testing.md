# 077 — 测试记录

日志与 xcresult 位于 `/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/reset-calendar/`（StudioSSD UUID `9D5FE511-B66C-4765-BB8F-61E5ACB3969D` 已校验可写）。iOS 测试用专用模拟器 `CodexBar iOS 27 iPhone 18 Pro`（`83278BCC-AE64-41F8-97A1-05CA13FA5CAE`，系统语言简体中文）。

## 本地构建与测试

| 项目 | 命令 | 结果 | 证据 |
|---|---|---|---|
| Mac 构建 | `swift build` | 通过，无新增警告 | `swift-build-1.log` |
| Mac 聚焦测试 | `swift test --filter 'ClaudeRateLimitResetCredits\|ClaudeOAuthResetCredits\|GrokRemainingResets\|UsageStoreSupplementalUsage\|GrokMenuCardModel\|ProviderArchitectureGatekeeper\|SyncV07\|SyncModel\|SyncCoordinator\|MenuCardModel'` | 430 项 / 56 个 suite 通过（首轮仅 1 项预期中的旧断言失败：eligible 但无可用 grant 现在是空库存，已改为新测试） | `mac-test-1.log`、`mac-test-2.log` |
| lint | `bash Scripts/lint.sh lint` | 通过（swiftformat、swiftlint、i18n、parser 审计等） | `lint-2.log` |
| 四语言 | `bash Scripts/lint.sh audit-i18n` | 全部 xcstrings 已翻译；432 个源码 key 都在目录中；新增 `InfoPlist.xcstrings` 四语言 | — |
| iOS 构建 | `xcodebuild build`（generic iOS Simulator） | BUILD SUCCEEDED，本次改动文件无警告 | `ios-build-1.log` |
| iOS 新增测试 | `-only-testing:CodexBarMobileTests/V077ResetCreditCalendarTests` + `V077ResetCreditEventKitTests` | 23 项通过（含真实 EventKit 往返：建日历、写事件、改标题、删事件、清理日历） | `ios-test-v077-3.log`、`v077-3.xcresult` |
| CloudKit 审计 | `docs/cloudkit-deploy-audit.md` 第 1–4 步 | `NO_DEPLOY` | 见审计文档 v0.76.0.2 节 |

## 模拟器实测（简体中文）

- 首次启动的更新说明显示 2.10.0 条目与"需要的 Mac 版本"。
- 演示模式 Claude 详情页：卡片"限制重置额度 · 可用 2 次重置"，两行分别显示"10月21日 周三 下午4:44 到期 / 2天后"和"10月28日 周三 下午4:44 到期 / 1周后"（截图 `shots/claude-card-zh.png`）。
- 设置 → 日历提醒：开关、说明、"Mac 尚未报告重置额度。"（模拟器未登录 iCloud，无真实数据）与 Mac 版本说明正确；打开开关弹出系统权限框，说明文字为中文版 `NSCalendarsFullAccessUsageDescription`；允许后开关保持打开并显示"上次更新"。
- 演示数据不会写入日历（`ContentView` 的同步任务在演示模式直接返回；Mock provider 在 `ResetCreditObservation.observations` 中被过滤，单测覆盖）。

## 16 组合兼容矩阵（docs/ios-sync-compatibility-testing.md）

old = Mac 0.76.0.1 / iPhone 2.9.0；new = Mac 0.76.0.2 / iPhone 2.10.0。实体 2 Mac × 2 iPhone 环境不可用，全部为 `substituted`：以单元测试（wire 编解码、合并器、对账规则、Mac 映射与推送）和代码审计替代。

各端行为依据：
- old Mac 只发 `codexResetCredits`；new Mac 另发 Claude / Grok 的 `resetCreditInventory`。
- old iPhone 解码时忽略未知 key（`ProviderUsageSnapshot.init(from:)` 只按已知 key 取值），界面与 2.9.0 相同。
- new iPhone：缺少该 key → 未知（不显示卡片、不动日历）；字段格式错误 → 未知且不影响整个 provider 解码（单测 `A malformed inventory is unknown without dropping the provider`）。
- 多台 Mac：合并器在有该字段的条目里取 `updatedAt` 最新的（单测 `Merger keeps the newest inventory even when it is empty`），旧 Mac 的空缺不会覆盖新 Mac 的数据；对账只接受更新的观测（单测 `An older observation can neither delete nor resurrect an event`）。

| Case | Mac A | Mac B | iPhone A | iPhone B | Result | Evidence | Notes |
|---:|---|---|---|---|---|---|---|
| 1 | old | old | old | old | substituted | 无 wire 变化 | 与 2.9.0 相同 |
| 2 | old | old | old | new | substituted | `Claude without an inventory from an older Mac has no observation`；Codex 观测单测 | new iPhone：Codex 卡片 + 日历可用，Claude / Grok 未知 |
| 3 | old | old | new | old | substituted | 同 2 | 同 2 |
| 4 | old | old | new | new | substituted | 同 2 + `A second device adopts the event already in the shared calendar`、`Duplicate events from two devices collapse into one` | 两台 iPhone 共用同一 iCloud 日历时按 URL 接管同一事件 |
| 5 | old | new | old | old | substituted | `Payload without the inventory key decodes as unknown`、Mac 推送单测 | old iPhone 忽略新 key |
| 6 | old | new | old | new | substituted | 合并器单测 + Mac 推送单测 | new iPhone 取 Mac B 的 Claude / Grok 库存 |
| 7 | old | new | new | old | substituted | 同 6 | 同 6 |
| 8 | old | new | new | new | substituted | 同 6 | 两台 iPhone 收到同一合并结果 |
| 9 | new | old | old | old | substituted | 同 5 | 同 5 |
| 10 | new | old | old | new | substituted | 同 6 | 同 6 |
| 11 | new | old | new | old | substituted | 同 6 | 同 6 |
| 12 | new | old | new | new | substituted | 同 6 | 同 6 |
| 13 | new | new | old | old | substituted | 同 5 | 同 5 |
| 14 | new | new | old | new | substituted | 合并器单测（取最新观测，含空库存） | 两台 Mac 对同一账号的观测按时间单调处理 |
| 15 | new | new | new | old | substituted | 同 14 | 同 14 |
| 16 | new | new | new | new | substituted | 同 14 + 对账单测 | 提前用掉 → 更新的空库存删除未来事件 |

剩余风险：实体多设备的 CloudKit 推送时序、真实 Claude / Grok 账号用掉 credit 后的端到端删除未在真机验证。

## 多台 iPhone / iPad 同时开启

同一 iCloud 账号下多台设备都开启日历提醒时：`makeCalendar` 先复用已有的、可写的"CodexBar"日历（优先 iCloud 源）；每个事件的 `url` 是 `codexbar://reset-credit/<key 的 SHA-256 前 16 字节>`（不含邮箱），设备在新建事件前按该 URL 在事件时间附近查找，找到就接管同一事件（单测 `A second device adopts the event already in the shared calendar`，真实 EventKit 往返测试也断言了 URL 查找与日历复用）。局限：两台设备在 iCloud 同步完成前几乎同时首次开启，仍可能各建一个日历。
