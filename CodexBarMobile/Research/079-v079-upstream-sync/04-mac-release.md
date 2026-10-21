# Mac draft release 证据

Status: `in-progress`；尚未构建/签名公证/创建 Draft。

## 发布方案

- 目标 Mac 0.79.0.1 / BUILD_NUMBER 172.1 / companion 2.10.0；Sparkle 172.1.2.10.0，拟用 tag v0.79.0.1-mobile.2.10.0。
- iOS 3.1.0 (246) 是本轮准备版本，未上传/发布，不能提前写成已发布的 Mac companion。已有 version.env 文档中的旧三段规则示例与四段规则冲突时，遵循顶部明确的四段规则。
- 使用 fork `Scripts/release.sh --draft-no-tag-push`。它在 origin 创建 Draft 和上传 zip/dSYM，跳过 tag 创建/推送及 appcast publication；目标 mobile-dev 只作 GitHub 已知 ref 占位，release notes 明确记录本地源码 SHA。今后用户授权发布前须改成 clean-reviewed 的正式提交。
- 所有签名/公证 staging、widget Xcode builds、大型 logs 使用 /Volumes/StudioSSD/Developer/BuildScratch/CodexBar/v079/；不输出 credential 值。
- Mac product inputs 修改后必须重打包，不能把先前 draft 的二进制当成后续修复已生效。
- 不调用 finalize，不创建 tag、不 push、不 merge、不上传 TestFlight。#196 维持 open，按仓库规则仅 live release 后才能关闭。

## 当前完成证据

- evidence/version-plan.json：数字比较确认新 Sparkle 大于当前 appcast 所有条目。
- 原始 appcast 保持已发布 fork 数据，尚未生成或发布新 feed。
