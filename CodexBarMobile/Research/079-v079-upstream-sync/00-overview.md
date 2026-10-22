# v0.77.0–v0.79.0 一次性上游同步

Status: `done`（Goal 已确认单版本方案）

## 范围与来源

- 分支：`upstream-sync/v0.79.0-mobile.3.1.0`，从最新 `origin/mobile-dev` `7fa778243f1a441a3d45dcfc561b89b16770449c` 创建；所有文档、代码、版本、打包均在该分支。
- 权威基线：`version.env` 的 `UPSTREAM_VERSION=v0.76.0`、`UPSTREAM_SYNC_DATE=2026-10-15`。Mac 0.76.0.2 / 169.2 / Mobile 2.10.0；iOS 项目 3.0.0 (245)。
- 起始 open upstream-sync：[#196](https://github.com/o1xhack/CodexBar-Mobile/issues/196)，只写到 v0.77.0，不能作为最新上游依据。
- GitHub Releases 确认 [v0.77.0](https://github.com/steipete/CodexBar/releases/tag/v0.77.0)、[v0.78.0](https://github.com/steipete/CodexBar/releases/tag/v0.78.0)、[v0.79.0](https://github.com/steipete/CodexBar/releases/tag/v0.79.0) 都已发布。只 merge 最终 v0.79.0，包含前三个版本，不拆版本。
- 历史已关闭 #193/#190/#191：只有 live release 后回复正式 URL 并关闭；本轮起初只准备draft；后续用户授权live后，#196已附正式URL并按completed关闭，终态见07。
- 上游累计 500 个文件，19344 additions / 4226 deletions。相关 PR 和 commit 详见 evidence/upstream-commits.txt、release-*.json。

## 版本方案

| 项目 | 本轮值 | 依据 |
|---|---|---|
| Mac MARKETING_VERSION | 0.79.0.1 | 新上游 + fork 首个补丁，四段规则优先于文档遗留示例 |
| BUILD_NUMBER | 172.1 | v0.79.0 的整数 172，加 fork .1 |
| MOBILE_VERSION | 3.1.0 | 先完成3.1.0(246) TestFlight上传/VALID，再发同一轮唯一Mac版本；原2.10 draft未公开 |
| Sparkle / CFBundleVersion | 172.1.3.1.0 | 大于上次169.2.2.10.0，公开feed签名/长度验证通过 |
| Mac tag | v0.79.0.1-mobile.3.1.0 | 已推送/公开；源为已审查的e64152322 |
| iOS | 3.1.0 (246) | 在项目 3.0.0 (245) 后准备一个功能版本，全部 targets 一致 |

## 阶段与风险

先调研设计、完整 Mac merge、bridge 审计、Mac 测试/draft，再 iOS 展示/本地化/测试和循环 review。成本缓存重构必须保留 fork parser revision/hash 和原地迁移，避免全量重扫或历史金额下降。上游 HTTP server 只跟随显式配置；不启动真实 provider 测试或导入 cookie。凭证问题、CloudKit deploy 或无法判断的 iOS scope 需要用户输入；起始阶段live release/TF/tag/push/merge未授权；用户后续明确授权push/PR和Mac live/iOS上传审核，执行边界以07为准。

本机 SSD 已校验 UUID `9D5FE511-B66C-4765-BB8F-61E5ACB3969D`，逻辑入口和项目 realpath 正确；构建与 evidence 临时大文件统一 BuildScratch。本目录保留小型可复核证据。

## 本轮验收结果

Mac完整回归、最终lint、签名公证draft和appcast候选校验完成；iOS3.1.0(246)四语功能、单测/Widget/render/引导与设备Release编译通过；本地循环review阻塞0。16组合均以冻结old/new真实consumer和定向生产入口测试替代，gate按文档完成；没有实体CloudKit/APNs/cache收敛证据，具体风险见03。

正式发布：[Mac 0.79.0.1 — Mobile 3.1.0](https://github.com/o1xhack/CodexBar-Mobile/releases/tag/v0.79.0.1-mobile.3.1.0)。同draft ID420093277原位晋级，artifact source15fb91b1f、tag e64152322，appcast commit238b29709；Mac实包/公开下载与feed验收通过。PR199/200/201均clean review/0 unresolved后合并，#196已completed关闭。iOS3.1.0(246)已VALID/IN_BETA_TESTING并提交App Review，WAITING_FOR_REVIEW/MANUAL，尚未公开iOS3.1.0。最新发布来源、CI超时修复、Duo证据与风险详07；历史draft及起始权限阶段保留在02–06，不能当最终状态。
