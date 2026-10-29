# 审查与 PR

状态：`in-progress`；完整本地源码审查已完成两轮，当前无未解决源码 finding。最终测试、签名产物与冻结提交仍须补审；未创建本轮 PR，未 push/merge/tag。

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
