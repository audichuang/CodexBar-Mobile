# 最近 Weekly 重置时间驱动的真实额度历史

状态：`done`（实现和本地验收）；远端CR及TestFlight发布结果另由外部provenance记录。用户已确认方案并授权本地 CR、PR CR、合并及 TestFlight。

## 最终约定

以当前用户全部 provider 的有效、尚未到来的 Weekly 重置时间的最小值为右端；左端严格减去 6×24 小时（144 小时），显示七个日期刻度。不是固定日期，也不是只看勾选的曲线。此约定取代 Research 083 的最远截止日/168小时设计。

页面每30秒重新求值；同步 publication 更新时重新 reconcile，过期重置退出候选，新的周期参与重新选取。Session、余额、月额度、未知/阻塞/错误/过期来源不充当 Weekly 锚点。无有效候选时以当前时间作为回退，不能伪造重置日。

真实历史仍按采集时间和账号归属绘制，重置分段、缺测不补齐。改变坐标轴不会创造旧历史或预测未来；若所有 Weekly 都刚重置且剩余超过六天，最新读数也可能在144小时窗口左侧，不能挪动读数掩盖这一边界。

## 实施与验收

- 修改模型取最小值/144小时及七日期刻度，保留原来源验证。
- 四语说明、同一3.2发布说明和build254同步。
- 测试不同用户、未勾选provider、纯时钟到期、收到新reset、DST、真实历史时间戳。
- 本地unit/render、完整App普通iPhone/Duo横竖屏、Air真实数据保留安装。
- 本地独立CR后推送PR，精确head审查、零未解决threads与CI通过后运行merge gate。
- 合并后从对应来源archive/upload，确认ASC VALID、Internal可安装与四语说明。

证据目录：`/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/QuotaNearestWeekly-3.2.0-254`。不改Mac、Shared wire、本地历史schema或CloudKit schema；NO_DEPLOY。
