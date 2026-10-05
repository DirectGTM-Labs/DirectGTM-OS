# S01 — 实际查询结果与对账

来源：[实际 db<>fiddle 运行记录](https://dbfiddle.uk/Wt3hw9F8)。

截图与核对日期：2026-10-05。浏览器所选环境：Postgres 18。

以下表格从上述运行页的实际输出整理，并与操作者提供的截图核对；不是把原先的预期结果直接标成实际结果。完整初始化包含 16 个合成机会，结果中的发现时间为 UTC（+00）。

## Q1：最早五条，只显示 ID 与标题

实际运行的查询：

```sql
SELECT opportunity_id, role_title
FROM dg_opportunities
ORDER BY discovered_at ASC, opportunity_id ASC
LIMIT 5;
```

实际输出：5 行 × 2 列；运行页状态为 `SELECT 5`。

| opportunity_id | role_title |
|---|---|
| O01 | Growth Engineer |
| O02 | Growth Lead |
| O03 | MarTech Engineer |
| O04 | SEO Operations |
| O05 | Growth Engineer |

## Q2：最早三条，显示四个字段

实际运行的查询：

```sql
SELECT opportunity_id, role_title, acquisition_route, discovered_at
FROM dg_opportunities
ORDER BY discovered_at ASC, opportunity_id ASC
LIMIT 3;
```

实际输出：3 行 × 4 列；运行页状态为 `SELECT 3`。

| opportunity_id | role_title | acquisition_route | discovered_at |
|---|---|---|---|
| O01 | Growth Engineer | direct | 2026-09-01 08:00:00+00 |
| O02 | Growth Lead | job_board | 2026-09-02 08:00:00+00 |
| O03 | MarTech Engineer | referral | 2026-09-03 08:00:00+00 |

## Q3：最早五条，显示四个字段

实际运行的查询：

```sql
SELECT opportunity_id, role_title, acquisition_route, discovered_at
FROM dg_opportunities
ORDER BY discovered_at ASC, opportunity_id ASC
LIMIT 5;
```

实际输出：5 行 × 4 列；运行页状态为 `SELECT 5`。

| opportunity_id | role_title | acquisition_route | discovered_at |
|---|---|---|---|
| O01 | Growth Engineer | direct | 2026-09-01 08:00:00+00 |
| O02 | Growth Lead | job_board | 2026-09-02 08:00:00+00 |
| O03 | MarTech Engineer | referral | 2026-09-03 08:00:00+00 |
| O04 | SEO Operations | job_board | 2026-09-04 08:00:00+00 |
| O05 | Growth Engineer | direct | 2026-09-05 08:00:00+00 |

## 校验记录

| 检查 | 实际观察 | 结论 |
|---|---|---|
| 主查询的 ID 与顺序 | Q2 为 O01、O02、O03 | 通过 |
| 增加数量限制 | Q3 为 O01—O05；Q2 为其前三条 | 通过 |
| 缩减输出列 | Q1 与 Q3 的 ID、标题相同；列数从 4 变为 2 | 通过 |
| 行列数量 | Q1 5×2；Q2 3×4；Q3 5×4 | 通过 |
| 完整输入身份 | 页面初始化与原完整 bootstrap 去除首尾空白后一致 | 通过 |

## 先前错误与修正

先前截图中的 SQL 输入框包含练习说明 `S01.md`，数据库在 `session_id: S01` 处报告语法错误。

当前记录显示已改用完整建表与示例数据 SQL，以及三个查询代码块；执行成功。

## 能力记录

本次：使用指导示例进行实际执行，记 `answer_assisted`。

已确认的是执行及结果核对。个人解释、独立复写和迁移能力仍待单独验收。
