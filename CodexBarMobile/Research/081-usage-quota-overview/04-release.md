# 3.2.0 (251) 发布来源与验收

状态：`done` · 2026-10-23。仅 TestFlight 内测，包含此前 Summary Tab 大更新与本次 Usage / Cost 功能；没有提交 App Review 或发布 Mac。

## 发布输入与范围

- 基线 `d90e42daef7f54611c7fba7c043452b7125f7436`，任务分支 `feature/usage-quota-overview`；最终 reviewed source `6cd449d8ba69628db9242bdef4cc9f71b5b8d875`，tree `332f57ee4b3095c0b3188409394e73777b1d2170`，见下方最终 receipt。
- 五个发布 target 的版本统一为 `3.2.0 (251)`，由 `project.yml` 生成 Xcode project。3.2 in-app notes 只有一个版本块，保留 Summary、加入剩余额度图和 Cost 分组排序，四语齐全。
- Mac `Sources/`、根 `Tests/`、`version.env`、`CodexBarMobile/Shared/`、既有 merger、CloudKit record schema/payload 没有变更。
- CloudKit audit：**NO_DEPLOY**。新增偏好和观测仅保存在每台 iPhone 本地；主 App、PushExtension、Widgets 使用 Production entitlement。WidgetOptions 无 CloudKit capability。
- 兼容性 16 组合为明确标注的 fixture / reader 替代验证，非两台真实 Mac × 两台真实 iPhone 的 Production 实测；详情见 `02-compatibility-plan.md` 和 `03-testing.md`。

## 交付门禁

1. 以 `03-testing.md` 中各次实际结果结算本地单元、渲染、原生交互、跨屏与独立 CR；保留历史失败及复跑证据。
2. PR 对 `mobile-dev`；当前 head 线上 Codex review clean，全部线程 resolved，PR Fast Checks 绿，临合并执行 `Scripts/check_pr_review_gate.sh`。
3. 从已审查的发布输入 Archive，核对五个 bundle 的版本与实际签名 Production entitlement，记录二进制、资源及完整 archive manifest hash。
4. 上传后回读 ASC `VALID`、`IN_BETA_TESTING` 和 Internal 组可用；四语 What to Test 包含完整 3.2 更新并回读核对。
5. 图标三层验收：1024px 源图、archive 实际编译图和 Apple CDN 图均人工查看；source 图已确认 1024×1024、无 Alpha。

发布证据根目录：`/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/UsageQuota-3.2.0-251/`。`provenance.json` 保存最终来源、hash、ASC build ID、处理状态、测试组及验证时间；archive/export/upload 日志、四语 notes 与截图在同目录。最终结果确认后更新此记录；已完成的 CR、merge、CI、Archive 与上传见下方 receipt，处理完成及内测可用不预先宣称。


## 15:52 UTC 发布候选调整

a05 的线上 Codex CR 已 clean；额外独立本地复核发现账号身份退化时可能混用历史，发布暂不放行。a05 的 Archive、Apple Distribution 本地 export、五目标版本和 Production entitlement 校验曾通过，相关完整证据移至 `superseded-a05bc8e/`，没有上传。修复改变生产输入，必须重新记录 source/tree 并 Archive；旧包及旧 clean receipt 不作为最终发布来源。

该时点 ASC 仅有 build 251 的 `AWAITING_UPLOAD` 预约记录（创建于 07:53 UTC），没有可安装 build。此历史状态不是上传成功或 TF 已分发证据；后续最终来源的上传结果见下。

## 最终来源、审查与合并 receipt

