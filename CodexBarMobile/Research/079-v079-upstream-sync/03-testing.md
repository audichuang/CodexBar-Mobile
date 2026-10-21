# 测试与兼容证据

Status: `done`（本地验收完成；16组合均为有边界的替代验证，无实体同步通过声明）。

## 最终结果

| Gate | 结果与证据 |
|---|---|
| Mac build / packaged regression | PASS：arm64+x86_64 显式SDK Release，Widget双架构；实包签名、公证、staple、launch/resource probes、dSYM UUID全部通过。04记录细节。 |
| Mac完整单测 | PASS：1791 selections /160 groups，160组first-pass，0失败/重试/超时；`v079-all-tests-acceptance.log`，672.4秒。 |
| 最终完整lint | PASS：PR修复后的`v079-pr199-r1-lint.log` exit0，3143文件0 SwiftLint violations；portable/CI/README/release guards、SwiftFormat、JS/TS、parser hash/revision、四语catalog、436个iOS源key通过。 |
| iOS完整单测及Widget回归 | PASS：PR修复后的`v079-pr199-r1-ios.log` / `pr199-r1-ios.xcresult`，1152 Swift Testing /72 suites，67 XCTest，0失败；包含WidgetSnapshotBuilder、WidgetRenderMatrix和本轮所有SwiftData/ledger/details用例。 |
| iOS设备Release build | PASS：generic/platform=iOS Release，CODE_SIGNING_ALLOWED=NO；PR修复后的`v079-pr199-r1-ios-release.log` / `pr199-r1-ios-release.xcresult`。主app及3个extension的实产物均3.1.0 (246)。未archive/upload。 |
| iOS引导交互 | PASS：Duo模拟器两条XCUITest，Duo27.1和iOS26.5均通过，首次notes→Setup→Continue、同版本重启不重复展示、Demo跳过notes；`v079-ios-intro-ui.log` / `ios-intro-ui.xcresult`。 |
| 四语/深浅色/辅助字号视觉 | PASS：生产details/full+teaser四语×Light/Dark共8图，日文accessibility3另1图，最终逐张目视验收。第一版大字号拆行已改竖排并复跑。证据`evidence/ios-validation.json`绑定截图SHA256。 |
| Mac draft与appcast候选 | PASS：04链接与digest/size/source/签名证据；仅draft，原发布feed未改。 |
| CloudKit Production schema | NO_DEPLOY：见下；未执行live schema export/写入。 |
| 2Mac×2iPhone gate | COMPLETE WITH SUBSTITUTIONS：16/16列出，64读取和32真实old/new consumer合并进程全部通过；不是16实体PASS。 |
| 循环review | 本地阻塞0，详见05；未创建PR，未替代未来GitHub exact-head gate。 |

日志根目录：`/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/`；xcresult、渲染附件与临时fixture位于其`v079/`子目录。轻量机器可读证据保存在本目录evidence。

## 命令与源码绑定

- Mac：`TMPDIR=.../v079/tmp bash Scripts/test.sh --direct-workers 4`；`Scripts/lint.sh lint`。全量测试时源码固定，审查tree `8f3b05e6f4f9151b0571a2f040e569206fa57bf2`。之后发布脚本的resultBundle路径/重复编译修复通过定向回归、独立review和完整实包流程；Mac产品输入自`4f66415b1ed50fa3327ad363365a21242f530287`起未变化。
- iOS：`DEVELOPER_DIR=/Volumes/StudioSSD/Developer/Xcode/Xcode-27.1-RC.app/Contents/Developer`，27.1 RC /27A9275；无安装或全局xcode-select变更。`xcodebuild -project CodexBarMobile/CodexBarMobile.xcodeproj -scheme CodexBarMobile -destination 'platform=iOS Simulator,id=FA6BFB39-3400-472B-8ED0-CD10A87F629E' -derivedDataPath .../v079/ios-derived -resultBundlePath .../v079/ios-full-final.xcresult -parallel-testing-enabled NO -only-testing:CodexBarMobileTests CODE_SIGNING_ALLOWED=NO test`。
- UI使用相同项目/destination/derivedData，仅选择`testVersionUpdateShowsReleaseNotesAndSetupGuideOnDemand`和`testChoosingDemoFromSetupGuideDismissesFirstLaunchReleaseNotes`，结果写入独立`ios-intro-ui.xcresult`。
- Release改destination为`generic/platform=iOS`、configuration Release、独立`ios-release`派生目录及result；全程SSD、无签名上传。
- iOS最终测试源码与独立review tree `beb4dc146badfd207830acdd9eccf6647e542877`一致；之后仅补Research证据。`ios-validation.json`记录关键源SHA256、结果路径、截图hash；frozen manifest逐文件绑定实际编译输入，newCommit是运行时Git HEAD而非声称未提交改动已在其中。

