# 审查与 PR

状态：`done`（本轮候选的调研、实现、测试、产物与审查记录完成；尚未合并或正式发布）。本地完整审查与7f6bdc416的GitHub review已clean，Fast Checks通过；收尾文档之后的最终current-head门禁结果见PR #225。历史失败及当时“待验证”字样按时间保留，不能替代当前结论。

## 完整源码审查

- 第一轮：base bdfb51085 至候选全部 diff、相关 caller/tests/release inputs；报告 `evidence/full-local-review-round1.md` 及 start/end fingerprint。两项 Cursor shared Weekly/uncapped spend 遗漏已修；原标签和 confirmed0/capped lane 均有生产 fixture 断言。
- 第二轮：完整 base→当前候选约754 tracked paths，599项与目标官方release逐字一致，其余fork/新增单独审查；逐路径覆盖类别与限制见 `evidence/final-local-review-round2.md` 和 manifests。F1 OpenCode source-recorded成本来源标错已贯通Core→fresh/cache→window→CLI/Mac→Shared→iOS→两Mac merge修复；基线已有fleet子开关错读手机sync也纳入本轮修复。新增async fixture隔离/serial、CLI UTC日期和native-only Remote缓存排除另经补审。
- Remote schema1读未知Core raw enum会失败，但当前SSH命令及summary producer严格native-only，读Scope/cache/source过滤已逐层审计，未发现现有回归；加native-after-ambient缓存回归断言。未扩大协议或部署schema，未来若支持来源成本必须另做旧client兼容设计。

## UI/证据审查

Duo真实姿态/输入display/后续action、iPad10图、真实SpringBoard Widget均有独立报告。撤回ImageRenderer黄占位、旧rotate回执和141秒Overview假阳性，保留失败。严格98秒Widget复测的mode/picker/Home/重开已独立确认。新caption九图JA AX3原受fixture压缩，最终intrinsic height九图已独立核对完整金额/四行caption、无裁切/重叠，问题已消解。

## 最终 gate 与 PR

102-selection新binary及最终3suite delta、iOS本地Archive已通过；完成quiet full lint/build、Mac signed/notarized no-tag draft后，冻结提交并审计artifact-input一致性，再进行完整candidate最终补审。只有local gate clean后才push origin、建立mobile-dev目标draft PR并请求GitHub Codex review，逐问题修复/复测/本地补审/回复/Resolve/重审，直到当前head clean+0unresolved+FastChecks绿，标ready并运行check_pr_review_gate.sh。当前尚未进入远端review，不把源码0finding冒充候选全部完成。

PR仅关联#221/#222，不提前关闭issues。最终停在用户merge/Mac正式发布/iOS具体阶段决定前。


Archive独立补审核对353项输入、101个逐文件产物、五bundle版本/Team/签名、Production角色、dSYM UUID全部一致。manifest解析序列化hash与实际文件hash已分别命名并记录算法；详见evidence/round2-ios-archive-independent-review.json和ios-archive-verified.json。0新增产品阻塞，不提前标完整候选gate clean。


## 最终产物补审

最终产品18ebb9727已通过128项受影响gate和full lint/build，重签、公证、真实runtime Group及appcast客户端签名校验。独立review已确认固定releaseID附件更新脚本，完整候选终审进行中；详细结果与最终PR/head在后续本节记录。未进入远端review前不宣称clean PR。

最终draft资产更新脚本补审无阻塞：禁止按logicaltag clobber，改为fresh API固定ID/assetID操作；实际tagless server标识与future logicaltag分别校验。已执行更新并回读新附件hash。

## 本地完整候选终审通过与远端交接

独立reviewer `/root/final_candidate_review` 在 `4ef5f75674b1788163c868bb350994b2e900a2b9` 对完整base→candidate及相关caller/tests/config/产物完成终审，0 unresolved findings。报告evidence/final-local-review-round2-current-clean.md及source-end JSON覆盖当前822 tracked变更路径；保留前轮发现与修复历史，不能将历史open状态当当前结论。

独立复核1826项Mac inputs与18ebb源码、两ZIP内部4exec签名/双架构/minOS、Group/Production角色、公证/UUID/远端附件hash；使用OpenSSL独立按真实App公钥验证Sparkle签名。iOS353 inputs与a36 Archive、Archive101文件重新核对一致；用户原有error.log/work与before/after记录一致，未纳入提交。见round2-final-mac-independent-verification.json和round2-final-artifact-public-checks.json。

PR：[225](https://github.com/o1xhack/CodexBar-Mobile/pull/225)，base mobile-dev，关联#221/#222，不自动关闭。当前文档增量只补报告与链接，无shipping input改动；补审后push，请求GitHub Codex review最终head，最终结果及线程/CI/gate以本PR记录交叉核对。达到clean reviewed PR后才询问用户合并、Mac live与iOS具体阶段。

## PR Fast Checks证据文件大小修复

55fad94b2的run40813721269执行到仓库size guard失败：mac-appgroup-selection-coverage.json为2270244字节，超过2097152限制。紧凑排版后仍超限，故仅将fullMethodInventory拆为独立JSON，用文件名+SHA256引用；重新组合后的所有键/值与SSD原始清单完全相等，不删库存/结果/二进制hash。evidence/mac-appgroup-coverage-split-proof.json记录可复核关系；原完整日志与原JSON保留SSD。产品输入未改，无需重打包。修复后本地size guard与文档增量审查通过再push；GitHub仍须对最终head完成检查和review。

## GitHub审查与交接记录

- 55fad首次请求于2026-10-29T03:43:15Z，曾running；后因证据大小修复被新head取代，不作为最终通过结果。
- 7f6bdc416请求 [6487381088](https://github.com/o1xhack/CodexBar-Mobile/pull/225#issuecomment-6487381088)，03:49:42Z接受；03:51:11Z机器人 [clean receipt](https://github.com/o1xhack/CodexBar-Mobile/pull/225#issuecomment-6487407087) 精确绑定该commit，summary completed/has_findings=false；reviewThreads为空，无需伪造回复或Resolve。
- Fast Checks [40814283730](https://github.com/o1xhack/CodexBar-Mobile/actions/runs/40814283730) success（3m8s）。前次文件大小failure已修复，保留证据。
- 此收尾提交只改Research状态/记录，不改shipping inputs。按规范本地增量审查后push，再对最终head运行远端review和check_pr_review_gate.sh；最终回执/gate保存在本PR评论及SSD，避免为了写入自己的SHA反复生成提交。Research done表示候选工作记录完成，不代替最终门禁，不代表public release。
- 最终交接须分别决定PR合并、Mac live及iOS的TestFlight/App Review/public阶段。未授权merge/auto-merge、tag/live/feed、iOS上传、CloudKit deploy；issues继续open。重型Final CI尚未运行，授权merge后、public前必须验证。
