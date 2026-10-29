# Mac 全量测试与 lint 超时诊断

日期：2026-10-28；独立局部审查 `mac_merge_review`。只读诊断，未修改受跟踪源码/测试，未编译，未重启或终止其他任务进程。

## 结论

当前没有证据证明这些失败是本轮合并引入的数据计算或进程归属回归。**也不能将初次失败标为成功或用 known flake 忽略。** 三个Swift失败selection与两个Python失败测试均在原有二进制/源码的隔离窄执行中通过；源审查确认它们含真实墙钟安全预算、进程启动/调度及全系统进程枚举依赖。最小下一步是避免 lint、全量Swift、Xcode构建同时运行，使用1个direct worker完成最终源码的全量gate，再判断是否还需产品修复。

原全量运行仅部分完成，窄复现不是完整gate。保持失败日志、报告 substituted/untested 的边界，最终候选需重新编译后完整验证。

## 当前环境与证据边界

- 工作区 HEAD：`2e51c676f3da02c981bce4ab518401aebd14e9c3`，另有主任务正在开发的dirty diff。
- 直接执行二进制：`.build/out/Products/Debug/CodexBarTests.xctest/Contents/MacOS/CodexBarTests`，mtime `2026-10-28T13:01:07-0700`，size `596884608`。本次未编译；它不包含后续待编译修改。
- 本次原始读取日志：`mac-full-tests.log`、`lint-4.log`，位于本报告同目录。
- 13:57观察到 load averages `67.95 / 106.37 / 220.39`；14:01仍为 `52.57 / 81.58 / 186.38`。一次只读进程状态计数为 S2333/R82/U11/Z3；vm_stat free4060页（16KiB页）。这些是诊断时的资源压力证据，**没有原失败瞬间的CPU/内存轨迹，不能宣称已经证明唯一因果**。
- mount/UUID/realpath/scratch可写验证通过。所有命令显式TMPDIR指向 `.../Upstream082/review-tmp`，Python tempfile遵守该路径。另查到Foundation temporaryDirectory不遵守TMPDIR，见下文存储项。

## 1. Antigravity 60000-row snapshot

原失败在 `AntigravityLocalScanTests.swift:75–76`：raw `fixture.report()` 的complete、60000 rows、11220000 tokens等断言均通过，随后 `fixture.snapshot()` 的coverage=false、tokens=nil。该测试总37.539s。失败snapshot为完全 unavailable，不是错误的局部金额或伪造零。

调用链：

1. `AntigravityLocalFixture.report` 默认 `estimateCost=false`，直接读60k行。
2. `fixture.snapshot` → `CostUsageFetcher.loadPricedAntigravityLocalSnapshot` → `loadAntigravityLocalSnapshot` → serial utility `CostUsageScanExecutor`。
3. 第二次扫描 `estimateCost=true`。`AntigravityLocalReader.Limits.duration=30`；Budget.check比较真实systemUptime，超限抛exhausted，reader返回partial空报告；Fetcher不发布空partial，投影为unavailable。
4. Budget在executor内实际开始工作后创建，**队列等待未被误算进30s**。但工作线程被系统抢占的时间仍计入墙钟预算，这是生产安全预算的现行定义。

37.5s与“raw约7.5s，第二次priced扫描触及30s”的路径吻合，但原日志没有预算statistics/阶段计时，不能把推算冒充直接测量。

隔离窄执行使用实际Swift Testing ID：

```text
swiftpm-testing-helper --test-bundle-path <上述二进制>   --filter 'CodexBarTests\.AntigravityLocalScanTests/.*history beyond the former row cap'   --no-parallel --testing-library swift-testing
```

环境使用`Scripts/test_environment.sh`和`direct_swift_test_groups.runtime_environment`（独立HOME、CFFIXED_USER_HOME、禁用真实Keychain）。实际1 test PASS，5.941s；日志 `review-antigravity-direct.log`。初次SwiftPM `--skip-build --filter AntigravityLocalScanTests/history`没有匹配任何test，日志`review-antigravity-narrow.log`明确记录0tests；它不算通过证据。

**建议**：不扩大生产30s预算以“修测试”。先在低并发完整gate确认。若仍需让功能断言不依赖机器速度，应在reader/fetch边界注入测试clock/扫描依赖，保留60k行语义断言及已有虚拟时钟budget边界测试，另单独保留真实负载性能验收。不能把60k→小fixture替换后声称验证了原规模。

## 2. Kiro root TERM / third-generation PTY fixture

原 `KiroStatusProbeTTYHardStopTests.swift:12` 失败为等待root-term-child PID文件20s，测试总45.463s。其它解析断言、term-child/late-child步骤已先执行，原输出没有证据表明该root-term-child曾成功发布PID后又漏杀。

`makeHardStopCLI`的root_term_child仅在Python根进程收到SIGTERM、handler获调度并fork后写文件。`SpawnedProcessGroup.abortSynchronously`源码568–582：

- 先创建0.4s deadline；
- `currentAbortProcessIdentities`包含process-group及descendant枚举；
- 发送TERM；
- 现有deadline到期后KILL。

因此在枚举或系统调度变慢时，TERM handler的有效运行机会可能缩短或消失。fixture将“TERM必先创建一个新child并写PID”视为无条件成立，但真实有界强杀没有承诺任意用户态handler一定运行。延长后续`waitForPID`并不能让一个已被KILL的root重新fork。

