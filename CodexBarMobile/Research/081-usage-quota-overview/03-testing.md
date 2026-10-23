# 实现验证记录

状态：`done` · 2026-10-22–23 · iOS 3.2.0 (251)。本文件按已读日志记录结果；未完成、失败与待重跑的门禁不会记为通过。

**最终生产来源已审查并合并；Archive 和 Apple Distribution 本地 export 验证通过。** reviewed head `6cd449d8ba69628db9242bdef4cc9f71b5b8d875` 的 clean receipt 为 `6369240831`，PR #208 gate 为 3 轮 / 0 unresolved，已合并。最新身份历史修复的专项为 43 tests / 参数展开 60 passes；早期全量结果和 combined `TEST FAILED` 历史分别保留。Final CI 与直接上传已成功；ASC 最终 build 已为 `VALID` / `IN_BETA_TESTING`；Internal 既有自动访问、四语 What to Test exact readback 和 Apple CDN 图标人工验收均通过。真实 2 Mac × 2 iPhone Production 同步没有执行，16 组合仍为 substituted；外屏旧 compact-phone navigation 的 skip 不计为 pass。

## 环境与证据

- 基线：`d90e42daef7f54611c7fba7c043452b7125f7436`，iOS 3.2.0 (250)；本轮 `feature/usage-quota-overview`，仅 iOS。
- Xcode：`/Volumes/StudioSSD/Developer/Xcode/Xcode-27.1-RC.app`；当前原生测试设备为 `CodexBar Compact QA`，Simulator UUID `77015D3F-613D-4B1E-B348-1624350AD7E1`。
- 本轮主证据目录：`/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/UsageQuota-3.2.0-251`。下文相对 evidence 路径均位于此目录。
- 组件渲染原始 PNG：`/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/UsageQuotaRenders`；导出的 XCTest 附件及映射为本轮目录的 `designer-attachments/manifest.json`。
- 验收 gallery：`/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/UsageQuota-3.2.0-251/gallery/gallery.md`，40 张原始图片、来源哈希与 gallery 均留在 BuildScratch，不进入 Git，只提交本文的证据索引。
- 测试使用虚构 provider/account、内存 store 与字典持久化；没有调用真实 CloudKit、Keychain 或 live provider。

## 已确认与待验证

