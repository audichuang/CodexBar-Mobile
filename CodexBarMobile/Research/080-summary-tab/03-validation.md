# Summary Tab 验证记录

- 状态：`in-progress`，以下记录区分实际结果和待执行项。
- 本地源代码版本：iOS 3.1.0 (247)，任务分支 `feature/summary-tab`。
- 授权范围：本地实现、构建、测试与 review；未执行 push、PR、merge、TestFlight、App Review 或公开发布。

## 环境与隔离

- StudioSSD 挂载与 UUID `9D5FE511-B66C-4765-BB8F-61E5ACB3969D`、项目可写、逻辑 working 入口与 realpath 验证通过。
- 采用命令级 `DEVELOPER_DIR=/Volumes/StudioSSD/Developer/Xcode/Xcode-27.1-RC.app/Contents/Developer`，实际 Xcode 27.1 / 27A9275 / iOS SDK 27.1；未修改全局 Xcode 选择。
- 模拟器初始测试目标：`83278BCC-AE64-41F8-97A1-05CA13FA5CAE`，iOS 27.0。iOS 17 最低部署版本保持不变。
- 所有新构建、日志、xcresult 与截图位于 `/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/`。
- 新模型单测使用内存 persistence；UI 演示/测试数据用内存 Summary store，未读取实际账号凭据，不做真实 provider probe 或 Keychain 读取。
- CloudKit entitlement 保持 Production；Shared payload、CloudKit schema、Mac 生产代码与同步写入流程没有修改。

## 实际验证

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| 新模型 / 17 项测试独立 Swift 6、iOS 17 typecheck | 通过（工程协作者） | 类型检查不替代正式执行 |
| 首轮 build-for-testing | 通过 | `summary080-build.log`；最终源代码继续增量重建 |
| SummaryCardTests + SummaryPresentationTests 正式执行 | 首轮 20 项通过，新增 Extra Usage 朗读回归后纳入全套 | `summary080-focused.log`、`Summary080-focused.xcresult` |
| Summary 原生 UI 交互与四语 | 待执行 | `SummaryTabUITests` |
| 窄/宽、字体放大、浅/深色原生渲染 | 32 个页面/容器组合通过，含 Summary 八种布局 | `LayoutPreviews/*-summary.png`；设计师已检查默认、宽屏、浅深色与 AX；最终图标/标题修订继续增量验收 |
| 适用 iOS 单元回归 | 1,177 Swift Testing + 67 XCTest 全部通过 | `summary080-unit.log`、`Summary080-unit.xcresult`；含 21 项新 Summary 测试 |

## Review 与重新研究

1. 独立 review 推动修复 legacy 匿名账号显式关联、真实 quota sourceCapturedAt、完整邮箱隐私清洗、extra utilization-only 数值、Credits 非货币单位、选中账号消失导航与 Mock 可见标识。
2. 稳定身份在 merge/unmerge 中的累计污染风险按目标规则先重新研究：`01-research.md` 补根因与真值矩阵，再改为稳定身份冻结、弱 record token 学习、显式 linkage 临时可撤销投影。reviewer 已完成模型静态复查，未再发现阻断问题。
3. 设计 review 推动色板自适应换行、额度主值横排/纵排适配、VoiceOver 完整身份与重置语义、账户别名草稿实时预览。

## 证据边界

本次不会把模拟器 fixture 测试称为真实多 Mac / 双 iPhone / Production 数据验证；尚未实际运行的检查保持待执行。正式发布时还须按当时源代码、归档与选中 ASC build 的 provenance 完成发布 gate。