## CloudKit Production schema 审计

- 对比最近published fork tag `v0.76.0.2-mobile.2.10.0`，Shared/iCloud/CloudConstants.swift零diff、payloadVersion仍1；recordType/直接字段/index/predicate/subscription无新增。
- Row.severity是现有opaque JSON内可选字段；adapter更多既有record实例，新provider是状态zone的运行时实例，原88项订阅ID前缀不变，尾追加到90项/270zones。
- 实包Mac entitlement与iOS源码entitlement均显式Production；无需Dashboard deploy，结论NO_DEPLOY。代码审计未冒称live schema export或跨设备写入验证。

## 2 Mac × 2 iPhone 兼容矩阵

- old Mac：published0.76.0.2；old Shared/consumer从该tag冻结，mobile-dev3.0.0 Shared与其零diff。new为本轮最终工作源码。
- CoreDevice inventory有两台iPhone tunnel connected，另一台unavailable；本轮没有可独立切换old/new的两台Mac+两台iPhone完整环境，因此全部substituted，没有实体PASS。
- `tools/check_frozen_wire.py --help`列出可复跑参数。最终运行scratch为`.../v079/compat-final`，日志`v079-compat-final.log` exit0：16 masks、64独立读取/roundtrip、32双writer正反顺序真实old/new merger进程。
- fixture覆盖新provider、Gemini窗口、Claude多账号/独立成本owner/clear分类、unknown severity、有效Munito同org跨Mac去重和同名异org分离、缺ID设备fallback。`evidence/matrix-wire.json`与`frozen-source-manifest.json`为最终证据；此前org-only矩阵已被最终矩阵覆盖。

| Case | Mac A | Mac B | iPhone A | iPhone B | Result | Evidence | Notes |
|---:|---|---|---|---|---|---|---|
| 1 | old | old | old | old | substituted | evidence/matrix-wire.json mask=0；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 |
| 2 | old | old | old | new | substituted | evidence/matrix-wire.json mask=1；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 |
| 3 | old | old | new | old | substituted | evidence/matrix-wire.json mask=2；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 |
| 4 | old | old | new | new | substituted | evidence/matrix-wire.json mask=3；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 |
| 5 | old | new | old | old | substituted | evidence/matrix-wire.json mask=4；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 旧 iOS 可能多显示一张无额度 Claude 本地成本卡；新 metadata 被忽略但基础金额/额度可读。 |
| 6 | old | new | old | new | substituted | evidence/matrix-wire.json mask=5；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 旧 iOS 可能多显示一张无额度 Claude 本地成本卡；新 metadata 被忽略但基础金额/额度可读。 |
| 7 | old | new | new | old | substituted | evidence/matrix-wire.json mask=6；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 旧 iOS 可能多显示一张无额度 Claude 本地成本卡；新 metadata 被忽略但基础金额/额度可读。 |
| 8 | old | new | new | new | substituted | evidence/matrix-wire.json mask=7；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 |
| 9 | new | old | old | old | substituted | evidence/matrix-wire.json mask=8；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 旧 iOS 可能多显示一张无额度 Claude 本地成本卡；新 metadata 被忽略但基础金额/额度可读。 |
| 10 | new | old | old | new | substituted | evidence/matrix-wire.json mask=9；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 旧 iOS 可能多显示一张无额度 Claude 本地成本卡；新 metadata 被忽略但基础金额/额度可读。 |
| 11 | new | old | new | old | substituted | evidence/matrix-wire.json mask=10；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 旧 iOS 可能多显示一张无额度 Claude 本地成本卡；新 metadata 被忽略但基础金额/额度可读。 |
| 12 | new | old | new | new | substituted | evidence/matrix-wire.json mask=11；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 |
| 13 | new | new | old | old | substituted | evidence/matrix-wire.json mask=12；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 旧 iOS 可能多显示一张无额度 Claude 本地成本卡；新 metadata 被忽略但基础金额/额度可读。 |
| 14 | new | new | old | new | substituted | evidence/matrix-wire.json mask=13；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 旧 iOS 可能多显示一张无额度 Claude 本地成本卡；新 metadata 被忽略但基础金额/额度可读。 |
| 15 | new | new | new | old | substituted | evidence/matrix-wire.json mask=14；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 旧 iOS 可能多显示一张无额度 Claude 本地成本卡；新 metadata 被忽略但基础金额/额度可读。 |
| 16 | new | new | new | new | substituted | evidence/matrix-wire.json mask=15；4 reads + 2 merges 均 exit0 | CloudKit/APNs/SwiftData/UI 未实测。 |


