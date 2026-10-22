# 正式发布与 iOS 审核提交

Status: in-progress（Mac已live、iOS已提交；自动CLI分发产物和最后文档审查仍在完成）

## 发布结果

- Mac：[0.79.0.1 — Mobile 3.1.0](https://github.com/o1xhack/CodexBar-Mobile/releases/tag/v0.79.0.1-mobile.3.1.0)，原 draft ID `420093277` 原位晋级；仅此一个本轮用户版本。Sparkle `172.1.3.1.0`，tag 指向已审查的发布工具修复 merge `e64152322fa63732b38dd6c1b832879bdc4943fe`（原上游同步 merge 为 `1b8a8be12a251b322e8467fe3966250bcb0a3d00`）。资产和已发布 feed 均已回读核验。
- iOS：3.1.0 (246)，ASC build `17160de4-173b-434b-93f7-5d3c102aac4f`，Apple 处理 `VALID`、内部 beta `IN_BETA_TESTING`。2026-10-22 04:44:15 UTC 提交 App Review，submission `c72ab909-dec3-4fdf-b714-06ce94e70004`，回读 `WAITING_FOR_REVIEW / MANUAL`。审核后仍由开发者手动发布，尚未在 App Store 公开 3.1.0。
- [PR #199](https://github.com/o1xhack/CodexBar-Mobile/pull/199) 已合并；[原 Final CI](https://github.com/o1xhack/CodexBar-Mobile/actions/runs/39723108855) 的正常矩阵全部通过，Swift 6.2 job 在30分钟上限被取消，并导致原 aggregate 失败，原 run 总结为 cancelled，绝不记作PASS。[定向兼容补跑](https://github.com/o1xhack/CodexBar-Mobile/actions/runs/39726703879) 固定相同发布源码并成功后，才创建/推送 tag、执行 `Scripts/release.sh --finalize`。上游 checks 含 skipped 项，不符合严格复用条件，因此实际执行 fork 完整矩阵，未弱化 gate。

## 版本与单版本约束

发布准备前实时 ASC 核对发现 3.0.0 已 `READY_FOR_SALE / READY_FOR_DISTRIBUTION`，旧 draft 的 `MOBILE_VERSION=2.10.0` 已不能代表配套分发状态。先完成 3.1.0 (246) 上传并确认 `VALID`，再发布同一 Mac `0.79.0.1`，将 companion metadata 更新为 `3.1.0`，重打包、签名、公证。`BUILD_NUMBER=172.1`、`UPSTREAM_VERSION=v0.79.0`、sync date `2026-10-21` 保持；Sparkle 从未发布的候选 `172.1.2.10.0` 改为正式 `172.1.3.1.0`。同一 draft ID 替换 tag/name/target/notes 和两份资产，旧 2.10 候选未公开，也没有发布旧 tag，未拆第二个版本。

## Mac 产品与发布证据

打包源码为 clean reviewed head `15fb91b1f34d15b79899f258de035687b16287bb`，与 merge `1b8a8be12` 的完整 tree 均为 `c72ef4f163ac411a443d84be6c9f309fc0044a45`。后续 tag commit `e64152322` 仅增加已审查的 CI/发布验证工具与文档，全部 Mac ARTIFACT_INPUTS 及 iOS 产品输入相对该源码仍零 diff。双架构 Release、Widget、签名、公证、staple、spctl、独立 launch/resource probes 与 dSYM UUID 全通过。notary ID `6b57e15b-da4b-482d-9049-ec0623b4972b`，`Accepted`。

| Asset | Bytes | SHA256 |
|---|---:|---|
| CodexBar-0.79.0.1-mobile.3.1.0.zip | 90774554 | 5db63fe39fd82da043d28243a477f4cc452e1b467e68c6db235a5582790ea0c0 |
| CodexBar-0.79.0.1-mobile.3.1.0.dSYM.zip | 72678034 | d42707e076a2256bb1fbc48400ea89f672a7805e04617a5fea637d860d7476b6 |

关键命令：`Scripts/sign-and-notarize.sh` → draft metadata/asset replacement → 独立验包与 `sign_update --verify` → 原矩阵成功 + 定向兼容补跑成功 → 从已审查 merge 创建/推送唯一 tag → `Scripts/release.sh --finalize`。发布前 feed 不变；发布后的 URL、signature、length、version 与已公证 ZIP 一致。具体机器证据在 `evidence/release-promotion.json`、`evidence/mac-release-verification.json` 和 `evidence/final-ci-coverage.json`；大日志位于 SSD BuildScratch。

## iOS Archive 与 App Review 来源

实际 archive checkout 是 `15fb91b1f`；`reviewedIOSInputsCommit=15be65cbda7e2036f9961376bae3edfcc1b81133` 表示较早已审查的相同 iOS 输入，不是实际 archive 时的 HEAD。两者到 merge 的 iOS code/resources/project/Shared diff 均为空，R6 clean 覆盖实际 archive head。Archive 为 `.../BuildScratch/CodexBar/TestFlight-20261021-213219/CodexBarMobile.xcarchive`；App 与三个扩展均 `3.1.0 / 246`，CloudKit `Production`。上传脚本的 lint、Archive、export/upload 均成功，无另存 IPA，使用 archive manifest 绑定来源。

Archive 在 export 前后各保留 101 文件 manifest。Xcode 在上传完成时给根 `Info.plist` 添加 `Distributions`，因此不能声称整个 archive 不变：pre-export tree SHA256 `98e732f6e7265cc0775efaa8976df37f38e1bb1c0c96bc85c9b2908f9d3456f9`，post-export `401abff1be19fe38aa1074565e47587ccd62517ab77be4480346fadf3718e7fd`。唯一变化是根 `Info.plist`；所有 Products/dSYMs 文件逐一相同，executable SHA256 `96c6c551bd207ed9e1d32c415aac9cd075e0e930ef3cf683c80310d19bea49b4`。算法与完整 manifests 见 evidence。

执行 `asc versions attach-build --version-id ... --build-id ...`、`asc validate`（0 errors / 0 blocking，6 个继承的非阻塞 listing warnings）、`asc review submit --dry-run` 后 `--confirm`，最后独立 GET 回读审核状态和 `MANUAL`。四语 What's New 已校验并同步，继承英文/简中截图和默认语言 fallback；保留既有审核说明/权限和 Duo/calendar 指引。源图、archive 编译图及 Apple CDN 服务端图标分别目视核对正确。未发送外部 beta 邀请，未执行 iOS public release。

## Duo 回归与风险边界

相对 3.0.0 merge `7fa778243f1a441a3d45dcfc561b89b16770449c`，`MobileAdaptiveLayout`、`ReportPanePlan`、`AdaptiveReportPanes`、`ReleaseNotesView` 与 Duo 测试文件 byte diff 均空。ContentView 仅成本数据撤回 guards 和 release notes 内容变化，不改 ArrangementView、reserved regions 或导航布局。

- Duo 27.1 外屏：`DuoWorkspaceUITests` 2 pass / 1 skip / 0 fail；通过选中账号与分享草稿在旋转/取消后保留、Cost/Share 控件可达性。宽栏独立滚动因 width < 760 条件跳过。
- iPad 27.0 宽容器：单独执行 `testWidePanesScrollIndependently`，1 pass / 0 skip / 0 fail，补足宽栏生产分支；不扩大为实体 Duo 认证。
- CloudKit 审计仍 `NO_DEPLOY`，实包 Mac/iOS 均 Production。16 组合仍为冻结 old/new 真实 consumer 替代验证（64 reads / 32 merges），未证明实体 CloudKit/APNs/cache 收敛。没有 live provider/cookie/真实 Keychain QA 探测。

## 循环审查与闭环

PR #199 共六轮，当前 head `15fb91b1f3` clean，所有 thread resolved；第六轮前已提交四字段 architecture audit。合并前即时 review gate 与 PR Fast Checks 通过。合并后再次运行 gate 按设计因状态 MERGED 返回非零，但其 readback 为 currentClean=true、unresolvedCount=0、architectureAuditRecorded=true，不冒称合并后脚本 PASS。独立两 agent 又复核 Mac 发布链与 iOS provenance/Duo，产品阻塞 0；修正了旧 draft 资产快照及 archive checkout/哈希时点表述。CI 容量修复与首段来源证据由 [PR #200](https://github.com/o1xhack/CodexBar-Mobile/pull/200) 合并，head `b98f8ab76bf9b45beb010c5e0a57447e187561a9` 一轮 clean / 0 unresolved，merge `e26ec6f31c1b11e3c3a017ad2631af2173faa39d`；[其正常 Final CI](https://github.com/o1xhack/CodexBar-Mobile/actions/runs/39726703532) lint / 路径 / aggregate 成功，按策略跳过无关重型矩阵。兼容job保持原Xcode26.3 / Swift6.2 / 缓存键 / `swift build --build-tests`覆盖，给60分钟完成并提取为 reusable/manual workflow，正常FinalCI仍要求其success。单独补跑的 workflow commit 是 `e26ec6f31`，实际 checkout source_ref 为完整 `1b8a8be12a251b322e8467fe3966250bcb0a3d00`，两者分别记录，不拿workflow head冒充产品源码。另将既有PR分支名的inline shell插值改成env+quoted参数传递。发布暂存/清理由 [PR #201](https://github.com/o1xhack/CodexBar-Mobile/pull/201) 修复：head `b77f20c0b9ed029d428ae1a880c29726eb45a32d` clean / 0 unresolved，合并前 gate 和 Fast Checks通过，merge `e64152322fa63732b38dd6c1b832879bdc4943fe`；[合并后 CI](https://github.com/o1xhack/CodexBar-Mobile/actions/runs/39728948937) lint/aggregate通过。enclosure/metadata/probe遵循配置暂存根，phase1/phase2先创建700权限私有目录并安装shell-escaped EXIT清理，再生成key；notes同目录。metadata用subshell自有trap，不覆盖父key清理。永久7项生命周期测试接入portable lint，精确错误码/目标诊断/空格单引号路径均覆盖，真实危险操作全部stub；另5项下载路径/错误清理契约通过。完整portable lint3143文件零违规，真实签名预检与公开下载验证另有证据。最终收尾 PR 的 exact-head review/gate 留在该 PR，避免把回执写入源码又改变已审查 head。

Mac live 后以正式 URL 回复并关闭 upstream-sync #196，Todoist Dev 移至 Release，区分 Mac 已公开与 iOS 待审核/手动发布。历史 00–06 的 draft/no-upload 叙述是此前权限阶段记录，本节与 release-promotion evidence 是最终状态。

## 自动 CLI 分发产物

Mac签名GUI包和dSYM已公开并通过发布脚本验收；release事件另触发 [Release CLI](https://github.com/o1xhack/CodexBar-Mobile/actions/runs/39729517647)，六个平台的独立tarballs/sha256目前构建中，不记为成功。Homebrew upstream tap job受fork guard保护，不写上游。
