# 078 — iPhone Duo：用量决策、成本分析与分享编辑

- 状态：`in-progress` — 本地实现和自动化验收完成；原生展开/半折叠姿态验收受 Xcode 系统组件初始化阻塞。用户已明确授权实施，无需再次确认。
- 日期：2026-10-20
- 分支：`feature/iphone-duo-experience`
- 基线：`5f1d7ec9c`，iOS 2.10.0 (243)，最低 iOS 17.0，Swift 6。
- 范围：iOS 主应用及相关测试；不修改 Mac、同步协议或 CloudKit schema。

## 1. 产品判断

CodexBar 的核心任务是判断哪个账号还有额度、何时恢复、额度为什么变化，以及成本花在哪里。展开应帮助用户在保留上下文的情况下查看细节。

本方案中的“两屏”指展开内屏中的两个内容区域。折叠关闭后继续在外屏操作同一任务；不另建 scene，不同时驱动内外屏，也不引入相机 accessory。

Usage 用导航型双栏；Cost 用互补分析区域；分享编辑用预览与操作区域；设置用分类与详情。不能只把所有页面套进同一个横向双栏。

## 2. 已核实的环境和资料

- Apple Workflow Skills 安装版本 0.3.3，`check_update.py --force` 返回 `up_to_date`。
- 使用其 adaptive-layout、duo-layout、duo-bars、duo-validation、布局案例和交互案例指导；它们提供设计依据，不替代运行测试。
- 默认 `/Applications/Xcode.app` 是 Xcode 27.0 / 27A266a，只带 iOS 27.0 SDK。
- 本次指定 `DEVELOPER_DIR=/Volumes/StudioSSD/Developer/Xcode/Xcode-27.1-RC.app/Contents/Developer`，实测 Xcode 27.1 / 27A9275、iOS 27.1 SDK。目录保留历史 RC 名称；Apple 2026-10-15 正式发布的 Xcode 27.1 也是 27A9275。
- 本机还有 Xcode 27.2 beta 2 / 27B5028f。用户要求采用支持 Duo 的最新 27.1 版本，本任务不选择 27.2。
- Apple 2026-10-19 当前发布记录为 Xcode 27.2 RC / 27B48 和 iOS 27.2 RC / 24B115；此项是更新核对，不是本次工具链要求。
- 原有 Duo `4A3A26E1-A464-4B67-A120-23E0D6FACD9D` 启动报 runtime profile 不匹配；新建本任务专用 Duo `FA6BFB39-3400-472B-8ED0-CD10A87F629E` 后成功启动 iOS 27.1。iPad QA 为 `E446FFE7-8834-495D-926B-C4D4803F4F1C` / iOS 27.0；旧系统兼容 QA 为 `F7DF92DB-2C2F-4475-8F19-615225381DB7` / iOS 26.5。未清除或改动其他项目设备。
- 27.1 SDK 的 SwiftUICore interface 中已找到 ArrangementView、SplitArrangementViewStyle、reservedRegions、toolbarVerticalEdge 等声明。最小 `ArrangementView + .split + reservedRegions(.division)` 文件经 Xcode 27.1 `swiftc -typecheck` 通过，target 为 `arm64-apple-ios17.0-simulator`，新 API 用 `@available(iOS 27.1, *)` 隔离。应用已使用同一工具链编译并运行；结果见第 7 节。
- StudioSSD 挂载、UUID `9D5FE511-B66C-4765-BB8F-61E5ACB3969D`、项目和 BuildScratch 可写及实体路径检查通过。
- 上游 `steipete/CodexBar` PR 查询 `Duo` 返回空；`adaptive` 结果主要为 Mac 刷新与成本窗口调整，未找到可直接复用的 iOS Duo 方案。这是有限查询结果，不宣称全库不存在相关代码。

参考来源：

