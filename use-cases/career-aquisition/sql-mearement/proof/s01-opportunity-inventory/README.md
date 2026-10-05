# Opportunity Inventory — Deterministic SQL Reads

This case defines a reproducible chronological review queue for career and consulting opportunities in DirectGTM-OS. Three PostgreSQL queries use the same synthetic input to demonstrate stable ordering, an explicit row limit and two output shapes.

The recorded execution returns five rows with two columns, three rows with four columns, and five rows with four columns. All three outputs preserve the expected opportunity ID order. The full fixture contains 16 opportunities; the limits affect the returned rows, not the stored opportunity count.

The result supports an initial manual review queue. Qualification, commercial value and contact priority require additional rules and are outside this case's scope. The sample records do not represent actual vacancies, clients or growth results.

## 本案例解决什么问题

把机会台账按发现时间读取成稳定、可复查的清单，供后续人工检查使用。

- 一行代表一个岗位或咨询机会，不代表一家公司。
- 同一家公司可以对应多个机会，不能把机会数量直接当公司数量。
- 以 `opportunity_id` 为唯一标识。
- 排序先使用 `discovered_at ASC`，时间相同再使用 `opportunity_id ASC`。
- 没有资格筛选，也没有额外时间范围条件；候选集合为示例表中的全部机会。
- `SELECT` 指定输出列，`LIMIT` 限制返回行数；这三条普通查询不修改原表。

## 交付文件

| 文件 | 用途 | 怎样使用 |
|---|---|---|
| `run.sql` | 完整输入及三条实际查询 | 在空的 PostgreSQL 18 练习环境执行全文 |
| `results.md` | 实际输出、运行来源及对账记录 | 阅读和检查，不要粘贴到 SQL 输入框 |
| `README.md` | 业务问题、规则、范围和复现说明 | GitHub 自动展示此文件；也可以在 Obsidian 阅读 |
| `screenshot.png` | 操作者提供的实际浏览器运行截图 | 补充执行证据；清晰的表格以 results.md 为准 |

## 查询与输出

查询编号与实际运行页面中的三个查询代码块一致。前面的大代码块负责准备数据，不计入三个查询。

| 编号 | 查询内容 | 实际结果 | 核对状态 |
|---|---|---|---|
| Q1 | 最早五条，只显示 ID 和标题 | O01—O05；5 行 × 2 列 | 通过 |
| Q2 | 最早三条，显示四个字段 | O01、O02、O03；3 行 × 4 列 | 通过 |
| Q3 | 最早五条，显示四个字段 | O01—O05；5 行 × 4 列 | 通过 |

## 数据与复现

- 数据：完整 `synthetic-v1` 合成训练输入。
- 实际运行页面：[db<>fiddle / Wt3hw9F8](https://dbfiddle.uk/Wt3hw9F8)。
- 截图与核对日期：2026-10-05。
- 浏览器所选环境：Postgres 18。
- 记录方式：从上述实际运行页面读取 SQL 与输出，并与操作者提供的截图核对。
- 初始化代码与之前完整模块的 `sql/bootstrap.sql` 在去除首尾空白后完全一致。
- 文件组织：将页面中的四个代码块合并到 `run.sql`，仅添加说明性 SQL 注释。

复跑步骤：

1. 打开 `run.sql`，复制文件中的全部文字。
2. 在 db<>fiddle 的空练习页选择 Postgres 18，清掉旧示例代码。
3. 把全文粘贴进一个左侧 SQL 输入框，点击顶部 `run`。
4. 建表及插入状态后会出现三个结果表，依次对应 Q1、Q2、Q3。
5. 对照 `results.md` 核对 ID 顺序、行数、列数和具体值。

完整初始化包含后续课程使用的其他表和视图。本案例仅验证机会台账的三条读取查询；初始化代码的出现不意味着操作者已独立掌握其中所有进阶写法。

## 验证与边界

- 三个结果的 ID 顺序正确。
- 输出分别为 5×2、3×4、5×4。
- Q2 是 Q3 的前三条，字段值一致。
- Q1 与 Q3 的 ID、标题一致；减少输出列没有改变选中的五个机会。
- `discovered_at` 与唯一且非空的 `opportunity_id` 组成稳定排序规则。
- 没有 `ORDER BY` 时不能保证结果是最早的记录，即使一次运行恰好返回相同 ID。
- 按时间最早不等于最匹配或最值得联系；本结果不作联系优先级判断。
- 数据为合成输入，不能据此声称真实市场转化、收入或业务提升。

## P1 证据状态

| 验收项 | 当前状态 |
|---|---|
| 在真实练习环境运行三条查询 | 已完成，截图及运行页可检查 |
| 核对顺序、数量、字段值 | 已完成 |
| 可复现输入、SQL、结果、说明 | 已整理，四个文件完整 |
| 操作者用自己的话解释粒度与查询逻辑 | 待口头或文字验收 |
| 操作者解释未排序结果的反例 | 待口头或文字验收 |
| 不看答案完成新的小变化或隔日复写 | 待独立验收 |

本次执行使用了指导示例，记为 `answer_assisted`。文档与文件组织依据实际执行记录协助整理，不作为操作者已独立解释或独立编写的证据。

这是一份可以归档的阶段 Proof；S01 的理解与独立迁移继续验收，P1 整体仍按后续任务推进。

## 下一步验收

先用自己的话回答：

1. 结果中的一行代表什么？
2. `SELECT` 和 `LIMIT` 分别决定什么？
3. 如果去掉 `ORDER BY`，为什么不能保证取到最早三条？
4. 这个结果能支持什么动作，哪些判断还需要别的规则？

隔日保留初始化部分，不看参考查询，写出“只显示 ID 和渠道，按发现时间与 ID 排序，取最早两条”的版本，先预测后运行。真实完成后再追加日期、SQL、结果及独立程度。