| 项目 | 当前结果 | 已读证据与边界 |
|---|---|---|
| Debug iOS build | pass | `build.log` 含 `BUILD SUCCEEDED`；不是 Archive/签名/TF 证据 |
| Portable lint 与四语 catalog | pass（pre-PR 最终轮） | `pre-pr-final-lint.log`：3143 files，0 violations；4 个 catalog 全语种 translated，523 source keys 存在；早轮 528 keys 仅是当时源码计数 |
| 组件渲染 34 配置 / 44 PNG | pass（含 AX 日期修正） | `duo-landscape-light.log` 中两个 `UsageQuotaRenderTests` 重新构建并通过；覆盖全部窄/宽、浅深色及大字配置，包含后改的 Accessibility 横轴端点标签 |
| 16 old/current wire × 独立 reader 组合及 inherited-extra | substituted · pass | `final-unit-ui-phone.log` 明确记录 16 cases 和独立 extra 回归通过，整个 compatibility suite 通过 |
| 每窗口原始来源证明 6 项 | pass | `final-unit-ui-phone.log` 的 source proof suite 通过，包含新增 Kimi 真实 alias authority map 与 same-clock legacy substitute 拒绝回归 |
| 图例隐私与稳定账号序号 | pass（纯展示 helper） | `Quota overview private labels` suite 通过；不替代完整原生隐私交互 |
| 全量 Swift Testing 与 XCTest 单元 | 历史 pass（两个后续 quota 修复前） | `final-unit-ui-phone.log`：1223 Swift Testing tests / 81 suites 通过；XCTest 单元 70 tests / 0 failures，含 render；不覆盖下述构建开始后的 AX 日期修改 |
| Accessibility / 窄宽横轴日期与折叠图例 | pass（分轮 render/native），增量 CR clean | Accessibility 或 chartWidth < 300 只显示 `[Now,end]`，其它宽度保留 midpoint；日期 domain 不变。折叠图例保留 provider/metric，冲突账号才加稳定序号并可横滑；后续各 native 当前姿态验证，不倒算到此前全量单元证据 |
| 原生 phone 新 QA 5 项与四语 Cost scope | pass | `final-unit-ui-phone.log` 五项 `UsageQuotaOverviewUITests` 全过；`testCostScopeExplanationInFourLanguages` 通过。该 combined run 仍因旧 release intro 断言失败，不能将 bundle 总结果写成成功 |
| Phone 完整编辑链最终 helper | pass（1/1） | `phone-editor-final.log`：最终 Form geometry/row helper 在 phone 增删、排序与重开链路通过 |
| Release intro / setup guide | 修正旧断言后 focused pass | 旧测试将 3.2 标题期望写成 3.1；修正后在 `duo-landscape-light.log` 复跑通过 |
| 原生 ColorPicker 实际选色与重开 | pass（主工程 ComputerUse 人工交互） | Claude Weekly 首条 `57632E93…` 从橙色改 dark azure，关闭编辑回 Usage 看到蓝线，重开仍保留；`evidence/phone-manual-blue-line.jpg`。区别于仅查询控件存在；不宣称是真机或 CloudKit 验证 |
| Duo 展开 landscape / light 当前姿态及完整编辑链 | pass（分轮关闭） | `duo-landscape-light.log` 中四 Tab、Cost 排序、release intro 通过；编辑 helper 修正后由 `duo-landscape-editor-final.log` 1/1 通过。诊断证实是可见 Form 容器 isHittable=false，不能归因为错 pane |
| Duo 展开 portrait / dark | pass（3/3 + 正向 current-pose 1/1） | `duo-portrait-dark.log` 的 3 项通过，但当时 raw 为 PortraitUpsideDown；后续 `duo-portrait-upright-dark.log` current-pose 1/1 通过，正向四 Tab 原图已由主工程验收 |
| iPad 原生 light | pass（3/3） | `ipad-native-light.log`：tablet 横竖/键盘/选中保留，Cost 整组排序及 current-pose 四 Tab 通过 |
| Large phone / dark | pass（2/2） | `large-phone-dark.log`：原生 navigation safe area/rotation、quota current-pose 四 Tab 均通过 |
| Duo actual 外屏 landscape / light | 1 pass + 1 skip（非 2 pass） | `duo-folded-outer-light.log`：current-pose 四 Tab 1 项通过；旧 phone-navigation test 因实际 width >= 600 不满足 compact phone 前提而 skip，不能计作外屏旋转通过 |
| Duo actual 外屏 portrait / light | pass（1/1） | CUA 切到实际外屏 portrait 后，`duo-folded-portrait-light.log` / summary 明确 current-pose 四 Tab 1 test、0 failures、0 skips，独立于 landscape run |
| 最终修复专项 | pass（43 tests / 参数展开 60 passes） | `recovery-identity-regression.log`：40 Swift Testing + 2 render + 1 native UI，0 failures / 0 skips；不是全量重跑 |
| PR exact-head CR / merge gate | pass · 已合并 | head `6cd449d8…`，clean receipt `6369240831`；`merge-gate-208.log`：3 轮 / 0 unresolved；merge `41dbf7cd…`，reviewed/merge tree 相同 |
| PR Fast Checks / Final CI | pass | `39983809520` 与合并后 `39984321217` 均成功，见 `provenance.json` |
| 最终 Production Archive / 本地分发 export | pass | `archive.log` / `export-local.log` 成功；`provenance.json` 记录 reviewed source `6cd449d8…` 的来源与 hash，旧候选单独保留 |
| TestFlight 上传 / ASC 处理 | pass；`VALID` / `IN_BETA_TESTING` | `export-upload.log` 于 `16:12:02Z` 上传成功；后续 `build-status.json` 回读最终 build `edf84cdb…` 已 VALID，internal IN_BETA_TESTING，external READY_FOR_BETA_SUBMISSION（未请求 external review） |
| TestFlight 可用 / 四语 / CDN 图标 | pass | `groups.json` complete=true，Internal 既有 all-builds 访问；四语 exact readback，实际 152px / unmasked 1024px CDN 图标人工通过，最终 receipt `16:17:08Z` |

## 渲染覆盖的实际含义

[`UsageQuotaRenderTests.swift`](../../CodexBarMobileTests/UsageQuotaRenderTests.swift) 直接 hosting 生产 `UsageQuotaOverviewView` / `UsageQuotaEditor`，不复制 UI。

