# 实施记录

状态：`in-progress`。

当前已完成：读取规则、官方Releases、open/历史closed Issues、源commit与版本/工具链预检；建立本轮分支；形成设计。

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