## 替代验证的剩余风险

- 冻结wire/consumer不执行CloudKit/APNs、真实reader缓存、后台或SwiftData，因此不能证明两个iPhone的网络收敛、静默推送、系统cache清理、真实账号权限与旧UI呈现。SwiftData迁移/ledger/widget使用新iOS实际实现的in-memory生产入口测试补足，仍不能替代实体收敛。
- old iOS不识别独立Claude cost owner隐藏规则，可能多一张无额度成本卡；旧CWL可能在clear后回填以前combined历史。Mac从未发送目录scoped金额，防止把不同目录daily混入machine历史。新iOS对明确机器撤回抑制展示、不删除原始ledger，普通nil与账号disown保留fallback。
- JSON时间以秒编码。同一秒内快速切换所有权可能并列；独立owner有确定性tie优先、旧record两次成功publication后清理，但不保证亚秒排序/瞬时UI消失。下一次完整publication可收敛，未声称实时实体验证。
- 当前Duo XCUITest的两张屏幕附件全黑；simctl复核同样全黑，open_sim工具返回成功也未改善。逻辑交互断言与9张生产视图ImageRenderer证据独立成立，黑图不作视觉PASS。随后在独立iOS26.5模拟器（F7DF92DB-2C2F-4475-8F19-615225381DB7）重复两条UI测试，2/2通过、41.47秒，`v079-ios-intro-ui-265.log` / `ios-intro-ui-265.xcresult`。正常导出两张notes/setup系统截图并逐张目视核对，补足完整引导界面证据；不扩大为Duo framebuffer修复。
- 上游tag checks快照27success/3skipped/0failure，不满足严格“全部heavy CI成功”复用条件。本轮无push/远端CI；未来获准merge时Final CI须重新判断，必要时运行fork矩阵。GitHubPR审查也尚未运行。
- 没有live provider probe、cookie import、真实Keychain读取或真实账号历史金额QA；使用标准Scripts/test.sh安全环境、stubs和合成数据。

## 关键回归与失败修复记录

