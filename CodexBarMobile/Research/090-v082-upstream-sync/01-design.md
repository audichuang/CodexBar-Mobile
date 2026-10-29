# 设计与验收计划

状态：`ready`，用户 Goal 已确认方案。

## Mac 集成

完整 merge v0.82.0，不以挑拣少数 commit 代替完整同步。保留上游所有 provider、CLI、Usage & Spend、Settings、更新器、安全和性能修复。v0.82 的 provider/shared app 源码目录重排应跟随，并修正 fork 仍引用旧路径的 lint/测试/hash/打包契约。

README 在 merge 中 byte-for-byte 保留 mobile-dev；之后独立审计上游 README factual diff，按需要有意移植。保留 fork CI 触发策略、发布脚本、签名与Production容器、iOS Shared模块、成本owner/clear和parser revision/hash约束。上游 CI 的执行实现改进可移植，不能恢复PR重型矩阵。

## Mac → iOS 数据合同

| 变化 | 实施判断与消费面 |
| --- | --- |
| Soniox / Trae CN / abliteration.ai / Chatbox | 注册provider、QuotaProviderList尾部追加、identity/mapper/mock/配色/图标、generic余额/额度/details；身份只用已验证稳定ID，无ID按device隔离，不用密钥作身份 |
| 月度 allowance daily target | 上游RateWindow新增quotaLimit/quotaUnit，当前Shared未携带；增加可选数值/单位，通过现有opaque payload传递。按本地日历与真实reset计算，未知/过期不显示，不猜今日消费 |
| 插件 detail pace | 上游Progress.expectedUsed当前被mapDetails丢弃；Shared增加可选expectedUsed，容错解码不抛弃有效used/total，iOS绘制本地化/可访问的pace marker |
| Kimi总量细分/赠送余额与到期、Trae额度、Cursor周池、WorkBuddy周期、Gemini Argon | 复用现有rateWindows/details/budget等结构；补第一方语义四语，不翻译动态用户插件文本 |
| Codex固定30天配速 | 核对iOS窗口选择/period判别，不能把30天当Weekly；采用实际duration，保留旧payload fallback |
| 插件刷新失败/陈旧时间、自定义窗口标题/reset | 核对producer失效状态经现有status/timestamp/wire与iOS消费者一致；保留last-good数据且有错误/age，不当新鲜成功 |
| Claude Cowork去重/未知价格下界、OpenCode v2/opt-in Codex成本、WAL扫描 | Mac完整保留；核对fork成本owner、coverage、零值/未知、历史清理及iOS ledger/widget统计不双算、不虚构金额 |
| fleet菜单/插件菜单选择、CLI登录、凭证命令、更新器/Liquid Glass | Mac完整支持；不把凭证或Mac控制API塞到wire，iOS仅消费实际可用数据。Mac session request drilldown未被现有sync模型提供，明确无远程请求详情控制面，不伪造可用功能 |

计划新字段均是现有DeviceProviderSnapshot.payload内的optional JSON；不提升providerPayloadVersion，不新增CKRecord字段/类型/index/query。最终diff必须按cloudkit-deploy-audit复查，当前是设计预判，不冒充最终NO_DEPLOY或Production实测。

## Duo 与回归

不重构现有容器。保护Summary全宽网格、显式点卡才开详情/返回保留筛选，Usage稳定账号与导航，Cost报告/日期和分享草稿/取消。新增数据不能挤掉普通iPhone和Duo的操作入口；检查四语、长文案、light/dark、大字号相关路径。实际Duo外/内屏横竖与状态连续性必须留证，不使用旧截图冒充本轮通过。

## 验证策略

- Mac：swift build、完整lint、隔离test.sh全量、focused新provider/pace/plugin/成本/CLI/身份/SyncCoordinator，回归fork关键功能。禁止真实Keychain读取或cookie导入；offline fixtures/test stores。
- iOS：xcodegen、完整单测（含WidgetSnapshotBuilderTests）、新增wire/pace/detail/provider测试、Release模拟器和device Archive，最低OS fallback。
- 同步：冻结真实old模型与consumer；16组合区分两Mac独立writer和两iPhone独立cache/reader，多设备去重、撤回、合并顺序、未知字段/旧payload、陈旧与错误。若无法组织真实四设备，逐格substituted并提供实际替代测试/剩余风险，不能称实机PASS。
- Mac打包：最终源commit、签名/公证/Production entitlement、ZIP/dSYM匹配、appcast候选版本单调与签名；仅--draft-no-tag-push，实际source与placeholder target分记。
- 先自查和独立本地review清零，再push/PR与exact-head GitHub Codex review，逐线程修复/回复/resolve，最终gate和Fast Checks成功。影响binary的修复重建候选产物。不得merge/发布。


## iOS局部review补充

Kimi gift新增Core/Shared Row.expiresAt optional（旧/坏optional容错），保留Mac原secondary文字，手机根据机器时间本地化expiry并在缓存到期后禁用进度、显示Expired；monthly稳定row ID用numeric progress重建读端百分比。旧payload无machine expiry不猜Mac本地化日期，保留原文与既有陈旧提示。动态gift名称保留原样，仅默认Bonus credits翻译。Daily target已知units走四语语义keys，未知自定义unit原样。Copilot无duration的calendar月在桥接端依据既有descriptor.pace标period.monthly，保留显式period、原windowMinutes和真实reset。16组合需重跑新expiry，CloudKit仍仅opaque optional JSON；最终代码审计与测试结果待刷新。


## 最终实包审计补充方案：Mac App Group（2026-10-28）

独立实包审计发现基线已有错配：AppGroupSupport实际请求3TUERHN53E.com.steipete.codexbar（debug加.debug），但Mac包只声明group.com.o1xhack.codexbar，且现有Developer ID profile未授权group.组。Apple官方说明Team前缀组可免profile，但必须在签名中声明；notary/Gatekeeper/短存活不能证明共享缓存可用。参考：https://developer.apple.com/documentation/xcode/accessing-app-group-containers 。Mac Widget只有AppGroup角色，不需要CloudKit/profile；主App继续使用已有CloudKit Production profile。

采取最小签名修复：Mac App/Widget统一签现有运行算法的Team组，debug规则一致。iOS group.com.o1xhack与CloudKit wire/schema不变，不新建Apple账号资源或迁移身份。为旧无权限时的Application Support fallback及standard widget选择补独立、copy-only/目标优先的迁移；保留源文件、原时间和已存在选择，copy失败保留重试资格，不伪造新快照。所有迁移测试用dictionary defaults、双snapshot URL、synthetic HOME与contained recording FileManager。

增加打包合同断言（两个签名组==实际运行ID，release/debug/adhoc行为）及AppGroup/Widget/Settings专项。重签/公证并替换本轮自己创建的draft附件，保留原坏候选证据；版本不变。最终签名包核对真实请求组、双架构/最低OS/签名/主App Production、客户端公钥与附件哈希，再完成完整候选review。
