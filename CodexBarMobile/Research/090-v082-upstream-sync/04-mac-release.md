# 候选产物与签名

状态：`in-progress`。iOS本地Archive已验证；Mac正式签名/公证/no-tag draft仍待最终quiet lint/build。无live release、tag、appcast发布、iOS export/upload。

## 固定版本

Mac0.82.0.1 / BUILD175.1 / Mobile3.2.0 / Sparkle175.1.3.2.0；draft逻辑tag v0.82.0.1-mobile.3.2.0，不创建/推送tag。Mac companion使用ASC已交付3.2.0(260)，iOS待交付版本独立3.3.0(261)；正式发布前按versioning重新核对实际顺序，不制造多个用户版本。

## iOS本地Archive（完成）

- 源码：a36c6b110da3d994c8bba6bbcfa777627efa42ff，Archive前assert所有iOS/Shared输入与该commit一致。完整输入manifest与生成project hash见evidence/ios-archive-source-manifest.json和ios-archive-verified.json。
- 命令：xcodegen generate后，xcodebuild archive -project CodexBarMobile.xcodeproj -scheme CodexBarMobile -configuration Release -destination generic/platform=iOS -jobs2 -allowProvisioningUpdates -packageAuthorizationProvider netrc；derived data、archive、xcresult均在/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/Upstream082下。
- 产物：CodexBarMobile-3.3.0-261.xcarchive；ios-local-archive.log/xcresult，ARCHIVE SUCCEEDED。
- App、Push、WidgetOptions、Widgets、CodexBarSync.framework五bundle均3.3.0/261；codesign --verify --deep --strict通过，五者signature TeamIdentifier均3TUERHN53E。
- App、Push、Widgets签名CloudKit environment=Production；WidgetOptions仅本地AppGroup选项，无CloudKit调用；framework没有独立execution entitlements。不能把无CloudKit角色的空entitlement误写成Development。
- App/扩展四语言lproj均存在。App与dSYM UUID DF54F795-6609-3905-B631-FBBAD26A1839匹配。主App binary SHA256 5df57e470d2bcc3875e3f68991b0ecad983187e25d6703e7861154fc04eed456；完整archive逐文件manifest的解析后JSON序列化SHA256为1d58f444ffbe377fb4591f9b01bf5c43f8bc975d2c5984ce2d051f46d9801e0e；实际manifest文件SHA256为21fd11e0bd8a300751ba60b8d217cc6d50680fcfc77c894b625a8a57af467109，算法见verified JSON，避免将两种编码混称文件hash。
- 当前是Apple Development本地签名、get-task-allow=true；不是App Store/TestFlight分发包。未export/上传/提交审核；将来分发需获相应授权并按当时reviewed inputs及签名方式重新核对。

## Mac候选（待完成）

最初sign-and-notarize在签名/公证前因lint纯排版修复取消，owned进程/编译孤儿已终止，private notarization temp副本无遗留；不把该次当成功。

后续从已冻结source重跑真实签名公证、ZIP/dSYM UUID、Production、Gatekeeper与isolated launch smoke；再用release.sh --draft-no-tag-push创建draft并核对附件digest，记录实际source SHA和placeholder target mobile-dev。候选appcast仅在scratch生成/签名验证，不修改/发布仓库feed。任何review修复改变artifact inputs就重建相应产物。
