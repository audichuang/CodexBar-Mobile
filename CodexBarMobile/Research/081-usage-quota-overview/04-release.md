# 3.2.0 (251) 发布来源与验收

状态：`in-progress` · 2026-10-23。仅 TestFlight 内测，包含此前 Summary Tab 大更新与本次 Usage / Cost 功能；没有提交 App Review 或发布 Mac。

## 发布输入与范围

- 基线 `d90e42daef7f54611c7fba7c043452b7125f7436`，任务分支 `feature/usage-quota-overview`；最终 source commit/tree、reviewed head、merge commit 以本次发布 receipt 为准。
- 五个发布 target 的版本统一为 `3.2.0 (251)`，由 `project.yml` 生成 Xcode project。3.2 in-app notes 只有一个版本块，保留 Summary、加入剩余额度图和 Cost 分组排序，四语齐全。
- Mac `Sources/`、根 `Tests/`、`version.env`、`CodexBarMobile/Shared/`、既有 merger、CloudKit record schema/payload 没有变更。
- CloudKit audit：**NO_DEPLOY**。新增偏好和观测仅保存在每台 iPhone 本地；主 App、PushExtension、Widgets 使用 Production entitlement。WidgetOptions 无 CloudKit capability。
- 兼容性 16 组合为明确标注的 fixture / reader 替代验证，非两台真实 Mac × 两台真实 iPhone 的 Production 实测；详情见 `02-compatibility-plan.md` 和 `03-testing.md`。

## 交付门禁

1. 以 `03-testing.md` 中各次实际结果结算本地单元、渲染、原生交互、跨屏与独立 CR；保留历史失败及复跑证据。
2. PR 对 `mobile-dev`；当前 head 线上 Codex review clean，全部线程 resolved，PR Fast Checks 绿，临合并执行 `Scripts/check_pr_review_gate.sh`。
3. 从已审查的发布输入 Archive，核对五个 bundle 的版本与实际签名 Production entitlement，记录二进制、资源及完整 archive manifest hash。
4. 上传后回读 ASC `VALID`、`IN_BETA_TESTING` 和 Internal 组可用；四语 What to Test 包含完整 3.2 更新并回读核对。
5. 图标三层验收：1024px 源图、archive 实际编译图和 Apple CDN 图均人工查看；source 图已确认 1024×1024、无 Alpha。

发布证据根目录：`/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/UsageQuota-3.2.0-251/`。`provenance.json` 保存最终来源、hash、ASC build ID、处理状态、测试组及验证时间；archive/export/upload 日志、四语 notes 与截图在同目录。最终结果确认后更新此记录；当前文档不预先宣称上传或 merge 已完成。


## 15:52 UTC 发布候选调整

a05 的线上 Codex CR 已 clean；额外独立本地复核发现账号身份退化时可能混用历史，发布暂不放行。a05 的 Archive、Apple Distribution 本地 export、五目标版本和 Production entitlement 校验曾通过，相关完整证据移至 `superseded-a05bc8e/`，没有上传。修复改变生产输入，必须重新记录 source/tree 并 Archive；旧包及旧 clean receipt 不作为最终发布来源。

ASC 当前仅有 build 251 的 `AWAITING_UPLOAD` 预约记录（创建于 07:53 UTC），没有可安装 build。此状态不是上传成功或 TF 已分发证据。
