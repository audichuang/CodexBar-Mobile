# v0.80.0–v0.82.0 单版本上游同步

状态：`in-progress`；用户 Goal 已确认调研后实施。本轮停止点是候选产物、当前 head 的本地与 PR review 全部通过，随后等待合并及正式发布决定。

## 冻结范围

- 分支：`upstream-sync/v0.82.0-mobile.3.3.0`，从最新 `origin/mobile-dev` `bdfb510853270c1ebf6b9d6f5ccbb289a2634db1` 创建。原有未跟踪 error.log / work/ 不属于本轮。
- version.env 基线：v0.79.0 / 2026-10-21；Mac 0.79.0.1 / 172.1 / Mobile 3.1.0。iOS 项目为 3.2.0 (260)。
- 起始 open upstream-sync：[221](https://github.com/o1xhack/CodexBar-Mobile/issues/221)、[222](https://github.com/o1xhack/CodexBar-Mobile/issues/222)。
- 官方 Releases 确认 v0.80.0、v0.81.0、v0.82.0；最新稳定 v0.82.0 发布于 2026-10-26T23:41:31Z，目标 commit `7749f7b94ae8f1b84b9ffb2046643cec810f4078`，远端 peeled tag 已核对。本轮不追逐随后新增 release。
- 只合并最终 v0.82.0，累计 697 文件（含大量 rename）、24202 additions / 4554 deletions；不拆用户版本。
- 历史 closed #196/#193 与 Research079：单 train 包含未有提醒的 release；只有 Mac public release 后才回帖完成并关闭 Issue。本轮 PR 仅关联，不用 closing keywords。
- 全量 release notes、提交/文件清单存 evidence/，后续 06-ios-impact-audit.md 逐项归类与验收。

## 版本方案

| 项目 | 候选值 | 依据 |
| --- | --- | --- |
| Mac MARKETING_VERSION | 0.82.0.1 | 上游三段 + 首个 fork 补丁；文档首部明确规则优先于遗留决策树 |
| BUILD_NUMBER | 175.1 | 上游 v0.82.0 整数 175，不擅自提升整数 |
| Mac MOBILE_VERSION | 3.2.0 | ASC 实时读取确认 3.2.0 READY_FOR_DISTRIBUTION / READY_FOR_SALE；不把未上传 3.3 当已交付 |
| Sparkle / CFBundleVersion | 175.1.3.2.0 | 大于最近 published 172.1.3.1.0 |
| draft 逻辑 tag | v0.82.0.1-mobile.3.2.0 | 不创建/推送真实 tag；source commit 与 draft 占位 target 分开记录 |
| iOS | 3.3.0 (261) | 3.2.0 (260) 已发布，最新上传260 VALID；本轮增加 provider/数据展示能力，全部 targets 一致 |

若后续用户授权先交付 iOS3.3再正式发布 Mac，正式发布前重新核实 companion 并更新候选包；不在本 Goal 未上传时声称3.3已配套交付。本轮只准备一个 Mac 候选版本。

## 环境与边界

StudioSSD UUID、working symbolic link、项目 realpath 与 BuildScratch 可写检查已通过。Xcode27.1 / 27A9275，iOS SDK27.1、macOS SDK27.0；iOS26.5/27.0/27.1 runtime 可用；最低 iOS17 保持不变。大型构建、Archive、结果和临时模型仅写 BuildScratch。

用户授权本轮本地构建/签名公证、无 tag draft及附件、任务分支push/PR与两轮review；未授权 merge/tag/live release/appcast/TestFlight/App Review/CloudKit deploy/Issue关闭。签名使用已授权凭证；不运行会触发 Keychain UI 的真实 provider/cookie 探测。上游 fetch 曾拒绝覆盖若干历史同名 tag，未 force；本轮 v0.80/81/82 已成功获取且目标hash与远端匹配。

