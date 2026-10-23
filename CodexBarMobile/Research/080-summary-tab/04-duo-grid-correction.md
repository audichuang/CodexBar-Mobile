# Duo 全宽网格与实际姿态验收修订

- 状态：`done`，实际 Duo 模拟器展开内屏竖屏/横屏及完整 App 截图已验收。
- 日期：2026-10-22；iOS 3.1.0 (248)，分支 `feature/summary-tab`。

## 用户最终要求

Summary 在 Duo 上初始只展示独立指标卡片，充分使用全部可用宽度；横屏、竖屏都不自动展开账号详情。用户点卡片才进入完整详情，返回保留 Provider 筛选。截图必须包含实际 App 的原生 Tab/导航栏，且是默认非编辑页面。普通 hosting 宽屏渲染不能替代实际 Duo 证明。

## 实现

`SummaryTab` 由 NavigationSplitView 改为单个 NavigationStack。只有卡片显式点击写入 UUID 路径；宽度、size class、旋转均不能自动开详情。网格按自身容器宽度取 2–4 列，辅助功能字号采用一列自然高度。账号或卡片消失、筛选不再匹配时清理失效路径；不按账号名字改绑。

Native TabView 仍由系统适配栏位，不能强制把任何 Duo 画面都做成侧边栏。技能参考指出完整内屏竖屏可保留水平栏；最终栏位须观察真实姿态，不以该描述冒充已观察结果。

## 首轮验证记录（历史失败与当时边界）

- build 248 正式 app 编译通过；最终严格方向测试源码也完成 `build-for-testing`，`Summary080-strict-geometry-build.xcresult` 成功。编译成功不代表横屏已运行通过。
- `Summary080-grid-navigation.xcresult` 首轮暴露两个自动化假设错误：实际返回按钮位于原生 rail，AX ID 为 BackButton；ScrollView frame 包含 rail safe area，不能用它当卡片内容宽度。已改为实际返回控件和网格自身内容 frame。
- `Summary080-grid-navigation2.xcresult` 两项测试返回成功：默认网格、显式点卡进入详情、返回保留 Codex 筛选。独立源码 review 无导航阻断。
- 设计复核发现该次 portrait/landscape 两张 attachment 均为 1398×2034 且 SHA-256 完全一致。因此 **撤回横屏通过结论**；原测试只证明调用了旋转 API，没有证明设备真的转屏。现已补充实际 app.frame 比例断言：最多等待 15 秒达到请求方向，第二次比例必须明显改变；未达到就明确失败并不保存冒充目标方向的截图。该严格方向测试尚未执行，不能继续把旧返回成功当双方向证据。
- [该组真实截图：Duo 合拢外屏竖屏](evidence/native-duo-outer-portrait-default.png)，默认非编辑，两列全宽网格、右侧原生 rail、无自动详情。它不能证明横屏或展开内屏。
- 导航修订后的普通 iPhone 回归：`Summary080-stack-regression.xcresult` 三项 UI 测试全部通过（添加/取消、倒计时/文字/颜色定制、点卡 push/返回保持筛选）。不作为 Duo 姿态证明。
- 独立 reviewer 复核生产导航与当前文档：无新增阻断，未发现当前 Duo 完成的误导声明。
- 展开内屏竖屏/横屏、旋转后的列数与原生栏位：**未通过验收，等待实际姿态证据**。

## 重新调研：模拟器姿态控制

实际构建 SDK 为 Xcode 27.1 RC / 27A9275，命令级 DEVELOPER_DIR，最低系统 iOS 17 不变。Duo runtime 27.1。全程不改全局 Xcode 选择。

Device Hub 27.1 的原生 hinge slider 显示范围 0–180，但 AX 设置、实际拖动后没有观察到内屏激活，随后前端失去响应。通过 macOS 原生 Force Quit 对话框仅恢复 Device Hub；模拟设备和其他 App 数据未清除。尝试已安装 27.2 beta 2 Device Hub 控制同一 27.1 Duo，也出现无响应。

公共 simctl help 没有 fold/hinge 命令；XCUIAutomation 的 XCUIDevice 头文件只有 orientation 等公开控制，没有公开折叠入口。没有猜测私有命令或伪造屏幕尺寸。27.2 runtime 创建 Duo 被明确拒绝为 incompatible device，未创建成功。

另创建干净任务用 Duo 27.1：`3B24CA2E-557F-4484-864E-72CE583CE926`，bootstatus 成功；但 Device Hub 选择该设备仍超时。未重置任何已有用户设备。连续无进展后按 sim-use escalation 要求停止同类重试，请用户手动展开；其余源码、文档、测试修订继续推进。

