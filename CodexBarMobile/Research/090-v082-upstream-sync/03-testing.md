# 测试、兼容与证据

状态：`in-progress`（等待最终本地与PR review）。历史失败、修复和当时待验状态保留，以本段为当前结论。

## 最终候选验收（2026-10-28）

当前产品源码：`18ebb97272a68853473b3c3c565fc56f719901e2`，后续仅补文档/证据。Mac Group/CLI 修复后重新构建、公证与校验；旧草稿包已hold，最终附件替换结果见04。iOS原353项Archive输入重新逐项SHA256核对不变（evidence/ios-archive-final-input-equivalence.json），保留a36来源Archive。

- 最终Mac受影响128 selections/43组全部首遍PASS，0fail/timeout/retry；与成本修复97项及原完整gate1620项去重，覆盖1845 selections/16194 method identifiers。123个条件XCTest skip及Swift Testing opt-in early-return限制保留；不是单一最终binary全量body通过。见evidence/mac-appgroup-final-coverage-review.md与proof。
- `mac-appgroup-full-lint.log`完整lint与`mac-appgroup-final-build.log`的swift build --jobs4通过；SwiftLint 3211文件0违规，4语言533keys、parser24/hash、CI/fork guards通过。16个打包合同及timestamp retry stub通过。
- 真实Developer ID签名QA正负控：独立nonce group的声明成员可open，无成员EPERM；containerURL非nil不能证明授权。未操作用户业务容器，任务QA容器已清理。最终App/CLI runtime group均与Widget签名Group一致，生产包本身单独验证。
- Mac最终双架构App/CLI/Watchdog/Widget均Developer ID、hardened runtime、minOS14.0；App与dSYM双架构UUID一致。公证`343e9fc0-4ac2-4f2e-9300-c0492953d430` Accepted，stapler、distribution policy、隔离启动通过。
- Sparkle175.1.3.2.0单调递增；最终ZIP长度92810809、Ed25519以及实际App内SUPublicEDKey客户端校验均通过。仅scratch候选appcast，仓库feed无修改。
- iOS全量1278 Swift Testing/85 suites +75 XCTest及后续150 tests/6 suites通过；普通iPhone/iPad、Duo实际内外屏横竖、partial和跨折叠操作、严格SpringBoard Widget及四语原生渲染证据继续有效。
- 16组合全部为 **substituted**（64 reads/32真实冻结consumer merges），没有实体双Mac/双iPhone CloudKit/APNs/缓存收敛实测。CloudKit结论 **NO_DEPLOY**；本轮Group仅Mac本地共享容器，iOS/Shared wire不变。
- GitHub PR review仍待完成；不把本地测试或notary结果当远端review通过。未merge/tag/live/feed发布或iOS上传。后续Final CI在授权合并后执行。

## 旧/新定义

- old Mac：最近published `v0.79.0.1-mobile.3.1.0`；old iOS：已发布3.2.0 (260)，ASC version→build关系只读回读绑定build ID c0e4d298-e201-471e-8625-1e79a667eb1f；源码使用已交付3.2基线bdfb51085（未重新下载商店二进制验证）。
- new Mac：本轮最终reviewed候选0.82.0.1；new iOS：3.3.0 (261)。实际commit/artifact hash将在完成后写入。
- 2 Mac × 2 iPhone gate适用：新增同步显示数据与optional metadata。

| Case | Mac A | Mac B | iPhone A | iPhone B | 结果 | 证据/风险 |
| ---: | --- | --- | --- | --- | --- | --- |
| 1 | old | old | old | old | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 2 | old | old | old | new | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 3 | old | old | new | old | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 4 | old | old | new | new | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 5 | old | new | old | old | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 6 | old | new | old | new | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 7 | old | new | new | old | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 8 | old | new | new | new | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 9 | new | old | old | old | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 10 | new | old | old | new | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 11 | new | old | new | old | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 12 | new | old | new | new | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 13 | new | new | old | old | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 14 | new | new | old | new | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 15 | new | new | new | old | substituted | frozen old/new model + consumer；见下方范围与风险 |
| 16 | new | new | new | new | substituted | frozen old/new model + consumer；见下方范围与风险 |

## 本机预检

StudioSSD身份与路径检查通过；Xcode27.1/27A9275，SDK iOS27.1/macOS27.0。ASC只读确认3.2.0已发布、build260 VALID；未写入ASC、未执行Production schema export/deploy。没有以此证明真实CloudKit收敛或Duo通过。


