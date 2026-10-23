# 摘要卡片信息减负 — 交互草案

状态：done（原生本地修正与验证完成）。用户已确认交互方案并授权原生修正；本轮进行代码与本地验证，不上传 TestFlight。

## 本轮目标

- 保留两列小长方形卡片，减少每张卡重复的服务商、账号与套餐文字。
- 身份行只保留单色品牌图标与短名称。默认用账号别名，卡片显示名称可单独覆盖；完整服务商、账号与套餐在点击后的详情里展示。
- 指标、主数值及一行次要信息构成其余两层。百分比模式辅以重置时间；倒计时模式辅以已用百分比；预计耗尽与重置倒计时分开标注。
- 默认卡片改为与 Usage/Cost 相同的 `.ultraThinMaterial`，页面用 `.systemBackground`；这是用户后续提出的统一色调要求，优先于早先的白卡默认。保留本地持久化 `.white` 枚举值以兼容已有布局，界面显示“默认”。用户可自行选色。图标始终为浅色界面的黑色、深色界面的白色，不跟随卡片强调色变化。
- 顶部保留服务商横滑筛选，不增加账号筛选；点击卡片后通过既有原生导航打开完整账号详情，不常驻右侧面板。
- 编辑页先展示卡片名称及实时预览，账号别名放入展开项，明确该别名会影响同账号所有卡片。

## 名称被隐藏的已确认原因

`Views/SummaryCardEditor.swift` 在 `hidePersonalInfo` 开启时，将 `accountAlias` 和 `displayName` 的输入控件都从 `TextField` 换成了 `SecureField`。这是密码式输入的直接原因，不是键盘或文字颜色问题。

原生编辑器已将这两个字段改为普通明文输入。修复保留非编辑页面隐藏个人信息的能力，不能通过全局关闭隐私选项来解决。编辑时显示用户正在输入的名称；退出编辑后的展示遵循最终确认的隐私语义。

## 图标与预览边界

交互文件：`summary-card-clarity.html`。使用仓库已有的 Claude 单色轮廓、官方 OpenAI 单色 PNG、Codex 产品 PNG，在本地预览中显示品牌形状，取代 `Cl / Cx`。Codex PNG 的单色效果是预览渲染处理，不是新找到的官方单色品牌包。

本草案只验证识别与深浅色效果，不把预览资源当作已获得额外商标许可。正式打包时仍需依据 `02-design-and-icons.md` 的来源与条款分别确认，且不能把预览效果称为官方提供的单色 Codex 资源。本轮未改 Mac 代码或 Shared 同步资源。原生图标采用新 iOS imageset 复制现有 31 个单色 SVG 与 Codex 原始 PNG；不改上游资源，未知图形才兜底文字。

## 交互验证

- 浏览器实际点击卡片 → 详情 → 自定义；输入 `C 5×` 为明文，实时预览与保存后卡片均显示该名称，其他同账号卡片保持原名。
- 外观按钮允许系统、浅色、深色切换；默认白卡对应深色模式的系统深色表面。
- 已在浏览器实查浅色黑图标与深色白图标；420px 与 320px 宽度均保留两列，未见内容重叠。320px 的 Weekly 倒计时编辑预览也已检查，名称输入的实际 `type` 为 `text`。
- 保留添加指标、服务商过滤、卡片色彩、百分比/倒计时切换，用于本轮设计反馈；数据为固定演示值。
- 此交互与原生应用为不同验证层次；原生模型/渲染/编辑回归已执行；实际系统浅深色验证及结果见下方。


## 原生实现与范围

