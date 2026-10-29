# Duo 原生折叠转换及内屏横屏独立证据审查

结论：仅审查指定的两个已完成bundle，3个case全部Passed，截图与输入事件支持本次内屏→外屏→内屏后的草稿/选中账号保护和内屏横屏两pane独立滚动。未发现新增阻塞。没有操作设备、编译或修改源码。

## 原生折叠/展开：duo-native-fold-3.xcresult

`testAccountAndShareDraftSurviveNativeFoldAndUnfold()` Passed，104.695869秒。只读核对测试源码、完整log、全部8张screen附件及xcresult原始Xcode diagnostics。

- 开始时活动window **951×669 points**，内屏display3；英文Usage搜索Codex并点入，再切Cost、打开分享、选择Heatmap。真实截图`7CC3BC60-CE5F-40E2-8C00-B98819462080.png`显示横屏左预览/右控制栏、选中Heatmap、Range Past Year、Provider All Providers、Share Image。inactive外屏为黑图。
- 主线程使用Computer Use选择Closed后，测试通过真实`shareWindow.frame` getter持续重新取size，等到min尺寸<550；diagnostics记录活动window **678×466 points**，不是仅依赖hinge操作返回。后续2条drag、Close与Usage点击均转为**display1**。`48E8A912-A435-47C2-B97B-29CE962BA131.png`是真实外屏横屏分享控制区：Heatmap仍选中，Range Past Year、Provider All Providers、Share Image完整可达。另一个screen此时黑色。这里display1是**正确的活动外屏**，不能沿用上一轮“display1就是错误”的判断。
- Close后cost-share-button重新出现，测试确认不存在ActivityListView；再点击Usage，Codex导航仍在。`314C0C2B-A351-4C9C-8D53-2EF8405C5549.png`显示外屏选中的Codex详情和Session/Weekly，而非回到其它账号或Usage根列表。
- 主线程选择Open后，测试等到详情window min尺寸>600，随后再点Cost、打开新分享。输入事件重回**display3**；新草稿Classic选中（不是取消的Heatmap），`C24C0693-C788-4B69-ABB1-4EE789733FA2.png`显示内屏横屏左右pane、Classic、Period30Days和完整Share Image；最后点击Close，case通过。

事件时序：首次搜索/选择/打开分享5次tap+Type Codex均display3；外屏2次drag+2次tap均display1；展开后3次tap均display3。逐条行号/path及diagnostics、图片SHA256见`duo-native-transitions-evidence.json`。

这次证明的是**内屏横屏→外屏横屏→内屏横屏**的真实转换及后续动作，不是内外屏portrait，也不是仅观察静态截图。range保留测试使用原有Past Year默认值，Heatmap选择则明确从Classic改变；不能据此额外声称所有非默认range选项均已验证。未主动点击Share Image，因此没有执行实际导出/发送。

## 内屏横屏：duo-inner-landscape-cost.xcresult

2项Passed（没有skip）：

- CostAndSharePanesAreAccessibleAtTheCurrentSize：26.408083秒。Cost真实两pane图`E187DAAA-6FC0-489D-B9FA-49C7FB4C82EE.png`左为Overview/ProviderShare，右为DailySpend曲线/DailyTokens，原生Tab及操作栏在右侧；分享图`D9B007D1-600C-4481-8893-413D8AF95D6D.png`左预览、右Classic/Period/ShareImage，无控件遮挡。Period/action的isHittable断言通过，Close后Cost控件出现。
- WidePanesScrollIndependently：17.384443秒。测试以实际Cost所属window宽>=760作为precondition，没有以固定app.frame猜姿态；先滚primary，Overview至少上移20pt而DailySpend坐标变化<=4pt；再滚secondary，Overview位置保持<=4pt而DailySpend至少上移20pt。`89AD738C-4D65-4364-A575-9DD85CE54C05.png`可见两侧各自下部内容（左ProviderShare/ModelMix，右SubscriptionUtilization/footer）。2条真实drag与4条tap全部display3，确认输入命中内屏。

## 截图与范围限制

- 本轮附件保留所有screen，能够区分活动屏App与停用屏黑图。XCTest PNG的IHDR仍可为2006×2852/1398×2034，但当前查看器按方向呈横屏；不拿存储像素顺序单独判断姿态，使用真实window尺寸、两pane实际画面及输入display共同确认。未旋转、裁切、拼接或改写图像。
- Computer Use选择Open/Closed的动作由主线程执行，本审查独立验证的是其后的真实window变化、正确屏输入和App后续状态。
- **fold1/fold2仍为失败/取消**；不能追认为Passed。它们的测试前提/判定修复由主线程记录；本报告的成功证据仅指fold3。outerlandscape首轮失败也保留，未将正在执行的outerL2提前记通过。
- 这些bundle没有覆盖partial fold、任意中间角度、整套四语/暗色/大字、实体设备或CloudKit收敛；对应其他已完成/待验矩阵由主线程分开记录。

独立审查阻塞发现：0（仅上述限定场景）。
