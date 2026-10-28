# 测试、兼容与证据

状态：`in-progress`；产品测试尚未执行。

## 旧/新定义

- old Mac：最近published `v0.79.0.1-mobile.3.1.0`；old iOS：已发布3.2.0 (260)，其source需与archive/ASC绑定核对。
- new Mac：本轮最终reviewed候选0.82.0.1；new iOS：3.3.0 (261)。实际commit/artifact hash将在完成后写入。
- 2 Mac × 2 iPhone gate适用：新增同步显示数据与optional metadata。

| Case | Mac A | Mac B | iPhone A | iPhone B | 结果 | 证据/风险 |
| ---: | --- | --- | --- | --- | --- | --- |
| 1 | old | old | old | old | 未执行 | 待验证；无通过声明 |
| 2 | old | old | old | new | 未执行 | 待验证；无通过声明 |
| 3 | old | old | new | old | 未执行 | 待验证；无通过声明 |
| 4 | old | old | new | new | 未执行 | 待验证；无通过声明 |
| 5 | old | new | old | old | 未执行 | 待验证；无通过声明 |
| 6 | old | new | old | new | 未执行 | 待验证；无通过声明 |
| 7 | old | new | new | old | 未执行 | 待验证；无通过声明 |
| 8 | old | new | new | new | 未执行 | 待验证；无通过声明 |
| 9 | new | old | old | old | 未执行 | 待验证；无通过声明 |
| 10 | new | old | old | new | 未执行 | 待验证；无通过声明 |
| 11 | new | old | new | old | 未执行 | 待验证；无通过声明 |
| 12 | new | old | new | new | 未执行 | 待验证；无通过声明 |
| 13 | new | new | old | old | 未执行 | 待验证；无通过声明 |
| 14 | new | new | old | new | 未执行 | 待验证；无通过声明 |
| 15 | new | new | new | old | 未执行 | 待验证；无通过声明 |
| 16 | new | new | new | new | 未执行 | 待验证；无通过声明 |

## 本机预检

StudioSSD身份与路径检查通过；Xcode27.1/27A9275，SDK iOS27.1/macOS27.0。ASC只读确认3.2.0已发布、build260 VALID；未写入ASC、未执行Production schema export/deploy。没有以此证明真实CloudKit收敛或Duo通过。

