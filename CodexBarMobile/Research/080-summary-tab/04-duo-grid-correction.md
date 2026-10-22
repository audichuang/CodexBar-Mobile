# Duo 全宽网格与实际姿态验收修订

- 状态：`in-progress`，实际展开内屏横竖屏尚未验收。
- 日期：2026-10-22；iOS 3.1.0 (248)，分支 `feature/summary-tab`。

## 用户最终要求

Summary 在 Duo 上初始只展示独立指标卡片，充分使用全部可用宽度；横屏、竖屏都不自动展开账号详情。用户点卡片才进入完整详情，返回保留 Provider 筛选。截图必须包含实际 App 的原生 Tab/导航栏，且是默认非编辑页面。普通 hosting 宽屏渲染不能替代实际 Duo 证明。

## 实现

`SummaryTab` 由 NavigationSplitView 改为单个 NavigationStack。只有卡片显式点击写入 UUID 路径；宽度、size class、旋转均不能自动开详情。网格按自身容器宽度取 2–4 列，辅助功能字号采用一列自然高度。账号或卡片消失、筛选不再匹配时清理失效路径；不按账号名字改绑。

Native TabView 仍由系统适配栏位，不能强制把任何 Duo 画面都做成侧边栏。技能参考指出完整内屏竖屏可保留水平栏；最终栏位须观察真实姿态，不以该描述冒充已观察结果。

## 已完成与未完成的证据

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

## 尚需完成

1. 真实展开内屏并确认 active screen 与实际 App bounds。
2. 竖屏、横屏各独立截图，断言实际方向变化，默认非编辑且无详情。
3. 设计师验收两张实际图，补充当前证据；保留旧失败记录，不改写成通过。
4. 收尾本地修订；不 push、PR、merge 或上传。
