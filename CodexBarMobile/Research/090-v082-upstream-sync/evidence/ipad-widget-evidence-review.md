# iPad 与真实系统widget证据独立审查

结论：iPad指定3个case与实际图通过；真实SpringBoard widget最低gate已有观察到的配置/选项/切模式及生效截图支持。另发现新增Overview自动用例**进程Passed但目标未达成**，不能以它声称Overview切换/关闭/重开通过，需要修正测试或撤回该额外成功结论。未操作设备、编译或修改源码。

## iPad

`ipad-final-navigation.xcresult` 3 Passed，0 failed/0 skipped。10张显式截图逐张检查，未发现新阻塞：

- `testCostShareEditorUsesTwoColumnsOnWideIPad` Passed362.727秒；横屏分享预览在左，Template/Period/ShareImage在右，preview.maxX<period.minX及action.isHittable硬断言通过；截图完整，无遮挡。
- `testTabletColumnsSearchAndSettingsSelectionSurviveResize` Passed144.353秒；竖屏单列账号sidebar和详情，搜索Codex后选中，旋转后仍选中Codex；横屏真实软键盘打开，sidebar/详情/原生tabs保持；收键盘、打开Usage Setting、转竖屏仍在该设置详情；Cost横竖屏均为Overview/ProviderShare与DailySpend两个报告pane。
- `testSummaryCardPushAndBackPreserveProviderFilter` Passed69.968秒；点卡进入Codex详情，返回后Codex筛选及两卡保留、Edit为非编辑，没有自动选详情。

仅代表iPad此runtime/设备的指定交互，不扩大成分屏任意尺寸、全系统/真机证明。

## 真实SpringBoard最低widget gate

规范`docs/RELEASE-CHECKLIST.md:29`要求至少打开系统编辑面板、确认可配置选项、实际切换一个mode并截图；Settings preview不可替代。现有独立可读证据满足这一限定最低结果：

1. `widget-system-setup-2.xcresult` /log进程Passed53.403秒；`widget-placed.png`显示真实HomeScreen CodexBar小widget，Overview内容Claude54%、Codex39%，不是Settings预览。
2. `widget-config-ui.json`真实系统面板暴露Widget Type=Overview、Color Style=Mono、Provider Selection=ChooseManually、Provider1/2。`widget-mode-picker-ui.json`与`widget-picker-current.png`均显示Overview/ProviderFocus/TodayCost/SyncHealth四选项，Overview有勾选。
3. label Today Cost点击失败后，主线程按fresh截图真实选项坐标(216,494)点击，receipt留存在`widget-mode-coordinate-action.log`，随后`widget-mode-selected.png`实际面板已显示TodayCost。receipt本身不作生效证明。
4. `widget-editor-dismiss-action.log`后最初`widget-today-cost-home.png`仍为placeholder，**不计完成**；稍后`widget-reopen-menu.png`虽命名像重开菜单，实际是HomeScreen，清晰显示今日**$19.42、822.0K tokens**。因此它能证明真实mode渲染已改变，但不证明成功重开菜单。
5. native长按receipt并未打开菜单，不写成成功重开；原today-cost自动两轮分别失败于找不到EditWidget及错误假设WorkflowUIforeground，原失败留存，不追认成Passed。

此为系统真实配置/切换结果的证据，不是“全部widget自动测试通过”，也不证明所有modes/families/colors/appearances。WidgetSnapshotBuilder及RenderMatrix应另据对应测试结果收拢。

## 新Overview自动用例的假阳性（需修正测试结论）

`widget-system-overview-final.xcresult`进程Passed141.711秒，但独立导出的四张关键附件全部仍是“小组件类型 今日费用 / 颜色样式 单色”的同一系统编辑面板：

- 512FBE8D-EF1A-456E-AF87-392B6FF1186D：名为Widget Type Picker，实际未开picker。
- 50BC6EBA-8292-4C11-B822-E751874421AF：名为Overview Configuration Selected，实际仍TodayCost。
- 23421C23-0B28-4245-A319-086905827BE1：名为Overview Widget，实际编辑面板未退出，不是HomeScreen widget。
- AF1EECF6-2046-4CB4-9FE6-B72CC8C1AC43：名为persisted configuration reopened，实际同一TodayCost编辑面板，不能证明曾关闭并重开。

源码helper允许host运行或Type+Style存在即成功，后续固定坐标(.80,.43)和home按键不校验picker/关闭状态，最终没有assert所选mode。因而一条“始终停在原面板”的路径也会Passed。建议必须在选项前验证真实菜单，选后断言实际type值；退出后确认配置面板消失及HomeScreen特征，再打开验证persisted值。若系统AX不可得，明确要求逐图readback，不能把exit0自动映射功能Passed。

这属于测试/证据缺陷，不据此认定产品widget回归。原真实手工TodayCost最低gate仍有效。

## 源与二进制边界

上述截图保留原时间、二进制及源状态；主线程告知其后追加provenanceCase/merger/caption修订，未改变widget布局/kinds。新代码已编译和focused复测的结果由主线程另收。布局/kind未变可保留此前系统配置行为的限定证据，但**旧截图不能绑定到尚未记录SHA/hash的最终候选产物**；尤其merger/shared数据语义需通过最新WidgetSnapshotBuilder/consumer测试，不用一张系统widget截图替代。签名Archive/source/artifact匹配仍需最终provenance记录。

原图、JSON和log的SHA256索引：`ipad-widget-evidence-review.json`。


## Strict Overview 复测：真实选择、Home 与重开均完成