这说明一个具体的fixture/真实调度竞争点；**没有失败瞬间的信号/枚举/文件轨迹，不能断言它是唯一根因**。相关生产代码相对v0.79到v0.82并未改动，不是本轮冲突新引入。

隔离窄执行2个Kiro失败selection：root TERM/third-gen PASS 2.508s，detached-child PASS 0.845s，合计3.355s。日志 `review-kiro-direct.log`。

**建议**：先低并发完整验证。若持续复现，给DEBUG fixture增加明确的TERM后、KILL前readiness gate或可控时钟/信号sender缝，让该测试确定性制造第三代child，再单独断言生产hard-stop预算；不要仅把20s提高到60s。如果产品合同确实需要保证完整TERM grace，再有针对性地考虑将grace起点置于身份枚举及TERM发送之后，并增加枚举延迟的确定性测试；不能仅为满足fixture而无依据改变生产hard-stop合同。

## 3. Kiro detached child functional probe

原失败为等待整个fetch及registry清空20s。Fixture中usage启动Python、再启动独立session的Python子进程并用pipe确认readiness；account和context还各启动独立进程。functional probe提供usage20s、context15s、account15s、pipe cap5s，fixture却从整体fetch启动时就以20s判断“promply”。生产fetch的多阶段预算与这个整体测试观察上限不是同一个量。

隔离同二进制PASS 0.845s，证明正常启动时确实不会等待60s holder自然退出，并验证child最终消失、用量解析和context数值。没有原失败阶段日志，暂不能分辨它当时卡在解释器启动、transport fallback、holder枚举还是context/account阶段；不应直接诊断产品死锁。

**建议**：保留真实helper/owned cleanup语义，拆开fixture启动readiness与清理观察起点；必要时对不属于该测试主题的account/context依赖使用stub或可控transport。重现时记录具体阶段及owned PID而不读取同机其它任务命令行/环境。

## 4. Python process cleanup deadlines

原 `lint-4.log` 两项：

- `test_timeout_escalates_for_term_ignoring_child`：`_drain`5s到期仍有owned PID85341，随后unrelated sentinel teardown等3s也超时。
- `test_timeout_retains_observed_child_after_it_starts_a_separate_session`：fixture ready握手10s未满足；controller随后清理临时目录，晚启动的fixture才写pid，出现FileNotFoundError。这是启动/退出时序失败后的次生现象，不能单独说明PID归属算法错误。

源码：`ci_swift_test_by_suite.py:390–409`的cleanup合同为TERM→3s后KILL→5s仍存活则fail closed，**不会在旧child仍活着时允许重试**。`test_swift_test_process_cleanup.py:277,291`的10s是解释器/文件readiness，不是被测cleanup deadline；fixture的stubborn/sentinel还有20s自过期界限。现有虚拟时钟测试`test_undrained_child_fails_closed_after_bounded_grace`独立锁定TERM/KILL/5s行为。

窄复现命令：

```text
TMPDIR=<SSD review-tmp> python3 Scripts/test_swift_test_process_cleanup.py   ProcessCleanupTests.test_timeout_escalates_for_term_ignoring_child   ProcessCleanupTests.test_timeout_retains_observed_child_after_it_starts_a_separate_session -v
```

实际2 tests PASS，7.821s；timeout-stubborn总5.203s（命令2s + cleanup约3.2s），timeout-session总2.146s；均输出`observed_before_drain=true`、`child_terminated=true`、`unrelated_sentinel_alive=true`。日志 `review-python-cleanup.log`。同一Homebrew Python3.15解释器，排除窄复现换解释器版本造成的假恢复。

**建议**：保留5s fail-closed及身份验证，不将真实超时改成成功。先串行完成portable lint与全量Swift，降低同机竞争。若仅fixture startup持续慢，可将setup预算与cleanup预算显式区分，并在setup失败时记录已启动owned handles、完成有界收尾后再删目录；不要通过放宽production drain合同掩盖未清理的子进程。

## 存储审计发现

原Kiro失败路径位于`/var/folders/.../T`。AntigravityLocalFixture也直接使用`FileManager.default.temporaryDirectory`。只读验证：

```text
TMPDIR=<SSD review-tmp> osascript -l JavaScript   -e 'ObjC.import("Foundation"); $.NSFileManager.defaultManager.temporaryDirectory.path.js'
→ /var/folders/.../T
```

因此“设置TMPDIR就已让Foundation大型fixture落SSD”的推断不成立。60k数据库fixture后续运行应显式从已验证的测试scratch/TMPDIR构造URL，保留正常非Codex环境的适当fallback；无需改系统全局temporary目录。只改测试落盘入口，不机械替换历史证据或专门路径测试字符串。本次已运行fixture有deinit删除逻辑；此发现后未再次运行大型DB fixture。

## 推荐收口顺序

1. 修正适用的大型fixture显式SSD路径，保留行为/规模；完成主任务新增字段编译。
2. 完整portable lint先单独运行，确认102项process cleanup测试与其余检查全部通过。
3. 使用SSD scratch运行完整Mac direct worker=1；若环境已明显稳定可经证据选择小并发，但不要同时跑lint/Xcode压力工作。
4. 若仍失败，保存阶段/预算/owned-process证据，按上述具体竞争点做最小可控seam与测试，不盲目放宽产品期限。
5. 原103成功/2fail/1recovered的部分全量运行保持其真实状态；最终完整新候选结果必须覆盖所有selections，不能以本报告的5个窄PASS取代。

收尾按codex-memory-capture判断：本次具体测试诊断写入本轮Research/报告即可，未新增长期记忆。
