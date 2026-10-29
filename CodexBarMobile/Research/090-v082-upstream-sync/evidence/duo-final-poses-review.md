# Duo 外屏横竖及部分折叠横屏独立验收

结论：指定4个已完成bundle共7个case全部Passed，0 failed / 0 skipped；实际子视口、正确display输入及后续动作成立。当前测试没有为取得通过而放松产品约束；short-landscape两列符合既有packing policy。仅对下列限定场景记录通过，历史失败保留。

## 证据与结果

同一专用Duo 44FF07DE-FAD8-4670-B9D8-35542A3FE199，iOS27.1 24A94232。全部screen截图和Xcode diagnostics已只读导出，逐bundle test时长、事件计数、源诊断/图SHA256见`duo-final-poses-evidence.json`。

| Bundle / 场景 | 实际几何与输入 | 后续动作及视觉验收 |
| --- | --- | --- |
| duo-outer-landscape-native-2 / Summary | Summary实际grid **678×466pt**；2 tap均display1；1 case Passed26.070s，无skip | 外屏横屏原生rail在左，Summary独立卡片全宽2列，Edit默认非编辑，无详情；点击Codex筛选后仅剩Codex两卡且仍网格，截图明确 |
| duo-outer-landscape-cost-native / Cost+Share | 实际window **678×466pt**；6 drag、3 tap全部display1；Passed62.195s | 正确外屏滚动至Budgets及DailySpend标题，打开分享后Classic/Period30Days/ShareImage完整可见，period/action isHittable通过，Close后Cost share控件出现 |
| duo-outer-portrait / Summary、点卡返回、Cost+Share | 实际window **466×678pt**；Summarygrid **466×526.3pt**，y151.7；4 drag、9 tap全部display1；3 case分别44.097/20.697/15.810s Passed | 外屏竖屏Summary2列与原生右侧rail清晰；点Codex卡才出现详情，返回后Codex筛选保留、非编辑；Cost实际滚至预算及DailySpend标题，分享Template/Period/ShareImage可见并可达，Close后Cost控件出现 |
| duo-partial-landscape / Summary、Cost+Share | Summary实际grid **951×517.3pt**，y151.7，根app.frame仍669×951故未以其猜方向；5 tap全部display3；2 case分别55.490/18.765s Passed | 部分折叠状态下内屏Summary全宽4列，无自动详情、Edit默认，点击Codex筛选仍正常；Cost左Overview/右DailySpend，pane间保留明显中间区域；分享左右预览/控制区、Period与ShareImage完整可达，Close返回Cost控件 |

外屏Cost两图在DailySpend标题刚进入视口时捕获，**只证明该标题可滚动达到，不声称整条曲线在这两张外屏截图中完整可见**。内屏/partial的Cost图则可见完整DailySpend曲线。Share控制截图和isHittable均完整成立，未点击实际Share Image导出/发送。

## 测试断言审查

- `SummaryModulePacking.columnCount`本来就是`shortHeight ? 2 : max(2,min(4,Int(width/175)))`；`MobileAdaptiveLayout.usesShortHeight`本来是`height<500 && width>height`。这两个产品文件及SummaryTab相对基线bdfb51085的diff为零。
- 测试现在用Summary所属**实际window**判断short-landscape，并期望2列；不是接受任何列数或跳过外屏。实际宽高比、全宽、列marker、首行卡片数、相等宽度、边界、8pt间距、非编辑、无自动详情都仍为硬断言。
- 真实姿态下再点Codex filter并断言selected、所有卡片ID属于Codex及无自动详情；这是原生姿态后的实际动作，不是只有截图。
- Cost/share用例的目标存在与isHittable断言仍在；滚动锚定实际祖先window以避免先前inactive-main输入错误。没有放宽为仅exists即成功。
- 外屏横屏通过测试driver设置正确朝向并等待真实grid宽>高，最终几何678×466，而不是以旋转命令回执认定横屏。前一轮实际竖屏的strict-L失败仍是失败。

## 边界与历史

- partial bundle运行前由主线程Computer Use选择Partially Open；本报告独立确认活动内屏、横屏实际子视口、中间pane区域与后续动作。bundle里没有单独保存hinge角度数值或reservedRegion对象，因此不声称验证了任意具体角度/所有中间尺寸，也不把这组当作flat展开验收。
- 本审查仅针对这些已完成bundle，不包含任意partial姿态、全部颜色/字号/语言、真机或CloudKit。4语和AX有其独立渲染/单元证据；它们不是本native姿态case的扩展结论。
- 原outer-landscape首次因launch导致portrait而strict-L失败，原fold1/2失败/取消及早期app-root手势路由失败都保留。成功bundle不追认旧失败为通过。
- 这些case记录Close tap及随后Cost share控件exists，未单独capture关闭后的前台截图；不扩大成完整系统分享/导出副作用测试。

独立审查阻塞发现：0（仅上述限定范围）。
