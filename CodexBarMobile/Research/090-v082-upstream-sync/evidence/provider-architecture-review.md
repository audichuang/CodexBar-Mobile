# Provider architecture gate 失败独立审计

日期：2026-10-28。只读审查 log、精确allowlist、scanner算法及对应产品源码，未修改tracked文件/编译/启动测试。

## 结论

目前未发现新增产品逻辑缺陷；失败来自合理上游新增provider/fork语义桥接和代码抽取后的exact allowlist漂移。应更新5个已有fingerprint、删除1个已陈旧的occurrence-2表项、补3个新exact构造；另外建议为被40行cluster边界切出的xAI/Grok尾部补独立exact项，保持旧显式审计强度。不能扩大窗口、排除文件/provider、删失败断言、放宽exact匹配或自动接受所有found值。

**日志准确计数：** 真正失败的test只有 `cross provider case clusters are derived or specifically justified`。其失败数组有12条诊断，其中3个fingerprint失配又重复产生unjustified诊断，归并为9处需处理构造。框架summary的14 known issues来自ProcessEnvironmentTests的敏感环境脱敏负向自测（failed expectations hide captured environment contents），不等于14个产品缺陷；不要将15 issues（含14known）说成15个未解决产品问题。

## 精确表项

完整可复制字段（path/anchor/occurrence/IDs/count/fingerprint/reason）在 `provider-architecture-review-anchors.json`。其中59引用的AccountIdentity长表保留完整排序和相对行偏移，不在正文截短后当作可执行表。

| 构造 | 操作与精确参数 |
| --- | --- |
| SyncCoordinator primary（1191） | 更新旧 `let label: String? = if provider == .alibabatokenplan {` 项；IDs=[alibabatokenplan,cursor,grok,ollama,qwencloud]；count6；fingerprint=[alibabatokenplan@0,grok@3,ollama@5,cursor@7,qwencloud@9,qwencloud@11] |
| SyncCoordinator account key（1500） | 更新 `case .wayfinder:`；IDs=[abliteration,chatbox,futureagi,gemini,munito,soniox,traecn,wayfinder]；count8；[wayfinder@0,munito@2,abliteration@11,chatbox@11,futureagi@11,soniox@11,traecn@11,gemini@13] |
| SyncCoordinator amount首段（1613） | 更新 `case .neuralwatt, .zenmux, .lithosai:`；IDs=[aiand,claude,claudeplatform,codex,cursor,fireworks,lithosai,neuralwatt,soniox,xapi,zenmux]；count11；[lithosai@0,neuralwatt@0,zenmux@0,aiand@4,cursor@4,fireworks@4,soniox@8,codex@18,claude@26,xapi@30,claudeplatform@36] |
| SyncCoordinator details（932） | 新增anchor `if provider == .soniox, let cost = providerCost, cost.limit <= 0, cost.balance != nil,`；IDs=[claude,soniox]；count2；[soniox@0,claude@8] |
| SyncCoordinator secondary/tertiary（1233） | 新增anchor `let label = provider == .alibabatokenplan`；IDs=[alibabatokenplan]；count2；[alibabatokenplan@0,alibabatokenplan@11] |
| MockProviderInjector尾部（2032） | 新增anchor `providerID: "chatbox", providerName: "Chatbox AI",`；IDs=[chatbox]；count1；[chatbox@0] |
| UsageStore+QuotaWarnings（61） | 原anchor不变；IDs=[aixy,amp,antigravity,claude,cursor,mimo,qoder]；count11；[antigravity@0,antigravity@9,cursor@12,mimo@16,qoder@16,amp@20,aixy@22,amp@27,aixy@29,claude@35,aixy@36] |
| UsageStore+Refresh（791–820） | **只删除** occurrence2 / IDs=[codex] / count1 / [codex@0] 的陈旧项；**保留不改**现有occurrence1 / IDs=[codex,deepseek] / count4 / [codex@0,deepseek@11,deepseek@19,codex@29] |
| AccountIdentityComputer（47） | 原 `case .codex:` anchor不变；在原55IDs加入abliteration/chatbox/soniox/traecn，count59；完整fingerprint见JSON |
| amount尾段（1656，额外保持覆盖） | 新增anchor `case .xai:`；IDs=[grok,xai]；count2；[xai@0,grok@3] |

这些行号仅说明本次源码位置；真正匹配用exact anchor，不应按行号忽略变化。若主线程再插入comments/调整语句，重新计算clusters并核对语义，不得机械沿用偏移。

## 每处语义理由与可否derive

