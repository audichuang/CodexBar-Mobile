# Duo Cost / 分享滚动失败独立审查

状态：已定位原失败中的测试输入路由缺陷；修订测试与复测尚待主线程执行，不能标记产品通过。

## 范围与约束

只读审查当前 `DuoWorkspaceUITests`、`AdaptiveReportPanes`、`ReportPanePlan`、`CostShareSheet`、CostDashboard及现有Summary滚动测试。未编译、未操作设备、未修改产品或测试源码，未调用真实账号/Keychain。

## 确认的根因

`duo-inner-portrait.log` 中，Cost页成功出现后，测试通过 `app.swipeUp()` 连续16次尝试使 Daily Spend 可见；接着分享编辑器的 Period、Share Image 分别再做16次。3处均失败。

原xcodebuild收尾未完成时，xcresult没有Info.plist，`xcresulttool`不能读取。主线程中断收尾进程后，工具可以正常导出104个附件。对 `Synthesized Event` 二进制plist的NSKeyedArchive只读解码，得到**全部48次drag的displayID=1、parentWindowSize=0×0；3次成功tap的displayID=3、parentWindowSize=669×951**。这直接证明应用根级`app.swipeUp()`发往了错误的非活动外屏，而具体元素tap发往了当前内屏。不是“发生了swipe”就能证明产品收到了滚动。

逐事件原始归纳：`duo-input-routing.json`。例如成功Cost tap对应 `689DDF16-65CB-46BE-A06F-88D76FA95B54`；第一条drag对应manifest中02:10:08的Synthesized Event。完整导出位于 `duo-portrait-review-attachments/`。

QuickTime失败录像实际2006×2852，metadata rotation=-180。只读抽取65秒和88秒帧得到 `duo-portrait-review-raw/cost-65s.png` 与 `share-88s.png`：分别停留Cost最初Overview/ProviderShare和分享预览+Template刚露头，符合48次手势未送到内屏的证据。原`capture()`只调用`XCUIScreen.main`，附件是停用外屏黑图，无法验收当前App；Summary已有正确的全部screen枚举。

## 源码审计结论

上述4个产品布局/分享文件相对base `bdfb51085`没有本轮修改。当前内屏竖屏按实际容器宽度<760选择stacked；未发现可凭静态代码确定的本轮产品回归。**这不证明所有Duo姿态产品行为已通过**，仍需将测试输入路由修正后执行真实动作。

## 最小修订建议

1. current-size姿态验收不在launch里设置`XCUIDevice.orientation`；真实内屏姿态由DeviceHub选择并以实际子视口比例确认。普通iPhone自动旋转用例可保留独立orientation流程。
2. 为外层可滚动容器加`workspace-stack` accessibilityIdentifier（仅测量/访问入口，保持布局行为）；滚动应锚定具体活跃scrollView，使用它所属window与scrollView frame交集中的坐标。不要以整个应用根或可能延伸几屏的内容frame中心发手势。
3. 对secondary目标：split时滚其所属pane；stacked时目标还在屏外，滚外层stack的实际window viewport。可参考`UsageQuotaOverviewUITests.revealSummaryElement`的窗口交集、遮挡扣除及有界slow drag。按identifier查包含目标的ancestor即可，不要假设`containing(XCUIElement)`重载存在。
4. attach每次目标、window、outer/primary/secondary frame和hittable状态；一次drag后确认Overview或已存在目标的frame推进，并在最终成功后执行一个动作（打开Period、选择后取消）。
5. capture枚举全部`XCUIScreen.screens`。新测试的Synthesized Event必须确认displayID=3；元素hit和实际画面推进必须一起成立，不能只更换命令然后宣称成功。

本次没有要求降低isHittable断言、增加无意义重试或放宽Duo gate。产品是否需要改动取决于正确输入路由后的实际失败。