- 卡片 24 配置：宽度 320、390、440、768、768（illustrative Duo-width）、300（sidebar）；每个浅/深色 × 常规/Accessibility 2，得到 24 PNG。
- 编辑器 10 配置：宽度 300、320、390、440、768；每个浅/深色、Accessibility 2。每配置记录顶部和滚动到底部，共 20 PNG。
- 合计 34 配置、44 组件 PNG；已核对原始输出计数与 manifest 中 `Production component in illustrative container` 附件数量均为 44。manifest 另外包含原生 UI 与失败附件，不能把全部附件数算作通过配置。
- 断言包括生产卡片宽度、横向不溢出、大字内容真实增高、5 个账号/metric/color 行可滚动到实际底部、原生 Form cell 有尺寸，且渲染不改保存选择。

这些是限定容器中的组件几何证据；浅深色为 hosting override，Duo-width 只是宽度。它们不证明实际 Duo display/pose 切换、原生 Tab/rail、系统 appearance 切换、所有屏幕交互或真机运行。视觉可接受性由设计师另行验图，不能仅凭测试断言代替。

## 首轮失败、研究与修复

### 窗口数值与观测时点混用

`focused.log` / `focused.xcresult` 的兼容 case 10–12 揭示真实设计问题：旧 A 的动态窗口为 30%/55%，新 B 的 legacy primary 为 40%/60%。既有 merger 可保留 A 的动态窗口，同时把 B 作为账号总体 source。新 store 若只读合并账号，会将 A 的旧值记到 B 的新 capture 下。

修复限定在新图的 [`UsageQuotaSourceResolver.swift`](../../CodexBarMobile/Models/UsageQuotaSourceResolver.swift)：稳定账号/windowID 对应到原始 writer 观测，各窗口使用自己的值与 capture；当前值、journal、预测与轴域共享证据。production 使用未归档设备对应的 `rawDeviceSnapshots`，避免把已折叠 alias 的 `deviceSnapshots` 再当原始来源。legacy 无 deviceID 使用统一 deviceKey。

canonical account 继续决定窗口是否存在、是否全局 blocked、是否不可用；raw evidence 不能解除这些约束。Kimi 继续遵从现有 capable-writer authority，不能由较新 legacy writer 清除 monthly block。来源缺失、身份歧义和同 capture 冲突保守处理。没有修改 Mac、Shared wire 或既有 merger 的显示语义。

独立本地 CR 还要求并复核了：隐私开启时 provider/metric/账号文字均清洗且有稳定账号序号；removed metric 不从旧 raw 来源复活；canonical error 不被旧成功样本提升为 available。当前源码复核未留下这些项的 P1/P2；相应专项通过记录在上表。

修复后的 `all-unit-ui-phone.log` 已保留原 `[40,60]` 严格断言并通过 16 参数，不是修改 expected 或去掉 legacy fixture。

### 较早全量轮次的 2 个模型 issues（已复跑关闭）

`all-unit-ui-phone.log` 的 1219 tests 轮次仍失败，具体为：

1. `calendar range includes unselected available windows and does not jump after removing a line`：两个断言按 `lines[0]/[1]` 假定 Session 在 Weekly 前；现默认顺序为 Weekly 优先，实际两个 end 与 near/far 恰好反转。工程改为按 windowID 查找，并明确移除 far 选择后仍保留 near、domain 不缩短。**`final-unit-ui-phone.log` 复跑通过**。
2. `an inherited extra window keeps its own old capture while a newer legacy writer refreshes native quota`：新增默认填充已选中该 extra，setup 再 `add` 返回 false。工程改为 setup 显式移除该绑定再添加并验证唯一；所有数值与来源断言保留。**`final-unit-ui-phone.log` 复跑通过**。

此处保留较早失败轮次与测试 setup 根因，不将旧失败结果改称成功。后续 `final-unit-ui-phone.log` 明确记录 Swift Testing 1223 tests / 81 suites 全过，XCTest 单元也全过；证据 bundle 为 `final-unit-ui-phone.xcresult`。该 combined run 的原生 UI 阶段仍须单独结算。

该轮原生 UI 后续结果：5 项新 QA 全部通过，四语 Cost scope 通过；唯一失败为既有 release intro 测试仍断言 `CodexBar 3.1.0`，实际标题已正确为 `CodexBar 3.2.0`。修正测试后由下一轮 Duo focused test 通过。保留 combined run 的 `TEST FAILED` 历史，不改写为整包成功。

