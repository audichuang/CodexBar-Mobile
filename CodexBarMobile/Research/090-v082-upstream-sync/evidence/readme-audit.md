# README 独立局部审查

日期：2026-10-28。范围：上游合并后有意调整的 README、Chatbox 文档元数据及其生成结果。本报告不代替最终完整候选版本的独立本地审查，也不构成发布批准。

## 结论

本范围阻塞问题为 0。允许将 `Scripts/check_fork_readme.sh` 的预期哈希更新为本次已独立审查的 README 候选：

`c53e809df169d190be70de5c27141375a71bc892a7156e96a460a8b8d7b83ff2`

理由是 fork README 已在合并提交原样保留，随后仅有意适配与本轮发布内容有关的事实和社区集成链接；不是为接受上游整份 README 而修改保护规则。审查期间没有修改仓库受跟踪文件，也没有更新保护哈希。

## 对象和保护规则

- 分支：`upstream-sync/v0.82.0-mobile.3.3.0`。
- 合并提交和审查时 HEAD：`2f4e6a4baa6f8a4b9d00fa3870eac074aae661c8`。
- fork 基线：`bdfb510853270c1ebf6b9d6f5ccbb289a2634db1`。
- Python 直接比较两次 `git show <commit>:README.md` 的字节串，完全相等。
- 当前 README 的 fork 开头至首个分隔线与基线字节一致；iPhone companion 定位、App Store、匹配 Mac Releases、fork 网站和作者入口均保留。
- 当前保护脚本仍使用旧哈希 `db47b54adb4ee09477ee8e6d87053b0796e490052e0b43ce0df9def8741b8801`，符合先独立审查后更新的顺序。
- SSD UUID 为 `9D5FE511-B66C-4765-BB8F-61E5ACB3969D`；仓库和报告目录可写且实际路径位于该 SSD。

## 逐项事实核对

已完整查看 `git diff v0.79.0..v0.82.0 -- README.md` 与当前 `git diff -- README.md docs/chatbox.md docs/providers.md`。

| 调整 | 证据与判断 |
|---|---|
| 106 → 110 providers | 当前注册枚举和生成脚本检查确认 110；新内容为 Soniox、Trae CN、Chatbox AI、abliteration.ai。 |
| 社交图片查询哈希 | `docs/social.png` SHA256 为 `1436859e75bb3a24c1c055714bebccdfa8b7f994636b6608bf638f995eacc77d`，README 使用对应前 16 位。 |
| Soniox | v0.80 发布证据与 `soniox.ts` 一致：组织 API key，预付 USD 余额、月支出和可选组织预算；README 未承诺不支持的字段。 |
| Trae CN | v0.80/v0.81 发布证据与 `traecn.js` 一致：浏览器 session，GetUserToken 后读取账户 credit 总量和消耗；未误称独立 API-key 授权。 |
| abliteration.ai | v0.81 发布证据与 `abliteration.ts` 一致：API key 读取 USD credits 和累计 usage；未添加推测 reset。 |
| Chatbox AI | v0.81 发布证据和 `chatbox.ts` 的 `CHATBOX_LICENSE_KEY`、原始 Authorization header、realtime license detail 请求一致；Quota/Plan、Credits、Top-up credits、Image Generation 映射支持所列功能。将泛化的 API token 改为 License key 能准确解释实际凭证，现有文档仍解释需要粘贴到通用 API key 设置框。 |
| CodexBar GTK | 上游 README 及 v0.80 发布说明新增的社区 GTK4/libadwaita 客户端；外部项目当前 README 确认读取 CodexBar CLI JSON，并支持 usage、spend 和 agent sessions。适合保留在既有 Linux desktop integration 段落。 |
| ccx | 上游 README 和 v0.80 发布说明新增的 macOS Claude/Codex task handoff 客户端；外部项目当前文档明确列出 `codexbar usage --provider both --format json` 的限额数据来源。适合既有 status bar/terminal 集成列表。 |

上游事实来源是本轮保存的 GitHub Releases 证据 `evidence/release-v080.json`、`release-v081.json`、`release-v082.json` 和合并后的插件源码。上游 README 的完整增量没有发现遗漏的额外安全或排障段落；原已与 fork 不同的 Linux/Omarchy 下载条目未被顺带覆盖。

社区链接在线核验：[CodexBar GTK](https://github.com/SaahiilM/codexbar-gtk)、[ccx](https://github.com/aaronwong1999/ccx)。这是项目说明与链接适用性核验，没有安装、运行或承诺完整端到端兼容。

## 生成文档检查

- `node Scripts/regenerate-provider-docs.mjs --check`：通过，`Provider documentation current: 110 registered providers`。
- `node Scripts/check-site-locales.mjs`：通过，23 locales、138 site messages、110 provider cards。
- 当前生成文档中仅 `docs/providers.md` 有新增工作区差异，为 Chatbox 相同 License key 文案；其余生成目录、图标和站点内容已与合并后的目标一致，无额外工作区增量。
- 本次未运行应用构建、真实账户探测或第三方集成，均不属于这次文档局部审查。

## 剩余边界

允许更新保护哈希仅针对上述精确内容；README 后续若改变，需重新核查。整个上游同步仍需完成版本、功能、同步、Duo、构建测试、产物来源、最终独立本地审查和 GitHub PR review 等完整 gate。

收尾按 codex-memory-capture 判断：本次是一次性事实核对，没有新增需要保存的长期偏好或流程信号，因此不写记忆。