## 已执行验证

| 项目 | 当前证据 |
| --- | --- |
| Mac compile | `mac-build-5.log`：swift build -j6，51.34秒；源码2f4e6a4ba对应的Mac/Shared产品输入 |
| iOS focused | `ios-focused-2.xcresult` / log：75 tests / 5 suites，0失败；含新metadata容错、daily target、provider订阅、WidgetSnapshotBuilder与旧详情回归 |
| 四语 | `ios-i18n.log`：所有xcstrings翻译完整，533个source keys齐全 |
| 16组合替代 | 16 masks、64独立reader读取、32 old/new真实pure consumer合并进程，全部验证通过；source/hash和逐组合操作见evidence/compatibility-*.json |

矩阵的old Shared来自当前已交付3.2源基线bdfb51085，与published Mac0.79.0.1的Shared逐文件diff为零；旧consumer来自同一3.2基线。两Mac分别mac-a/mac-b并提供独立device keys；两个phone分别执行独立reader进程，每次验证旧/新反向解码、roundtrip、optional quota units/expectedUsed、append-only订阅与两writer正反序。新provider无验证身份时按device保留两份，既有稳定Claude身份合并并取最新观察。

**为什么substituted：** 本轮本机没有可组织的2Mac×2iPhone四设备同步环境。替代的是生产模型与合并器的离线执行，不是实体设备CloudKit链路。未验证实际CK写入/推送投递、两台iPhone持久缓存收敛/SwiftData迁移、联网恢复和物理折叠。对应iOS store、cache、UI测试将另行记录；这些结果不能回写为16实体PASS。发现失败仍须修复并复跑。

## 第二阶段验证与局部review

- Mac focused：mac-focused.log，76 tests /9 suites全部通过；含4新provider、月target、Kimi、detail pace、mock回归。
- Mac bridge/Command Code：mac-bridge-3.log，105 tests /9 suites全部通过（源码在测试期间仍有Soniox周期/observedAt测试增强，最终由全量gate重新覆盖）。此前bridge-2因测试对非optional数组误用?.编译失败，已修，保留失败日志。
- iOS full unit：ios-full-unit.xcresult，1272 Swift Testing tests /84 suites通过，xcodebuild TEST EXECUTE SUCCEEDED；源对应新增功能首版，后续locale/AX修复单独复测。
- iOS新render专项：ios-v082-render.xcresult Passed，11 test definitions（含参数化共17runs），0fail；导出9张图片。图片审查发现ImageRenderer的ProgressView黄条是unsupported native control占位，撤回它对进度外观的证明；该组只能支持文本/计算测试。新UIHostingController窗口渲染复测启动为ios-v082-native-render.xcresult，结果待收拢。
- 同组图片暴露Kimi第一方allowlist缺失，Other features等未翻译，已补；日文AX3下预算金额及长quota标题拥挤，补自适应排布。新native图及交互仍需审查，不能沿用旧图通过结论。
- README局部独立审查0阻塞后有意适配已提交c7b11c28e。Mac/Shared局部review发现3项并修复：Soniox双金额通道、插件三槽标题、Command Code账号catalog；后者skip-build实测原失败已留review-token-catalog.log。报告在evidence，不替代最终完整candidate review。
- 全量SwiftLint原发现多项（主要是新测试参数格式、上游长文件/type）；未放宽规则，原行为拆CurrencyGroup extension和插件fixture helper，修复6个文件的SwiftLint复测0violations。完整lint-4与mac-full-tests仍在运行。
- CloudKit code audit：NO_DEPLOY，见evidence/cloudkit-code-audit.md；当前未export/deploy，signed包Production验证待产物。

### 原生设备进度（未验收）

本轮专用Duo27.1 `44FF07DE-FAD8-4670-B9D8-35542A3FE199` 已创建/boot，sim-use preflight三项通过。Device Hub Computer Use两次getApp超时；未重启/清空共享设备或其他任务进程。实际四姿态与跨姿态action尚未通过；不以boot或display枚举代替验收。普通iPhone QA为C4943B97-C088-4DD5-9EAF-A98110E7AE77，27.0。

## 后续待收拢（2026-10-28）

