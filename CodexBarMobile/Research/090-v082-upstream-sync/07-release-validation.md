# 正式交付与 Final CI 修复

状态：`in-progress`。用户2026-10-29明确授权依次合并PR225、Mac正式Release、iOS创建版本送审并审核后公开发布。

## 已执行与来源

PR225已按当前head33cc5607b的clean review、0threads和FastChecks通过后merge为03f4e96f1493b61b067fbe4e2c2c8eb692222ab4。Mac1826/iOS353输入与18ebb/a36原产物逐项相等。当前ASC已公开3.2.0，Mac companion保持3.2.0正确。Mac未tag/public，iOS未上传/创建3.3版本。

合并后Final CI40925158735按merge SHA checkout执行；Linuxdesktop40925167440通过，lint通过。Mac分片5/6、2/6在fresh编译失败：StatusItemController+UserPlugins.swift:414复杂fingerprint表达式type-check超时，未进入测试。CI使用Xcode26.3/Swift6.2.4；本机Xcode27/Swift6.4已通过的结果不能替代此工具链验收。原日志保留BuildScratch/CodexBar/Release082-20261029/ci-job-*.log。

## 修复方案（执行前）

从已合并mobile-dev创建fix/v082-release-compiler。仅把fingerprint中的可选错误/旧快照消息提为显式String局部值，八个字段改为显式[String]，再与原reset数组按原顺序拼接；不改变任何字段、分隔符、默认值或持久化行为。用既有UserPluginQuotaPresentationTests、UserPluginRefreshTests覆盖标题、reset、错误捕获年龄、语言与恢复后的fingerprint；本地build/lint后独立review、PR当前head review，合并并确认新Final CI。

因Mac shipping source变化，重建同一0.82.0.1/Sparkle175.1.3.2.0候选、签名公证并替换固定draftID427366941的ZIP/dSYM；不增加用户版本，不复用旧Mac包冒充review修复。iOS源与3.3.0(261)导出包不变，五bundle Distribution/Production、UUID与原Archive一致；source和compiled图标均已验，Apple服务端图标待上传后核。

公开前正式body移除旧no-tag/placeholder/review-in-progress描述，绑定最终reviewed merge与实际artifact source。所有三步骤后续证据保留本目录、PR评论与SSD；CloudKit NO_DEPLOY不变，16组合仍是substituted，不改写实体PASS。

## 本地复测与夹具兼容

首轮测试/build未启动：新SSD tmp目录尚未创建；补齐后测试22项/2suite通过（测试5.164s，fresh编译562.14s），swift build通过（1.57s）。首次完整lint在签名重试夹具失败，原因是TMPDIR尾斜线导致mktemp路径包含双斜线，而Path(expected)规范化后与原字符串比较不等，真实两次签名参数未改变。规范化TMPDIR后该合同通过；同时将夹具断言改为Path等价比较，原first/retry所有参数逐字一致断言保留，并分别使用带/不带尾斜线验证，避免默认macOS临时路径写法造成假失败。

完整lint还要求条件赋值使用if expression；按仓库formatter改为显式String的if expression，仍隔离于显式[String]字段数组。将对最终写法重跑相同两suite及完整lint；旧结果不冒充最终冻结输入通过。

## 最终本地 gate（冻结前）

最终源码使用formatter要求的显式String if-expression，签名夹具以Path比较实际目标，原raw参数完整相等断言不变。compiler-fix-tests-3.log：22tests/2suites通过（fresh增量编译17.25s，测试5.235s）；compiler-fix-build-3.log：swift build通过（1.17s）。compiler-fix-lint-4.log完整lint通过，SwiftLint3211文件0违规，四语533source keys、parser/hash、CI/fork政策及所有脚本合同通过；无新parser变更。签名合同另以TMPDIR带/不带末尾斜线分别通过，每轮16个entitlement/profile cases以及timestamp retry参数保留检查。

独立本地review对最终if-expression、八字段及reset拼接、六种error/snapshot状态和路径夹具补审均0findings；source报告保留SSD independent-release-compiler-source-review.json，最终提交将再次核对diff与证据再push。Mac重签公证与固定draft附件更新、当前head PR review及新FinalCI尚待完成；iOS353输入和已导出分发包仍不变。
