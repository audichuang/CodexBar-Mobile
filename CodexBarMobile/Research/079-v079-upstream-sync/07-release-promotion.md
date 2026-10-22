# 正式发布与iOS审核提交

Status: in-progress

用户明确授权Mac live release、iOS上传并提交App Review，iOS保持MANUAL发布。ASC实时核对3.0.0已READY_FOR_SALE，旧draft的Mobile2.10只代表历史基线，正式发布不再沿用。先上传已审查的3.1.0(246)，再发本轮唯一Mac0.79.0.1-mobile.3.1.0，Sparkle172.1.3.1.0；Mac版本和build172.1不再多拆一次用户版本。保持原draft release ID，替换旧metadata/资产；旧2.10包已有本地备份。

Duo：MobileAdaptiveLayout.swift、ReleaseNotesView.swift与mobile-dev完全一致；ContentView仅成本数据撤回与release notes内容变化，无布局/ArrangementView/保留区变化。重新执行DuoWorkspaceUITests，记录实际结果，不扩称实体硬件验证。

提交6轮前已在PR记录架构audit四字段，采取协调发布而非追加功能补丁。Mac产品输入变化仅version.env的MOBILE_VERSION；必须重打包、签名、公证，并在merge后确认Final CI。iOS产品输入不变，archive source固定15be65cbda7e2036f9961376bae3edfcc1b81133。CloudKit仍NO_DEPLOY，Production entitlements不变。
