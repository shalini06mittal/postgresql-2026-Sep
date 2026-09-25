# PostgreSQL Querying: Joins, Sorting, Limiting, Subqueries, MERGE and Window Functions

A teaching guide to combining, ordering, and analyzing data in PostgreSQL.

> **Version note:** Written for modern PostgreSQL (14–18). Version-specific features are flagged inline (for example `FETCH FIRST ... WITH TIES` in 13, `MERGE` in 15, `NOT MATCHED BY SOURCE` and `MERGE ... RETURNING` in 17).

---

## Table of Contents

1. [Sample Data](#1-sample-data)
2. [Joins](#2-joins)
   - [2.1 Why Joins?](#21-why-joins)
   - [2.2 INNER JOIN](#22-inner-join)
   - [2.3 LEFT, RIGHT and FULL OUTER JOIN](#23-left-right-and-full-outer-join)
   - [2.4 CROSS JOIN](#24-cross-join)
   - [2.5 Self Joins](#25-self-joins)
   - [2.6 USING, NATURAL and Non-Equi Joins](#26-using-natural-and-non-equi-joins)
   - [2.7 Anti-Joins and Semi-Joins](#27-anti-joins-and-semi-joins)
   - [2.8 LATERAL Joins](#28-lateral-joins)
   - [2.9 Join Algorithms](#29-join-algorithms)
   - [2.10 Set Operators](#210-set-operators)
   - [2.11 Common Join Pitfalls](#211-common-join-pitfalls)
3. [Sorting](#3-sorting)
   - [3.1 ORDER BY Basics](#31-order-by-basics)
   - [3.2 NULL Ordering](#32-null-ordering)
   - [3.3 Sorting by Expressions and Custom Orders](#33-sorting-by-expressions-and-custom-orders)
   - [3.4 Collation and Text Sorting](#34-collation-and-text-sorting)
   - [3.5 Sorting and Performance](#35-sorting-and-performance)
4. [Limiting Results](#4-limiting-results)
   - [4.1 LIMIT and OFFSET](#41-limit-and-offset)
   - [4.2 FETCH FIRST and WITH TIES](#42-fetch-first-and-with-ties)
   - [4.3 Pagination Strategies](#43-pagination-strategies)
   - [4.4 DISTINCT ON: Top Row per Group](#44-distinct-on-top-row-per-group)
   - [4.5 Sampling Rows](#45-sampling-rows)
5. [Subqueries](#5-subqueries)
   - [5.1 Types of Subqueries](#51-types-of-subqueries)
   - [5.2 Scalar Subqueries](#52-scalar-subqueries)
   - [5.3 IN, ANY and ALL](#53-in-any-and-all)
   - [5.4 EXISTS and NOT EXISTS](#54-exists-and-not-exists)
   - [5.5 Correlated Subqueries](#55-correlated-subqueries)
   - [5.6 Subqueries in FROM](#56-subqueries-in-from)
   - [5.7 Common Table Expressions](#57-common-table-expressions)
   - [5.8 Recursive CTEs](#58-recursive-ctes)
   - [5.9 Subquery vs Join](#59-subquery-vs-join)
6. [MERGE](#6-merge)
   - [6.1 What MERGE Does](#61-what-merge-does)
   - [6.2 Syntax](#62-syntax)
   - [6.3 Basic Examples](#63-basic-examples)
   - [6.4 Conditions and Clause Order](#64-conditions-and-clause-order)
   - [6.5 NOT MATCHED BY SOURCE and RETURNING](#65-not-matched-by-source-and-returning)
   - [6.6 Rules, Limits and Concurrency](#66-rules-limits-and-concurrency)
   - [6.7 MERGE vs INSERT ON CONFLICT](#67-merge-vs-insert-on-conflict)
7. [Window Functions](#7-window-functions)
   - [7.1 The Idea](#71-the-idea)
   - [7.2 Syntax](#72-syntax)
   - [7.3 PARTITION BY and ORDER BY](#73-partition-by-and-order-by)
   - [7.4 Ranking Functions](#74-ranking-functions)
   - [7.5 Value Functions: LAG, LEAD and Friends](#75-value-functions-lag-lead-and-friends)
   - [7.6 Aggregates as Window Functions](#76-aggregates-as-window-functions)
   - [7.7 Frames](#77-frames)
   - [7.8 Named Windows and FILTER](#78-named-windows-and-filter)
   - [7.9 Classic Patterns](#79-classic-patterns)
   - [7.10 Restrictions](#710-restrictions)
8. [Query Execution Order and Performance Tips](#8-query-execution-order-and-performance-tips)
9. [Hands-On Exercises](#9-hands-on-exercises)
10. [Quick Reference Cheat Sheet](#10-quick-reference-cheat-sheet)

---

## 1. Sample Data

All examples use these tables. Run this script in `psql` to follow along.

```sql
CREATE TABLE departments (
    id   integer PRIMARY KEY,
    name text NOT NULL
);

CREATE TABLE employees (
    id         integer PRIMARY KEY,
    name       text NOT NULL,
    dept_id    integer REFERENCES departments (id),   -- nullable on purpose
    manager_id integer REFERENCES employees (id),
    salary     numeric(10,2) NOT NULL,
    hire_date  date NOT NULL
);

CREATE TABLE sales (
    id        integer PRIMARY KEY,
    emp_id    integer REFERENCES employees (id),
    sale_date date NOT NULL,
    amount    numeric(10,2) NOT NULL
);

INSERT INTO departments VALUES
    (1, 'Engineering'), (2, 'Sales'), (3, 'HR'), (4, 'Legal');   -- Legal has no employees

INSERT INTO employees VALUES
    (1, 'Alice', 1, NULL, 150000, '2018-03-01'),
    (2, 'Bob',   1, 1,    120000, '2019-06-15'),
    (3, 'Carol', 1, 1,    120000, '2020-01-10'),
    (4, 'Dave',  2, 1,     90000, '2019-09-01'),
    (5, 'Erin',  2, 4,     85000, '2021-02-20'),
    (6, 'Frank', 2, 4,     85000, '2022-07-11'),
    (7, 'Grace', NULL, 1,  70000, '2023-01-05'),             -- no department
    (8, 'Heidi', 3, 1,     65000, '2020-11-30');

INSERT INTO sales VALUES
    (1, 4, '2026-01-05',  500),
    (2, 4, '2026-01-20',  700),
    (3, 5, '2026-01-12',  300),
    (4, 5, '2026-02-03',  900),
    (5, 6, '2026-02-14',  400),
    (6, 4, '2026-02-25',  650),
    (7, 6, '2026-03-02', 1200),
    (8, 5, '2026-03-15',  350);
```

Deliberate quirks for teaching: **Legal** has no employees, **Grace** has no department, **Alice** has no manager, and several people share the same salary (useful for ranking).

---

## 2. Joins

### 2.1 Why Joins?

Relational data is split across tables to avoid duplication. A **join** combines rows from two or more tables based on a related column, typically a foreign key matching a primary key.

```
 employees                    departments
 +----+-------+---------+     +----+-------------+
 | id | name  | dept_id | --> | id | name        |
 +----+-------+---------+     +----+-------------+
 | 1  | Alice | 1       |     | 1  | Engineering |
 | 7  | Grace | NULL    |     | 4  | Legal       |
 +----+-------+---------+     +----+-------------+
```

| Join type | Returns |
|---|---|
| `INNER JOIN` | Only rows with a match on both sides |
| `LEFT [OUTER] JOIN` | All left rows + matches (NULLs where no match) |
| `RIGHT [OUTER] JOIN` | All right rows + matches |
| `FULL [OUTER] JOIN` | All rows from both sides |
| `CROSS JOIN` | Every combination (Cartesian product) |

### 2.2 INNER JOIN

```sql
SELECT e.name AS employee, d.name AS department
FROM employees e
INNER JOIN departments d ON d.id = e.dept_id;
```

- `INNER` is optional: `JOIN` alone means inner join.
- **Grace** (NULL `dept_id`) and **Legal** (no employees) do **not** appear.
- Table aliases (`e`, `d`) keep queries short and are required for self joins.

Joining more than two tables:

```sql
SELECT e.name, d.name AS dept, s.sale_date, s.amount
FROM employees e
JOIN departments d ON d.id = e.dept_id
JOIN sales s       ON s.emp_id = e.id
ORDER BY s.sale_date;
```

### 2.3 LEFT, RIGHT and FULL OUTER JOIN

```sql
-- LEFT: keep every employee, even without a department
SELECT e.name, d.name AS department
FROM employees e
LEFT JOIN departments d ON d.id = e.dept_id;
-- Grace appears with department = NULL

-- RIGHT: keep every department, even without employees
SELECT e.name, d.name AS department
FROM employees e
RIGHT JOIN departments d ON d.id = e.dept_id;
-- Legal appears with employee = NULL

-- FULL: keep everything from both sides
SELECT e.name, d.name AS department
FROM employees e
FULL JOIN departments d ON d.id = e.dept_id;
-- Both Grace and Legal appear
```

```
 INNER          LEFT           RIGHT          FULL
 ( A (=) B )    ( A(=) B )     ( A (=)B )     ( A(=)B )
   overlap       A + overlap    overlap + B    everything
```

> `RIGHT JOIN` is just a `LEFT JOIN` with the tables swapped. Most developers stick to `LEFT` for readability.

**ON vs WHERE in outer joins**

```sql
-- Filter in ON: keeps all employees; only Sales-dept matches are joined
SELECT e.name, d.name
FROM employees e
LEFT JOIN departments d ON d.id = e.dept_id AND d.name = 'Sales';

-- Filter in WHERE: removes non-matching rows entirely (behaves like an INNER JOIN)
SELECT e.name, d.name
FROM employees e
LEFT JOIN departments d ON d.id = e.dept_id
WHERE d.name = 'Sales';
```

For outer joins, conditions on the **optional side** belong in `ON` if you want to preserve unmatched rows.

### 2.4 CROSS JOIN

Produces `rows(A) x rows(B)` combinations. Useful for generating grids or calendars.

```sql
SELECT d.name, m.month
FROM departments d
CROSS JOIN generate_series(1, 3) AS m(month);   -- 4 x 3 = 12 rows

-- Equivalent old style (avoid): FROM departments d, generate_series(1,3) m
```

> Forgetting a join condition silently creates a Cartesian product, so watch out for unexpectedly huge row counts.

### 2.5 Self Joins

Join a table to itself using two aliases, for example to look up each employee's manager.

```sql
SELECT e.name AS employee, m.name AS manager
FROM employees e
LEFT JOIN employees m ON m.id = e.manager_id
ORDER BY e.id;
-- Alice has manager NULL (LEFT JOIN keeps her)
```

Find employees earning more than a colleague in the same department:

```sql
SELECT DISTINCT a.name
FROM employees a
JOIN employees b ON a.dept_id = b.dept_id AND a.salary > b.salary;
```

### 2.6 USING, NATURAL and Non-Equi Joins

**USING**: shorthand when the join columns have the same name. The column appears once in `SELECT *`.

```sql
SELECT * FROM employees JOIN sales USING (id);   -- joins on id = id (illustrative only)
```

**NATURAL JOIN**: joins on *all* columns with matching names. **Avoid it**: adding a column to either table later can silently change results.

**Non-equi joins**: conditions other than `=`.

```sql
-- Pair each employee with colleagues hired later, in the same department
SELECT a.name AS earlier, b.name AS later
FROM employees a
JOIN employees b
  ON a.dept_id = b.dept_id AND a.hire_date < b.hire_date;

-- Range join
SELECT e.name, s.amount
FROM employees e
JOIN sales s ON s.emp_id = e.id AND s.sale_date BETWEEN e.hire_date AND now();
```

**NULLs never match with `=`.** To join treating NULL as equal:

```sql
ON a.col IS NOT DISTINCT FROM b.col
```

### 2.7 Anti-Joins and Semi-Joins

**Anti-join: rows with NO match.** Departments with no employees:

```sql
-- Preferred: NOT EXISTS
SELECT d.*
FROM departments d
WHERE NOT EXISTS (SELECT 1 FROM employees e WHERE e.dept_id = d.id);

-- Alternative: LEFT JOIN ... IS NULL
SELECT d.*
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.id
WHERE e.id IS NULL;
-- Both return: Legal
```

**Semi-join: rows that HAVE a match, without duplicating them.** Departments that have at least one employee:

```sql
SELECT d.*
FROM departments d
WHERE EXISTS (SELECT 1 FROM employees e WHERE e.dept_id = d.id);
```

Compare with `JOIN`, which would return a department once *per employee*.

### 2.8 LATERAL Joins

A `LATERAL` subquery in `FROM` may reference columns from tables listed **before** it, like a per-row loop. It is ideal for "top N per group".

```sql
-- Top 2 sales for each sales employee
SELECT e.name, top.sale_date, top.amount
FROM employees e
CROSS JOIN LATERAL (
    SELECT s.sale_date, s.amount
    FROM sales s
    WHERE s.emp_id = e.id
    ORDER BY s.amount DESC
    LIMIT 2
) AS top
WHERE e.dept_id = 2;

-- Keep employees with zero sales too
... LEFT JOIN LATERAL ( ... ) top ON true
```

Set-returning functions in `FROM` are implicitly lateral:

```sql
SELECT e.name, t.tag
FROM products e, jsonb_array_elements_text(e.tags) AS t(tag);
```

### 2.9 Join Algorithms

The planner chooses one of three strategies per join. See them with `EXPLAIN`.

| Algorithm | How it works | Best when |
|---|---|---|
| **Nested Loop** | For each outer row, look up matches in the inner side (index scan ideal) | One side is small, or the inner side is indexed |
| **Hash Join** | Build a hash table from the smaller side, probe with the other | Large unsorted inputs, equality conditions |
| **Merge Join** | Sort both sides (or use index order) and merge | Both sides large and already sorted, or sorted cheaply |

```sql
EXPLAIN ANALYZE
SELECT e.name, d.name
FROM employees e JOIN departments d ON d.id = e.dept_id;
```

Performance tips:

- **Index foreign key columns** (`employees.dept_id`, `sales.emp_id`). PostgreSQL does not create these automatically.
- Keep statistics fresh (`ANALYZE`) so the planner picks good join orders.
- Join on columns of the **same data type** to avoid casts that block index use.

### 2.10 Set Operators

Related to joins: combine the **results** of queries vertically. Column counts and types must line up.

| Operator | Result |
|---|---|
| `UNION` | Rows from either query, duplicates removed |
| `UNION ALL` | Rows from either query, duplicates kept (faster) |
| `INTERSECT` | Rows in both |
| `EXCEPT` | Rows in the first but not the second |

```sql
SELECT id FROM employees WHERE dept_id = 1
UNION
SELECT id FROM employees WHERE salary > 100000;

SELECT id FROM departments
EXCEPT
SELECT dept_id FROM employees;          -- departments with no employees
```

Use `UNION ALL` unless you truly need de-duplication, because `UNION` adds a sort or hash step.

### 2.11 Common Join Pitfalls

| Pitfall | Symptom | Fix |
|---|---|---|
| Missing join condition | Row count explodes (Cartesian product) | Always write `ON` |
| Filtering outer side in `WHERE` | Outer join behaves like inner join | Move condition to `ON` |
| One-to-many duplicates | Sums are inflated | Aggregate before joining, or use `EXISTS` |
| NULL join keys | Rows silently vanish | Use `LEFT JOIN`, or `IS NOT DISTINCT FROM` |
| `SELECT *` with joins | Duplicate column names, brittle code | List needed columns |
| Ambiguous column names | Error `column reference "id" is ambiguous` | Qualify with alias |

Inflated sum example:

```sql
-- Wrong if a department joins to many employees AND many sales rows
-- Right: aggregate the many-side first
SELECT e.name, s.total
FROM employees e
JOIN (SELECT emp_id, sum(amount) AS total FROM sales GROUP BY emp_id) s
  ON s.emp_id = e.id;
```

---

## 3. Sorting

### 3.1 ORDER BY Basics

Without `ORDER BY`, PostgreSQL returns rows in **no guaranteed order**, even if they appear sorted today.

```sql
SELECT name, salary FROM employees ORDER BY salary;              -- ascending (default)
SELECT name, salary FROM employees ORDER BY salary DESC;         -- descending
SELECT name, dept_id, salary
FROM employees
ORDER BY dept_id ASC, salary DESC, name;                         -- multiple keys
```

- Later keys break ties in earlier ones.
- You may sort by a column **not in the SELECT list**.
- You may sort by an **output alias** or **position** (`ORDER BY 2`), though positions make code fragile.

```sql
SELECT name, salary * 12 AS annual FROM employees ORDER BY annual DESC;
```

- With `SELECT DISTINCT`, the `ORDER BY` expressions must appear in the select list.
- With `GROUP BY`, you can order by aggregates: `ORDER BY sum(amount) DESC`.

### 3.2 NULL Ordering

PostgreSQL treats `NULL` as **larger than any non-null value**:

| Direction | NULLs appear |
|---|---|
| `ASC` | **Last** |
| `DESC` | **First** |

Override explicitly:

```sql
SELECT name, dept_id FROM employees ORDER BY dept_id NULLS FIRST;
SELECT name, dept_id FROM employees ORDER BY dept_id DESC NULLS LAST;
```

### 3.3 Sorting by Expressions and Custom Orders

```sql
-- By expression
SELECT name FROM employees ORDER BY length(name), name;

-- Custom category order with CASE
SELECT name, dept_id FROM employees
ORDER BY CASE dept_id
             WHEN 2 THEN 1      -- Sales first
             WHEN 1 THEN 2      -- then Engineering
             ELSE 3
         END,
         name;

-- Explicit list order using array position
SELECT * FROM departments
ORDER BY array_position(ARRAY['Sales','Engineering','HR','Legal'], name);

-- Random order (expensive on big tables)
SELECT * FROM employees ORDER BY random();
```

### 3.4 Collation and Text Sorting

Text sort order depends on the **collation** (language and locale rules).

```sql
SELECT name FROM employees ORDER BY name COLLATE "C";        -- byte order: uppercase before lowercase
SELECT name FROM employees ORDER BY name COLLATE "en_US";    -- linguistic order (name depends on OS/ICU)
SELECT name FROM employees ORDER BY lower(name);             -- simple case-insensitive sort
```

- Collation is set per database, column, or expression.
- Changing OS or ICU library versions can change sort order, which can corrupt existing text indexes. Reindex after such upgrades.
- The `C` collation is fastest and deterministic but not linguistically correct.

### 3.5 Sorting and Performance

- Sorting large results is expensive. If the data does not fit in `work_mem`, PostgreSQL spills to disk (`Sort Method: external merge` in `EXPLAIN ANALYZE`).
- An **index matching the ORDER BY** can avoid the sort entirely:

```sql
CREATE INDEX idx_emp_dept_salary ON employees (dept_id, salary DESC);
-- Can satisfy: ORDER BY dept_id, salary DESC
```

- `ORDER BY ... LIMIT n` uses an efficient **top-N heapsort** (or an index) and does not sort everything.
- PostgreSQL 13+ has **incremental sort**: if the input is already sorted by the leading keys, it only sorts within groups.
- Index null ordering matters: an index on `(col)` is `ASC NULLS LAST`. Match it, or specify `NULLS FIRST` in the index definition.

---

## 4. Limiting Results

### 4.1 LIMIT and OFFSET

```sql
SELECT name, salary FROM employees ORDER BY salary DESC LIMIT 3;             -- top 3
SELECT name, salary FROM employees ORDER BY salary DESC LIMIT 3 OFFSET 3;    -- rows 4-6
```

- `OFFSET n` skips the first `n` rows.
- `LIMIT ALL` or `LIMIT NULL` means no limit.
- **Always pair `LIMIT` with `ORDER BY`.** Otherwise the rows returned are arbitrary. Add a unique tie-breaker (like `id`) for stable results.

```sql
ORDER BY salary DESC, id       -- deterministic
```

### 4.2 FETCH FIRST and WITH TIES

The SQL-standard equivalent of `LIMIT`:

```sql
SELECT name, salary FROM employees
ORDER BY salary DESC
OFFSET 0 ROWS
FETCH FIRST 3 ROWS ONLY;
```

**`WITH TIES`** (PostgreSQL 13+) also returns any additional rows that tie with the last row:

```sql
SELECT name, salary FROM employees
ORDER BY salary DESC
FETCH FIRST 3 ROWS WITH TIES;
-- Alice (150000), Bob (120000), Carol (120000): exactly 3, no tie beyond
-- With FETCH FIRST 5: Dave(90000), then Erin AND Frank (85000 tie) -> may return 6 rows
```

`WITH TIES` requires an `ORDER BY`.

### 4.3 Pagination Strategies

**Offset pagination** (simple, but slows down on deep pages):

```sql
-- Page 3, 20 per page
SELECT * FROM sales ORDER BY id LIMIT 20 OFFSET 40;
```

The database still reads and discards the first 40 rows. At `OFFSET 1000000` this becomes very slow. It can also skip or repeat rows if data changes between requests.

**Keyset (seek) pagination**: remember the last row seen and continue after it. Fast at any depth and stable.

```sql
-- First page
SELECT id, sale_date, amount FROM sales ORDER BY sale_date, id LIMIT 3;

-- Next page: pass the last row's (sale_date, id)
SELECT id, sale_date, amount FROM sales
WHERE (sale_date, id) > ('2026-01-20', 2)      -- row-value comparison
ORDER BY sale_date, id
LIMIT 3;
```

Back it with a matching index:

```sql
CREATE INDEX idx_sales_date_id ON sales (sale_date, id);
```

| | Offset | Keyset |
|---|---|---|
| Jump to page N | Yes | No (next/previous only) |
| Deep-page speed | Degrades | Constant |
| Stable under inserts | No | Yes |
| Complexity | Low | Moderate |

### 4.4 DISTINCT ON: Top Row per Group

A PostgreSQL extension that keeps the **first row of each group** according to `ORDER BY`.

```sql
-- Highest-paid employee in each department
SELECT DISTINCT ON (dept_id) dept_id, name, salary
FROM employees
WHERE dept_id IS NOT NULL
ORDER BY dept_id, salary DESC;
```

- The `DISTINCT ON` expressions must match the **leftmost** `ORDER BY` expressions.
- For "top N per group" with N > 1, use a window function (section 7.9) or `LATERAL`.

### 4.5 Sampling Rows

```sql
SELECT * FROM sales TABLESAMPLE BERNOULLI (10);       -- about 10% of rows, row by row
SELECT * FROM sales TABLESAMPLE SYSTEM (10);          -- about 10% of pages, faster, clustered
SELECT * FROM sales TABLESAMPLE BERNOULLI (10) REPEATABLE (42);   -- reproducible
```

Much cheaper than `ORDER BY random() LIMIT n` on large tables.

---

## 5. Subqueries

### 5.1 Types of Subqueries

A **subquery** is a `SELECT` nested inside another statement, always enclosed in parentheses.

| Type | Returns | Typical location |
|---|---|---|
| **Scalar** | One row, one column | `SELECT` list, `WHERE`, `SET` |
| **Row** | One row, several columns | `WHERE (a, b) = (subquery)` |
| **Table** | Many rows and columns | `FROM`, `IN`, `EXISTS`, `ANY` |
| **Correlated** | Depends on the outer row | Any of the above |

### 5.2 Scalar Subqueries

Must return **at most one row and one column**. If it returns zero rows the value is `NULL`. More than one row is an error.

```sql
-- Employees earning above the company average
SELECT name, salary
FROM employees
WHERE salary > (SELECT avg(salary) FROM employees);
-- Alice, Bob, Carol (average is 98,125)

-- In the SELECT list
SELECT name,
       salary,
       salary - (SELECT avg(salary) FROM employees) AS diff_from_avg
FROM employees;

-- In an UPDATE
UPDATE employees
SET salary = salary * 1.05
WHERE dept_id = (SELECT id FROM departments WHERE name = 'Sales');
```

### 5.3 IN, ANY and ALL

```sql
-- IN: membership in a subquery result
SELECT name FROM employees
WHERE dept_id IN (SELECT id FROM departments WHERE name IN ('Sales', 'HR'));

-- ANY / SOME: comparison satisfied by at least one value
SELECT name FROM employees
WHERE salary > ANY (SELECT salary FROM employees WHERE dept_id = 2);

-- ALL: comparison satisfied by every value
SELECT name FROM employees
WHERE salary > ALL (SELECT salary FROM employees WHERE dept_id = 2);
```

Facts: `x IN (...)` is the same as `x = ANY (...)`. `x NOT IN (...)` is the same as `x <> ALL (...)`.

> **The NOT IN trap:** if the subquery returns **any NULL**, `NOT IN` never evaluates to true, so you get zero rows.
>
> ```sql
> SELECT * FROM departments
> WHERE id NOT IN (SELECT dept_id FROM employees);   -- returns NOTHING (Grace has NULL dept_id)
> ```
>
> Use `NOT EXISTS` (or filter `WHERE dept_id IS NOT NULL` inside the subquery) instead.

### 5.4 EXISTS and NOT EXISTS

`EXISTS` returns true if the subquery produces **at least one row**. The select list is irrelevant, so `SELECT 1` is the convention. It stops at the first match and handles NULLs safely.

```sql
-- Employees who made at least one sale
SELECT e.name
FROM employees e
WHERE EXISTS (SELECT 1 FROM sales s WHERE s.emp_id = e.id);

-- Departments with no employees
SELECT d.name
FROM departments d
WHERE NOT EXISTS (SELECT 1 FROM employees e WHERE e.dept_id = d.id);
```

### 5.5 Correlated Subqueries

A correlated subquery references the outer query, conceptually re-running for each outer row (the planner often rewrites it into a join).

```sql
-- Employees earning the highest salary in their own department
SELECT e.name, e.dept_id, e.salary
FROM employees e
WHERE e.salary = (SELECT max(salary) FROM employees WHERE dept_id = e.dept_id);

-- Latest sale per employee (as a correlated scalar subquery)
SELECT e.name,
       (SELECT max(s.sale_date) FROM sales s WHERE s.emp_id = e.id) AS last_sale
FROM employees e;
```

They are readable but can be slow on large tables. Compare with a `JOIN`, `LATERAL`, or window function alternative and check `EXPLAIN`.

### 5.6 Subqueries in FROM

A subquery in `FROM` is a **derived table** and **must have an alias**.

```sql
SELECT dept_id, avg_salary
FROM (
    SELECT dept_id, avg(salary) AS avg_salary
    FROM employees
    GROUP BY dept_id
) AS dept_stats
WHERE avg_salary > 80000;
```

Subqueries in `HAVING`:

```sql
SELECT dept_id, sum(salary)
FROM employees
GROUP BY dept_id
HAVING sum(salary) > (SELECT avg(salary) FROM employees);
```

### 5.7 Common Table Expressions

A **CTE** (`WITH` query) names a subquery so it can be read top-to-bottom and reused.

```sql
WITH dept_stats AS (
    SELECT dept_id, avg(salary) AS avg_salary, count(*) AS headcount
    FROM employees
    WHERE dept_id IS NOT NULL
    GROUP BY dept_id
),
big_depts AS (
    SELECT dept_id FROM dept_stats WHERE headcount >= 3
)
SELECT e.name, e.salary, ds.avg_salary
FROM employees e
JOIN dept_stats ds USING (dept_id)
WHERE e.dept_id IN (SELECT dept_id FROM big_depts);
```

**Materialization (PostgreSQL 12+)**

- A CTE referenced **once** and with no side effects is inlined into the main query, like a subquery.
- A CTE referenced **more than once** is computed once and stored (materialized).
- Control it explicitly:

```sql
WITH s AS MATERIALIZED     (SELECT ... ) SELECT ...;   -- force a separate step
WITH s AS NOT MATERIALIZED (SELECT ... ) SELECT ...;   -- force inlining
```

CTEs can also contain `INSERT`, `UPDATE`, `DELETE ... RETURNING` (data-modifying CTEs).

### 5.8 Recursive CTEs

For hierarchical or graph data (org charts, category trees, bill of materials).

```sql
WITH RECURSIVE org AS (
    -- Anchor: start at the top
    SELECT id, name, manager_id, 1 AS depth, name::text AS path
    FROM employees
    WHERE manager_id IS NULL

    UNION ALL

    -- Recursive step: join back to the CTE itself
    SELECT e.id, e.name, e.manager_id, o.depth + 1, o.path || ' > ' || e.name
    FROM employees e
    JOIN org o ON e.manager_id = o.id
)
SELECT depth, path FROM org ORDER BY path;
```

```
depth | path
------+--------------------
  1   | Alice
  2   | Alice > Bob
  2   | Alice > Carol
  2   | Alice > Dave
  3   | Alice > Dave > Erin
  3   | Alice > Dave > Frank
  2   | Alice > Grace
  2   | Alice > Heidi
```

Safety notes:

- Recursion stops when the recursive step returns no new rows. Cyclic data loops forever. Add a depth limit (`WHERE o.depth < 20`), or use the `CYCLE` clause (PostgreSQL 14+):

```sql
WITH RECURSIVE org AS (...)
CYCLE id SET is_cycle USING path_ids
SELECT * FROM org WHERE NOT is_cycle;
```

- `SEARCH DEPTH FIRST BY ... SET ...` or `SEARCH BREADTH FIRST` (14+) control traversal order.

### 5.9 Subquery vs Join

| Situation | Prefer |
|---|---|
| Need columns from the other table | `JOIN` |
| Only checking existence or absence | `EXISTS` / `NOT EXISTS` |
| Compare with one aggregate value | Scalar subquery |
| Need a reusable, readable step | CTE |
| Top N per group | `LATERAL` or window function |
| Anti-join with possible NULLs | `NOT EXISTS`, never `NOT IN` |

PostgreSQL's planner often converts equivalent forms to the same plan, so **readability** should usually drive the choice. Verify hot queries with `EXPLAIN (ANALYZE, BUFFERS)`.

---

## 6. MERGE

### 6.1 What MERGE Does

`MERGE` (PostgreSQL 15+) synchronizes a **target** table with a **source** in one statement. It joins the two, then per row runs `INSERT`, `UPDATE`, or `DELETE` depending on whether a match was found. This is often called "upsert" or "sync" logic.

```
 source row --join ON--> target row found?
                          |-- yes --> WHEN MATCHED           --> UPDATE / DELETE / DO NOTHING
                          |-- no  --> WHEN NOT MATCHED       --> INSERT / DO NOTHING
 target row with no source row  ---> WHEN NOT MATCHED BY SOURCE (17+) --> UPDATE / DELETE
```

### 6.2 Syntax

```sql
MERGE INTO target_table [AS t]
USING source_table_or_query [AS s]
ON join_condition
WHEN MATCHED [AND condition] THEN
    UPDATE SET col = expr [, ...]
  | DELETE
  | DO NOTHING
WHEN NOT MATCHED [BY TARGET] [AND condition] THEN
    INSERT [(cols)] VALUES (exprs)
  | DO NOTHING
WHEN NOT MATCHED BY SOURCE [AND condition] THEN          -- PostgreSQL 17+
    UPDATE SET ... | DELETE | DO NOTHING
[RETURNING ...];                                         -- PostgreSQL 17+
```

The source can be a table, view, subquery, or a `VALUES` list.

### 6.3 Basic Examples

Setup:

```sql
CREATE TABLE inventory (
    sku        text PRIMARY KEY,
    qty        integer NOT NULL,
    updated_at timestamptz DEFAULT now()
);
CREATE TABLE incoming (sku text, qty integer);

INSERT INTO inventory (sku, qty) VALUES ('A1', 10), ('B2', 5), ('C3', 8);
INSERT INTO incoming VALUES ('A1', 4), ('B2', 0), ('D4', 7);
```

**Update existing, insert new:**

```sql
MERGE INTO inventory AS t
USING incoming AS s
ON t.sku = s.sku
WHEN MATCHED THEN
    UPDATE SET qty = t.qty + s.qty, updated_at = now()
WHEN NOT MATCHED THEN
    INSERT (sku, qty) VALUES (s.sku, s.qty);
-- A1: 10 + 4 = 14 | B2: 5 + 0 = 5 | C3 untouched | D4 inserted with 7
```

**Add a delete rule:**

```sql
MERGE INTO inventory AS t
USING incoming AS s ON t.sku = s.sku
WHEN MATCHED AND s.qty = 0 THEN
    DELETE
WHEN MATCHED THEN
    UPDATE SET qty = t.qty + s.qty, updated_at = now()
WHEN NOT MATCHED THEN
    INSERT (sku, qty) VALUES (s.sku, s.qty);
-- B2 is deleted because incoming qty = 0
```

**Source as a VALUES list (single-row upsert):**

```sql
MERGE INTO inventory AS t
USING (VALUES ('E5', 12)) AS s (sku, qty)
ON t.sku = s.sku
WHEN MATCHED THEN UPDATE SET qty = s.qty
WHEN NOT MATCHED THEN INSERT (sku, qty) VALUES (s.sku, s.qty);
```

The command tag reports the total affected rows, for example `MERGE 3`.

### 6.4 Conditions and Clause Order

- Each `WHEN` clause may have an extra `AND condition`.
- For each row, clauses are evaluated **top to bottom**, and the **first** clause whose match state and condition apply is executed. Later clauses are skipped for that row.
- Put the **most specific** conditions first (as with `CASE`).
- If no clause applies, the row is left alone.
- In `WHEN NOT MATCHED [BY TARGET]` clauses you can reference only **source** columns. In `WHEN NOT MATCHED BY SOURCE` clauses you can reference only **target** columns.
- `DO NOTHING` explicitly skips a case (useful to stop later clauses from matching).

```sql
MERGE INTO inventory t
USING incoming s ON t.sku = s.sku
WHEN MATCHED AND t.qty = s.qty THEN DO NOTHING           -- avoid pointless writes
WHEN MATCHED THEN UPDATE SET qty = s.qty
WHEN NOT MATCHED THEN INSERT (sku, qty) VALUES (s.sku, s.qty);
```

### 6.5 NOT MATCHED BY SOURCE and RETURNING

Both are **PostgreSQL 17+**.

**Full synchronization**: make the target mirror the source, deleting anything the source no longer has.

```sql
MERGE INTO inventory AS t
USING incoming AS s ON t.sku = s.sku
WHEN MATCHED THEN
    UPDATE SET qty = s.qty
WHEN NOT MATCHED THEN
    INSERT (sku, qty) VALUES (s.sku, s.qty)
WHEN NOT MATCHED BY SOURCE THEN
    DELETE;
```

Or soft-delete instead:

```sql
WHEN NOT MATCHED BY SOURCE THEN
    UPDATE SET qty = 0
```

**RETURNING with `merge_action()`** reports what happened to each row:

```sql
MERGE INTO inventory AS t
USING incoming AS s ON t.sku = s.sku
WHEN MATCHED THEN UPDATE SET qty = t.qty + s.qty
WHEN NOT MATCHED THEN INSERT (sku, qty) VALUES (s.sku, s.qty)
RETURNING merge_action() AS action, t.sku, t.qty;
```

```
 action | sku | qty
--------+-----+-----
 UPDATE | A1  |  14
 UPDATE | B2  |   5
 INSERT | D4  |   7
```

PostgreSQL 18 additionally allows `OLD` and `NEW` references in `RETURNING`.

### 6.6 Rules, Limits and Concurrency

- **Source must not match a target row more than once.** If two source rows match the same target row, PostgreSQL raises: `MERGE command cannot affect row a second time`. De-duplicate the source first.

```sql
USING (SELECT sku, sum(qty) AS qty FROM incoming GROUP BY sku) AS s
```

- The target can be a table, partitioned table, or (17+) an updatable view. It cannot be a foreign table.
- Row-level triggers on the target fire as usual.
- `MERGE` does **not** support `ON CONFLICT`. Its own `WHEN` clauses take over that role.
- **Concurrency:** if another session inserts a matching key between MERGE's join and its insert step, MERGE can fail with a unique violation. It does not silently retry the way `INSERT ... ON CONFLICT` does. Applications should be ready to retry on `unique_violation`.
- For predictable performance, index the **join columns** on both sides (especially the target).
- `MERGE` needs `SELECT` privilege on the source, plus `INSERT`/`UPDATE`/`DELETE` privileges on the target matching the actions used.

### 6.7 MERGE vs INSERT ON CONFLICT

| | `INSERT ... ON CONFLICT` | `MERGE` |
|---|---|---|
| Version | 9.5+ | 15+ |
| Conflict detection | Unique index or constraint | Arbitrary `ON` join condition |
| Actions | Insert, or update / nothing on conflict | Insert, update, delete, do nothing |
| Multiple conditional branches | No | Yes |
| Delete rows | No | Yes |
| Concurrency guarantee | Atomic; never raises unique violation for the conflict target | May raise unique violation under races |
| Best for | Single-table upsert on a unique key | Bulk sync, ETL, multi-branch logic |

---

## 7. Window Functions

### 7.1 The Idea

A **window function** calculates a value across a set of rows *related to the current row*, **without collapsing them** into one row like `GROUP BY` does.

```sql
-- GROUP BY: one row per department
SELECT dept_id, avg(salary) FROM employees GROUP BY dept_id;

-- Window: every employee row, plus the department average alongside
SELECT name, dept_id, salary,
       avg(salary) OVER (PARTITION BY dept_id) AS dept_avg
FROM employees;
```

```
 GROUP BY collapses rows           Window keeps every row
 +-------+---------+              +-------+---------+----------+
 | dept  | avg     |              | name  | salary  | dept_avg |
 +-------+---------+              +-------+---------+----------+
 |   1   | 130000  |              | Alice | 150000  | 130000   |
 |   2   |  86667  |              | Bob   | 120000  | 130000   |
 +-------+---------+              | Carol | 120000  | 130000   |
                                  +-------+---------+----------+
```

### 7.2 Syntax

```sql
function_name(args) OVER (
    [PARTITION BY expr, ...]
    [ORDER BY expr [ASC|DESC] [NULLS FIRST|LAST], ...]
    [frame_clause]
)
```

| Part | Purpose |
|---|---|
| `PARTITION BY` | Splits rows into independent groups (omit for one big group) |
| `ORDER BY` | Orders rows within each partition; required by ranking and offset functions |
| Frame clause | Which rows around the current row are visible to the function |

An empty `OVER ()` means the window is the entire result set.

### 7.3 PARTITION BY and ORDER BY

```sql
SELECT name, dept_id, salary,
       sum(salary) OVER ()                        AS company_total,
       sum(salary) OVER (PARTITION BY dept_id)    AS dept_total,
       sum(salary) OVER (ORDER BY hire_date)      AS running_total,
       round(100.0 * salary / sum(salary) OVER (), 1) AS pct_of_company
FROM employees
ORDER BY hire_date;
```

- **Partition:** rows sharing the same `PARTITION BY` values form a window.
- **Order:** within a partition, `ORDER BY` defines sequence. It also changes the default frame (see 7.7).
- The **query's** final `ORDER BY` is separate from the window's `ORDER BY`.

### 7.4 Ranking Functions

| Function | Behavior on ties | Gaps after ties? |
|---|---|---|
| `row_number()` | Unique sequential number; ties broken arbitrarily | No |
| `rank()` | Ties share a rank | **Yes** (1, 2, 2, 4) |
| `dense_rank()` | Ties share a rank | **No** (1, 2, 2, 3) |
| `percent_rank()` | `(rank - 1) / (rows - 1)` | — |
| `cume_dist()` | Fraction of rows at or before this row's peers | — |
| `ntile(n)` | Divides the partition into `n` roughly equal buckets | — |

```sql
SELECT name, dept_id, salary,
       row_number() OVER w AS row_num,
       rank()       OVER w AS rnk,
       dense_rank() OVER w AS dense
FROM employees
WHERE dept_id IN (1, 2)
WINDOW w AS (PARTITION BY dept_id ORDER BY salary DESC);
```

```
 name  | dept_id | salary | row_num | rnk | dense
-------+---------+--------+---------+-----+------
 Alice |    1    | 150000 |    1    |  1  |   1
 Bob   |    1    | 120000 |    2    |  2  |   2
 Carol |    1    | 120000 |    3    |  2  |   2      <- tie with Bob
 Dave  |    2    |  90000 |    1    |  1  |   1
 Erin  |    2    |  85000 |    2    |  2  |   2
 Frank |    2    |  85000 |    3    |  2  |   2      <- tie with Erin
```

> For ties, `row_number()` order is arbitrary. Add a tie-breaker (`ORDER BY salary DESC, id`) if you need repeatable results.

```sql
-- Quartiles of salary
SELECT name, salary, ntile(4) OVER (ORDER BY salary) AS quartile FROM employees;
```

### 7.5 Value Functions: LAG, LEAD and Friends

| Function | Returns |
|---|---|
| `lag(expr [, offset [, default]])` | Value from `offset` rows **before** the current row (default offset 1) |
| `lead(expr [, offset [, default]])` | Value from `offset` rows **after** |
| `first_value(expr)` | Value from the first row of the frame |
| `last_value(expr)` | Value from the last row of the frame |
| `nth_value(expr, n)` | Value from the n-th row of the frame |

Month-over-month change:

```sql
WITH monthly AS (
    SELECT date_trunc('month', sale_date)::date AS month, sum(amount) AS total
    FROM sales
    GROUP BY 1
)
SELECT month,
       total,
       lag(total) OVER (ORDER BY month)                    AS prev_total,
       total - lag(total) OVER (ORDER BY month)            AS change,
       lead(total) OVER (ORDER BY month)                   AS next_total
FROM monthly;
```

```
   month    | total | prev_total | change | next_total
------------+-------+------------+--------+-----------
 2026-01-01 | 1500  |   NULL     |  NULL  |   1950
 2026-02-01 | 1950  |   1500     |   450  |   1550
 2026-03-01 | 1550  |   1950     |  -400  |   NULL
```

Provide a default to avoid NULL at the edges: `lag(total, 1, 0) OVER (...)`.

```sql
-- Compare each salary to the department's top salary
SELECT name, dept_id, salary,
       first_value(salary) OVER (PARTITION BY dept_id ORDER BY salary DESC) AS dept_top
FROM employees;
```

### 7.6 Aggregates as Window Functions

Any aggregate (`sum`, `avg`, `count`, `min`, `max`, `array_agg`, `string_agg`, ...) can be used with `OVER`.

```sql
-- Running total of sales per employee
SELECT emp_id, sale_date, amount,
       sum(amount) OVER (PARTITION BY emp_id ORDER BY sale_date) AS running_total
FROM sales
ORDER BY emp_id, sale_date;
-- Dave (emp 4): 500, 1200, 1850

-- Share of total
SELECT emp_id, sum(amount) AS total,
       round(100.0 * sum(amount) / sum(sum(amount)) OVER (), 1) AS pct
FROM sales
GROUP BY emp_id;
```

In the second query, `sum(sum(amount)) OVER ()` works because the window function runs **after** `GROUP BY`, and so sees the grouped totals.

### 7.7 Frames

The **frame** is the subset of the partition the function actually sees for the current row.

```
 mode BETWEEN start AND end [EXCLUDE ...]

 mode:   ROWS    (physical row counts)
         RANGE   (value-based, on the ORDER BY column)
         GROUPS  (peer groups, PostgreSQL 11+)

 bounds: UNBOUNDED PRECEDING | n PRECEDING | CURRENT ROW | n FOLLOWING | UNBOUNDED FOLLOWING
```

**Default frame**

| Window definition | Default frame |
|---|---|
| With `ORDER BY` | `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` (includes **peers** with equal sort values) |
| Without `ORDER BY` | The entire partition |

**Moving average (3-row window):**

```sql
SELECT sale_date, amount,
       round(avg(amount) OVER (
           ORDER BY sale_date
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ), 2) AS moving_avg_3
FROM sales;
```

**Range by value** (needs a single numeric/date ORDER BY key):

```sql
SELECT sale_date, amount,
       sum(amount) OVER (
           ORDER BY sale_date
           RANGE BETWEEN INTERVAL '7 days' PRECEDING AND CURRENT ROW
       ) AS last_7_days
FROM sales;
```

**ROWS vs RANGE with ties:** with `RANGE` (the default), rows with equal `ORDER BY` values are peers and all get the same running total. Use `ROWS` for a strict row-by-row running total.

```sql
sum(amount) OVER (ORDER BY sale_date ROWS UNBOUNDED PRECEDING)
```

> **The `last_value` gotcha:** with the default frame ending at `CURRENT ROW`, `last_value()` just returns the current row's value. To get the true last row, extend the frame:
>
> ```sql
> last_value(salary) OVER (
>     PARTITION BY dept_id ORDER BY salary
>     ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
> )
> ```

Ranking functions (`row_number`, `rank`, ...) and `lag`/`lead` **ignore** the frame. Only aggregates and `first_value` / `last_value` / `nth_value` use it.

### 7.8 Named Windows and FILTER

Avoid repetition with a `WINDOW` clause:

```sql
SELECT name, dept_id, salary,
       rank()         OVER w AS rnk,
       sum(salary)    OVER w AS running_sum,
       avg(salary)    OVER (w ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) AS smooth
FROM employees
WINDOW w AS (PARTITION BY dept_id ORDER BY salary DESC);
```

Restrict which rows an **aggregate** window function counts with `FILTER`:

```sql
SELECT emp_id, sale_date, amount,
       count(*) FILTER (WHERE amount > 500)
           OVER (PARTITION BY emp_id) AS big_sales_for_emp
FROM sales;
```

### 7.9 Classic Patterns

**Top N per group**: the 2 highest-paid employees per department

```sql
SELECT *
FROM (
    SELECT name, dept_id, salary,
           dense_rank() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS rnk
    FROM employees
    WHERE dept_id IS NOT NULL
) ranked
WHERE rnk <= 2;
```

Window functions cannot go directly in `WHERE`, so wrap them in a subquery or CTE.

**Remove duplicates** (keep the latest row per key):

```sql
DELETE FROM sales
WHERE id IN (
    SELECT id FROM (
        SELECT id, row_number() OVER (PARTITION BY emp_id, sale_date ORDER BY id DESC) AS rn
        FROM sales
    ) t
    WHERE rn > 1
);
```

**Gaps and islands**: group consecutive runs

```sql
-- IDs: 1,2,3, 7,8, 12  ->  islands (1-3), (7-8), (12-12)
SELECT min(id) AS island_start, max(id) AS island_end
FROM (
    SELECT id, id - row_number() OVER (ORDER BY id) AS grp
    FROM some_table
) t
GROUP BY grp;
```

**Difference from previous row** and **percent change**:

```sql
SELECT sale_date, amount,
       amount - lag(amount) OVER (ORDER BY sale_date) AS diff,
       round(100.0 * (amount - lag(amount) OVER w) / nullif(lag(amount) OVER w, 0), 1) AS pct_change
FROM sales
WINDOW w AS (ORDER BY sale_date);
```

**Cumulative distribution / percentile position:**

```sql
SELECT name, salary,
       round(percent_rank() OVER (ORDER BY salary)::numeric, 2) AS pct_rank,
       round(cume_dist()    OVER (ORDER BY salary)::numeric, 2) AS cum_dist
FROM employees;
```

**Median (ordered-set aggregate, not a window function, but often needed alongside):**

```sql
SELECT dept_id, percentile_cont(0.5) WITHIN GROUP (ORDER BY salary) AS median_salary
FROM employees GROUP BY dept_id;
```

### 7.10 Restrictions

- Allowed only in the **SELECT list** and **ORDER BY**. They are **not** allowed in `WHERE`, `GROUP BY`, `HAVING`, or `JOIN ... ON`. Wrap in a subquery or CTE to filter on them.
- They run **after** `WHERE`, `GROUP BY`, and `HAVING`, so they see only surviving rows and grouped results.
- Window functions cannot be nested inside each other.
- PostgreSQL has no `QUALIFY` clause. Use a subquery or CTE instead.
- Different `OVER` definitions in one query may each require their own sort, so limit the number of distinct windows on big data, and index columns used in `PARTITION BY` / `ORDER BY` where helpful.

---

## 8. Query Execution Order and Performance Tips

**Logical order of evaluation** (not the order you write it):

```
 1. FROM / JOIN        build the row source
 2. WHERE              filter rows
 3. GROUP BY           form groups
 4. HAVING             filter groups
 5. Window functions   computed over the remaining rows
 6. SELECT             evaluate expressions, aliases assigned
 7. DISTINCT / DISTINCT ON
 8. UNION / INTERSECT / EXCEPT
 9. ORDER BY           may use output aliases
10. LIMIT / OFFSET / FETCH
```

Consequences:

- You **cannot** use a `SELECT` alias in `WHERE` (but you can in `ORDER BY`).
- Window functions cannot appear in `WHERE`.
- `LIMIT` applies last, so it does not reduce the work done by joins and aggregates unless an index lets the planner stop early.

**Practical tips**

| Goal | Advice |
|---|---|
| Understand a slow query | `EXPLAIN (ANALYZE, BUFFERS)`, and compare estimated vs actual rows |
| Speed up joins | Index foreign keys and join columns; keep data types matching |
| Avoid large sorts | Add indexes matching `ORDER BY`; use `LIMIT`; raise `work_mem` for the session if needed |
| Filter early | Put conditions in `WHERE` (or the `ON` of inner joins) so fewer rows flow upward |
| Keep statistics fresh | `ANALYZE` after bulk loads |
| Prefer `EXISTS` | Over `IN` with large or nullable subqueries, and always over `NOT IN` |
| Use `UNION ALL` | Unless de-duplication is required |
| Test safely | Wrap DML/MERGE experiments in `BEGIN; ... ROLLBACK;` |

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT e.name, d.name, sum(s.amount)
FROM employees e
JOIN departments d ON d.id = e.dept_id
JOIN sales s ON s.emp_id = e.id
GROUP BY e.name, d.name
ORDER BY 3 DESC
LIMIT 5;
```

---

## 9. Hands-On Exercises

Use the sample data from section 1.

**Exercise 1: Joins**

1. List every employee with their department name, including employees with no department.
2. List every department with its employee count, including departments with no employees.
3. Show each employee with their manager's name (managers can be NULL).
4. Find departments that have **no** employees using `NOT EXISTS`, then again with `LEFT JOIN ... IS NULL`, then again with `NOT IN`. Explain why the third gives a different answer.
5. Produce a full outer join between employees and departments and count the unmatched rows on each side.

**Exercise 2: Sorting and limiting**

1. Sort employees by department (NULL department **first**), then by salary descending.
2. Return the 3 highest-paid employees using `LIMIT`, then with `FETCH FIRST 3 ROWS WITH TIES`. Then change to 5 and compare.
3. Return "page 2" of sales (page size 3) using `OFFSET`, then reproduce it using keyset pagination.
4. Use `DISTINCT ON` to find each employee's most recent sale.

**Exercise 3: Subqueries**

1. Find employees earning more than the average salary of **their own department** (correlated subquery).
2. Find employees who have made at least one sale (`EXISTS`) and those who have made none (`NOT EXISTS`).
3. Use a CTE to compute total sales per employee, then list only those above the average of those totals.
4. Write a recursive CTE listing all direct and indirect reports of Dave.

**Exercise 4: MERGE**

1. Create `price_list(sku, price)` and `price_updates(sku, price)`. Write a `MERGE` that updates changed prices, inserts new SKUs, and skips unchanged rows with `DO NOTHING`.
2. Add a condition that deletes SKUs when the updated price is `NULL`.
3. (PostgreSQL 17+) Add `WHEN NOT MATCHED BY SOURCE THEN DELETE` and `RETURNING merge_action(), *` to see what changed.
4. Deliberately put a duplicate `sku` in `price_updates` and observe the error.

**Exercise 5: Window functions**

1. Rank employees by salary within each department using `row_number`, `rank`, and `dense_rank` side by side. Where do they differ?
2. Compute a running total of sales per employee ordered by date.
3. Show each month's sales total next to the previous month's, with the percentage change.
4. Compute each employee's salary as a percentage of their department total.
5. Return the top 2 earners per department without using `LIMIT`.
6. Compute a 3-row moving average of sales amounts, then change `ROWS` to `RANGE` and explain any difference.
7. Demonstrate the `last_value` gotcha, then fix it with an explicit frame.

---

## 10. Quick Reference Cheat Sheet

**Joins**

```sql
FROM a JOIN b ON a.id = b.a_id            -- inner
FROM a LEFT JOIN b ON ...                 -- all of a
FROM a FULL JOIN b ON ...                 -- all of both
FROM a CROSS JOIN b                       -- every combination
FROM a JOIN a AS a2 ON ...                -- self join
FROM a CROSS JOIN LATERAL (SELECT ... WHERE x = a.x LIMIT 3) t   -- per-row subquery
WHERE NOT EXISTS (SELECT 1 FROM b WHERE b.a_id = a.id)           -- anti-join
```

**Sorting and limiting**

```sql
ORDER BY col DESC NULLS LAST, other ASC
ORDER BY CASE ... END
LIMIT 10 OFFSET 20
FETCH FIRST 10 ROWS ONLY | WITH TIES
WHERE (k1, id) > (:last_k1, :last_id) ORDER BY k1, id LIMIT 20      -- keyset paging
SELECT DISTINCT ON (grp) ... ORDER BY grp, ranking_col DESC          -- top 1 per group
```

**Subqueries**

```sql
WHERE x > (SELECT avg(x) FROM t)                   -- scalar
WHERE x IN (SELECT ...)      WHERE x > ANY (SELECT ...)
WHERE EXISTS (SELECT 1 ...)  WHERE NOT EXISTS (SELECT 1 ...)   -- NULL-safe
FROM (SELECT ...) AS alias
WITH cte AS (SELECT ...) SELECT ... FROM cte;
WITH RECURSIVE r AS (anchor UNION ALL recursive_step) SELECT ... FROM r;
```

**MERGE**

```sql
MERGE INTO t USING s ON t.k = s.k
WHEN MATCHED AND cond THEN UPDATE SET ... | DELETE | DO NOTHING
WHEN NOT MATCHED THEN INSERT (...) VALUES (...)
WHEN NOT MATCHED BY SOURCE THEN DELETE                -- 17+
RETURNING merge_action(), t.*;                        -- 17+
```

**Window functions**

```sql
fn() OVER (PARTITION BY p ORDER BY o ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)

row_number()  rank()  dense_rank()  ntile(n)  percent_rank()  cume_dist()
lag(x,n,def)  lead(x,n,def)  first_value(x)  last_value(x)  nth_value(x,n)
sum(x) OVER (...)  avg(x) OVER (...)  count(*) FILTER (WHERE ...) OVER (...)
WINDOW w AS (PARTITION BY p ORDER BY o)
```

**Remember**

| Rule | Why |
|---|---|
| Always `ORDER BY` with `LIMIT` | Otherwise row selection is arbitrary |
| Never `NOT IN` with nullable subqueries | One NULL makes the whole test fail |
| Conditions on the optional side of an outer join go in `ON` | `WHERE` turns it into an inner join |
| Index foreign keys | Speeds joins, deletes, and updates |
| Window functions go in a subquery to be filtered | They are not allowed in `WHERE` |
| Default window frame stops at `CURRENT ROW` (with `ORDER BY`) | Explains the `last_value` surprise |
| De-duplicate the `MERGE` source | One source row per target row |

---

*Further reading: the official PostgreSQL documentation at <https://www.postgresql.org/docs/current/>: "Queries" (joins, sorting, limits, WITH), "Window Functions", "SQL Commands: MERGE", and "Functions and Operators".*