- Mac定向259tests/18suites+11dashboard；身份/架构97tests/4suites；mock75/4；策略身份30/2均通过。覆盖parser前驱hash原地迁移、scope切换、tcr无active、slot删账号两周期、组织ID规范化/同org去重、quota订阅尾追加及旧功能。
- iOS实际SwiftDataBridge→ledger→Insights/TokenActivity/WidgetProjection验证：两Mac各两quota+一个owner不重复；40天ledger-only历史迁移；clear一台不影响另一台；保留预算；combined→adapter→combined；reverse clear；冷启动adapter账号clear不撤回机器history；幂等、普通nil、别名和unknown详情兼容。
- 首次全量第28组暴露Keychain产品gate与测试安全开关混用，增加已有task override固定测试产品状态，底层仍禁止真实SecItem；第二次第109组发现mock计数未更新，补116/121/111；第三次第130组架构guard缺具体reason/旧anchor/fingerprint，修真实合同并审计清单。失败日志均保留，不计PASS；最终160组first-pass覆盖这些修复。14known issues为故意触发expectation的脱敏fixture，不是产品失败。
- 初次lint需provider文档生成和social.png缓存token同步，已单独事实审计、保持fork入口并通过最终lint；没有用改hash绕过README规则。
- Mac首次draft的锁定依赖缓存缺对象、Xcode隐式result路径问题已修，精确版本未变，最终显式SDK打包/签名公证通过，详04。
- iOS先有1150Swift+66XCTest成功，独立review又补机器clear/账号disown区分和冷启动测试；最终1151+66全部通过。第一版大字号截图过密，改辅助字号竖排及浅色告警色后，最终9图重新渲染目视检查。

## PR #199 首轮审查修复与复测

用户随后授权push/PR及循环review。分支已推送、PR面向mobile-dev；初始head8de535ee3。Codex指出Vercel personal-budget新增两条稳定语义文案未进入iOS本地化allowlist/catalog，造成中文/日文仍为英文（discussion_r4342646390）。修复只增加既有第一方语义路由的两条label与四语条目，插件自定义文案保持原样，不改wire/schema/Mac产品输入。

复测：1152SwiftTesting/72suites +67XCTest，0失败；全量含新四语参数化路由测试和Vercel完整/teaser实际生产视图ImageRenderer。新增四张截图逐张目视验收，无缺翻译/裁切；通用设备Release构建与完整lint均exit0。轻量证据见evidence/pr199-round1.json；Mac draft/原16组合可复用，因为Mac产品/Shared模型/merger均无变动。已有3.1同版本Vercel更新说明覆盖该功能，未重复追加release block；开发者CHANGELOG补充具体翻译修复。外部CR终态以PR的当前head审查与check_pr_review_gate.sh为准。

## PR #199 第二轮：Gemini / Vercel 窗口语义

Codex在head6fb718610指出Gemini Web五小时/每周窗口未携带label，sync退回CLI的Pro/Flash。修复在TypeScript插件源给两个真实窗口显式label，经仓库生成器同步JS，复用mapper/sync已存在的显式label优先；不改全局metadata。独立review复核同类新增动态window，另补Vercel Personal budget的窗口翻译入口。CLI模型名不变，原3.1更新说明已覆盖Gemini/Vercel功能，不新建版本或重复release block。

- `v079-pr199-r2-focused.log`：59 tests /3 suites，exit0；含双JS engine真实plugin→snapshot→MockSyncPusher→JSON读回，覆盖双窗口/仅五小时/仅每周、CLI Pro/Flash/Flash Lite，及架构守卫。
- `v079-pr199-r2-ios.log`：1153SwiftTesting/72suites +67XCTest，全通过；包括Gemini四语时间标签和CLI原样、Vercel四语窗口名回归。`pr199-r2-ios.xcresult`。
- `v079-pr199-r2-ios-release.log`：generic iOS Release BUILD SUCCEEDED；`v079-pr199-r2-lint.log`完整lint exit0，0 violations、四语/source436keys/parser guards通过。
- `v079-pr199-r2-compat.log`：增强Gemini old Pro/Flash vs new5-hour/Weekly fixture后16/16，64reads/32consumer merges通过，已更新evidence的matrix与source manifest。仍为substituted，不代表实体收敛。
- 独立静态复审当前TS/JS、桥接测试与窗口翻译diff无阻塞；生成JS与focused编译输入字节一致。
- Mac完整回归此时运行中（1791selections/160groups），不将未完成运行记PASS。插件属于Mac产品输入，旧4f draft尚不能代表此修复；将重新打包、签名公证及验包后更新04/evidence。
