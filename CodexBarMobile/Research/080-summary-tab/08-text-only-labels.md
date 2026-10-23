# Summary 纯文字标签

状态：done（本地实现、代码 review 与验证通过；PR/TF 交付另记回执）。用户明确要求取消 Summary 的服务商图标，采用服务商名称或用户自定义文字，覆盖此前单色图标方案。

## 目标与实现

- 顶部保留现有高度的横滑 Provider 筛选，按钮仅显示 Claude、Codex 等服务商名称，无图标和缩写。
- 卡片首行不再放品牌图标，也不自动拼接邮箱、工作区和套餐；显示优先级：单卡自定义名称 → 用户设置的账号别名 → 服务商名称。
- 不同账号仍有独立持久绑定；用户可通过自定义名称和颜色区分。完整身份保留在详情、添加时的账号选择和 VoiceOver 中。
- 编辑器预览和排序列表采用相同命名规则；明文编辑和浏览时隐私清洗规则不变。
- 清理不再引用的 iOS Summary 专用图片与渲染组件，不改 Mac 图标资源或历史研究证据。
- 不改变卡片高度、指标语义、筛选行为、原生 Tab Bar 或 Duo 全宽布局。iOS 准备为 3.2.0 (250)。

## 验证计划

- 更新既有名称规则回归，验证默认服务商、自定义名称/账号别名优先级，以及隐藏邮箱后仍保留独立绑定。
- 聚焦模型、渲染与编辑/筛选 UI 验证；查看真实应用深浅色原图，确认移除图标后无占位空白。
- 四语文案审计与本地格式检查。本轮不读取真实账号或 Keychain，不改同步链路，不需 Mac 更新或 schema deploy。

## 验证结果

- 23 项 Summary 模型/显示测试、1 项三尺寸/外观渲染测试、隐私明文输入/保存/重新打开以及 Provider 筛选/倒计时/改名/颜色 UI 均通过。
- 实际 Duo 系统 light、dark 分别运行；完整 App 原图见 `evidence/text-labels/`。默认卡片仅显示 Claude / Codex，自定义卡片显示 My key limit。没有品牌图标或残位，四列网格及原生右侧 rail 完整。浅色由独立设计复查通过，深色由主 agent 直接查看。
- 初次名称回归暴露同名组织的完整账号标题也重名，已修：非用户别名的同名组织账号在详情/添加选择中带持久 anchor 序号，并附可用邮箱；隐私清洗后仍能区分，重排不换号。卡片首行仍保持简洁。
- 独立源码复查 clean；四语 audit 488 个源 key 齐全，所有 locale translated；本地 portable lint、格式检查和 diff 检查通过。
- `SummaryInfoView` 的过时品牌资源说明已移除；历史 Research 里的图标来源、旧截图不删除，以保留决策过程。
- 本轮复现目录：`/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/SummaryTextLabels/`。`final-light.xcresult`、`final-dark.xcresult` 是最终通过结果；首次 `regression.xcresult` 的一个失败已由上述同名账号修正消除。
- 没有新的真机认证或同步矩阵；仅本地展示层变化，Mac、Shared、schema、同步数据和缓存均不变。TF 归档及可用性以随后发布回执为准。