### 后续 Kimi alias 来源修正

进一步 review 发现设备 alias 折叠后，outer merger 的账号 `sourceReport.sourceDeviceID` 可能是 canonical alias ID，而真实 quota 来源仍保存在 `mergedSnapshot.providerQuotaSources` 的 actual writer ID/capture 中。仅靠 report ID 会误拒绝正常来源；仅比较 capture/window 又不足以严格证明 authority。

新图改为同时接收该 reader-local `quotaSources` map，以 canonical publicationKey 找到既有 merger 已选中的实际 quota writer，再严格验证 raw writer ID、capture 与 canonical effective window。production 明确传 map，缺失证据不降级为猜测；兼容 reader 每次从其完整 merged snapshot 取得 map。该修正及真实 alias、同 clock legacy 巧合的第 6 项 regression 已在 `final-unit-ui-phone.log` 中通过，不借用此前 5 项 pass 宣称完成。

## 16 组合替代验证实测

完整方法见 [`02-compatibility-plan.md`](02-compatibility-plan.md)。old reader 是冻结 build-250 字段投影后接当前纯 cache/merge；不是旧二进制。Mac old/new 是旧形状/current fixture，本轮没有 new Mac 发版。A/B reader 各自使用独立缓存与字典持久化。

最终单元证据为 `final-unit-ui-phone.log` 中参数测试 `two writers converge through independent full and cold delta readers without sharing preferences` 的 16 cases pass；它仅证明表中的替代参数测试，未覆盖真实服务器订阅/后台推送。

| Case | Mac A fixture | Mac B fixture | iPhone A reader | iPhone B reader | 结果 |
|---:|---|---|---|---|---|
| 1 | old | old | old | old | substituted · pass |
| 2 | old | old | old | new | substituted · pass |
| 3 | old | old | new | old | substituted · pass |
| 4 | old | old | new | new | substituted · pass |
| 5 | old | new | old | old | substituted · pass |
| 6 | old | new | old | new | substituted · pass |
| 7 | old | new | new | old | substituted · pass |
| 8 | old | new | new | new | substituted · pass |
| 9 | new | old | old | old | substituted · pass |
| 10 | new | old | old | new | substituted · pass |
| 11 | new | old | new | old | substituted · pass |
| 12 | new | old | new | new | substituted · pass |
| 13 | new | new | old | old | substituted · pass |
| 14 | new | new | old | new | substituted · pass |
| 15 | new | new | new | old | substituted · pass |
| 16 | new | new | new | new | substituted · pass |

两台真实 Mac × 两台真实 iPhone 的版本切换未执行。残余风险包括 Production 容器/权限、真实数据分布、旧二进制完整 decoder/UI、silent push、后台时序、change-token 失效与网络、实际 defaults/恢复行为。组件或缓存替代不能消除这些风险。图表偏好/观测本就各 iPhone 本地独立，不能要求不同本地历史产生完全相同预测曲线。

## 后续结果入口

### Duo landscape/light 与手工 ColorPicker 观察

`duo-landscape-light.xcresult` / `.log`：组件 tests 2/2、release intro、Cost whole-group、native 当前姿态截图通过；当时编辑器 reveal helper 失败，该 bundle 总结果仍为 Failed。早期曾怀疑全屏 swipe 命中其它 pane，但后续 diagnostic **没有支持该归因**：唯一正确 Form 已可见，frame 为 `{149,8,653,661}`，只是容器 `isHittable=false`，内部真实 row buttons 仍可点击。

最终 test-only helper 通过 quota row identifiers 定位正确 Form，取 Form 与 app window 的可见交集，并要求内部真实 row control `isHittable`；随后从交集内部相对坐标拖动，不再向非交互容器索要 hit point。保留真实 Add/count/action/排序/重开断言，没有跳过链路。`duo-landscape-editor-final.log` / `.xcresult` 明确 1 test、0 failures、`TEST SUCCEEDED`，完整编辑链已关闭；没有为此修改生产布局。

已独立读取 `duo-landscape-light-attachments/manifest.json` 并验看 screen 1 的 Usage、Summary、Cost、Settings 完整 App 图：包含原生侧边 rail/Tab 和状态区；Usage 位于左栏，Summary 保持全宽网格，Cost 把 Daily Spend 移到 Overview 前，Settings 双栏仍完整。未发现这些已查看截图中的新阻断。这里只证明本次真实 Simulator landscape/light 当前姿态，不外推 portrait、外屏或系统 dark。

