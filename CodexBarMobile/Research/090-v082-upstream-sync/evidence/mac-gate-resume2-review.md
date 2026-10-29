# Mac full gate 第二次续跑独立审查

日期：2026-10-28。只读审查，未改 tracked 文件、未重编译/启动测试、未运行 live provider/Keychain。

## 结论

当前两个 Mock count 修复和 `resume_mac_gate_2.py` 方案源码审查通过，未发现新增阻塞问题。已通过的原留存692 selections与phase1前46组506 selections可以合并为1198个不相交的留存selections；原1845 selections下剩余647必须实际执行。最终group数量由新 discovery/regroup决定，不能锁死为57/58或按旧组号裁切。本报告不宣称第二次续跑或最终full gate已经通过。

## Mock 期望值核对

对 `MockProviderInjector.swift` 的静态catalog独立提取核对：

- current provider allowlist：110项、110 distinct；legacy三个 `kimik2/crossmodel/crof`；synthetic两个 `_mock_cursor_unknown/_mock_synthetic_unknown`。
- `simpleProviderProfiles` 共117条，`allMocks()`另追加8条rich，得到125 snapshots。
- 合并simple/rich的distinct IDs共115，符合110 current +3legacy +2synthetic。
- current-provider snapshots共120（125−3−2）；Soniox/Trae CN/abliteration/Chatbox各新增一个profile，四新ID均在allowlist和QuotaProviderList。

因此 `realBorrowedMocks` 116→120、allMocks与两条sync写路径121→125、unique111→115均来自实际provider新增，不是为消除失败放宽范围。原allowlist set equality、realCatalog匹配、每账号标识与ghost清理、真实与mock隔离等断言均保留。测试名称/历史注释更新和新provider计数保持一致。原phase1 group47的6个issue均为这些旧count断言，retry仍失败；未将失败判为flaky。

## 续跑分区与真实通过证据

独立解析 `mac-full-tests-2.log` 和 `mac-full-tests-resume.log`：

| 来源 | 实际执行 | 可留存 |
| --- | --- | --- |
| 初始worker1 | group1–62；前61 PASS、62 FAIL |694原通过selections减2个受SyncCoordinator变更影响suite=692 |
| phase1 | group1–47；前46均有框架最终PASS且无框架失败、47 FAIL |506 selections，与前692无重叠 |
| 当前完整selection库存 |1845 |留存1198，剩647 |

整个原phase1失败group47（含两个变更Mock suites、MockProviderInjectorTests及其他9个suite）均未混入留存，即便组内部分单项曾通过也全部续跑。两个改名Mock测试方法仍在未留存suite内，不会因方法名变化失去覆盖。

## wrapper 与来源审查

当前HEAD `d3a961d28c6a1876cf6352bdf6f1c477e22c2a19`。Mac输入相对 `f3b87fa94` 的完整 `Sources/Shared/Tests/TestsLinux/TestsPlugin/Scripts/Package.swift` diff仅两个Mock测试文件；无新增产品/runner/共享fixture变更。f3b87fa94包含上次复审过的Cursor与lexical ./ CatchUp修复。

- wrapper仍调用production `runner.main()`；仅筛选shard groups。原discovery、prepare_runtime、run_command ownership/cleanup、worker1、--no-parallel环境保持。
- 原完整旧selection必须存在于新discovery；remaining与retained不相交、并集等于新完整names；名字差新增suite自动进入remaining。
- 原 `prepare_runtime` 先执行，对新完整method inventory和实际各二进制XCTest/Swift Testing库存逐集合比较；未把inventory先裁成remaining。
- 新增retained方法集合对比：相同retained selectors分别匹配phase1保存的完整method inventory与新inventory，集合必须完全相等。同名suite增/删/改方法不能悄悄继承旧证据。
- 允许五个已知Mac测试文件的source guard合理：三个Cursor/CatchUp旧修复在phase1已执行通过，本次未再变；两个Mock suite明确不在retained。独立源码diff确认当前只有这两个测试继续变化。若后续触及其他生产输入/fixture/已留存suite，必须重新做影响分析并移入rerun，不可仅靠allowed名单沿用。
- save_runtime保存完整expected inventory、runtime/products、精确group selectors、每个binary SHA256、HEAD/dirty diff/source manifest hash，保存到scratch而非会删除的runner临时目录。

上述wrapper/source/log SHA256、精确1198留存名单及分区证明写入 `mac-gate-resume2-review-proof.json`。原始失败log继续保留。`retained_original_group_count=61`应解释为来源组数；不代表该61组每个selection都原封不动保留，两个suite已按影响重跑。

## 仍需执行后核验

1. 两个变更Mock suite及MockProviderInjectorTests重编专项结果，确认新count和真实sync两写路径都通过。
2. 新discovery/retained-method对比和prepare_runtime校验成功，actual remaining/grouplist与manifest一致；所有剩余groups最终code0，不允许0test/group或静默missing。
3. 将三个阶段与专项串成组合证据；保留各阶段source/binary hash及失败。准确表述为“组合证据覆盖完整新测试库存”，不将任何原失败log或新单一binary称从头full PASS。
4. 最终候选变动需再核对；本报告不替代打包产物、Duo其余姿态、PR exact-head review和release gate。

## iOS catalog格式修复的附带核对

独立解析当前Localizable.xcstrings与bdfb51085基线：新增17 entries，既有entries语义修改0、删除0。恢复旧文本布局未改变既有翻译语义；新四语是否完整仍以本轮i18n gate为准。该文件不进入Mac测试产品，不影响上述Mac留存分区。