- [Apple：Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)
- [Apple：ArrangementView](https://developer.apple.com/documentation/swiftui/arrangementview)
- [Apple：Xcode 27.1 正式版记录](https://developer.apple.com/news/releases/?id=10152026a)
- [Apple：Xcode SDK 与系统要求](https://developer.apple.com/xcode/system-requirements)
- [Apple：当前发布列表](https://developer.apple.com/news/releases/)

以上两个 Duo 文档已读取 Apple 提供的 Markdown 正文；文档中的布局能力必须通过本应用实际流程验证。

## 3. 现有实现与具体问题

| 位置 | 源码观察 | 设计影响 |
| --- | --- | --- |
| ContentView 根视图 | 对 TabView 强制 `.horizontalSizeClass = .compact`；手工右侧导航仅在 illustrative preview 开启 | 不能把预览中的侧边按钮当成真实 Duo 适配；27.1 使用原生 bars，移除对系统适配的根级压制后回归 iPad |
| MobileAdaptiveLayout | 宽 ≥700、高 ≥600 才 roomy；只有宽大于高才 list/detail | 宽阔竖屏仍显示卡片网格；两栏是否可读应由实际可用空间和文字大小决定，不把竖屏等同单栏 |
| UsageTab | NavigationSplitView 已存在，选择为 UsageCardKey；首次进入宽屏会自动选择首项并将 compactColumn 改为 detail | 需要区分自动预览与用户主动打开，防止只展开再关闭就被带入首个账号详情 |
| ProviderListView 宽屏行 | 仅保留名字、账号副标题、pin/checkmark | 用户判断剩余额度仍要逐项点击；宽屏列表应保留关键额度和重置提示 |
| ProviderDetailView | 多账号选择是本地数组下标；图表日期为本地 state | 同步排序变化和折叠重组时要按稳定账号身份保留选择，不能默默换账号 |
| CostDashboardView | 单个 ScrollView 内 AnyLayout 双列，底部再堆 Model Mix / budgets；日期选择与 chart scroll 已存在 | 长页面两列仍一起滚动；分清总览与趋势，同时保留缺失数据和多 Mac 统计口径 |
| CostShareSheet | GeometryReader 条件分支在 HStack 与单列 ScrollView 间切换；Share Image 按钮跨整个底部 | 分享草稿虽在父层，子视图和滚动位置仍需验证；折叠时预览和编辑应分区，分享按钮属于编辑区 |
| UsageSortEditorView | 仅手动排序允许 `.onMove`，置顶与普通分组分别处理 | 延续这一明确入口，不让普通拖动成为修改账号或排序的隐式操作 |
| MobileAdaptiveLayoutTests | 现有静态尺寸截图是 illustrative preview，未证明原生 Duo 姿态与输入连续性 | 新验收必须运行生产页面，观察折叠后的真实操作结果 |

本次未运行真实账号 provider 探测、Keychain 读取或日历写入。先用现有合成 fixture 覆盖多账号、错误、缺失历史，真实同步验收若后续需要则单独记录。

## 4. 每个页面如何使用空间

### Usage：保留“选谁”的上下文，再回答“还能用多少”

| 状态 | 第一内容区 | 第二内容区 | 行为 |
| --- | --- | --- | --- |
| 外屏 / 狭窄窗口 | 现有用量卡片列表或已打开的账号详情 | 不常驻 | 点击进入详情，返回回到原列表位置 |
| 展开且两栏可读 | 服务商／独立账号列表、搜索、置顶、当前主要额度与下次重置 | 所选账号的完整额度窗口、配速、reset credits 到期、成本与历史、同步来源 | 左侧点击更新右侧；不同 provider 的额度窗口保留原名和单位 |
| 书本式部分折叠 | 同上 | 同上 | 导航容器处理 fold，按钮与关键数值不压在活动折叠区 |
| 上下分区或每区高度不足 | 保留可用的当前导航页，列表通过返回／侧栏入口可达 | 不强制上下各一半的长列表和长详情 | Usage 的核心是阅读与选择，不强加桌面控制台布局 |
| 辅助功能大字号 | 当前列表或详情单列，允许内容自然换行 | 明确导航入口 | 不以缩字体维持两栏 |

列表摘要不能简单统一成“周剩余百分比”：Codex/Claude 的周期窗口、余额型 API 服务和多模型窗口具有不同含义。优先复用 UsageCard 已有的展示规则；缺失额度显示未提供，错误/陈旧来源保留提示，不当作零或可用。

默认展开可预览第一张卡，但只有用户点击后的选择才能改变关闭后的导航位置。已打开账号 B 后展开再关闭，仍是账号 B。账号身份用现有稳定 key / identity，不使用可变下标；账号消失才按现有 selection resolver 回退，并给出可理解的上下文。

### Cost：一侧交代统计口径，一侧观察时间变化

| 状态 | 第一内容区 | 第二内容区 |
| --- | --- | --- |
| 展开宽窗口 | Overview、统计口径／缺失提示、Provider Share、Model Mix、预算 | Daily Spend、Token Activity、Subscription Utilization |
| 外屏 / 狭窄窗口 / 大字号 | 单条完整滚动阅读顺序：总览与 provider/model 明细、预算 → 日成本趋势、活跃热图及订阅用量 | 无隐藏内容，所有部分仍可达 |
| 部分折叠 | 优先保持完整图表及其选中日期读数位于同一可用区域 | 在空间足够时分区；不足时回到可滚动单列 |

两区属于同一个报告周期和数据版本；不复制查询或刷新任务。每区可独立滚动，切回单列时保持同一报告与图表日期；跨姿态的精确像素滚动位置尚未列为通过，不能把子视图身份稳定等同于精确阅读位置已验证。

日成本图拖动只改变日期读数，热图点击只改变热图日期。它们的时间口径和数据覆盖可能不同，本轮不悄悄联动成一个跨图筛选器。Provider Share 仍标明当前报告周期，不能因选中某天而让用户误以为它变成当日构成。

### 分享卡片：最适合做明确的两区域协作

| 状态 | 预览区 | 编辑区 |
| --- | --- | --- |
| 展开平放且宽度足够 | 左侧大预览，可完整看到导出边界 | 右侧模板、周期／热图区间、账号范围、Share Image |
| 桌面折叠且上下区域可用 | 上半屏预览 | 下半屏编辑和分享，按钮只归编辑区 |
| 外屏 / 狭窄窗口 / 大字号 | 同一页面中的预览 | 下方完整编辑控件；预览/编辑均可通过滚动到达 |

模板、日期范围、账号范围和加载结果由分享会话持有。最终容器使用稳定子视图的自定义 Layout 和 reserved regions，不随几何变化改用另一棵视图树。打开已有 picker 再折叠，应能继续选择或按系统规则关闭并保留草稿；关闭分享编辑不触发导出，姿态变化不自动分享。

使用 ArrangementView 的 split 风格评估原生 fold 布局，不用覆盖在预览上的 controls。必须确保紧凑状态不会因为系统只显示 primary 而丢失编辑入口；必要时提供显式“预览／编辑”切换。原生容器未满足这一契约时使用稳定身份的自定义 Layout + reserved regions；不为使用某 API 牺牲操作可达性。

### 设置、同步与阅读页面

- 展开：设置分类与所选设置详情。保留 About & Sync、用量、成本、小组件、日历等现有分类。
- 版本记录和帮助保持可读行宽，额外空间不用于放另一份重复正文。
- 合并／归档设备、清除历史、日历权限等动作仍从显式入口进入；折叠不是确认或提交。
- 操作 sheet 持有稳定目标 ID；折叠过程中目标消失时失效并关闭，不能转而操作列表新占据同一下标的对象。

## 5. 拖动与连续性交互契约

| 操作 | 具体结果 | 不允许的副作用 |
| --- | --- | --- |
| 拖动系统窗口边缘／分屏尺寸 | 根据当前容器空间重排，在两栏最低可读尺寸以下回到单列 | 不切换 tab、不重置账号、不重跑同步或取消草稿 |
| 展开／关闭 | 恢复同一导航任务；保留账号、图表日期和搜索文本；阅读位置连续性单独验证 | 不把自动预览当作用户主动进入详情 |
| 日成本图拖动／横向滚动 | 使用现有图表交互选择日期或浏览历史，选中读数与图一起避让折叠区 | 不同时触发全页换栏或账号切换 |
| 手动排序的拖动手柄 | 在排序编辑器内完成置顶组或普通组的重排；沿用当前持久化语义 | 不在普通列表误触排序，不隐式置顶、跨账号合并或修改 Mac |
| 拖动过程中窗口缩窄／折叠 | 未完成的拖动取消或由系统结束；完成后按稳定 ID 应用一次 | 不重复保存，不按过期数组下标处理 |
| 普通 Usage 卡片长按／拖出 | 本轮保持已有菜单和滚动行为；账号选择仍用点击 | 不把拖到另一屏解释为换登录账号、转移额度或合并身份 |
| 搜索输入 → 展开 → 关闭 → 继续输入 | 搜索词保留，输入路径继续工作；用户明确收起键盘后不再次强抢焦点 | 不仅凭文本还在就宣称编辑连续性通过 |
| 分享模板 picker／菜单展开时折叠 | 当前选择保留，popover 锚点仍指向实际触发控件或合理关闭 | 不漂移到另一个账号／设置项，不自动提交 |

不增加自绘分栏拖动手柄：本轮的栏宽由内容最小宽度和系统容器共同决定。用户拖系统分屏尺寸有明确反馈；额外自定义分隔条会与折叠区和图表手势竞争。也不新增跨服务商“额度比较”功能，因为不同重置周期和单位不能直接排序；若以后做，需要独立明确可比口径。

## 6. 实施分期与状态所有权

1. 根导航与 layout policy：移除生产视图对系统 bars 的不必要压制，保留 iOS 17+ fallback；按本地容器和文字尺寸决定可读列数。原生 toolbar 使用 title + symbol，保证 overflow 可辨识。
2. Usage：增加可判断额度的紧凑行；区分预览与用户选择；稳定账号身份；保持搜索与详情 state 不因姿态分支重建。
3. Cost：提取总览／趋势组件和会话状态；数据加载仍属于 CostTab；绑定日期和滚动锚点，复用同一个数据口径。
4. 分享：稳定编辑会话与 pane-local 分享操作，27.1 arrangement / reserved-region 路径和旧 OS 紧凑路径。
5. 设置和辅助页：读宽、sheet/menu 锚点、目标身份和原生 bars 回归。
6. 四语言文案、当前版本 release notes 合并、CHANGELOG、build number 和验收记录。在可交付时统一递增 build，保持营销版本 2.10.0，除非后续用户另定发布版本。

模型接口先于视图逻辑：layout policy 输入可用尺寸、文字大小、必要的可用区域，输出页面布局；场景内状态持有 tab、账号稳定 key、搜索、日期和分享草稿；数据加载服务不依赖布局枚举。协议仅用于实际边界，不为每个纯值计算增加空抽象。

主要文件：`ContentView.swift`、`Models/MobileAdaptiveLayout.swift`、`Views/ProviderDetailView.swift`、`Views/CostShareSheet.swift`、`Views/TokenActivityView.swift`、相关 Tests / UITests、`Localizable.xcstrings`。

## 7. 验收计划

构建与所有大型产物：`/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/Duo-078/<run>/`。illustrative test 已改为输出至 BuildScratch/LayoutPreviews，并生成 24 张通用容器预览；它们不作为原生折叠证据。

| 场景 | 必须验证的实际结果 | 当前证据 |
| --- | --- | --- |
| Xcode 27.1 / SDK 27.1；deployment iOS 17 | app 编译、相关 unit tests 与四语完整性 | 应用构建通过；64 XCTest + 1,141 Swift Testing 通过；四语源 key 审计 426 项通过 |
| Duo Usage：列表 → 账号 B → 展开 → 部分折叠 → 关闭 | 账号 B、导航和有效操作保留；返回仍到原列表 | Duo 外屏搜索 Codex、打开详情、旋转、跨 tab 再返回通过；真正展开/部分折叠仍缺原生姿态证据 |
| Duo 搜索：输入 → 展开/关闭 → 继续输入 → 主动收键盘 → 再折叠 | 分别记录文本、焦点、键盘、光标、后续输入；不强抢焦点 | iPad 搜索/输入与设置尺寸变化回归通过；Duo 原生折叠中的输入连续性未验证 |
| Duo Cost：滚动历史、选日期、展开/收窄 | 日期与可见图表范围保留；报告周期及缺失数据提示仍准确 | 最终 iPad 双栏独立滚动、Duo 外屏图表可达通过；跨原生折叠日期与精确阅读位置未验证 |
| Duo 分享：改模板/区间/账号 → 折叠 → 继续编辑 → 取消 | 预览与导出数据一致，取消不导出；编辑区和分享按钮可达 | Duo 外屏、iPad、iOS 26.5：选择热图、旋转、范围与账号控件可达、关闭不出现系统分享页，通过；实际折叠待验证 |
| 手动排序拖动与窄化 | 结果按 ID 只应用一次；自动排序模式不允许手动拖动 | 沿用现有稳定 key 排序实现；拖动中原生折叠未实测 |
| 设置中的滚动行与操作 sheet | 锚点、对象、取消语义正确；不产生真实设备合并或日历写入 | iPad 设置分类/详情尺寸变化通过；实际折叠中的危险操作 sheet 未实测，未触发设备合并或日历写入 |
| 普通 iPhone + iPad，代表性旧 runtime | 导航、分享、设置、滚动和操作可达；不因 native bars 回归 | iPad / iOS 27.0 与普通 iPhone / iOS 26.5 的账号、Cost、分享流程各 2 项 UI 测试通过；最终回归另记 |
| 中文长标题、日文、Dark Mode、大字号、VoiceOver/RTL | 代表性页面不截断关键操作；朗读分组合理；硬件区域不二次镜像 | 四语言 Cost UI 测试通过，24 张通用容器预览及大字号单列策略通过；VoiceOver/RTL 原生折叠未验证 |
| 真实硬件折叠 | 实体交互与性能 | 未验证；不以 Simulator 替代声称通过 |

使用系统实际提供的 Duo 姿态控制，不虚构 simctl fold 命令。截图与成功输入分开记录；通用尺寸预览不代替 Duo 原生 bars／reserved regions。此次不改变 Shared 数据结构，不开启真实账号探测。若实现意外涉及同步或跨版本渲染协议，重新评估 `docs/ios-sync-compatibility-testing.md` 的适用验证。

## 8. 确认项

用户已确认并要求直接全部实施本方案：Usage 导航双栏、Cost 总览与趋势、分享预览与编辑分区，以及上述拖动与折叠连续性契约。用户后续指示已满足设计确认，继续实现及测试。

本地代码、自动化测试和可查看的运行效果已完成；原生折叠姿态验收保留未闭环状态。上传、推送和公开发布不在本次交付范围。


## 9. 实现与运行验证记录

- 新增 `ReportPanePlan` 纯布局策略与 `AdaptiveReportPanes`；活动 fold 的实际 frame 加 margins 决定分区，不推算铰链角度。分享允许上下分区，Cost 避免变成两个过短的报告区域。五项策略测试覆盖偏心折叠区、上下/左右区域、文字放大与窄屏回退。
- 紧凑布局保留两个内容子树，用内容实际高度交给外层滚动；宽布局让每个区自行滚动。实际 Duo 外屏测试发现空轴内层 ScrollView 会得到零高度，已改为始终具有垂直测量语义的滚动容器，紧凑时禁用其独立滚动。后续 Duo 与 iOS 26.5 UI 测试验证了趋势、模板和分享按钮都可达。
- 外层和两内层 ScrollView 始终保持垂直轴，只通过 isScrollEnabled 切换滚动职责；保持内容子树身份与正常的系统安全区。曾试用 ignoresSafeArea / 负 contentMargins 来消除双重留白，但实际测试发现 AX 触控坐标偏移，已全部撤回；固定滚动轴的最终实现同时修复留白与定位。内容中的图表横向手势仍启用。
- Usage 行复用现有单位、额度窗口、余额、错误和来源信息；多账号组只显示账号数。详情选择改用 cardIdentityKey，列表的自动预览不修改 compactColumn。
- 保留手动排序的现有明确入口和按稳定 key 持久化的机制，不添加跨账号拖放副作用。此次没有触发真实合并、日历或额度写入。
- 最终版本为 **2.10.0 (244)**，所有 iOS target 同步递增；四语言 release notes 合并在同一营销版本内。CloudKit Production entitlement 保持不变，无 Shared / Mac 修改。
- 验证数据全部是已有合成 fixture。`unit-tests.xcresult`：64 XCTest + 1,141 Swift Testing；`duo-ui-final.xcresult`：2 项 Duo UI；`ipad-ui.xcresult`：2 项 iPad UI；`compat-ui.xcresult`：2 项 iOS 26.5 UI，均通过。`final-validation.log` 中 9 项布局测试、四语言和 iPad 搜索/设置连续性通过，随后暴露触控坐标问题；`pane-accessibility.log` 保留失败尝试。两次失败运行在测试结束后的结果收集阶段挂起，已终止本任务对应 xcodebuild，不能把未完成的 xcresult 当完整证据。最终结构修正由 `scroll-layout-final.xcresult` 的两项 UI 测试通过确认。
- Xcode 27.1 GUI 首次启动要求安装系统组件。曾发现重复的 DevicesSystemUpdater 等待退出 Xcode；取消重复初始化后，主 Xcode 仍停在 “Waiting for other install tasks on the system”。已退出本任务的受阻初始化，不删除系统安装锁、不终止其他项目的构建任务。CLI 27.1 构建与测试可用，但 Device Hub 原生 fold 控制验证未完成。
- 真实屏幕截图与通用容器预览分别标注；iPad 的双栏运行图不标作 Duo 展开图。未宣称真实硬件、折叠时光标/输入法、VoiceOver 或中途排序拖动测试通过。

### 最终本地验收

- `ipad-acceptance.xcresult`：最终构建的 3 项 UI 测试全通过（账号与分享草稿旋转连续性、Cost/分享操作可达、两栏独立滚动）。
- `duo-acceptance.xcresult`：同一最终构建的 2 项 Duo 外屏 UI 测试全通过（账号与分享草稿连续性、Cost/分享操作可达）。两次均以 `TEST EXECUTE SUCCEEDED` 正常结束。
- 旧系统兼容的 2 项 UI 测试来自此前实现；最终滚动轴修正之后未重跑 iOS 26.5，不把此前通过归作最终二进制的完整兼容验收。
- 最终截图：`/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/Duo-078/review/README.md`；Usage 窗口名已检查为 Session / Weekly，另保留两栏独立滚动后的图。
- 本地 Git 提交交付，未推送、上传或发布。仓库规则在 pushed commits 后更新 Todoist，因此本次不将看板移至已推送或已发布状态。
