# Usage 实际额度消耗历史修正

状态：`done`（实现、本地 CR、Air 与四姿态验收；远端交付以实际 PR/TF 回执为准） · 2026-10-23

## 用户确定的目标

Remaining Quota 只显示真实额度消耗历史。预测线不属于此图；如未来需要，应作为另一张独立图表重新设计。此要求取代 Research 081 对未来时间轴和估算线的错误解释。

## 根因与真机参考

已通过 iPhone Use 查看 iPhone Air 的 Claude/Codex 详情：详情使用真实历史；Overview 原实现从现在向未来 extrapolate，两点均值估算形成直线，快速消耗被压在七天横轴内形成陡降。不能用插值造弯解决语义错误。

## 实施边界

- 纵轴保持剩余额度 0–100%，横轴为所有有效 Provider 中最晚 Weekly 重置时间向前完整 7×24 小时，显示以重置日结尾的 7 个日期刻度。例如绘图区含 23 日的数据，刻度显示 24–30 日。移除 24 小时缩放选项，未来区域留空。
- 线只使用对应账号、窗口、周期的真实采样，停在最新 source capture；单点不补成曲线，不假设周期开始时一定是 100%。
- 长缺测断线，重置/用量回落切段；保留一行折叠图例、五线限制、颜色和账号设置。
- 删除本图预测数据字段、推算计算和 Estimated 文案，不保留可选预测模式。
- 继续使用稳定账号所有权校验。Mac 现有 utilizationHistory 无账号归属，不能直接导入；不修改 Mac/CloudKit wire。因此修复不能补回从未被 iPhone 正确采集的完整历史；首次只有一个有效样本时如实显示点。
- 保持 v1 存储兼容与 96 点上限，保留整个已采集周期的首末点，从内部点中按时间间距做有界抽样；老版本已丢弃的历史无法恢复。

## 验收

- [x] 用户明确更正语义：只有真实损耗线
- [x] 真机参考与 source/wire 归属审计
- [x] 模型、图表、存储保留与四语说明修改
- [x] 模型/来源/兼容回归、构建和原生渲染验收
- [x] 最终本地差异审查（3 项边界 finding 均修复并复核 clean）

本次先完成本地修正与验证；不得把已有 TF 252 的证据当作本次修复的证据。

## 本地验证结果

- 工具链：命令级 Xcode 27.1 RC `27A9275`，iOS Simulator SDK 27.1；执行设备为 iOS 27.0 普通 iPhone 模拟器 `77015D3F-613D-4B1E-B348-1624350AD7E1`。
- 最终逻辑：`final-model.xcresult` 报告 43 个 Swift Testing 测试通过，0 issue。包含周/月完整连续周期压缩、真实缺测边界传播、同 capture 修正前后、重复同步、账号所有权和旧/新缓存矩阵。旧版 v1 设置继续可读，新增可选边界字段不改变 wire。
- 渲染：2 个 XCTest 通过，共 52 个 production component/editor 状态；覆盖 300–768pt、小屏横屏、浅深色及 accessibility 字号。图像已人工查看，不能将这些容器截图称为实际 Duo 姿态证据。
- 原生 App：`testPhoneQuotaChartAndLegendClearBarsThroughLandscapeSearchAndRotation` 通过，普通 iPhone 首屏横竖屏、搜索、展开图例和旋转状态保留均验收；导出并人工查看了完整 App 横竖屏截图。数据明确为模拟 fixture，不冒充本人的真实历史。
- 文案：`Scripts/lint.sh audit-i18n` 通过；格式单测 6/6；`git diff --check` 通过。
- 独立本地 CR：补充压缩前连续性标记、孤立真实点可见性、同时间戳修正继承边界，逐项复核 clean。

证据目录：`/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/QuotaObservedHistory`。
`verified.xcresult` 保存渲染和原生 UI 结果，最后的同时间戳修正仅改变模型/存储，最终全部模型重跑记录为 `final-model.xcresult`。早期失败记录保留供追溯，不能当作通过。

本轮未更改 Mac、CloudKit payload、签名配置和 build number，未推送 PR、合并或上传 TF。线上仍是此前的 3.2.0 (252)；下一次 beta 上传需递增 build 并重新走发布验证。

## 继续交付授权（2026-10-23）

用户已明确授权继续推送、PR CR、全部通过后合并并上传新 TF，要求普通 iPhone 与 Duo 横竖屏完整 App 截图；随后明确要求先安装到 iPhone Air 检查真实数据。本轮先在保留 App 数据的情况下安装同源码 Release 开发签名版，真实验证后再推进远端和分发。版本为 3.2.0 (253)，完整 3.2 Summary 更新说明保留。不发布 Mac 或 App Store 正式版。

- [x] iPhone Air 新版安装与真实 Claude/Codex 曲线验证
- [x] 普通 iPhone 与 Duo 横竖屏完整 App 截图
- [ ] 发布测试门禁、当前 head PR CR 清零、合并与 Final CI
- [ ] 253 Archive/签名/上传、四语完整说明、ASC/Internal 可用与图标验收

## 真机暴露的问题及最新语义更正

Air 安装后发现 Claude/Codex 与旧版 `legacy-no-identity` 的有效合并记录被 blanket linked-account guard 停止采样，histories=0。修正为先计算同 Provider 的有效 linkage 传递闭包（包括 weak 节点），再要求唯一 linked stable owner，且该 owner 与唯一稳定 anchor 一致；原始 source 校验仍拒绝匿名 writer 作为已知账号证明。双 stable owner、间接 weak 桥与换绑继续隔离。已有两次真实 Production 读数记录在新证据目录 air-sampling-sanitized.json。

用户进一步确认本图是固定的 Weekly 日历窗口，不按本机已采集跨度缩放：最晚 Weekly reset 倒推完整 7 天，七个日期标签从下一天至重置日，23→30 日示例标签为 24–30。较早开始的额度周期只显示落在该共同窗口内的实际历史，左侧可以已经剩 70%。这取代之前本地“历史至现在”的实现和说明；真实采样不延伸到未来。

## 253 最终工程验收

详见 [03-testing.md](03-testing.md)：全量 iOS unit 1311 passed / 1 EventKit权限集成skip / 0 failed；最后日期边界与52状态渲染的40项专项通过；普通 iPhone 横竖屏搜索/图例/旋转回归、Duo真实展开内屏两姿态原生四Tab测试均通过并人工查看完整截图。Air已保留真实数据安装3.2.0(253)，最终周轴为23→30、刻度24→30；真实短期读数集中在左侧，未来留空。已修复旧匿名账号合并导致可信采样被停用的问题；无法恢复本机从未保存过的历史。

新证据目录：`/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/QuotaObservedHistory-3.2.0-253`。所有四姿态完整App截图为明确的模拟fixture，Air截图为真实账号。构建前/后Air shipping输入已实际捕获，最终head提交后验证等价。在线CR、gate/merge、Archive和ASC四语/Internal/CDN的真实回执保存在该目录 `provenance.json`，本文件中的工程done不代表尚未发生的上传。仅iOS本地cache/UI/测试/版本/文案变化，Mac与Shared wire零diff，NO_DEPLOY。
