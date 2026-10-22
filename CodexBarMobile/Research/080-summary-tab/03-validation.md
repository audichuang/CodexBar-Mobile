# Summary Tab 验证记录

- 状态：`done`（本地交付）；日期：2026-10-22。
- iOS 3.1.0 (247)，分支 `feature/summary-tab`。未改变 MARKETING_VERSION。
- 本次范围为本地实现、构建、测试、设计与独立 review；未执行 push、PR、merge、TestFlight、App Review 或公开发布。

## 环境与隔离

- StudioSSD 挂载与 UUID `9D5FE511-B66C-4765-BB8F-61E5ACB3969D`、项目可写、逻辑 working 入口与 realpath 验证通过。
- 命令级 `DEVELOPER_DIR=/Volumes/StudioSSD/Developer/Xcode/Xcode-27.1-RC.app/Contents/Developer`，实际 Xcode 27.1 / 27A9275 / iOS SDK 27.1；未修改全局 Xcode 选择。iOS 17 最低部署版本不变。
- 主要目标：iOS 27.0 iPhone `83278BCC-AE64-41F8-97A1-05CA13FA5CAE`；另用 iOS 27.1 Duo `FA6BFB39-3400-472B-8ED0-CD10A87F629E` 做 sim-use 原生预测卡创建检查，preflight 通过。
- 所有新构建、日志、xcresult 与原始截图位于 `/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/`。精选截图复制到本目录 `evidence/`，不是 HTML 渲染。
- 新模型单测使用内存 persistence；UI 演示/测试数据用内存 Summary store。没有真实 provider probe、浏览器 Cookie 导入或真实 Keychain 读取。
- CloudKit entitlement 保持 Production；Shared payload、CloudKit schema、Mac 生产代码与同步写入流程没有修改。

## 实际验证

| 项目 | 结果 | BuildScratch/CodexBar 下证据 |
| --- | --- | --- |
| 工程协作者独立 Swift 6 / iOS 17 typecheck | 通过；不替代正式执行 | 新模型与最初 17 项测试 |
| 首轮 build-for-testing | 通过 | `summary080-build.log` |
| 全套 iOS 单元与既有渲染回归 | **1,177 Swift Testing + 67 XCTest，0 失败** | `summary080-unit.log`、`Summary080-unit.xcresult` |
| 最终模型、显示与布局修订后专项 | **21 项新 Summary 测试 + 1 项 32 组合页面渲染，0 失败** | `summary080-final.log`、`Summary080-final.xcresult` |
| 原生关键交互、四语 | **3 UI 测试通过**：取消不留卡、创建只加一张；Provider 筛选；倒计时/名称/颜色；en、zh-Hans、zh-Hant、ja | `summary080-ui.log`、`Summary080-ui.xcresult` |
| 日期、额度、倒计时、余额的原生混排 | **新增 1 XCTest 通过**：正常手机、窄侧栏深色、AX 单列三组合；80% 合成窗口由真实 resolver 算出重置前耗尽日期 | `Summary080-polish2.xcresult` 中 `SummaryCardRenderTests`；`Summary080-card-variants/` |
| 编辑器常驻标签最终焦点回归 | **最终 UI 测试通过**：实际输入、改倒计时、改颜色并保存 | `summary080-editor-final.log`、`Summary080-editor-final.xcresult` |
| 原生预测卡创建 | sim-use 完成 Provider → Claude → 预计耗尽 Weekly → 自定义 → 添加；6 张变 7 张，显示真实的 Lasts until reset | `summary080-duo-added-depletion.png` |
| 本地源码/文案检查 | SwiftFormat 新 Swift 文件通过、`git diff --check` 通过；58 个新 key 四语均 translated；仓库 audit 493 个源码 key 全覆盖 | `summary080-format.log`、`summary080-localization-audit.log` |

全套回归后只做已明确发现的显示、编辑器与可访问性修订；按改动范围做专项重建与复测，没有重复跑无关矩阵。

## 原生截图

- [最终手机界面：百分比、倒计时、自定义紫色与默认白色](evidence/native-summary.png)
- [最终编辑器：常驻字段标签、预览与颜色](evidence/native-editor.png)
- [真实双栏：指标网格与选中账号详情](evidence/native-wide.png)
- [四种卡片混排：合成数据的日期、余额、百分比、倒计时](evidence/native-card-variants.png)
- [窄侧栏深色](evidence/native-card-variants-dark.png)
- [AX 大字单列](evidence/native-card-variants-accessibility.png)

后三张是明确标注 synthetic data 的独立测试夹具：高配速窗口由 resolver 产生 emptyAt；不修改正式 PreviewData，不把合成日期写入账号或生产数据。默认演示账号的配速均可持续到重置，因此原生创建流程忠实显示 Lasts until reset。

## Review、失败修复与重新研究

1. 工程与独立 review 修复 legacy 匿名账号显式关联、真实 quota sourceCapturedAt、完整邮箱隐私清洗、extra utilization-only 数值、Credits 非货币单位、选中账号消失导航、Mock 可见标识与 VoiceOver。
2. 稳定身份 merge/unmerge 的累计污染按目标规则先重新研究：`01-research.md` 记录根因与真值矩阵，再冻结首次稳定身份集合、学习弱 record token、将显式 linkage 作为可撤销投影。正式测试覆盖拆分后缺失与恢复，不凭名称改绑。
3. 设计 review 修复色板溢出、大字主值、默认标题保留套餐后缀、装饰 monogram 缩成省略号、预测卡窗口名称被长前缀截掉，以及真正宽屏的 sizeClass 映射。
4. 编辑器 LabeledContent 增量版本在真实 UI 回归中暴露行 label/输入框合并导致点按后无键盘焦点（`Summary080-polish2.xcresult` 的 UI 子测试失败，渲染子测试通过）。改成常驻 caption + 独立全宽输入框，未用测试坐标绕过；最终 `Summary080-editor-final.xcresult` 通过。新增渲染测试的初次参数标签编译错误已按现有 initializer 修正后运行通过。
5. 设计师完成以上六张原生图片审查；独立 reviewer 最终增量复查无阻断，可以本地交付。

## 可重复运行

先 `xcodegen generate --spec CodexBarMobile/project.yml`，使用以上命令级 DEVELOPER_DIR。所有 xcodebuild 均指定：

```sh
xcodebuild -project CodexBarMobile/CodexBarMobile.xcodeproj -scheme CodexBarMobile \
  -destination 'platform=iOS Simulator,id=83278BCC-AE64-41F8-97A1-05CA13FA5CAE' \
  -derivedDataPath /Volumes/StudioSSD/Developer/BuildScratch/CodexBar/Summary080 \
  -resultBundlePath /Volumes/StudioSSD/Developer/BuildScratch/CodexBar/<fresh-result-name>.xcresult \
  -only-testing:CodexBarMobileTests test CODE_SIGNING_ALLOWED=NO
```

UI 改为 `-only-testing:CodexBarMobileUITests/SummaryTabUITests`；最终窄专项使用 `SummaryCardTests`、`SummaryPresentationTests`、`SummaryCardRenderTests` 和必要的页面渲染测试。结果目录使用新名字，不覆盖已有 xcresult。

## 证据边界

这是本地模拟器、合成 fixture、原生 SwiftUI 渲染与独立源码 review 的完成证据，未声称真实多 Mac / 双 iPhone / Production 同步验证或物理设备折叠验证。同步协议没有改变；正式发布时仍须依当时源代码与归档完成适用发布 gate，不能把本次未上传的模拟器二进制当作已发布版本。