- 第二轮iOS局部审查4项：units、Kimi reader expiry/locale、动态gift名、Copilot无duration月份。修复已进入工作区，专项与compatibility-2正在执行；旧16组合报告没有expiresAt字段，尚不能证明最终wire完成。
- ios-v082-native-render.xcresult已成功，真实hosting替代黄条占位；之后又增加units/Kimi expiry与Copilot，当前新验证ios-v082-kimi-ui.xcresult，含普通iPhone导航、Summary点卡返回、Cost分享草稿旋转/取消。未提前标通过。
- lint-4失败不是产品格式：test_swift_test_process_cleanup的timeout-stubborn drain超过5秒及timeout-session fixture readiness超过10秒；保留原始trace，须诊断/复测，不当已知flake跳过。
- Mac full仍在进程中；AntigravityLocalScan 60000-row snapshot coverage/tokens首轮失败，后续runner重试与根因待定位。
- Device Hub经Computer Use native Force Quit恢复尝试后getApp仍超时；已核实真实path/版本，但fullpath getApp使CUA kernel超时重置，随后getState初始化也超时。没有收到有效Duo姿态证据，不冒充通过。用户要求代理自行使用Computer Use，后续代理继续处理，不要求用户手动操作。

## 收拢更新：locale、wire 与原生 Duo（2026-10-28 14:25 PDT）

- `ios-v082-kimi-ui.xcresult`：Passed，16 definitions /22 runs、0 failure、runtimeWarnings=[]；含四语units/Kimi reader expiry/metadata/native hosting render，以及普通iPhone导航、Summary点卡返回保留筛选、Cost分享草稿旋转/取消。新截图进度控件正常；不再使用ImageRenderer黄色占位作为视觉证据。EN light与JA AX3已人工查看，其他截图仍需收拢。
- `compatibility-2.log`：16 masks /64 reader reads /32 old/new pure consumer merges全部通过，已将最终包含expiresAt的source manifest复制至evidence。16行仍全部为substituted；不声称CloudKit/APNs/实体缓存收敛通过。
- `lint-5.log`完整lint退出0。随后增加大型fixture显式SSD临时目录与UI手势诊断，最终release lint仍将重跑；不放宽任何lint/test规则。
- `mac-review-fixes-2.log`真实失败：383 tests /38 suites /31 issues，批量MainActor readiness超时。独立同二进制串行复现47 tests /6 suites全通过（6.378s），含主要失败路径及全部7项V082 bridge；报告在evidence/mac-spend-readiness-review.md。完整worker1 gate `mac-full-tests-2.log`进行中，未当作全量通过。
- 原Mac全量与lint4失败的隔离诊断见evidence/mac-test-failure-review.md；没有改变生产安全期限或终止其他任务进程。
- Duo Computer Use恢复并实际展开内屏，公开display截图为2007×2853；原生旋转后曾取得2853×2007。`duo-inner-landscape.xcresult` Summary严格viewport验证通过；内屏portrait Summary严格viewport及点击返回保留filter已通过。
- `duo-inner-portrait.xcresult` Cost/share case失败，xcodebuild测试结束后收尾卡住约13分钟，向本任务owned pid50403发送SIGINT后保留finalized结果。独立读取Synthesized Event发现成功点击displayID=3/window669×951，但全部app.swipeUp发到inactive outer displayID=1/window0×0；这是手势路由错误的直接证据，尚未证明页面滚动通过。测试现改为真实scroll ancestor/window裁剪后的手势坐标，并捕获所有XCUIScreen；待复测实际位移/控件可达，不能直接忽略失败。
- CUA原生AX姿态控制可用；Mac坐标click目前返回noWindowsAvailable；sim-use inner hierarchy空，未用这些命令回执冒充交互PASS。
- Todoist本轮任务`6hrVCGRx5hMf69h2`位于In Progress；候选未完成，无PR、draft或Archive完成声明。

### Duo 手势修复后的真实复测

`duo-inner-portrait-routing.xcresult` TEST EXECUTE SUCCEEDED（45.06s）：独立审查4次drag、3次tap均路由活动inner displayID=3。真实内屏截图显示Cost已滚至Daily Spend曲线，Share已露完整Template、Period与Share Image；关闭后Cost分享入口exists断言通过。见evidence/duo-routing-retest-review.md与逐事件json。此结果替代原路由失败case，原失败保留；未扩写为全Duo矩阵已完成。

9张native hosting四语light/dark及JA AX3视觉审查完成，限定范围0新增阻塞；见evidence/v082-render-visual-review.md。完整App语言与真实viewport操作仍分别验证，host环境旧文案不作为整App四语截图证明。