| 项目 | 已确认结果 |
| --- | --- |
| Reviewed source | `6cd449d8ba69628db9242bdef4cc9f71b5b8d875` |
| Reviewed / merged source tree | `332f57ee4b3095c0b3188409394e73777b1d2170`，二者一致 |
| 最终 exact-head clean | [receipt 6369240831](https://github.com/o1xhack/CodexBar-Mobile/pull/208#issuecomment-6369240831)，`2026-10-23T16:07:20Z` |
| 临合并 gate | `merge-gate-208.log`：pass，3 轮 / 0 unresolved |
| PR / merge | [#208](https://github.com/o1xhack/CodexBar-Mobile/pull/208)，`41dbf7cd313fc4c95007ab62c153a68c71d6bdff`，`2026-10-23T16:08:48Z` |
| PR Fast Checks | [39983809520](https://github.com/o1xhack/CodexBar-Mobile/actions/runs/39983809520)：success |
| Final CI | [39984321217](https://github.com/o1xhack/CodexBar-Mobile/actions/runs/39984321217)：success |
| 最新修复验证 | 40 Swift Testing + 2 render + 1 native UI，共 43 tests / 参数展开 60 passes，0 failures / 0 skips；34 渲染配置 / 44 PNG |

全量 1223 Swift Testing / 70 XCTest 属于两个后续 quota 修复前；最终修复通过上述专项，不冒充全量重跑。早期 combined `TEST FAILED`、修正旧 release-intro 断言后的 focused pass、原生适用项 pass 及外屏 compact-phone 1 skip 边界保留在 `03-testing.md`。16 组合继续标记 substituted，非物理多设备 Production 认证。

## 最终 Archive、签名与直接上传

最终 `archive.log` 为 `ARCHIVE SUCCEEDED`，`codesign --verify --deep --strict` 通过。主 App、PushExtension、WidgetOptions、Widgets 和 Sync framework 版本均为 3.2.0 (251)。CloudKit 为 **Production / NO_DEPLOY**。archive 中开发签名字段不冒充 distribution：主 App / 三个 extension 的 archive `get-task-allow=true`，主 App archive APS 为 development；export 阶段重新 distribution 签名。

`export-local.log` 为 `EXPORT SUCCEEDED`；本地导出检查确认 App / 三个 extension 全部 Apple Distribution、`get-task-allow=false`，主 App APS 为 production；需要 CloudKit 的 App、PushExtension、Widgets 仍为 Production。WidgetOptions 没有 CloudKit capability。

| 证据 | SHA-256 / 结果 |
| --- | --- |
| Archive 主二进制 | `5a4e66f4f80f5bc6d5ea12b7f367594ef6b5099489cd5800d50cdbffbda69e8e` |
| Archive Assets | `5a9dfa498f3673a3a4ebba5e61b66486eafe9eac5796776e8ca50e272ae2d085` |
| 完整 archive manifest（101 files） | `715c6d2392cb7e0c2e3e610eb1941af2b0d9b9a5d5e3575fa2474721549e961e` |
| 本地 validation IPA | `233929447ef006e9fe46cdf9c614011563a75abb242e996697e70845b676be36`；**仅本地校验，不是实际上传 IPA hash** |
| 实际上传日志 `export-upload.log` | `140d8ae4347a02709f5d955de4270128a46abcb1fa42476bf9d9c348a9a1d0c8` |

实际上传使用 Xcode `exportArchive destination=upload` 从同一 reviewed archive 直接上传；`export-upload.log` 于 `2026-10-23T16:12:02Z` 明确 `Upload succeeded` 与 `EXPORT SUCCEEDED`。该模式没有在 Export 目录留下可供 hash 的实际上传 IPA，因此 provenance 使用 reviewed source / archive manifest / 上传日志链路；不将本地 validation IPA hash 写成 uploaded IPA hash。

源 1024×1024 图标无 Alpha，archive 编译图 120×120 完全不透明，二者均已人工查看通过。第三层使用实际 altool iconAssetToken 的 152px 图和实际 unmasked 1024px App Store CDN 图，已下载并人工验收：均为预期蓝色代码括号与双柱。`apple-cdn-icon.png` SHA-256 `77fb08e08e353f9c57e45314aec5dc8458b89c02048de2748576dffb882aa211`；`apple-cdn-appstore-icon.png` SHA-256 `9913672b3dc891ec4302413d677c16e77c50e6520ad960a414a43bb2a115519d`。

## TestFlight 最终验收

`upload-status.json` 实际回读：buildUpload ID `edf84cdb-4cee-4f7e-874d-d90fde2c4cff`，3.2.0 (251)，uploadedDate `2026-10-23T09:12:01-07:00`，state **PROCESSING**。该 ID 当时仅作为 buildUpload 记录；后续 `build-status.json` 确认最终 ASC build ID 也是 `edf84cdb-4cee-4f7e-874d-d90fde2c4cff`，processingState `VALID`，expired=false，internalBuildState `IN_BETA_TESTING`，externalBuildState `READY_FOR_BETA_SUBMISSION`。未请求 external review。

- [x] Reviewed source / exact-head clean / gate / merge / Final CI
- [x] 最终 Archive / 本地 distribution 校验 / 直接上传成功
- [x] ASC 最终 build ID `edf84cdb-4cee-4f7e-874d-d90fde2c4cff` 与 `VALID`
- [x] internalBuildState `IN_BETA_TESTING`
- [x] Internal 既有自动全 build 访问与可用状态回读
- [x] 完整 3.2 四语 What to Test 写入与 exact readback
- [x] Apple CDN 两种实际图标人工验收

`groups.json` 的 `complete=true`，组名 Internal，membership=`explicit-and-all-builds`，`hasAccessToAllBuilds=true`，确认既有自动访问。显式 add Internal 请求返回 HTTP 422（该 endpoint 不支持给 internal group 分配），没有改变设置，不记作新增 assignment 成功；服务端完整回读证明本 build 已有访问权限，因此不阻断内测。

`test-notes-readback.json` 已回读 en-US / zh-Hans / zh-Hant / ja 全部四语，与 `test-notes.json` exact match；文案包含此前 Summary 大更新与本次 Usage / Cost、估算边界和跨屏测试建议，未丢失 3.2 内容。

最终验收时间：`2026-10-23T16:17:08.140550+00:00`（`provenance.json`）。3.2.0 (251) 已在 Internal TestFlight 可用，本次目标及 Research 为 `done`。验证范围仍是 Simulator / 16 substituted 组合，不扩展为实体四设备 Production 认证。没有提交 external beta review、App Review，也没有发布 App Store 正式版或 Mac。