主工程通过 ComputerUse 实际操作 phone QA 原生 App 的 ColorPicker：首个 Claude Weekly 选择 UUID 前缀 `57632E93`，由橙色改为 dark azure，关闭编辑后 Usage 图例与曲线变蓝，重开编辑仍保留 dark azure。独立验看 `evidence/phone-manual-blue-line.jpg` 可见蓝色 Claude Weekly 图例/曲线及完整 phone Tab Bar；点击、选色与重开步骤由主工程实时观察记录，此图本身只展示最终图表状态。此处是真实原生交互，区别于自动测试只断言 ColorPicker exists；不把 Simulator phone QA 称为物理真机验证。

### Duo portrait/dark 与 iPad 后续验证

- `duo-portrait-dark.log` / `.xcresult`：3 tests、0 failures、`TEST SUCCEEDED`。通过项为 `testCostWholeGroupOrderMovesNumbersAcrossTheOldPaneBoundary`、`testEditorLimitRemoveAddColorAndOrderSurviveReentry`、`testNativeUsageChartInCurrentDisplayPose`。编辑器已在该姿态完成真实目标控件的增删/重排/重开断言，不再只是 UI 元素存在。
- 较早 Duo raw 截图实际为 **PortraitUpsideDown**，该轮功能/布局结果保留原有姿态事实。后续 `duo-portrait-upright-dark.log` / `.xcresult` 的 `testNativeUsageChartInCurrentDisplayPose` 1/1 通过，已补正向四个原生 Tab 图并由主工程验收；正向证据来自独立 run，不是旋转旧图片。
- `ipad-native-light.log` / `.xcresult`：iPad Pro 11-inch (M5)、iOS Simulator 27.0，3 tests、0 failures、summary `Passed`。`testTabletColumnsSearchAndSettingsSelectionSurviveResize` 实际覆盖 portrait→landscape→portrait，包含搜索过滤、点击账号后收起键盘、宽屏键盘出现时保留 sidebar/detail、Settings 选中项跨旋转保留，以及 Cost 的横竖布局；另两项验证整组 Cost 排序及当前姿态四个原生 Tab。
- `large-phone-dark.log` / `.xcresult`：2 tests、0 failures，`testPhoneNavigationSafeAreaAndRotation` 与 `testNativeUsageChartInCurrentDisplayPose` 通过，包含 large phone 当前系统 dark 下的原生导航/旋转和图表四 Tab。
- `phone-editor-final.log` / `.xcresult`：最终 Form helper 的 phone 完整编辑链 1 test、0 failures，通过增删、顺序与关闭重开断言。
- `duo-folded-outer-light.log` / `.xcresult`：实际折叠外屏处于 landscape/light；`testNativeUsageChartInCurrentDisplayPose` 通过，覆盖该当前姿态的四个原生 Tab。`testPhoneNavigationSafeAreaAndRotation` 因实际宽度 >= 600、要求 compact phone 而 skip。准确结果是 **1 pass + 1 skip / 0 failures**，不是两项通过，也不是外屏 portrait/旋转已验收。
- CUA 切换为实际外屏 portrait 后，独立 `duo-folded-portrait-light.log` / `.xcresult` 的 `testNativeUsageChartInCurrentDisplayPose` 1/1 通过，summary `Passed`、0 failures、0 skips；summary/原始附件均已保留。不能把此前 landscape 的 pass 或旧 compact-phone test 的 skip 当成此轮 portrait 证据。

### 最终增量 independent local CR

结论：**clean，无剩余 P1/P2**。此结论仅针对上次 clean 后的增量，未将运行中的 QA 结果算作通过。

只读检查范围：

- `UsageQuotaOverviewView`：`chartWidth < 300` / Accessibility 时只保留横轴端点，其它宽度保留 midpoint；日期 domain、额度点和估算数据不变。宽度测量不会形成不断改变容器尺寸的反馈；折叠图例横滑、展开状态及 AX value 保留。
- `UsageQuotaPresentation.collapsedTitle` 及对应展示单测：provider/metric 继续脱敏，仅当两条可见同 provider/metric 来自不同账号时追加稳定 `#序号`；全长 AX 仍使用清洗后的完整身份，不按当前排序重编号。
- `UsageQuotaOverviewUITests` 的 `reveal` / `top` / `usageScroller` / 最终 `scrollEditorForm`：编辑时按真实 row 标识定位 Form，验证可见交集和内部 row 可点击，再在交集内拖动；Usage 时按图表编辑控件寻找所在纵向 list。可见非交互 Form 容器不等于不可操作；最终目标仍必须实际 `exists && isHittable`，Add/count/action 等交互断言未放松。独立增量 CR 复核该 test-only 修正 clean，无 P1/P2。

