# 最终 App Group 修复后的 Mac 组合测试覆盖独立审查

日期：2026-10-28。审查源码HEAD `18ebb97272a68853473b3c3c565fc56f719901e2`，tracked输入clean；仅只读日志/源码/清单/5测试binary SHA，未构建、测试或操作设备/真实用户容器。

## 结论

**最终Mac组合测试库存gate在限定范围通过。** 当前1845 selections、16194个method identifiers均有对应的接受证据，missing=[]；上次a36成本修复102/最终3suite与本轮128组合不漏项。全部本轮128在最终gate3重新执行，不计失败gate2的前23个成功组，也不把首轮68913旧Widget模块编译失败计为通过。

本结论不宣称同一最终binary从头全量PASS、不把条件native/live证明当已执行。full lint/build与签名实包验收独立收拢。

## 精确去重后的接受分区

| 证据层 | selections | 对应当前method IDs |
| --- | ---: | ---: |
| 本次最终AppGroup gate3 | 128 | 1113 |
| 此前成本修复gate（排除本次重复覆盖） | 97 | 1121 |
| 旧完整gate未受两轮修复影响部分 | 1620 | 13960 |
| 合计 |1845|16194|

两轮affected selections有5个重叠suite：CloudSyncSettingsTests、PiWidgetFreshnessTests、PreferencesPaneSmokeTests、ProviderArchitectureGatekeeperTests、SettingsStoreTokenCostSourceTests。它们采用最新gate3通过证据，不能把102+128直接相加充当230个独立selections。

本轮128之外，1717 retained selections对应15081个method IDs，和a36 source-freeze inventory真实逐集合相同；本审查重新计算，未只信retainedMethodsEqual标志。完整方法数从16182到16194新增12，均属于AppGroupSupportTests，旧方法无移除；新19个@Test与baseline7方法对应。parameterized widget-first有两cases，方法计数仍是一个，不能混同cases/selection。

## gate3日志、清单与binary核验

`mac-appgroup-gate-3.log` 与 `mac-appgroup-selection-coverage.json`：

- sourceCommit精确绑定18ebb9727，dirty为空；selected128与独立审查清单完全相同，retained1717与其无交集，并集等于完整新discovery1845。
- 43个Selected group与43个真实Swift test group一一对应，128名称每个恰好出现一次；每组有最终框架PASS摘要，无框架fail、timeout或retry。
- 实际模式为production **serial SwiftPM**、worker1、group-size3，前置fresh discovery编译；各执行命令保留--skip-build/--no-parallel。discovery117.4s、execution283.5s、total403.8s。
- 保存的完整inventory为16194，无重复；128选择映射1113个非空method IDs，retained映射15081；总并集完整、无跨分区方法交集。
- 当前5个debug test binary重算SHA全部等于coverage JSON记录。它们不是最终签名release app，不能拿这组SHA替代ZIP/notarized app的artifact审计。

## 最后两文件delta源码结论

相对已独立补审0c80，18ebb仅修改WidgetProvider的一行derive和architecture精确anchor一行。

`providers = Self.supportedProviders(from: snapshot)`与旧`available.isEmpty ? [.codex] : available`语义等价：缺snapshot或无真实provider时helper默认保留Codex placeholder；有真实provider时返回相同supported列表。用于持久化保护的available仍以includePlaceholder:false计算，nil stored/无真实provider绝不写推导default的修复未回退；有效legacy Cursor同值不promote，真实移除时仍可保存合法fallback。

gate只把helper anchor改为包含includePlaceholder的完整return行，expectedIDs=[codex]、count1、fingerprint[codex@0]不变；selected原1ref anchor保持。没有放宽scanner窗口、过滤或匹配规则。derive删除了重复literal，从共同helper取值，既避免重复例外，也保持真实调用链。此两文件delta开放源码finding=0，并已由本轮AppGroup/Widget/architecture fresh执行覆盖。

此前Widget-first顺序、partial-copy staging/cleanup重试、publisher竞争、helper签名Team及debug/symlink识别的生产seam测试均在本轮128内。签名脚本timestamp fallback的$target修复与stub/entitlements合同属于shell/打包gate，应在full lint/package证据独立记录；不把Swift gate3当作已经执行这些shell测试。

## 条件跳过准确分类

新gate3仅有2个唯一显式XCTest skip：

- ProviderAccentColorScreenshotRenderTests/test_renderAccentColorSettingsScreenshots：未启用CODEXBAR_ACCENT_SCREENSHOT_DIR。
- WidgetReadabilityNativeProofTests/test_syntheticWidgetViews：未启用CODEXBAR_WIDGET_READABILITY_PROOF_DIR。

这2个都已经属于原完整链的123个skip，现为重跑后再次skip。旧123中其余121在未重跑部分按原证据保留，所以去重后整体仍为 **123**，不是125。本审查将两新skip与旧完整method标识核对，也确认无新增不认识的skip。

123是框架显式XCTest skip计数；部分Swift Testing opt-in原生proof在env未启用时直接return，不显示为框架skip。选择并PASS不等于运行其native UI body。原截图/原生交互/live provider边界、真实Keychain禁区仍保持；本次不为凑“全通过”打开这些环境开关。

## OS授权与其他证据的独立范围

`group-os-authorization/proof.json`记载新UUID QA组的正负控，sourceCommit0c80、positive/negative均通过，未访问既有业务payload/defaults，且明确container URL非nil本身不是授权证明。父线程记录正控目录FD open成功、负控EPERM以及QA测试目录清理。这是OS授权机制的限定证据，不能替代最终真实app/helper/widget签名entitlements/Team/同组身份、Production/profile/notarization/staple和新附件source/hash绑定；本审查没有操作用户容器。

原完整gate的多build来源、初始temporary runtime未保留完整旧binary manifest限制继续保留，详见`mac-final-coverage-review.md`与`mac-frozen-composite-gate-review.md`。本轮接受的是明示分区的组合证据，singleBinaryFullPass=false。

## 尚未纳入本结论的gate

full lint/build由父线程session38018执行，日志 `/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/Upstream082/mac-appgroup-full-lint.log`；本报告不提前计通过。Mac需使用修复后的新签名/公证包，旧draft继续hold直到新artifact审计。iOS353既有输入hash不变的归档provenance、原16组合兼容证据及其substituted风险按各自记录保持，不因Mac本地AppGroup重测被改写为实体PASS。

最终完整candidate/发布产物review和PR当前head gate仍独立完成。本报告不授权push、merge或发布。

## 可回填Research的简述

“18ebb9727 clean：AppGroup最终128 selections/43组首遍全PASS，0fail/timeout/retry；新12方法使完整inventory16194，1717 retained methods逐集合不变。与此前成本102/冻结3suite及旧完整gate去重组合覆盖全部1845 selections；明确123个条件XCTest skip及opt-in guard-return边界，非单binary全量PASS。full lint/build及新签包证据另列。”

小JSON证明：`mac-appgroup-final-coverage-proof.json`，包括源绑定、三分区hash与数量、12新method清单、2新skip标识、旧证据链接SHA和当前binary复核；不包含任何failed gate2成功前缀。
