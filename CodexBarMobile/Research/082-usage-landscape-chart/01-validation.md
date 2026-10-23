# 验证与发布记录

状态：`in-progress` · 2026-10-23 · iOS 3.2.0 (252)

## 当前边界

252 已成功构建，完整 iOS 单元测试、最终 lint 与独立本地静态 CR 已完成。最终生产方案保留原 `ProviderListView` 搜索归属及 `isPresented` 绑定，仅在短高且搜索未激活时使用 `.minimize`，激活后使用 `.automatic`。普通 iPhone 的 iOS 27 完整交互流程及 Duo 展开横竖屏最终测试均已通过；iOS 26 串行最终对照也已通过。PR、线上 CR、Archive 与上传尚未完成。使用真实 App 原生截图，组件渲染仅作为补充证据。

证据根目录：`/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/UsageLandscape-3.2.0-252`（下文文件名均相对该目录）。

## 测试与屏幕矩阵

| 项目 | 验收要求 | 状态 / 证据 |
|---|---|---|
| 普通 iPhone 竖屏 | 完整 App、原生导航与 Tab Bar、图表/图例可见 | `phone-accepted.xcresult`：1 passed / 0 failed / 0 skipped；首屏及横屏交互后恢复竖屏均通过 frame 断言 |
| 普通 iPhone 横屏 | 首屏完整图表与折叠图例，不被搜索/原生栏位遮住；不能依赖预先滚动 | `phone-accepted.xcresult` 完整流程通过；横屏首屏图表/折叠图例无需滚动，关闭搜索后再次通过相同可见边界检查 |
| Duo 展开横屏 | 完整 App、原生自适应栏位、图表与图例可见 | `duo-landscape-final.xcresult`：1 passed / 0 failed / 0 skipped；包括全部四个 Tab 与展开图例；完整图保留在 `duo-landscape-final-attachments/` |
| Duo 展开竖屏 | 完整 App、原生自适应栏位、图表与图例可见 | `duo-portrait-final.xcresult`：1 passed / 0 failed / 0 skipped；最终方案当前姿态测试包括四个 Tab 与展开图例 |
| 搜索与旋转 | 搜索入口可达、筛选与清除、旋转后状态/导航连续 | iOS 27 `phone-accepted` 验证 Codex→清空→Claude→Codex、关闭/键盘退出/未过滤列表恢复、Tab 切换及恢复竖屏；iOS 26 `phone-ios26-accepted` 同样 1 passed / 0 failed / 0 skipped |
| 图例交互 | 展开明细可滚动到达；收起后保留已选条目 | Duo 最终两姿态通过；iOS 27 `phone-accepted` 完整流程已验证五条展开图例逐项可达、收起及返回后选择保持 |
| 小屏与大字号 | 667×375、844×390 等实际容器；辅助功能字号不截字 | 新短高与辅助功能字号组件渲染纳入已通过的完整单元测试；不替代原生栏位验证 |
| 模型、组件渲染与原生 UI 回归 | 记录通过、失败和跳过，不以组件渲染代替原生首屏 | `unit-suite.xcresult` 共 1303 cases：1302 passed / 1 skipped / 0 failed；原生 UI 结果按各行单列 |
| 四语、格式与差异范围 | 无缺失翻译，生产改动只涉及 iOS 布局 | `lint-final.log` 完整脚本通过：3143 文件 / 0 violations，523 source keys 全部存在，全部四语 translated |
| 独立本地 CR | findings 修复后回归并记录审查对象 | 最终 idle-only minimize 方案及相关差异经独立本地静态审查，无 findings；原生验收另以通过的 xcresult 记录 |

## 已完成验证与历史失败

