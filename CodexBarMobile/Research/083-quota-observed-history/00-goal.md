# Usage 实际额度消耗历史修正

状态：`done`（本地修正与验证完成；未发布） · 2026-10-23

## 用户确定的目标

Remaining Quota 只显示真实额度消耗历史。预测线不属于此图；如未来需要，应作为另一张独立图表重新设计。此要求取代 Research 081 对未来时间轴和估算线的错误解释。

## 根因与真机参考

已通过 iPhone Use 查看 iPhone Air 的 Claude/Codex 详情：详情使用真实历史；Overview 原实现从现在向未来 extrapolate，两点均值估算形成直线，快速消耗被压在七天横轴内形成陡降。不能用插值造弯解决语义错误。

## 实施边界

- 纵轴保持剩余额度 0–100%，横轴为可用历史到现在，支持过去 24 小时筛选。
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