### Mac 全库存续跑与Cursor补修

`mac-full-tests-2.log`完整discovery1845 selections/165groups，前61groups通过后，group62的CostUsageCatchUpCompletionTests归一化fixture失败且一次重试仍失败。原因是fixture原假定实际根在/var或/private/var，SSD路径不满足；生产逻辑未改。首次改成symlink仍失败，因为生产只做lexical ./及/private/var规范化，不解析symlink；保留`mac-cursor-catchup-fixes.log`失败证据。最终使用contained raw `/./`字符串别名，保留不同path与同一标准路径断言。

`mac-cursor-catchup-fixes-2.log`重新编译后29tests/3suites全部通过（3.854s），包含真实Cursor XSubscription两种形状的Weekly/Total和4.47按需消费、zero/capped分流，以及修正后的CatchUp全suite。没有改生产path规范化或放宽安全时限。

完整剩余coverage使用scratch/resume_mac_gate.py：仍调用仓库production discovery、prepare_runtime全method inventory验证、owned process containment及worker1 runtime；仅过滤之前已通过且仍有效的selections。独立review要求将此前已通过但受primary helper抽取影响的AlibabaTokenPlanSyncTests、ClaudeTokenAccountCostTests移入重跑；剩余数量由新discovery计算，保存mac-resume-coverage/runtime.json中的精确集合、全部method inventory、binary SHA256和source fingerprint。首61groups报告仍是失败报告，最终只能把保留证据+新续跑+受影响专项称作“组合证据覆盖完整库存”，不能冒充原log或所有测试都在单一新二进制一次全PASS。续跑当前进行中。

Duo native fold首轮仅接受外屏portrait宽度、第二轮NSPredicate CGRect KVC尺寸未动态匹配实际窗口，均保留失败/取消证据；实际观察到inner951×669→outer678×466，Heatmap草稿仍在，尚未宣称后续操作通过。第三轮改用真实frame getter closure与双维度inner判定，待操作完成。

### 测试收尾：mock、quota catalog 和架构审计

- `mac-mock-final.log`：3 suites /70 tests，1.686秒全部通过。集中补齐Mac集成测试的125 total/115 unique/120 current-ID snapshots；历史计数保留，当前测试名和断言更新，set equality和真实sync写路径断言未删除。
- `mac-full-tests-resume.log`前46groups通过后mock旧断言失败；第二续跑保留1198 selections、执行647/58groups。其前14groups通过后ProviderArchitectureGatekeeper阻塞。精确review见evidence/provider-architecture-review.md；更新5个fingerprint、补4个exact construct，删除Refresh旧occurrence2重复项，保留occurrence1的Codex/DeepSeek四引用审计。未改扫描器、窗口大小或默认allowlist规则。
- 初版review曾建议occurrence2改1，实施脚本在发现两个相同anchor时assert失败，未写入tracked文件；复审查明四引用cluster真实从791跨到820，已纠正报告为仅删除陈旧occurrence2。`mac-architecture-final-2.log`：48 tests /1 suite，9.236秒全部通过。
- 第三续跑保留1366 selections、执行479/44groups；前7groups通过后Mac侧QuotaProviderListTests另两条旧90/270断言失败（iOS同名文件此前已更新）。现统一94/282，集中rg未再发现同类旧provider/mock count断言；90天历史数据等无关fixture未机械替换。专项与最后续跑仍待通过。
- 本轮若干直接swiftformat调用因PATH无该命令而未执行，均不计成功。已改用仓库固定`.build/lint-tools/bin/swiftformat`对24个候选Swift文件执行成功，`git diff --check`随后通过；完整lint仍须执行。

### 原生Duo进一步证据

- `duo-native-fold-3.xcresult` PASS104.696s，独立输入/图片审查证明inner landscape951×669→outer landscape678×466→inner landscape，display3→1→3，外屏草稿范围/模板/Provider保留，取消后仍Codex，展开后fresh Classic草稿可创建。
- `duo-inner-landscape-cost.xcresult`两项PASS、0skip：Cost与分享控件可达、两个Cost窗格独立滚动；见evidence/duo-native-transitions-review.md。
- outer landscape前3轮使用XCUIDevice或错误的启动时机，真实viewport仍portrait；不能当landscape PASS。后续native旋转已使viewport678×466，首个native测试又发现测试误将既有compact-landscape两列合同当三列；审阅SummaryModulePacking/MobileAdaptiveLayout确认产品在短横屏有意保持两列与完整2×2 chart，没有改产品布局。
- `duo-outer-landscape-native-2.xcresult`严格viewport/卡片排布/全宽/native chrome检查与后续Codex filter tap全部PASS26.070s；实际grid/app678×466，expected compact两列。其余outer portrait与partial fold仍待收拢，不能扩写全矩阵完成。

