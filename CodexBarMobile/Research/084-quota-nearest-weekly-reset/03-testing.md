# 3.2.0 (254) 验证记录

状态：本地实现、测试和实机验证完成；远端审查与TestFlight回执待执行。证据目录：`/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/QuotaNearestWeekly-3.2.0-254`。

## 环境与边界

Xcode27.1RC/27A9275；普通iPhone模拟器iOS27.0、Duo展开内屏iOS27.1、实体Air iOS27.0.1。所有build/result/archive/export主产物在StudioSSD BuildScratch；复用既有DerivedData缓存，254结果独立保存。

此次只改iOS坐标轴、标签锚定、四语与build。Mac、CloudKit wire/schema、本地历史schema及采集规则均无变化；不发布Mac，CloudKit审计NO_DEPLOY。全量iOS unit包含WidgetSnapshotBuilder与现有16组合兼容替代测试；未执行完整实体两Mac×两iPhone矩阵，不能声称实体组合通过。

## 已验证

- 最终全量iOS测试：1317项，1316通过、0失败、1跳过（原有需真实授权的EventKit集成）。`final-units.xcresult`，包含52状态额度渲染与兼容测试。

- 独立本地CR两轮无未解决finding。
- 第一次全量unit指出旧兼容fixture仍断言最远+2h；按新规则改成最近+1h，保留全部来源/历史断言，最终全量复测通过。
- Air真实数据保留安装254（Release/Apple Development，非TF分发签名），Production。
- Air首次发现最右日期刻度被裁切，首尾标签改为向内锚定，重新构建安装后18..24七日期全部可见。
- Air区间由最近Grok24日11:13决定，为18日11:13至24日11:13；真实已保存曲线仍只在23日附近。旧日期没有伪造填充。截图`screenshots/air-real.png.jpg`。
- Lint、四语翻译与520源码key检查通过。
- 普通iPhone横竖屏原生UI回归通过，包含搜索、取消、图例展开/收起及旋转；截图`iphone-portrait.png`、`iphone-landscape.png`。
- Duo展开内屏横竖屏原生UI回归通过，包含四个Tab和五条图例；截图`duo-landscape.png`、`duo-portrait.png`。七日期均可见，搜索栏与原生Tab Bar无遮挡。模拟器截图使用明确标识的合成fixture，不冒充Air真实数据。
- Device Hub控制器曾多次挂起，重启控制器后用实际旋转和截图确认展开竖屏；未清除模拟器数据，卡顿不计为通过。

## 自动切换契约

单测以可控时钟证明：最近reset精确到期后，无需新快照就退出候选；另一账号未来reset接替。新周期同步到达后重新排序。页面沿用30秒TimelineView及publicationRevision触发reconcile。没有声称在实机等待数天跨过真实Weekly重置。

## 已知精确时长边界

严格144小时与七个24小时刻度优先。在DST午夜附近，本地日期文本可能跳过或重复一天；实际时间点不变。如果全部Weekly刚重置、距截止大于六天，当前采样可在窗口左侧；按用户要求不扩展窗口、不移动采样。

最终unit/UI、PR、archive与TF实际结果将记录在本目录及外部provenance.json；在真实回执前不能标为发布完成。