- 构建采用 Xcode 27.1 RC（`27A9275`）与 iOS 27.1 SDK，`build.log` 记录成功；`test-without-building` 使用 Xcode 27.2 beta 2 控制器。设备运行时分别记录：普通 iPhone 为 iOS 27.0（`24A434`），Duo 为 iOS 27.1（`24A94232`），另有 iOS 26.5 对照。控制器版本、构建 SDK 和实际设备运行时不能混为一谈。
- `unit-suite-summary.json` 回读为 `Passed`，总计 1303 cases，其中 1302 passed、1 skipped、0 failed。日志包含 1232 个 Swift Testing cases / 81 suites 和 71 个 XCTest cases；唯一跳过为 EventKit 在独立日历中创建、更新、删除事件的集成测试，未记为通过。
- 上述完整单元测试在搜索呈现调查前已运行；随后搜索生命周期修正由专项原生流程补充验证，不将较早结果冒充最终修改后重新运行的全量测试。
- 首次 `phone-interactions-summary.json` 为 `Failed`：原生关闭按钮实际为 `close`，最初测试仅查找 `Cancel`。修正 locator 后进一步发现了真实的 iOS 27 搜索生命周期问题，不能把全部失败统一归为测试错误。
- 始终强制 `.minimize` 时，iOS 27 上原生关闭操作没有退出搜索，手动操作也重现；绑定诊断没有观察到写入 `false`。调整 placement、移除绑定或扩大到整个导航容器均未解决，因此均未保留。最终仅在搜索未激活时偏好最小化、激活时交还 `.automatic` 后，`phone-search-state` 已通过关闭、键盘退出、完整图表/图例 frame 检查，并能滚动找到恢复后的 Claude。未据此断言 Apple 内部缺陷原因。
- 搜索测试的系统差异与输入失败：iOS 26 关闭后可保留 `Close` 节点，因此最终断言检查查询清空、导航恢复、键盘退出和可见边界，不把原生节点存在当成失败。`phone-complete` 曾因 `typeText("Codex")` 后实际只有 `Cod` 而失败；未更改生产逻辑来掩盖输入问题，后续串行流程重新验证完整输入及过滤。
- 滚动/AX 辅助问题：LazyVGrid 屏幕外项不保证存在，整屏 swipe 可能越过图例，过渡期或屏幕外控件的 `isHittable` 查询也可能抛出异常。历史 `phone-ios26-complete`、`phone-verified`、`phone-verified2`、`phone-final-pass` 保留失败结果。最终辅助函数先检查实际 frame，再查询可交互性，使用稳定滚动容器 `usage-provider-list` 和有界短距离滚动；普通高卡片只需实际可达，不要求整张高度大于 viewport 的卡片完整塞入。退出后用首个未过滤 Provider 验证列表恢复，另以明确的 Claude 搜索验证过滤切换。图表与折叠图例的完整首屏 frame 断言始终未放宽。
- `phone-accepted-summary.json` 已回读 `Passed`：1 passed / 0 failed / 0 skipped，完整覆盖默认竖屏、首次横屏、输入/清空/切换 Provider/关闭搜索、五条图例可达、Tab 切换与恢复竖屏。历史失败 bundle 不改写为通过；iOS 26 的 `phone-ios26-accepted-summary.json` 同样为 `Passed`：1 passed / 0 failed / 0 skipped。
- `duo-portrait-final-summary.json` 与 `duo-landscape-final-summary.json` 均回读为 `Passed`，各 1 passed / 0 failed / 0 skipped；完整截图及四 Tab/展开图例证据保留在各自附件目录。

## 最终完整截图

`final-app-screenshots/gallery.html` 汇总普通 iPhone 横/竖屏与 Duo 实际展开内屏横/竖屏。四张 PNG 均来自最终通过的原生测试，未裁切或修图；`sources.json` 保存对应 attachment、设备 ID 与 SHA256。独立设计复核确认图形、日期轴、折叠图例和展开按钮未被原生搜索/标签栏遮住。所有屏幕采用合成演示数据。

最终测试源仅在通过后整理格式并将空字符串判断改为等价 `isEmpty`，窄范围 SwiftFormat/SwiftLint 通过；最终 build-for-testing 再编译核验。

## 源码与发布

- 基线：`ac6ce659c83a372507b757a23e7e81ed5e737e85`；分支：`fix/usage-landscape-chart`。
- Marketing version 保持 `3.2.0`，全部五个 target build number 为 `252`。
- 最终 source commit、PR、exact-head CR、CI、merge：待完成。
- Archive、export、签名/CloudKit Production 审计、上传 receipt、ASC build 状态：待完成。
- 四语 What to Test 保留完整 3.2 更新并增加横屏修复；最终保存与回读：待完成。
- Mac、共享 wire、CloudKit schema 均不改动；相关路径 diff 为空，本次 `NO_DEPLOY`。不进行 App Review、公开发布或 Mac release。

所有新构建、测试结果、Archive、导出与截图均保留在上述 BuildScratch 证据根目录；最终补入发布 provenance。当前所有 UI 证据来自模拟器，不声称真机验收或实体多设备 Production 同步验证。
