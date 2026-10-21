# Mac draft release 证据

Status: `done`（仅 draft；live release、tag、push 未授权）。

## 发布方案

- 目标 Mac 0.79.0.1 / BUILD_NUMBER 172.1 / companion 2.10.0；Sparkle 172.1.2.10.0，拟用 tag v0.79.0.1-mobile.2.10.0。
- iOS 3.1.0 (246) 是本轮准备版本，未上传/发布，不能提前写成已发布的 Mac companion。已有 version.env 文档中的旧三段规则示例与四段规则冲突时，遵循顶部明确的四段规则。
- 使用 fork `Scripts/release.sh --draft-no-tag-push`。它在 origin 创建 Draft 和上传 zip/dSYM，跳过 tag 创建/推送及 appcast publication；目标 mobile-dev 只作 GitHub 已知 ref 占位，release notes 明确记录本地源码 SHA。今后用户授权发布前须改成 clean-reviewed 的正式提交。
- 所有签名/公证 staging、widget Xcode builds、大型 logs 使用 /Volumes/StudioSSD/Developer/BuildScratch/CodexBar/v079/；不输出 credential 值。
- Mac product inputs 修改后必须重打包，不能把先前 draft 的二进制当成后续修复已生效。
- 不调用 finalize，不创建 tag、不 push、不 merge、不上传 TestFlight。#196 维持 open，按仓库规则仅 live release 后才能关闭。

## 当前完成证据

- evidence/version-plan.json：数字比较确认新 Sparkle 大于当前 appcast 所有条目。
- 签名 appcast 候选已生成并验证；根 appcast 已恢复已发布 feed 原字节，未发布新 feed。

## 包验收项目（均已完成，具体证据见下）

- 实包CFBundleShortVersionString/CFBundleVersion/CodexGitCommit、universal app与CLI的arm64/x86_64架构、dSYM UUID对应。
- 签名严格校验、公证Accepted+staple、distribution policy、隔离HOME/禁用Keychain/禁止网络的resource与launch smoke。
- ZIP/dSYM SHA256与draft asset digest/size对应；draft published_at=null、draft=true，local与origin refs/tags均不存在。
- 使用完整下载tag URL在SSD生成签名appcast候选，保存候选证据后恢复已发布feed原字节，不发布候选feed。校验candidate enclosure长度、URL、edSignature与真实ZIP，并再次检查Sparkle单调递增。

## 首轮打包失败与恢复

`v079-mac-draft.log`：双架构Release与显式SDK产品构建均通过（378.39/373.62/329.01/328.26秒），Widget依赖解析失败：Xcode的SweetCookieKit cached bare repository缺少锁定5b0aead7093a067c61a2b17bfd2b6560fbc71ef3对象。官方远端v0.5.9 annotated tag peel正是该SHA，未更新依赖版本；仅对本轮SSD SourcePackages repository/checkout按锁定SHA fetch补齐缓存。失败时Xcode自动error result落入系统临时目录，已给widget build显式唯一-resultBundlePath到derived_dir/Results，防止重试回退。此轮无签名公证/draft成功声明。

- 独立review确认以上resultBundle修复与增强org矩阵阻塞0。移除sign-and-notarize中未使用产物的重复无SDK前置编译；package_app仍逐arch显式SDK完整build→stage→arch/minos验证，保留ARCH_LIST供dSYM处理，不跳过构建/校验。package signing(16 entitlements/profile cases)、product path/SDK metadata、Info.plist回归均通过。

## 实包验收完成

- `v079-mac-draft-retry.log` exit0；完整lint通过；显式SDK arm64/x86_64 build 328.77/325.51秒，Widget双架构Xcode build通过，结果包在本轮SSD widget-derived/.../Results/。
- Apple notarization `d8371ece-9515-45e2-9af6-79aa9bb032e3`：Accepted，staple+validate、distribution policy均通过；隔离HOME、禁止网络/Keychain、checkout不可读条件下，helper CLI、symlink CLI、app资源probe及app存活2秒通过。
- Draft：https://github.com/o1xhack/CodexBar-Mobile/releases/tag/untagged-3b25e34f5a865b165d53 。isDraft=true / published_at=null，tag_name为拟用版本；本地和origin实际tag均不存在。
- 源码 `4f66415b1ed50fa3327ad363365a21242f530287`；实包Info.plist对应0.79.0.1 / 172.1.2.10.0，app/CLI/widget均包含arm64+x86_64，dSYM UUID逐arch对应，codesign严格验证、spctl、stapler通过，CloudKit entitlement明确Production。
- ZIP 90,773,292 bytes / SHA256 e060a4a6095369b0187dfece9bab9a98efb11626da27d8c062d6863d956f7c5d；dSYM ZIP 72,676,818 bytes / SHA256 06655d13f4112fff5a7c101fb8ed8c4d83bb44eaaaf27a77304a2d96f8c59dee；GitHub asset digest/size完全对应。
- 本地candidate appcast使用完整tag download URL，172.1.2.10.0单调递增、enclosure长度与真实ZIP对应，EdDSA验证exit0；原appcast已恢复原字节，无feed publication。
- 小型可复核证据见evidence/mac-draft-verification.json、mac-draft-release.json、appcast-candidate.xml、appcast-verification.json；详细验包日志在BuildScratch/v079/mac-qa/verification.log。

## PR修复后的artifact刷新

前述4f实包是历史成功证据；PR修复修改了Gemini插件和sync产品输入，必须刷新同一个draft。ca源第一次刷新中双archRelease通过，错误使用未带CODEXBAR_前缀的widget root导致新缓存缺锁定SweetCookieKit commit；改为已验证的CODEXBAR_WIDGET_DERIVED_DATA_ROOT。之后独立审查发现Gemini Web身份P1，主动中断该旧源重试并终止其本任务编译子进程，不将未完成产物上传。下一次完整签名/公证与asset替换将绑定修复后的正式commit，保留原draft URL、无tag/live/feed publication。