## 最终收拢（2026-10-28 16:03 PDT，继续执行）

- Mac全库存最后续跑`mac-full-tests-resume-4.log`退出0：395 selections/37groups，36组首轮PASS，group26总耗时180秒超时后12个suite各自fresh进程均PASS；没有修改安全期限。与前序保留证据组合覆盖1845 selections，逐集合独立审计进行中。库存含条件skip，不等于全部方法体/可选native证明都执行；亦不冒充一次新二进制全量PASS。
- `mac-final-build.log` swift build PASS8.66秒。`lint-final.log`底层policy/portable检查通过后报SyncCoordinator新调用2条multiline_arguments；已按每行一个参数纯排版修复，逻辑未改，后续focused/build/lint重新核对。首次Mac打包在签名/公证前向已核实owned PGID73104发送TERM取消，未生成候选；从干净commit重跑。
- Duo外屏portrait `duo-outer-portrait.xcresult`3cases PASS；外屏landscape Cost `duo-outer-landscape-cost-native.xcresult`PASS；partial landscape `duo-partial-landscape.xcresult`2cases PASS。最终4bundle/7case审查0fail/0skip/0新增阻塞，实际viewport/输入display与后续action见evidence/duo-final-poses-*.md/json。partial不当作平展，不声称具体折叠角度；Cost标题刚入视口不冒称曲线完整可见，Close后exists无final截图的边界明确保留。
- Widget真实系统setup首轮失败：添加按钮AX查询过窄，且图库首项是Token Activity，不能支持四mode gate。第二轮显式选择本地化CodexBar Widget heading后成功放置真实status小组件（widget-system-setup-2.xcresult PASS53.403s，图有Claude54%/Codex39%）。旧mode gate随后错误长按屏幕中心空白进入jiggle失败；保留失败，没有宣称模式已切换。修正为已视觉确认的左上widget中心，并要求编辑前、选择后、Home Screen及重开配置截图读回；绿色测试本身不证明mode成功。

### 最终收拢续记（2026-10-28 16:45 PDT）

- Mac完整库存组合独立审计已完成：1845 selections/16177 method IDs，无集合遗漏，123 unique XCTest按env条件skip（包含可选native/screenshot/live TTY证明）。首阶段缺持久binary SHA/fullmethod manifest、各阶段多构建hash均在evidence/mac-final-coverage-review.*明确；不冒称最终单binary全部body执行。随后round2产品修复另有102个精确affected selections复测计划（evidence/round2-affected-mac-*），其余1743保留原有效证据，实际新inventory与结果待回填。
- `ios26-final-full-unit.xcresult` TEST_EXECUTE_SUCCEEDED：iOS26.5普通iPhone，75 XCTest/0fail与1278 Swift Testing tests/85suites PASS。包含原生/illustrative render的SDK诊断保留，不把generic尺寸图当Duo本体验收。此前Duo最终unit启动卡在CoreSimulator launch bridge，采样证据保留，取消该owned run并关闭本任务Duo；未作为产品崩溃或PASS。
- `ios26-review-fixes.xcresult`：新增sourceRecorded与merger修复后，150 Swift Testing tests/6suites+1 nativehosting XCTest PASS；后者8.266秒导出9张四语/lightdark/JA AX3图，包含新来源说明。完整ProviderDetailView private switch仍以源码审查证明；拼装caption图不冒充该私有分支的实际导航。
- `ipad-final-navigation.xcresult` TEST_EXECUTE_SUCCEEDED：3PASS/0fail/0skip，iPad13-inch(M5)/iOS27.0。Usage选择/搜索/真实键盘/旋转、Settings详情、Cost分享双列、Summary显式点入back保留filter，独立10图复核见evidence/ipad-widget-evidence-review.*。
- `compatibility-4`全16 masks/64读取/32 old-new真实pure consumer合并进程PASS，现包含sourceRecorded→旧unknown、显式金额0、Mac A recorded/Mac B priced和正反序merge保义。新manifest与matrix已替换为这轮实际工作区hash；全部16行仍substituted，CK/APNs/实体双手机缓存风险不变。
- 真实系统Widget手动native自动化：Overview图→系统Type/Color Style/四mode→TodayCost选择读回→最终HomeScreen今日$19.42/822.0Ktokens，满足canonical最低system gate。中间placeholder、sim-use标签失败与longpress未开菜单不算成功；证据见独立报告。`widget-system-overview-final.xcresult`虽XCTest Passed141.711秒，图始终停编辑面板，属测试假阳性，已撤回Overview/重开成功结论。严格版改真实Type行坐标、实际本地化值、选中读回、关闭面板Type消失和重开值断言；`widget-system-overview-strict.xcresult` TEST_EXECUTE_SUCCEEDED98.354秒，尚待独立图/AX验收，不能只凭exit0回填功能PASS。
- `lint-final-2.log`未通过：process cleanup synthetic success fixture10秒readiness超时，测试记录退出时未ready；未削弱时限。与早先诊断一致，最终全lint须在编译/UI负载结束后串行重跑。当前改动文件pinnedSwiftFormat/SwiftLint与diff检查单列，不冒充全lint。
- review-fix Mac compile初次用系统Python3.9被containment预检正确拒绝；改为Homebrew3.15。随后Core新earlyreturn后switch缺显式return、CLI测试错用CodexBarCLI.liveHistoryLine(实际CLIRenderer)编译失败均已修，失败log保留；当前最终新binary gate运行中，不将编译失败计PASS。

