# Mac full gate 续跑方案与 CatchUp fixture 修复独立审查

日期：2026-10-28；只读审查，未改产品/测试/runner、未编译/运行测试。

## 结论

保留真实通过且未受后续变更影响的测试证据、重新发现完整库存、续跑未覆盖/受影响 selections 的方案成立；不能把原失败的 log 称为完整 PASS。初版有两处需要纠正，主 agent 已修正源码 fixture 和 rerun selection 集合；最终 runtime/method/source/artifact manifest 的保存已在 scratch wrapper 加入；执行生成值及最终 coverage 仍待核验。

## 路径测试修复

原失败来自 `CostUsageCatchUpCompletionTests` 第451行依赖 `/var` 或 `/private/var` 的 fixture 假设。当前实际 TMPDIR 在 StudioSSD，两个替换分支都返回原 path，所以 normalizedPath != path 稳定失败，不构成生产路径归一化故障证据。

第一版用 symlink alias 不等价：`CostUsageStore+CodexCache.swift:728` 的 normalizedCodexPath 仅 standardizedFileURL 与 /private/var 文本前缀，`cachedCodexUsageEntry:820` 也不解析任意 symlink。alias 对应的 pending path 无法匹配 cache.files 原 key，reconcile 会保留 alias，随后 empty 断言仍失败。已及时报告主 agent，未建议扩张生产逻辑来适配测试。

当前修复改为 raw String `parent + "/./" + filename`，保持两个不同输入字符串而在生产的文本归一化后是同一 session。断言 URL.standardizedFileURL.path == path 加强前提；两条 pending path 的归一化去重、identity repair、后续 catchUp pending 清除等原断言均保留。只在 env.root 内活动，不依赖 /var、不创建外部链接、不更改生产语义。源码修复适当；重编测试结果尚待主线程。

## 留存与续跑集合

原 `mac-full-tests-2.log` 的 production runner 摘要：1845 selections、165 groups；61 first-pass successful、1 failed、0 recovered、0 timeouts。原 group62 因 CatchUp fixture 失败，且 retry 后仍失败，不能将其内其余通过测试整组视为已覆盖；它应全部续跑。

逐原组解析得到：前61组共 **694 selections**，并非61×12；isolated suites 会拆组。review发现“前61没有 syncmapper suite”的假设不成立：

- `AlibabaTokenPlanSyncTests`（原group17）实际多次构造 SyncCoordinator/pushCurrentSnapshot，走本轮抽取的 primary mapper。
- `ClaudeTokenAccountCostTests`（原group39）同样构造 SyncCoordinator 并 push，属于受影响调用链。

主 agent 已把两suite从 covered 移出，因此正确可留存集合为692 selections；剩余库存必须按**完整新 discovery names 集合差**计算，不按 group index 硬裁。新测试会影响最终 selection/method数量，不应锁死104 groups。AppDelegateTests 只是coordinator生命周期注入，ClaudeFamilyResolverTests 仅注释提到SyncCoordinator，不需据此额外重跑。

## wrapper 检查

scratch/resume_mac_gate.py 仍调用 production `runner.main()`，只替换 shard_groups 选择步骤；保留 production discovery、prepare_runtime、run_command ownership/cleanup、worker环境和 --no-parallel 执行，是合适的复用方式。full method inventory 未被 suite filter 裁掉，prepare_runtime 仍以新完整库存与各测试二进制的 XCTest/Swift Testing discovery 比较，失败即拒绝 direct execution。

已有：旧 selections 必须都仍存在于新 discovery；retained 与 remaining 不交且并集等于新完整 selections；强制重跑 CursorSandUsageTests、V082MobileBridgeTests、CatchUp 以及上述两个旧已通过suite。新 suite 不会因旧group序号偏移漏掉。

更新后的 save_runtime 已先调用原 prepare_runtime，再持久保存完整 expected methods、runtime、groups、binary SHA256、HEAD/dirty diff/source-manifest hash，并检查 retained 测试未被修改。当前对照9ea3595e4的Mac相关diff仅SyncCoordinator及3个force重跑测试文件；TestsLinux/TestsPlugin/Package/Scripts/Shared及其余Mac源码未变。原group1–62均确实出现在执行输出，前61组均有测试框架最终通过摘要且无框架失败标记（原17/42组含预期负向fixture产品error日志，不能按error子串误判），group62为真实失败。下列项目仍需在执行结束后核验（相关代码保存机制已加入）：

1. 完整新 method inventory 与 runtime products/实际binary SHA256、源码 manifest/diff hash。生产 main 的临时 manifest/results 会清理，只留 mac-resume-coverage.json 的suite名字不足以复核真实运行库存。可在scratch包装原 prepare_runtime，先调用原函数再保存入参 expected、groups、返回runtime/binary hashes；不要修改校验本身。
2. retained suites 的测试源/fixture/common shared dependency 未改变；至少与前次 source manifest 核对。若同名 retained suite 内新增方法，仅 `old_all <= names` 不能发现，需将受改suite移入remaining，或比对旧/新 per-suite method inventory。当前已知Swift变更在Cursor bridge/Cursor/CatchUp与iOS测试，force集合覆盖Mac测试变化。
3. 续跑没有 missing selection、0-test selection 或库存 mismatch；所有剩余groups最终code0；保留原失败日志、首61成功列表、精确692留存列表、续跑实际groups/results/日志及后续Cursor focused证据。若某group中途失败，不能以只看末尾单组成功宣告完成。
4. 在Research/03称为“合并证据覆盖完整测试库存”，区分原构建已通过692 selections与新构建其余/受影响selections；不能称单一新二进制从头全量PASS。CI/release gate若要求同一最终artifact全量执行，应按其明确要求执行，不能用续跑推导替代。

原log哈希、完整留存selection列表和review开始之后Swift源变化清单存于 `mac-gate-resume-review-proof.json`。此报告仅审查方案和源码，不宣称续跑已通过。