- `SummaryResolvedCard.compactTitle` 是纯显示投影，优先单卡名称、账号别名、唯一组织名称、完整邮箱、套餐/持久 anchor 序号。完整邮箱不会截成 local-part 后绕过隐私清洗；同名 workspace 保留邮箱区分。完整 `accountTitle` 与持久化绑定不变。
- `SummaryMetricTile` 保持紧凑矩形，调整间距和字号；预测日期/时间在中行，窗口/预计耗尽在末行。未知、失效、过期和陈旧仍显式显示。编辑预览仅对用户主动填写的名称开放明文，不关闭全局隐私设置。
- `MobileSurfaceStyle` 是 iOS 专用局部样式：Summary 网格、编辑器与 Settings 首页及详情列表共用系统画布和轻材质，不使用全局 UIAppearance，不改变 Usage/Cost 外观。
- Settings 主页六个 Section、About & Sync、Usage/Cost/Widget 设置、Calendar Reminders、More Apps、Release Notes、Developer Tools 入口及五个诊断/原始数据列表均已统一基础表面。保留独立操作 sheet、系统提示与功能专用图表配色，不改导航和数据逻辑。
- 版本准备为 3.2.0 (249)，四语文案齐全。本地修改尚未进入 PR 或 TF；当前可安装 TF 仍为 248。


## 原生验证与 review

- Xcode 27.1 (27A9275)，iOS 27.1 Duo 内屏；命令级 `DEVELOPER_DIR` 固定到已有 Xcode，项目最低 iOS 17 不变。所有构建和 xcresult 放在 StudioSSD BuildScratch。
- `regression.xcresult`：23 项 Summary 模型/显示 Swift Testing 与 1 项三组合渲染 XCTest 通过；取消创建/正式创建、provider 筛选/倒计时/名字/颜色两个既有 UI 用例通过。首个隐私 UI 用例发现 DisclosureGroup 外层 ID 覆盖子输入框 ID，已将 ID 移到 label。
- `ui-final.xcresult`：隐私回归通过。输入含 email 的名称与普通别名为 TextField，编辑时原文可见，保存后浏览会脱敏，重新打开仍有原文。未用关闭全局隐私或坐标点击绕过。
- 启动参数 `-AppleInterfaceStyle Dark` 在 Duo 未真实切换外观；那组名字带 Dark 的截图不作为深色证据。最终通过 `simctl ui <UDID> appearance dark/light` 设置并回读实际系统外观，分别执行 `testTabSurfacesInCurrentSystemAppearance`。最终证据在 `evidence/clarity/`，错误标签截图已由真实系统截图覆盖。
- `actual-dark.xcresult`：四 Tab 实际深色截图/切换通过；已人工与设计师查看 Summary 全宽四列、原生右 rail、Settings 分组与 About & Sync 的黑底深灰材质，白色图标清晰。
- 32 个新增图标与原资源逐字节比对通过；actool 编译及 Swift 6/iOS 17 typecheck 通过。资源来源/哈希见 `evidence/monochrome-assets-provenance.json`。四语 audit 491 个 source key 全覆盖，所有 locales translated；SwiftFormat 与 diff 检查通过。
- 独立源码 review 的三个 P2 已修：自动隐私短名使用持久 anchor 序号区分同名组织；VoiceOver 仍保留完整账号身份；陈旧预测继续显示窗口。后续源码复查 clean，设置深层列表追加部分也已终审。

本轮复现与结果根目录：`/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/SummaryClarityNative/`。原生截图是模拟器证据，不宣称真机验收或新的 TestFlight 上传。

- `actual-light.xcresult`：实际系统 light 回读后四 Tab 切换/截图通过；Settings 主页、默认 About & Sync 与 Cost 的白色页面、浅灰材质卡片一致，原生分组圆角与右侧导航保留。实际 dark 与 light 两次验证都已通过，而不是仅按截图文件名判断。
- 最终本地检查共 23 项模型/显示单测、1 项三种尺寸/外观渲染、创建取消/创建、筛选/倒计时/名称/配色、隐私模式输入保存重开，以及两个真实系统外观轮次。没有运行真实 provider probes、Keychain 读取、Mac 测试或新的 2 Mac × 2 iPhone 同步矩阵；本次不改同步链路。

### 完整 App 原图

- [Summary 浅色](evidence/clarity/summary-unified-surface-light.png)
- [Summary 深色](evidence/clarity/summary-unified-surface-dark.png)
- [Settings 浅色](evidence/clarity/setting-surface-reference-light.png)
- [Settings 深色](evidence/clarity/setting-surface-reference-dark.png)
- Usage/Cost 同姿态参考及明文编辑截图保存在同目录。