1. **Primary/secondary/tertiary labels：** 已复审真实Cursor unified fixture。周池在Core中成为primary，无显式label/title，需descriptor Weekly；legacy Total仍保留。Alibaba按真实duration命名，Grok/Ollama/Qwen用provider-owned动态语义，显式label/title始终优先。此次抽取把旧7ref cluster分成primary6ref和Alibaba2ref，不是漏掉两个case。可在未来基于descriptor字段统一部分取label接口，但通用positional metadata不足以推断所有fork wire语义；此轮现有映射有具体必要性，不需为通过gate重写架构。
2. **Source/account keys：** Munito只有API签发organization ID能稳定合并；Wayfinder/四新providers没有可验证账号证明，保留device bucket，避免拿API/license key当identity合并不同凭证；Gemini Web与CLI隔离。源不可验证本身不能从ratewindow/branding推导，provider-specific约定合理。
3. **Amount语义：** ProviderCost.used并非统一spend，某些provider用它表示余额；Soniox prepaid balance与月spend独立，Cursor无上限为spend，正limit走budget避免重复。Codex/Claude/X API/Claude Platform与xAI/Grok各自余额约定不能安全靠limit字段单独derive。新Soniox代码增加长度导致原40line cluster切分，xai/grok未被删除。
4. **Details持久化：** Soniox两种金额要通过providerAmount+details都保留；Claude reset credit inventory明确live-only，不能持久化到iOS。原Claude marker在cluster首Soniox之后，scanner不能用它解释已开始的构造；必须给整个新cluster具体理由。不能将Claude过滤推广到所有provider或丢掉Soniox月spend。
5. **Mock尾部：** 具体测试profile刻意枚举provider/account/quota形状，用来证明125条mock均通过两写路径。Chatbox刚好在旧cluster外，补具体fixture理由合理；derive通用空profile会丢失该端到端覆盖目的。
6. **Quota warning：** 上游Cursor shared weekly pool从primary映射到weekly警告lane，避免按session语义提醒；旧Antigravity families、balance suppression、Amp/Aixy动态labels、Claude/Aixy extras规则保留。该producer语义不是简单两个槽位可推导，新增cursor token合理。
7. **Refresh occurrence（纠正第一版建议）：** `resolveAnchorLine`按trimmed整行exact比较，独立brace anchor仅820行；315的else-if及689的inline expression均不匹配。但anchor可位于cluster内部，不必是cluster首行。当前cluster从791行Codex开始，802/810行DeepSeek、820行Codex，相邻gap=11/8/10均≤12、总跨度29<40，所以它是一个IDs=[codex,deepseek]、count4的完整cluster。现有occurrence1项正好匹配这个4ref cluster，因此gate不报它的fingerprint mismatch；occurrence2则找不到第二个anchor。**必须保留现有occurrence1的4ref项，仅删除stale occurrence2的1ref项**。先前建议occurrence2→1未检查关联既有表项，是错误建议，已撤回；该建议未被写入tracked文件。若机械改成1会同时造成duplicate cluster及错误count1，降低覆盖或直接失败。widget owner reconciliation产品代码仍被现有4ref项覆盖，无需删产品分支。
8. **AccountIdentity：** 新4provider加入显式non-Tier-A nil集合，59引用合理；不能替换成泛化default、直接按email/API key merge或删掉穷举，gate仍应发现未来新provider未审身份契约。

## 一个未报错但应保持的审计覆盖

amount新首cluster止于ClaudePlatform@36，xai位于原首行之后43行，于是xai/grok成为新2ref cluster。当前未报unjustified是因为Claude Platform的具体marker在其前40行窗口、且前cluster已有allowlist，marker尚未消耗，刚好被借用。这不是该理由真的解释xAI/Grok。新增精确tail条目可保留原旧11ref表曾对xai/grok提供的显式审查覆盖，比仅删去旧IDs更严谨。此处未发现产品金额实现错误。

## Review轮数与后续验证

当前是完整独立本地Code Review第1轮之后的测试收尾/精准基线修复，不应把resume方案审查次数当作完整candidate review第2/3/4轮。此前Cursor两finding已修源码并复审；完整候选/产物最终review仍须执行。尚未push/请求GitHub Review，因此remote PR review rounds=0。

Git skill五轮后architecture-audit条款位于PR `review→fix→test→reply→resolve→push→review`循环；本地多次遇到测试旧表不自动等于已经五轮PR review，但本次重复模式应集中审计count/catalog/anchor/fingerprint，避免继续只改下一条失败。无需当前发PR评论或削弱gate。

实施精确表项后，必须重编并运行整个ProviderArchitectureGatekeeperTests（包括负向scanner自测），再续跑未覆盖完整库存；保留失败log和新source/binary provenance。如果表项/marker补齐再改变产品逻辑，相关先前通过证据要重新评估，不能沿用本报告的源码结论。

## 精确apply要求

`delete-stale-exact`必须按path+anchor+occurrence=2+IDs=[codex]+count1+fingerprint=[codex@0]唯一匹配后删除该整个AllowedProviderConstruct及相邻分隔逗号。不能只按path+anchor匹配，也不能把occurrence1原记录覆盖。其余update-existing应唯一匹配对应既有项；如有重复，停止而不写文件。JSON的preservedRelatedConstructs提供occurrence1完整保留身份，供删除前后assert。最终操作数：5更新、1删除、4新增；不再是6更新。
