# Summary iOS 3.2 TestFlight 准备与来源

- 授权：2026-10-22 用户要求合并 PR #204，并重新归档上传包含最终修订的 TF；不含 Mac 发布、App Store 送审或公开发布。
- PR #204：当前 head `9ec2231aa1fc75b5429fcce3c432b09a602f26bd` 通过两轮线上 review、0 unresolved、Fast Checks 与合并前 gate；合并为 `a22464bdb`。merge tree 与已审 head 一致。
- ASC 实时核对：最新 TF 为 `3.1.0 (246)`，Summary 的 247/248 尚未上传；3.1.0 已为 `READY_FOR_SALE / READY_FOR_DISTRIBUTION`，所以必须新开 `3.2.0 (248)` train，不能继续上传已关闭的 3.1 train。build 248 尚未占用，无需再增加 build。

## 范围与 Mac / CloudKit 审计

PR #204 所有改动均在 `CodexBarMobile/`；相对 published `v0.79.0.1-mobile.3.1.0`，`Sources/`、`Shared/`、`CodexBarMobile/Shared/`、`Scripts/cloudkit/`、`version.env` 均无改动。没有新增 record type/field/index/subscription，没有 payload / decoder / fallback / shared cache 变更，Production entitlements 保留。结论 `NO_DEPLOY`，无需配套 Mac release。

Summary 仅在 iPhone 本地保存面板布局并读取既有同步结果。各 Mac 版本已有的数据能力仍决定哪些卡片可选；不要求 Mac 更新来启用 Summary。此次版本与说明修订同样仅在 iOS，sync framework 仅包版本号随 App 对齐，不改共享协议。

本次没有同步链路、跨版本 payload/reader 或既有缓存行为变化；按 canonical sync compatibility gate 记录为不适用新的 16 设备组合矩阵。既有单元/fixture 多账号与关联身份、旧字段缺失/陈旧/重置状态回归及 Duo 模拟器证据继续适用；不声称新做了物理 2 Mac × 2 iPhone / APNs 验收。

## 版本与说明修订

五个 target 一致为 3.2.0 (248)。Summary 的 highlight 和说明从已发布 3.1 历史中移出，成为独立 3.2 最新条目；旧 3.1 的 provider、calendar、reset-credit 与原有 Duo 说明保持。新增“无需 Mac 更新”说明在 en / zh-Hans / zh-Hant / ja 均 translated。

本地 release-prep 独立 review 通过，完整 lint（含 SwiftFormat、SwiftLint、i18n/源码 key 覆盖与 policy guards）通过。主功能测试、两种真实内屏姿态与上一轮测试可移植性修复已分别留在 03–05 记录中。

## 归档与状态证据

构建 SDK：Xcode 27.1 RC / 27A9275，最低系统 iOS 17 不变。使用现有 Xcode Apple ID session 完成 cloud signing/upload；全局 App Manager key 仅用于 ASC 元数据/状态读写。每个 packaging 命令显式指定 `-packageAuthorizationProvider netrc`。

新的 Archive、Export、日志与 provenance receipt 均由调用方保存于 `/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/`。receipt 记录 exact source commit/tree、App/extension 版本、签名 Production entitlement、archive/IPA 哈希与 ASC build ID；TF 的 VALID 和 beta 可用状态需由 ASC 回读，不能以 archive/upload 命令返回成功替代。

后续上传状态、最终 source SHA、TF build ID 与发布边界在对应 PR comment / Todoist 及本地 receipt 中回读记录；本准备文档不提前声称上传、App Review 或公开发布完成。