### 冻结与候选核对（2026-10-28 17:20 PDT）

- 源码/测试冻结到a36c6b110da3d994c8bba6bbcfa777627efa42ff。Mac review-fix gate4重编后102 affected selections/19 groups全部PASS，0fail/0timeout/0retry；实际mode为canonical serial SwiftPM fallback而非direct。source/binary proof另存；discovery1611.6秒、execution525.1秒，不隐藏编译成本。新增fixture/native-after-ambient断言的最终freeze delta正在fresh rediscovery+3suite重跑，并比较其余1743 retained selections完整method inventory，无变化才允许沿用旧证据。
- iOS26.5真实普通iPhone navigation与Summary push/back：ios26-final-phone-navigation.xcresult TEST_EXECUTE_SUCCEEDED，2PASS；保留SDK AppEnum to-0.0诊断，不声称runtimeWarnings为空。
- strict Widget8图/2层级已独立确认：真实四mode初始Today Cost勾选→概览选中→Home Claude54/Codex39→重开概览，1PASS0fail0skip。原141秒假阳性仍保留并撤回；报告见ipad-widget-evidence-review。
- JA AX3压缩是测试fixture内容新增caption后固定窗口高度不足；只给诊断stack intrinsic vertical sizing和更高窗口，未修改Budget产品。ios26-render-intrinsic.xcresult PASS38.169秒，9图逐张复查：daily target $17.50完整、四行caption/usage/Kimi/expired gift完整，无黄占位/重叠/裁切。
- iOS本地Release Archive已完成并通过签名/版本/Production/dSYM检查，见04及evidence/ios-archive-verified.json。未上传；签名为本地development。仅关闭本轮task-owned已完成QA的3个普通模拟器，Duo此前在launch诊断后已关闭，未操作其他项目设备。


### 最终源码测试冻结补证

`mac-source-freeze-delta.log`退出0：fresh rediscovery 1845 selections，最终CLICostTests/OpenCodeLocalHistoryPublicationTests/SyncCostIsEstimatedTests53 tests/三suite一组全部通过，0fail/timeout/retry；discovery343.2秒，execution12.5秒。`evidence/mac-source-freeze-inventory.json`保存当前5个test binary SHA及完整16182 method IDs，证明1743 retained selections所含14923 method IDs与已审计旧全库存完全相同。102项受影响测试由gate4独立复测；本次delta补盖最终增加的隔离fixture/native-only cache断言。组合证据的多binary/条件skip局限仍保留。

quiet lint第三次启动未完成：首次非login bash缺node；login bash随后选到Xcode Python3.9，canonical containment预检因缺waitid/WNOWAIT正确拒绝。均不计PASS，未改变检查要求。第四次显式以Homebrew Python3.15及既有node置前重跑，结果另记。
