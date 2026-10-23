# Usage 图表普通 iPhone 横屏可见性修复

状态：`done` · 2026-10-23 · iOS 3.2.0 (252)

## 目标与授权

用户要求修复普通 iPhone 横屏中图表、图例被搜索栏和 Tab Bar 挡住的问题，重新验证普通 iPhone 与展开 iPhone Duo 的横屏、竖屏，提供完整 App 截图，然后完成本地 CR、PR 线上 CR 与新 TestFlight。此前 3.2 的 Summary、Usage 与 Cost 更新继续包含在同一版本中。

本次仅修改 iOS 界面适配与相应测试、说明和 build number。不发布 Mac 或 App Store 正式版本。任务分支：`fix/usage-landscape-chart`；基线：`ac6ce659c83a372507b757a23e7e81ed5e737e85`。

## 根因与方案

3.2.0 (251) 的 Usage 在普通 iPhone 横屏仍保留永久展开的原生搜索抽屉。图表卡片的标题、控制栏分成两行，再加上 170 pt 图形、图例和留白，超过原生导航栏与 Tab Bar 之间的首屏可用高度。先前截图依靠滚动展示图形，没有证明整个图表卡片在首屏可见，因此不能作为横屏无裁切的证据。

- 通过实际容器尺寸判断短高布局：`height > 0 && height < 500 && width > height`，不使用设备型号或固定横竖屏枚举。
- 短高布局保留原生搜索，改用 toolbar placement；iOS 26 及以上仅在搜索未激活时使用 `.searchToolbarBehavior(.minimize)`，激活后切回 `.automatic`，让原生关闭操作正常结束搜索。其他尺寸保留原生永久搜索抽屉；搜索文字、`isPresented` 绑定和筛选仍归原来的 `ProviderListView` 管理，不扩大到整个 Usage 导航容器。
- 短高且非辅助功能字号下，图表标题、估算说明、时间范围和编辑入口尽量同排；宽度不足时用 `ViewThatFits` 回退。图形高 140 pt、卡片内边距 12 pt、组间距 8 pt、折叠图例至少 32 pt。
- 辅助功能字号保留可纵向滚动的完整内容，不能为了首屏塞下而截字或压缩文字。展开图例可以滚动，但必须完整可达。
- Mock 数据提示紧跟图表，图表成为 Usage 首个内容项。原生安全区、导航栏、Tab Bar 和 iPhone Duo 栏位策略不变；不使用负边距或 `ignoresSafeArea` 隐藏遮挡。

### 原生搜索交互调查

真实 App 验证发现：短高模式始终强制 `.minimize` 时，iOS 27 测试运行环境可以开启和筛选搜索，但点击原生关闭按钮没有退出搜索；手动点击也复现，不能只归因于 XCTest locator。绑定诊断没有观察到关闭操作写入 `false`，不支持 App 主动重新开启搜索的猜测。

仅改变 placement、移除 `isPresented` 绑定、将搜索归属移到外层 `NavigationSplitView` 都没有解决该运行环境中的关闭问题；这些实验均未保留。最终保留原搜索归属和状态，只在未激活时偏好最小化，激活后交还原生 automatic 呈现。`phone-search-state` 运行已确认原生关闭按钮消失、键盘退出、图表与图例恢复可见边界，且退出后可滚动找到未过滤的 Claude；完整交互结果继续写入验证文档。不据此断言 Apple 内部实现或缺陷根因。

## 验收

默认字号、搜索未激活、图例折叠时，普通 iPhone 横屏首次进入 Usage 即可看到完整图形与图例，不得先滚动、裁切截图或隐藏原生栏位后再声称通过。按当前窗口、导航栏、搜索栏和 Tab Bar 的实际 frame 检查可见边界。

普通 iPhone 竖屏、横屏与 Duo 展开竖屏、横屏均重新运行真实 App 并保存完整截图；旋转前后的搜索、图例展开、范围选择和详情导航应可用。补充小屏短高容器与大字号渲染，区分组件渲染、原生交互和实体设备证据。

## 实施进度

- [x] 用户批准修复与完整 CR/TestFlight 交付
- [x] 根因与短高布局方案确认
- [x] 生产布局修复，保留原生搜索与栏位
- [x] 同步所有 target build number 为 252；合并 3.2 四语言发布说明
- [x] 252 构建与完整 iOS 单元测试通过，包含模型/组件渲染；iOS 26/27 原生 UI 最终重跑通过
- [x] 四种屏幕姿态完整 App 截图及实际可见性验收
- [x] 独立本地静态 CR 无 findings；原生交互回归结果按验证文档单独记录
- [x] PR #210 exact-head 线上 CR：1 轮 / 0 unresolved；Fast Checks、Final CI `40005040876` 成功并合并
- [x] 最终已审源码 Archive、Production entitlement、本地 Apple Distribution export 与实际编译图标验收
- [x] 实际上传成功 receipt 与实际上传 IPA 签名、版本、资源/代码一致性审计
- [x] ASC `VALID` / `IN_BETA_TESTING`、Internal 既有全 build 访问、四语说明精确回读与 Apple CDN 实际图标验收

## 数据与发布边界

此补丁不改变 Mac `Sources/`、共享 wire payload、CloudKit record/schema、账号身份绑定、额度采样或估算逻辑。相关路径 diff 为空，CloudKit 审计为 `NO_DEPLOY`；已核验 Archive 与本地分发 export 中使用 CloudKit 的三个 bundle 均为 Production。实体多设备同步不作为本次布局补丁的已验证结果。

PR #210 的 reviewed head 为 `0e78e8ff6d82d723dd58292b039dceda2a08a79b`，合并/Archive 来源为 `14a191367e4b67cdec868cfdcef7fc7f8135f943`；两者 204 项发布输入摘要一致。测试、审查、分发审计与实际上传均已完成；上传成功时间为 `2026-10-23T18:44:23.985Z`，delivery UUID / ASC build ID 为 `f895b559-3312-4b78-8cfb-11de6ac63d43`。最终于 `2026-10-23T18:56:17Z` 确认 ASC `VALID` / `IN_BETA_TESTING`，Internal 既有全 build 访问、四语说明精确回读、Apple CDN 真实 1024px 图标均通过；3.2.0 (252) 已可供内部测试，目标状态更新为 `done`。当前收尾分支为 `review/usage-landscape-release-closeout`，只更新文档，不改变已上传来源。

验证过程与发布证据记录在 [01-validation.md](01-validation.md)。遇到原生栏位行为与设计假设不符时重新调查，不用放宽截图/可见性断言掩盖问题。