后续 `widget-system-overview-strict.xcresult` 的 `testSpringBoardWidgetCanSelectOverview()` 为 **1 Passed / 0 failed / 0 skipped，98.353804 秒**，设备 iPhone 18 Pro / iOS Simulator 27.0 (24A434)。该结论来自 tests JSON 与实际关键截图/AX，未仅依赖进程状态。此前假阳性记录保留，不追认旧用例。

8 张 PNG 及 2 份系统层级已检查。初始 Home 为 Today Cost $19.42 / 822.0 K tokens；初次编辑后的两张加载 spinner 是中间态，不作为已配置证明。随后四张关键图构成完整结果链：

1. `DB8C9732-CFE1-4085-9E53-672C155E2327.png` 是真实四模式 picker：概览、服务商详情、今日费用、同步状态，初始勾选今日费用。
2. `9F8F04F5-C87A-4F63-9979-57B157585997.png` 系统编辑面板 Type 已为“概览”，不是仍停在 Today Cost。
3. `8F54B099-EDD1-4184-BE03-4AE5A3932CBA.png` 是真正退出编辑后的 Home Screen，实际 Overview widget 显示 Claude 54% / Codex 39%。因此未把 editor 截图误称 Home。
4. `83A4AEAC-D7D6-4720-BEEF-8F3520437B3A.png` 重开编辑后仍为“概览”；`0C73DBDF-F474-4699-BAF6-0B6A887B26E1.txt` 行47–50也读到小组件类型及 Button 概览。再关闭的测试断言通过，但没有额外最终关闭后的截图，故只将该关闭视作自动断言证据。

现有证据支持这一设备和 runtime 的 Today Cost → Overview 系统配置、Home 生效与重开保留。Provider 1/2 显示 Not selected，为该系统当前 AppEntity 配置状态；Overview 仍实际显示默认 Claude/Codex，不扩大成实体选择所有路径已通过。最终产物绑定仍需主线程记录 source/artifact provenance。

## 新 provenance native render 9 图：caption 通过，AX3 budget target 截断待处理

`ios26-review-fixes.xcresult` 导出的 `provenance-native-render-attachments/` 九图已逐张视觉检查：en、zh-Hans、zh-Hant、ja 的 light/dark 各一及 ja light AX3。新 source-recorded caption 四语完整，常规字号为一行，JA AX3 自然四行；无重叠、裁切或 UIKit 控件黄色占位。Kimi expected usage 40%、expired gift 的灰色/期限、budget $12.50 / $100.00 与 native progress 可读。

发现新图中的 **JA AX3 Budget daily target 被省略为“1日あたりの目安: $1…”**（`1E02200B-4AD6-498D-AA8A-92679D175160.png`）；旧截图 `v082-kimi-ui-attachments/526741F0-9B9C-49C3-88ED-88A130338A16.png` 同处“1日あたりの目安: $17.50”两行完整。新 caption 增加了固定 390×1800 hosting fixture 中的内容高度，Budget 的 TimelineView Text 当前未声明纵向 intrinsic size，**推断可能为 fixture 垂直压缩**，不能单据此认定生产 ScrollView 必然截断，也不能以该图证明 AX3 金额完整。建议修正 fixture 的 intrinsic/scroll 测量或使目标 Text 可完整纵向展开，重新截图确认。

底部品牌色测试标签在 AX3 分词折行属 fixture，不是生产 provider row。host App 默认中文使 EN/JA 的旧 Used/reset 文案混有中文，图只证明 locale-explicit 新文案和样式，不证明整个 App 语言切换。caption 在 fixture 是独立 Text，**不是直接调用 ProviderDetailView 的 private production caption 分支**；本审查验证其本地化文字与排版，真实分支语义须结合源码与 semantic tests。严格 Widget 复测已经通过，但本次九图整体尚不能无条件标记 AX3 全量完整。


## Intrinsic render 复测：原 AX3 金额压缩已解除

后续 `ios26-render-intrinsic.xcresult`/log 的 render 用例为 Passed，38.169 秒（执行状态由主线程收拢）。本审查逐张查看 `intrinsic-native-render-attachments/` 的全部九图，并核对当前 `V082RenderTests` 只对诊断内容 stack 加 `.fixedSize(horizontal: false, vertical: true)`，hosting window 改为宽390、常规高900/AX3高2400；Budget 产品布局未为本疑点修改。

- `8E5EFCA7-5317-4375-8E72-48D01304A674.png`：JA AX3 daily target 现在完整两行“1日あたりの目安: $17.50”，无省略号。Budget 的 `$12.50 / $100.00` 完整，新增 caption 四行完整；usage target 150 credits、Kimi 25/100、expected40%、Other features5/100 与 expired gift 日期全部保留且无重叠。标题和合成品牌标签的自然折行仍为预期 fixture 行为。
- EN/Hans/Hant/JA light/dark 八张常规图：新 caption、daily target、monthly detail 与过期 gift 全部可读；长日期自然换行，原生 progress/tick 均可见，无黄色 unsupported placeholder。没有因 intrinsic 修复导致新的挤断。

因此此前“AX3 budget target 截断”在修正测量容器后已闭环为 **诊断 fixture 的垂直压缩**。旧失败/压缩截图与原段保留，后续以本轮完整截图作为新文案/金额 AX3 排版证据。本复测不扩大原有范围：宿主默认语言、fixture caption 未直接调用 private production 分支、最终 source/artifact provenance 的边界仍成立。九图 SHA256 已追加 JSON；未操作设备、编译或修改产品源码。
