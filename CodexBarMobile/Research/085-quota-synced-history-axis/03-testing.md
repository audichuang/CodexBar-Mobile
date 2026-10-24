# 255 验证记录

证据目录：`/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/QuotaSyncedHistory-3.2.0-255`。

- Xcode 27.1 RC / 27A9275，iOS 27.0完整单测：1319通过、0失败、1项既有EventKit权限条件跳过（参数展开1512次通过）。`final-units.xcresult`、`unit-summary.json`。
- 首次单测编译发现测试fixture对let属性赋值，已修正并完整重跑；保留失败记录，不算通过证据。
- `Scripts/lint.sh lint`、四语本地化及`git diff --check`通过。
- 独立本地CR复查数据来源、周期过滤、同时间本地优先、源冲突/多账号、旧wire没有owner的边界，无未解决发现。
- iPhone Air保留真实数据安装255开发签名Release/CloudKit Production版本。`air-build.log`、`air-install.json`。
- Air详情已有20至23日Claude历史，总览修复后从20日约97%连续下降至23日59%，与详情范围一致；Codex23日历史也出现。未补造100%起点。`screenshots/air-detail-before.jpg`、`air-real.jpg`、`air-expanded.jpg`。
- 日期标签OCR中心间距：修复前约86.5/87.7/86.5/87.7/86.5/49.0px；修复后83.13/81.99/81.99/84.27/81.99/84.27px。文字边界识别有像素误差，模型刻度严格24小时。`axis-verification.json`。
- 普通iPhone横竖屏、展开图例末行、原生搜索/旋转恢复UI测试通过：`phone.xcresult`。截图使用模拟数据验证布局，真实历史依据Air。
- Duo展开横竖屏UI均通过：`duo-portrait.xcresult`、`duo-landscape.xcresult`。完整App截图首尾日期完整、间距均匀、折叠图例未被原生栏位遮挡。控制器无响应后仅重启Device Hub控制器，保留模拟器，通过实际screen 1截图确认横屏。
- 源图标浅/深色检查通过，版本全5target为3.2.0 (255)。发行Archive、签名、上传、ASC/CDN及CR记录由本轮独立provenance保存；本文件不预先声称上传完成。

## 同步兼容矩阵

本轮不改变Mac、Shared wire、CloudKit schema/写入、持久archive，只改iOS只读历史展示。CloudKit为NO_DEPLOY。没有可用于受控切换版本的2 Mac × 2 iPhone完整实体阵列；16组合以完整iOS兼容fixture、源选择/账号隔离测试和实际Air旧Mac同步读取替代。旧iPhone不受读端代码影响，不能把替代验证声称为16组真实硬件通过。

| Case | Mac A | Mac B | iPhone A | iPhone B | Result | Evidence | Notes |
|---:|---|---|---|---|---|---|---|
| 1 | old | old | old | old | substituted | final-units.xcresult；Air实拍 | Mac/wire未变化；未重演实体推送时序 |
| 2 | old | old | old | new | substituted | final-units.xcresult；Air实拍 | Mac/wire未变化；未重演实体推送时序 |
| 3 | old | old | new | old | substituted | final-units.xcresult；Air实拍 | Mac/wire未变化；未重演实体推送时序 |
| 4 | old | old | new | new | substituted | final-units.xcresult；Air实拍 | Mac/wire未变化；未重演实体推送时序 |
| 5 | old | new | old | old | substituted | final-units.xcresult；Air实拍 | Mac/wire未变化；未重演实体推送时序 |
| 6 | old | new | old | new | substituted | final-units.xcresult；Air实拍 | Mac/wire未变化；未重演实体推送时序 |
| 7 | old | new | new | old | substituted | final-units.xcresult；Air实拍 | Mac/wire未变化；未重演实体推送时序 |
| 8 | old | new | new | new | substituted | final-units.xcresult；Air实拍 | Mac/wire未变化；未重演实体推送时序 |
| 9 | new | old | old | old | substituted | final-units.xcresult；Air实拍 | Mac/wire未变化；未重演实体推送时序 |
| 10 | new | old | old | new | substituted | final-units.xcresult；Air实拍 | Mac/wire未变化；未重演实体推送时序 |
| 11 | new | old | new | old | substituted | final-units.xcresult；Air实拍 | Mac/wire未变化；未重演实体推送时序 |
| 12 | new | old | new | new | substituted | final-units.xcresult；Air实拍 | Mac/wire未变化；未重演实体推送时序 |
| 13 | new | new | old | old | substituted | final-units.xcresult；Air实拍 | Mac/wire未变化；未重演实体推送时序 |
| 14 | new | new | old | new | substituted | final-units.xcresult；Air实拍 | Mac/wire未变化；未重演实体推送时序 |
| 15 | new | new | new | old | substituted | final-units.xcresult；Air实拍 | Mac/wire未变化；未重演实体推送时序 |
| 16 | new | new | new | new | substituted | final-units.xcresult；Air实拍 | Mac/wire未变化；未重演实体推送时序 |

残余边界：旧wire历史为服务商级，缺少逐点账号归属；界面明确标注来源，不保存成已验证账号历史。多账号/冲突来源保守省略同步曲线，保留账号本地历史。实际多设备后台推送、所有旧新客户端时序未经16组实体重演。
