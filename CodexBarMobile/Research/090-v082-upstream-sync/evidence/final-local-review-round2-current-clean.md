# 最终完整候选独立本地 Code Review — clean handoff

审查者：final_candidate_review。只读审查源码、Git、产物、公开签名/provisioning信息与GitHub draft API；只写BuildScratch报告，没有修改源码、构建/运行测试、操作设备、真实账户Keychain或业务容器、推送/合并/发布。

**结论：0 unresolved findings，当前完整本地review gate clean，可进入用户已授权的push/PR与GitHub current-head review阶段。** 此结论不代表PR已审、已merge、已正式发布或iOS已上传。

## 当前来源

- base：bdfb510853270c1ebf6b9d6f5ccbb289a2634db1；完整候选HEAD：4ef5f75674b1788163c868bb350994b2e900a2b9。
- Mac产品/签名来源：18ebb97272a68853473b3c3c565fc56f719901e2；其后仅Research/索引文档，1826项artifact inputs逐一与该commit及当前源码相同，覆盖集合精确相等。
- iOS本地Archive来源：a36c6b110da3d994c8bba6bbcfa777627efa42ff；353项输入到当前仍相同，101个Archive文件最终又逐一size/hash核对通过。
- tracked工作树/index均clean，仅预存error.log/work未跟踪；本轮前/后及当前文件树mode/type/size/hash完整一致。

## 完整范围与发现闭环

继承完整round1/round2逐路径来源审查与所有明确修复补审，最终复核全部base→current变更清单、最终shipping输入、执行证据、产物和文档的一致性。最初599项official-equal采用字节保留与关键引用/集成路径审计，不能把它表述为每条上游源码逐行形式证明。全部发现保留历史，不因修复删除：

- Cursor shared Weekly/uncapped金额（含0）遗漏已修，生产mapper/真实形状fixture复测。
- sourceRecorded贯通fresh/cache、日期窗口、CLI/Mac、Shared、iOS四语、双Mac merger及旧unknown容错；Remote schema1仍严格native-only，新增ambient缓存后原生排除断言。
- fleet子选项基线错误门控、异步fixture竞争/真实defaults隔离、CLI UTC用例均已修。
- R2-A1实际Mac App Group发布能力阻塞：签名与运行ID已对齐Team组；首次Widget默认写回、fallback partial copy/publisher竞争、CLI executable Team/debug解析、三阶段CLI权限、timestamp retry均经源码补审与新受影响gate。最终实包签名/真实运行组及OS正负控证据闭环，已关闭。
- draft更新按tag clobber范围漏洞已修为固定ID/own asset ID/upload_url，旧资产ID/digest与SSD保留副本确认后替换。

## 最终产物独立核对

Mac ZIP 06dcb2492cc1bdeac809650deceb4d1a4388c0170f167b866ec57bdb23473aa1，92810809 bytes；dSYM ZIP d0d3be366d0d243c562b44a1d8df904aecdf16db860fedd86d45185199c00162，74088431 bytes。ZIP实际内容中4个执行文件hash与解包结果吻合，无用户根文件或非法相对路径。App/CLI/watchdog/Widget均arm64+x86_64、minOS14、精确Developer ID Authority/Team3TUERHN53E/hardened runtime、strict签名通过；deep签名、stapler及distribution policy独立读回exit0。App与dSYM两arch UUID匹配。

App/CLI/Widget signed group均3TUERHN53E.com.steipete.codexbar，真实签名App/CLI只读runtime诊断同组，Team前缀授权规则及nonce sandbox正负控吻合；不再靠containerURL非nil或短存活冒充权限。Widget/CLI为AppGroup-only不误要求CloudKit/profile；主App有效profile的AppID/Production/允许containers与签名一致。

App0.82.0.1、Sparkle175.1.3.2.0、companion3.2.0；Mac Widget build175.1依既有包合同单独核对。候选appcast长度/URL/版本/单调性/实际ZIPhash正确；本reviewer另用OpenSSL直接以实际实包SUPublicEDKey验证真实enclosure Ed25519成功，未读取private key。仓库appcast与base仍逐字相同。

GitHub fresh只读API：draft427366941仍draft=true，server tag_name为untagged-780e47f927e739ed48a3，target mobile-dev是placeholder。新ZIP asset687242232、dSYM asset687242624的size/digest与本地精确一致；正文source/placeholder/未发布边界准确。future logical publication tag v0.82.0.1-mobile.3.2.0尚未创建。

保留iOS Archive五bundle3.3.0/261与签名Team正确，App/Push/Widgets Production；WidgetOptions仅本地AppGroup、framework无execution entitlements。App/dSYM UUID一致。它是Apple Development、get-task-allow=true本地Archive，不是App Store/TestFlight分发包，没有export/upload。

## 验证证据与边界

Mac最终128 selections/43groups首遍PASS，与此前97成本分区+1620旧未受影响分区去重覆盖1845 selections/16194 method identifiers；接受独立覆盖审查的实际集合/日志/binary proof，不冒充最终single-binary全量body一次通过。123个条件XCTest skip及Swift Testing opt-in early-return如实保留。full lint3211 SwiftLint/533四语keys/parser与fork CI guards、build、16package合同和timestamp stub通过证据分别记录。

iOS1278 Swift Testing/85suites+75XCTest及150专项/原生渲染、旧系统/普通iPhone/iPad、Duo实际内外横竖/partial/折叠操作和严格系统Widget独立证据已收拢。旧ImageRenderer占位、错误display手势、141秒Widget假阳性及其他失败未沿用，修复/替代证据和残余限制明确。

16种同步组合全部substituted（64读取/32冻结真实pure-consumer merges），不是实体双Mac/双iPhone CloudKit/APNs/缓存收敛验证。CloudKit NO_DEPLOY为明确schema/payload代码审计；本地Mac AppGroup变更不改iOS/Shared wire。README是在merge保留fork后按单独事实审计有意适配，不能声称最终README字节等于base；最终hash guard通过。上游release重CI复用guard未获可复用状态时应按canonical postmerge完整CI执行，未放宽guard。

4ef5最终文档如实区分历史pending与当前结果、server draft tag与future publication tag、iOS已交付3.2与本地3.3，未冒称live或clean PR。后续只需PRURL/本结论的文档小增量补审；shipping输入如再改变，必须重新审影响范围及产物。

本报告不授权merge/tag/live release/appcast/TestFlight/AppReview/CloudKit deploy；下一阶段仍须GitHub当前head review、问题修复复测、线程清零与PR gate。

## 可复核指纹

final-local-review-round2-current-clean-source-end.json；round2-final-mac-independent-verification.json；round2-final-artifact-public-checks.json；历史完整报告final-local-review-round2.md及round1/round2 manifests。当前最终报告可复制至Research evidence，不修改任何产品输入。