本次 CR 未修改生产代码、未启动额外 build/test。Duo 正向 portrait、iPad、large phone、phone/landscape 编辑 final、外屏 landscape 与外屏 portrait 结果均来自中央测试日志，全部适用 native QA 已通过。保留 folded landscape 旧 phone-navigation 的 1 skip，因为该测试的 compact-width 前提不适用，不能记为第二项通过或额外旋转覆盖。

此处记录的是当时本地验证冻结点；pre-PR lint/四语已通过。后续线上 CR、合并与当前发布状态见本文末和 `04-release.md`。Hosting 大字截图不是真实 device pose 证明。最终用户可安装产物的来源记录写入 `04-release.md`。


## 线上 CR 第一轮：高频采样的时间跨度

PR #208 首轮审查 head `9d5c209e50908b1e26c66abd6dfcb2c82c98b275` 提出一个 P2：Weekly 每五分钟采样时，截取最近 12 点只覆盖 55 分钟，永远达不到六小时的 pattern 门槛。进一步检查发现，只去掉 12 点截取仍不够；每分钟采样时，96 点存储容量也只能保留 95 分钟。

本轮修正以共享的时间跨度要求约束历史保留与预测选取，保留真实端点和最新读数；不生成虚构观测。重置、时长变化、额度下降仍先断段，真正缺测仍不能伪装为连续忙闲模式。新增测试覆盖高频采样、滚动保留、最新端点与缺测边界。该修复的实际测试结果在下文记录；不复用此前全量 pass 作为新代码的通过证据。

初次 archive（source `9d5c209…`）已保留在 `superseded-9d5c209/`，从未上传；因本轮生产逻辑变化，必须从最终审查输入重新归档。

修复后的 `online-r1-quota-regression.log` / `.xcresult` 为 **TEST SUCCEEDED**：36 个 Swift Testing tests / 4 suites 通过（参数用例另按日志保留，包含每分钟/每五分钟高频采样、滚动、重复读数、短尾、近缺测与旧 gap 后恢复）；两个生产组件 render tests 通过（34 配置 / 44 PNG）；`testNativeUsageChartInCurrentDisplayPose` 在 compact phone 1/1 通过，覆盖完整四 Tab、折叠/展开图例和返回状态。此轮没有重跑全量 1223 tests，不将早轮结果误记为新来源的全量结果。

最终方案先按共享 `minimumHistorySpan` 对有界存储保留真实端点及最新尾点，再选择最新且至少有三段观测的充分时间跨度；原有最长缺测、单调消耗和当前 capture/value 检查保留。独立 reviewer 对本轮三个 Swift 文件复审 clean，无 P1/P2；设计师逐张查看最新八个窄屏/宽屏/AX/浅深色代表 render，未发现新增布局或曲线溢出问题。界面布局与先前跨屏矩阵相同。


## 审查恢复与额外独立复核

