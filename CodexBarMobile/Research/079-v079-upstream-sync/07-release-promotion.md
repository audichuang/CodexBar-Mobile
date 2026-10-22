# 正式发布与 iOS 审核提交

Status: in-progress（iOS 已提交 App Review；Mac 完成签名公证与验包，等待 Final CI 后公开）。

用户明确授权 Mac live release、iOS 上传并提交 App Review，iOS 保持 MANUAL 发布。ASC 实时核对 3.0.0 已 READY_FOR_SALE，旧 draft 的 Mobile 2.10 只代表历史基线，正式发布不再沿用。先上传 3.1.0 (246)，再发本轮唯一 Mac 0.79.0.1-mobile.3.1.0，Sparkle 172.1.3.1.0；Mac版本和 build 172.1 不拆第二个用户版本。原 draft ID420093277 原位更新 metadata/资产；旧 2.10 候选从未公开且已留本地备份。

iOS actual archive checkout 是 `15fb91b1f34d15b79899f258de035687b16287bb`；`reviewedIOSInputsCommit=15be65cbda7e2036f9961376bae3edfcc1b81133` 代表较早已审查的相同产品输入，不是实际 archive 时 HEAD。两个提交到 merge `1b8a8be12a251b322e8467fe3966250bcb0a3d00` 的产品输入无差异；actual source 和 merge 的完整 tree 相同。ASC build `17160de4-173b-434b-93f7-5d3c102aac4f` 已 VALID / IN_BETA_TESTING，submission `c72ab909-dec3-4fdf-b714-06ce94e70004`，回读 `WAITING_FOR_REVIEW / MANUAL`，未公开 iOS 3.1.0。

Duo：MobileAdaptiveLayout、ReportPanePlan、AdaptiveReportPanes、ReleaseNotesView 与基线 7fa778243f1a441a3d45dcfc561b89b16770449c byte diff 均空；ContentView 仅成本撤回 guard 和 notes 内容变化，无布局/ArrangementView/reserved regions/导航变化。Duo 外屏既有 UI 测试 2 pass / 1 宽度条件 skip / 0 fail；另在 iPad 27.0 宽容器跑独立滚动测试，1 pass / 0 skip / 0 fail。不扩大为实体 Duo 折叠验证。

Archive 的101文件 pre/post-export manifests 均保存。Xcode 上传完成后只在根 Info.plist 加入 Distributions，因此分别保存上传前后 tree hash；App、三个扩展、资源与 dSYM 文件逐一相同。来源、hash 算法和差异详情见 `evidence/ios246-archive-provenance.json`。源图、archive 编译图、Apple CDN 图标分别目视核对正确。

PR #199 六轮 exact-head clean，所有线程已 resolved，第六轮前有四字段 architecture audit；合并前 review gate/Fast Checks 通过。合并后 gate 按设计因 MERGED 状态拒绝，但 currentClean=true、unresolvedCount=0，不冒称这次调用 PASS。独立 Mac / iOS agents 复核产品阻塞0，证据措辞问题在本收尾修正。Final CI39723108855仍在运行，未先 tag 或 public release。CloudKit仍 NO_DEPLOY，Mac/iOS Production，16组合保留替代验证/实体收敛风险边界。
