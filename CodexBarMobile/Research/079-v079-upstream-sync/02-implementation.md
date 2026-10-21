# 实现记录

Status: `in-progress`

## 合并与冲突

- 完整 merge v0.79.0（`b49d42eb53bbf79785b344492d594760dd163eac`），包含 v0.77/78；上游 Releases、所有相关非 merge commits、tag check runs 已保存 evidence。
- README 在 merge 后首先保留 fork 原字节。随后只通过 provider 文档生成器移植 Future AGI/Munito 与总数104→106；独立 review 确认身份和下载入口未改后再更新 guard hash。不移植 Linux widget 推广和上游宣传图 URL。
- 保留 fork release.sh/make_appcast/.mac-release.env、appcast、release-cli/linux-desktop、AGENTS 与版本规则；不添加上游 tag-triggered release.yml/release-policy 自动发布机制。保留 CI 的 Linux libxml2 链接验证。
- Mac 字符串冲突保留两侧 key（Voice slots/Professional voices + 新 HTTP/server/Claude 文案）。
- CodexbarApp 同时保留 Mobile sync start 与上游 opt-in HTTP server start。persistWidgetSnapshot 保留成功 publication 输入，同时刷新 CLI cache。
- suite discovery 保留 fork 重复 inventory 稳定检查，加入上游私有 HOME 环境，不触发真实 provider/Keychain。
- SyncModels 的 tcr slot predecessor 支持与 fork 无邮箱 Account N 回收合并；source prefix 必须匹配，防止跨来源删除。

## Bridge

- Future AGI / Munito 新增到 AccountIdentityComputer 的无稳定跨 Mac 身份分支；没有证据时不拼接 token/hash 伪造账号身份。
- QuotaProviderList 尾追加两个 provider：88→90（264→270 个状态订阅），不改变已发布订阅 ID 顺序。
- mock 119→121 snapshots / 109→111 IDs；两个新 provider 的窗口与详情形状按上游插件构造，23 locale 只同步数字。
- details.Row.severity 是现有 opaque JSON 的可选枚举，unknown/missing 非致命回退；Mac mapDetails 透传，旧读者忽略。
- Claude mapped cost sync 复用 tokenSnapshot(for:) 验证当前 directory/config revision；账号切换前旧 publication 不进入新账号。
- 显式展开 store.claudeSwapAccountSnapshots（同时含 tcr 来源）；新记录 key 包括来源与 slot。优先于 token-account expansion，scanner 成本保留为独立 device-local cost owner，所有 adapter 账号不复制成本，无本机路径或凭证进入 wire。

## Review 1

独立 reviewer 找到两个 P1，均已修代码并增加回归，实际测试待 03 回填：
1. published fork hash a5aa8ea108856b6d 未列 compatible predecessor，会重建历史 store。登记该 hash，并复用删除原 JSONL 后比较完整 SQLite snapshot 的参数化回归。
2. Claude 目录切换后 Mobile 直接读取旧 token publication，绕过上游 scope guard。已改用当前 scope reader，并扩展 A→B→A→unmapped 切换的 sync 前后断言。

parserLogicVersion 22→23，生成 parser hash bf8c2cb80c247dd9。Hash 兼容名单同时保留 fork 0.73/0.74 和上游 byte-marker 前驱。没有读取真实成本数据库验证，因此不声称真实账号历史金额 QA 已通过。

## Review 2–3：adapter 身份与成本根因调整

- local slot 不是跨设备账号身份。record key 改为 deviceID + source + slot + verified ownershipFingerprint；同设备换邮箱会换 key 并清理旧记录。缺失可验证归属时使用设备局部身份，不能因两台 Mac 的 slot 1 相同而合并。
- 有 historyAccountKey 时只写 opaque workspace identity（来源以 email+organization 构建）；缺少 workspace 证据时保守按设备拆分，不用邮箱把不同 workspace 错合。
- token account mapped directory 与 adapter selection 是不同状态；tcr 没有 active slot。因此成本改为 `claude-local-cost:<deviceID>` 独立 owner，quota 账号显式清除继承成本。Shared `isProviderLevelCostEnvelope` 扩展识别这一 key，新 Usage/widget 不把它算额外账号，Cost 继续计入。
- adapter 优先级复用 ClaudeSwapMenuPrecedence（包括 showSingleAccount），并观察该配置。无 snapshot 的错误账号从 accountEmail/sourceLabel 补身份，不生成 quota，时间为 distantPast，不伪装成新鲜用量。
- 旧 iOS 不识别新的 cost owner 隐藏规则，可能额外显示一张无额度的 Claude 成本卡；金额没有复制。这是旧读者的展示限制，必须在16组合与发布风险中注明。
- README social.png 已由上游替换，独立审查后同步实际图像 cache token 60784c48f741564c；fork 下载与身份仍保留。

## Review 4：避免 directory-scoped history 污染旧 iOS CWL

最终方案以01-design的第四轮根因审计为准。Mobile不发送任何directory-scoped Claude成本；已有combined成本继续原合同，切换来源时显式撤回。新增Mac fixture测试 mapped A→B→A→unmapped 的本地扫描tokens与wire拒绝，combined恢复后才发送汇总。旧机器历史不被机械删除，也不会收到B的scoped daily再和A相加。

定向测试首轮122项只有新增slot移除断言失败：生产清理要连续两个成功push确认，fixture只push了一次。已改为两周期检查，未削弱生产删除门。

## Mac 阶段 checkpoint / Review 5

第5轮独立审查确认：按“scoped仅Mac、Mobile仅combined”的范围，Mac/bridge 无新阻塞。iOS阶段必须修复 ContentView.fromLedger 对costSummaryCleared的遗漏，抑制旧CWL回填但不删历史；combined→mapped→combined补集成回归。

本checkpoint保留完整upstream merge与设计，不表示release完成。产品编译已通过，最终focused测试目标仍在编译；full tests、lint终态和draft待完成，记录在03/04。只提交本地任务分支，不合并mobile-dev、不push。

## 新 provider 身份补充审查

独立iOS contract审查确认：nil身份并不会自动按设备分组，实际进入legacy-no-identity固定bucket；新Future AGI只有loginMethod，Munito的accountID未获稳定身份审计，因此两个新provider在无token account key时会混合不同Mac组织。已在syncAccountRecordKey仅为futureagi/munito添加requested key优先、否则device-local key的回退；Wayfinder和所有旧provider行为保持不变。

补静态key/identity定向测试（两设备不同，同设备稳定，配置key不覆盖）与冻结wire矩阵内新provider的两Mac账号保留。完整回归正在以481544bc7的二进制执行；此隔离分支修复后补focused测试与重新编译，明确记录两份证据，不把旧full run谎称成新head二进制。
