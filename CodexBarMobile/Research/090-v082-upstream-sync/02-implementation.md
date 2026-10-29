# 实施记录

状态：`in-progress`。

当前已完成完整上游合并、Shared/iOS适配、Mac Group/CLI修复、最终测试和签名候选；最终产品源码18ebb9727。历史实施过程如下，当前验收以03–05为准。

后续在本文件记录merge冲突、fork保留、bridge/iOS实现、版本与本地检查；不以计划代替结果。


## 首轮完整合并

- Merge commit：`2f4e6a4ba`，第二parent为官方v0.82.0。所有工作位于本轮upstream-sync分支。
- 保留README原字节、appcast、fork发布py删除状态及CI触发政策；合并上游musl stack/smoke与路径gate测试，不移植PR heavy/draft deferral政策。
- 合并RateWindow的fork period/id/label与上游title/quotaLimit/quotaUnit；同时保留CostUsageModels.isEstimated与上游sourceRecorded，成本库保留fork历史parser哈希兼容，parserLogicVersion=24，重新生成hash。
- 跟随上游app source目录移动；保留已合并至TokenAccounts的fork fan-out逻辑，不恢复重复AccountRefreshPolicy。
- 保留插件publication generation和新hooks两条路径、Aixy动态quota窗口身份、fork日期时区与上游session inspection入口。
- 编译修复：新fleet观察器使用macFleetSync设置，避免混用Mobile开关；resolved quota threshold使用新的instanceID签名，quota enable沿用UsageProvider签名。
- Mac `swift build -j 6`通过（51.34秒），日志 `BuildScratch/CodexBar/Upstream082/mac-build-5.log`；完整/定向测试尚未通过验收。
- Shared新增可选quotaLimit/quotaUnit与detail Progress.expectedUsed，保留坏optional容错与旧payload；新providers无已验证身份时按device key隔离。
- PreviewData已核对：新provider复用现有generic quota/budget/detail类型，不新增四套重复样例；新数值/marker由专项fixtures/生产view渲染验证，结果待写03。

## 文档规则消歧

修正文档下半部仍按三段Mac版本的旧决策树；明确四段版本、新上游fork计数器重置、内部commit不加可见版本，并以实际已交付iOS核对companion。保留旧tag表为明确标注的历史事实。

## 局部独立审查与后续修复

- README事实独立审查0阻塞后，单独提交c7b11c28e；保留fork身份下载入口并更新保护hash。报告在evidence/readme-audit.md。
- Mac/Shared局部审查发现Soniox余额/无预算支出丢失、插件三槽title被fallback覆盖、Command Code catalog sentinel落后；已补amount/details独立通道、Prepaid balance周期、显式title优先和39-provider sentinel。Soniox含32组合并验证时间戳；新测试待最终全量编译结果。报告在evidence/mac-merge-review.md，不替代最终完整候选review。
- iOS 3.3(261)五targets；daily target、expected-use marker、4provider配色/语义与四语release notes已实现。1272项完整单测通过；新增render专项11项通过并导出9图，但图片审查发现ImageRenderer不能证明native ProgressView（占位黄条），故改用真实UIHostingController/窗口渲染复测；日本语大字预算金额被挤断，补ViewThatFits竖排fallback。Kimi缺第一方provider allowlist导致新标签不翻译，已补并加断言。
- lint发现新mock数值/新测试参数格式及上游两个超长类型，正按原行为拆helper extension修复，不放宽lint阈值。
- 官方Added/Changed/Fixed逐项清单75条在06；CloudKit源码审计NO_DEPLOY，证据见evidence/cloudkit-code-audit.md，未声称签名产物或Production实测。

## 完整本地review第一轮补修

独立完整审查发现两项Cursor v0.80用户数据遗漏：shared weekly pool仍走metadata Total标签；无上限on-demand spend被budget正limit guard丢失且无amount lane。现抽取生产调用的syncPrimaryRateWindow，复用Cursor descriptor Weekly fallback，显式label/title与legacy Total保持；Cursor limit<=0映射spend，0为真实清除值，正limit仍仅走budget。上游sanitized XSubscription真实fixture扩展验证Weekly/Total与4.47金额/周期/观察时间，另加zero/capped回归。受影响编译/测试待完整旧输入gate结束后运行，未因源码review通过提前关闭验证。

## 第二轮完整review修复

- 基线既存的 Mac fleet 子选项门控误读手机同步开关，直接影响本轮fleet能力；现改为macFleetSyncEnabled，保留可用性与版本限制，未自动打开秘密同步。
- OpenCode本地来源成本曾被fork结构化summary标成list-price estimate。增加含义为“包含来源记录金额、可混合估算”的sourceRecorded provenance；不冒充vendor billing/receipt。central tokenSnapshot覆盖fresh/cached/native/Pi窗口，按实际日期entries收窄；Mac菜单、CLI text/JSON/live history、Shared和iOS、两Mac合并均跟进。0为真实金额，缺失/非有限值不发明来源；isEstimated/coverage保持独立，不因来源记录强行清除。
- Core/window、Dashboard month/week、CLI zero/mixed解释、builtin publisher、plugin3currency×2、缓存/新扫描和双writer正反序均补断言。新增async参数fixture采用dictionary defaults、stub stores、synthetic HOME/contained widget URL、no-op reloader和显式deviceID，并串行，避免真实defaults/账号/文件探测。
- 3.3同一in-app details条目合并来源成本说明，四语齐全；未加可见版本。执行结果在03分开记录，不把源码审查当测试通过。


## 实包审查后的App Group修复（待最终执行验证）

根因是fork打包group.标识与上游既有Team前缀运行算法分别维护，普通签名/公证/短启动未验证能力。Mac App、CLI、Widget改签实际Team组；Mac Widget/CLI不虚加CloudKit/profile，主App保Production与既有profile。只读Source审计未发现Mac Sync/Shared对旧group.o1x的运行访问，iOS组及353个Archive输入保持一致。

旧ApplicationSupport快照和standard选择采用独立marker迁移，目标现有值优先；快照先copy到同目录UUID staging，成功move no-overwrite，partial失败保持源数据与重试资格，新publisher抢先写的target优先。Widget初次无snapshot或无stored时不保存默认Codex，旧Widget标准域选择仍可读，真实provider消失仍支持明确fallback；不自动写入同值旧选择，以免覆盖同时发生的新显式选择。

小签名probe实际发现Helper Bundle.main是Contents/Helpers目录，原Team解析回退Y5PE65HELJ；改为验证实际executable签名并从外层App识别debug（含symlink），after probe为3TUERHN53E。CLI在初签、copy seal、最终sign三阶段均携带AppGroup-only权限。sourceRole/resource smoke新增只读实际Group JSON供最终实包对齐，不调用containerURL/NSUserDefaults/Keychain。所有新增迁移tests为dictionary defaults/双snapshotURL/contained RecordingFileManager/synthetic HOME。

两位独立agent发现并闭环首次Widget写默认的竞态与resign shift后$1时间戳fallback错误；补真实caller顺序、partial/publisher、helper/debug及timestamp带/不带entitlement重试回归。128项受影响复测（127原审计+resource smoke suite）、full lint/build和重签包尚待通过。首次新gate在源码仍审查变更时编到旧Widget module、新test调用seam导致compile失败，400.9秒/0执行，不计成功；后续从稳定commit fresh重跑。


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