07:43 / 08:17 UTC 对同一 a05 head 的请求长时间未返回结果。15:50 UTC 在核对仓库审查设置及可访问的后台后重新发起，15:52 UTC 收到 [当前 head clean receipt](https://github.com/o1xhack/CodexBar-Mobile/pull/208#issuecomment-6368948944)。后台没有暴露旧请求的错误日志；普通额度充足不等于独立 Code Review 额度已确认，不能据此宣称已定位服务故障原因。

与此同时，新独立 reviewer 对 a05 完整差异发现 P2：同一 weak record 槽上的稳定账号 A 变为无稳定身份的快照时，历史许可函数将 0 个 stable 匹配视作无歧义，可把新读数接到 A 的历史；反向匿名→稳定身份首次学习也可能保留未经证明的旧历史。实际 wire 允许 record-only 身份，例如 Future AGI 的普通 API 配置可只带登录方式与同设备槽位，换凭据后仍可能复用 weak key；即使没有稳定→匿名过渡，weak→weak 也不构成历史账号证明。

修复要求将历史与可验证的稳定账号来源绑定；身份丢失、首次确认或来源无法证明时不沿用旧 pattern，保留当前额度与诚实的均值估算。旧本地观测无 owner 证明时重新积累，卡片选择和配色保留。生产 UI、共享 wire、Mac 代码不变。修复后冻结四个模型/测试文件的独立静态复核已 clean，报告 `recovery-fix-review.md`，SHA-256 `deb7bd9038109d7b18706a2ff89ab6171f0f79e857822873526bcefed181a413`。新增 4 个测试（其中 1 个参数化）覆盖 weak→weak、stable→weak→stable、legacy 首次稳定身份、缺失/错误/正确 owner 证明，且保留当前值、均值回退、选择与颜色的断言。`recovery-identity-regression.log` / `.xcresult` 实际 **TEST SUCCEEDED**：40 个 Swift Testing tests / 4 suites、两个生产 render tests（34 配置 / 44 PNG）及 compact phone 原生四 Tab / 图例测试全部通过，0 failures / 0 skips。主工程查看最新 phone 浅色与宽屏深色原图，未发现此模型修复引入的视觉变化；没有改变 UI。此增量不冒充全量重跑，不将 a05 的线上 clean 用于后续 head。

`recovery-identity-lint.log` 的 portable lint 全部通过（3143 files，0 violations，四语与 523 source keys 审核通过）；`git diff --check` 通过。对基线的 Mac `Sources`、根 `Tests`、`version.env`、Shared 和 CI workflow 差异为空。

## 最终 exact-head 审查与发布前回读

最终生产 source `6cd449d8ba69628db9242bdef4cc9f71b5b8d875`，tree `332f57ee4b3095c0b3188409394e73777b1d2170`。最终 [clean receipt](https://github.com/o1xhack/CodexBar-Mobile/pull/208#issuecomment-6369240831) 完成于 `2026-10-23T16:07:20Z`；`merge-gate-208.log` 明确 `rounds=3 unresolved=0`。PR #208 于 `16:08:48Z` 合并，merge commit `41dbf7cd313fc4c95007ab62c153a68c71d6bdff` 的 tree 与 reviewed source 一致。[PR Fast Checks 39983809520](https://github.com/o1xhack/CodexBar-Mobile/actions/runs/39983809520) 成功；[Final CI 39984321217](https://github.com/o1xhack/CodexBar-Mobile/actions/runs/39984321217) 已成功，状态记录于 `provenance.json`。

已读取最新 `recovery-identity-regression.log` 的 40 Swift Testing tests / 4 suites、两个 render tests、一个 native UI 的成功记录及 `TEST SUCCEEDED`；参数展开结果为 60 passes，总计 43 tests，0 failures / 0 skips。两个 render tests 产出 34 配置 / 44 PNG。保留此前 1223 Swift Testing + 70 XCTest 只属于早期源码的边界，不把最终专项算成全量。

最终 source 的 `archive.log` 为 `ARCHIVE SUCCEEDED`，`export-local.log` 为 `EXPORT SUCCEEDED`；实际 archive / distribution entitlement 与 hash 见 `provenance.json` 和 `04-release.md`。`export-upload.log` 明确 `2026-10-23T16:12:02Z` Upload succeeded / `EXPORT SUCCEEDED`；`upload-status.json` 回读 buildUpload `edf84cdb-4cee-4f7e-874d-d90fde2c4cff` 为 `PROCESSING`。后续 `build-status.json` 回读相同 ID 的最终 build 为 `VALID`，internal `IN_BETA_TESTING`、external `READY_FOR_BETA_SUBMISSION`。未请求 external review。`groups.json` 的 complete=true，Internal membership=`explicit-and-all-builds`、hasAccessToAllBuilds=true，确认既有自动访问；显式 add endpoint 返回 HTTP 422，不计作新 assignment，也不构成可用性阻断。`test-notes-readback.json` 的 en-US / zh-Hans / zh-Hant / ja 与待发布完整 3.2 文案 exact match。实际 altool iconAssetToken 152px 与 unmasked 1024px Apple CDN 图标均下载并人工验看为预期蓝色括号与双柱。`provenance.json` 最终 verificationCompletedAt 为 `2026-10-23T16:17:08.140550+00:00`；TestFlight 验收完成，Research 标记 `done`，上述历史测试及替代边界不变。