## 续验检查清单

- [x] 真实展开内屏并确认 active framebuffer 与 App 内容。
- [x] 竖屏、横屏各独立截图，按实际子视口断言方向，默认非编辑且无详情。
- [x] 设计师验收两张实际图；保留旧失败，不改写成通过。
- [x] 本地修订与验证记录收尾；未 push、PR、merge 或上传。

## 用户手动展开后的续验

用户已手动展开干净 Duo，继续使用同一 build 248。Device Hub 的 Mac AX 查询仍超时，但 simctl 与 iOS XCTest 通道可用，不再反复重启控制器。

首次默认截图黑屏，经逐 display 对照确认：primary 外屏已停用；inner framebuffer port `AF2068FF-C6AA-4266-BD10-984266406F63` 有实际展开桌面和 App，横屏原始像素为 2853×2007。这不是 App 黑屏或缺少 Tab。`XCUIScreen.main` 不能单独承担 Duo 完整截图，测试截图已按 SDK 公开的 `XCUIScreen.screens` 枚举所有屏幕保存。

`Summary080-inner-poses.xcresult` 中 push/返回保留筛选通过；自动方向测试明确失败，根 app.frame 始终 669×951。保存的所谓 portrait 内屏图实际是横屏四列，不能沿用测试标签。设计师按实际画面审核该内屏横屏通过。没有声称 App 崩溃；Xcode 日志中的 runner 重启摘要与 App 生命周期另行区分。

用户要求由代理继续操作，随后 Computer Use 重新连接 Device Hub 成功，确认正确设备和 hinge=180。先按 AX Rotate Left，再用实际按钮截图坐标点击；后者确认内屏真实像素从 2853×2007 变为 2007×2853。没有要求用户代操作旋转。

改为两项按真实 Device Hub 姿态分别执行的 UI case：`testSummaryExpandedPortraitViewport` 与 `testSummaryExpandedLandscapeViewport`，用 summary-grid 子视口比例作硬断言，保留满宽、列数、首行跨度、非编辑和无详情检查。删除不可依赖的根 app.frame 自动方向等待，不放宽实际方向要求。截图仍保存全部屏幕，同时以 simctl 指定 inner port 保存原始完整画面。

## 最终验收结果

生产 App 仍为 build 248、源码 `114498c89` 的全宽网格实现；本次只修订 UI 测试与证据记录，不再改生产布局。Xcode 27.1 RC 构建，27.1 Duo runtime；27.2 beta 2 Device Hub 仅作宿主控制器。

| 场景 | 实际结果 | 证据 |
| --- | --- | --- |
| 展开内屏竖屏 | 全宽三列，默认 Edit 按钮（非编辑态），无自动详情；底部原生 Tab，顶部原生操作栏；UI case 通过 | `Summary080-inner-portrait.xcresult` / `summary080-inner-portrait.log` |
| 同一 Summary 从竖屏转横屏 | 由代理通过 Computer Use 点击原生 Rotate Left，卡片变四列，Tab/操作栏到右侧；页面与筛选保持，无自动详情；UI case 通过 | `Summary080-inner-landscape.xcresult` / `summary080-inner-landscape.log` |
| 显式点卡 / 返回 | 展开内屏点击 Codex 卡片才 push，返回保留 Codex 筛选与非编辑态 | 首轮 `Summary080-inner-poses.xcresult` 的 navigation case 通过；该轮自动方向 case 失败保留 |
| 独立设计 / review | 设计师逐张验收最终横竖图通过；reviewer 检查姿态独立 case、真实子视口断言与全部屏幕截图，无新增阻断 | 本任务协作记录 |

### 给用户的完整 App 原图

- [竖屏完整 App：2007×2853，三列与底部 Tab](evidence/native-duo-inner-portrait.png)
- [横屏完整 App：2853×2007，四列与右侧 Tab](evidence/native-duo-inner-landscape.png)

两张均由 simctl 对真实 active inner framebuffer 直接截图，未裁切、拼接或后期旋转，不是 HTML / hosting preview。保留系统栏、导航、Provider 筛选与所有当前固定卡片，显示演示数据标识。XCTest 内屏附件的方向 metadata 在部分查看器显示倒置，所以主交付采用上述直接 framebuffer 原图，不靠修改图像来模拟姿态。

本次完成的范围是 Summary 在实际 Duo 模拟器展开横竖屏的适配、交互与原生截图；不声称物理折叠设备、完整姿态矩阵或发布验证。
