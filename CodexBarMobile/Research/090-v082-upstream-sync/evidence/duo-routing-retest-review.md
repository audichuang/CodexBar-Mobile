# Duo 内屏滚动路由修复复测独立审查

结论：原失败的输入路由缺陷已得到运行证据验证。本次内屏竖屏Cost/分享可达性用例Passed，45.060秒；没有由原失败证明的产品滚动缺陷。

## 实际证据

- `duo-inner-portrait-routing.xcresult`：Duo `44FF07DE-FAD8-4670-B9D8-35542A3FE199`，iOS27.1 24A94232，CostAndSharePanesAreAccessibleAtTheCurrentSize单用例Passed，xcodebuild TEST EXECUTE SUCCEEDED。
- 对全部附件导出后，成功test仅保留4张显式截图，自动Synthesized Event二进制附件已删除。因此未伪造不存在的事件附件。继续只读解压xcresult原始Xcode diagnostics，找到**4条drag全部display3；3条tap也全部display3**。事件路径、原诊断SHA256和行号记录在`duo-routing-retest-events.json`。原诊断只读提取为`duo-routing-xcode-diagnostics.txt`。
- 对照上一轮`duo-input-routing.json`：48条应用根级drag全部display1，3条具体元素tap全部display3。修复将手势锚定真实scrollView祖先和window交集后，本轮不再发往停用外屏。
- 成功4条drag中，前3条使Cost滚到后面的Budgets和Daily Spend，后1条使分享页控制区进入屏幕；不再循环16次而没有移动。

## 独立视觉检查

`duo-routing-retest-attachments/manifest.json`保存全部4图；screen0是停用外屏黑图，screen1是2006×2852活动内屏完整App图。原图带方向metadata，在当前查看器倒置；本审查未修改/旋转图像文件。

- Cost screen1（15D52B2E-5E65-4E43-920A-58B8BA93DE0A.png）可见真实Daily Spend (USD)完整曲线、日期刻度及上方Codex/Claude预算卡；与原失败停在Overview/ProviderShare的录像帧不同，证明实际内容发生滚动。
- Share screen1（7DC808CC-9C4A-4AC8-8F21-44C2F4FE69F5.png）可见Template下Classic/Vibe/Heatmap、Details/Period 30 Days、说明文字和完整蓝色Share Image按钮，无裁切；上方原生Create Share Card导航和Close仍在。period和action的isHittable断言均通过。
- Close在日志42.05秒点击，其实际事件display3；43.48秒随后等待Cost的cost-share-button，44.49秒exists通过。**没有单独的close后截图或isHittable断言**，因此close后前台画面的证据强度低于上面的两张完整App图；后续跨姿态收尾可补capture/可点断言。并未触发实际Share Image导出或系统分享。

## 适用范围

此次只证明选定真实内屏竖屏下Cost第二报告、分享Period/Share Image可通过真实滚动达到，并可点击Close返回对应Cost控件。不是全部Duo姿态、折叠状态、草稿跨姿态保留或实体设备证明。相关其他矩阵仍由主线程逐项执行。未编译、操作设备、修改产品/测试源码，也未降低断言或隐去原失败。
