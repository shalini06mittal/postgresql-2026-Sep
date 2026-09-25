# PostgreSQL Table Inheritance, Views, Sequences, Indexing and Partitioning

A teaching guide that explains, in plain language, how PostgreSQL lets you build table hierarchies, present data through views, generate numbers automatically, speed up queries with indexes, and split huge tables into manageable pieces.

> **Version note:** Written for modern PostgreSQL (14–18). Version-specific behavior is flagged inline.

---

## Table of Contents

1. [Sample Data](#1-sample-data)
2. [Table Inheritance](#2-table-inheritance)
   - [2.1 What Problem Does Inheritance Solve?](#21-what-problem-does-inheritance-solve)
   - [2.2 How It Works](#22-how-it-works)
   - [2.3 Querying Inherited Tables](#23-querying-inherited-tables)
   - [2.4 What Is NOT Inherited](#24-what-is-not-inherited)
   - [2.5 Adding and Removing Inheritance](#25-adding-and-removing-inheritance)
   - [2.6 Multiple Inheritance](#26-multiple-inheritance)
   - [2.7 Why Inheritance Fell Out of Favor](#27-why-inheritance-fell-out-of-favor)
   - [2.8 When It Still Makes Sense](#28-when-it-still-makes-sense)
3. [Views](#3-views)
   - [3.1 What Is a View, Really?](#31-what-is-a-view-really)
   - [3.2 Creating and Using Views](#32-creating-and-using-views)
   - [3.3 Updatable Views](#33-updatable-views)
   - [3.4 WITH CHECK OPTION](#34-with-check-option)
   - [3.5 Materialized Views](#35-materialized-views)
   - [3.6 Refreshing Materialized Views](#36-refreshing-materialized-views)
   - [3.7 Views and Security: security_barrier and security_invoker](#37-views-and-security-security_barrier-and-security_invoker)
   - [3.8 Managing Views](#38-managing-views)
   - [3.9 When to Use Which](#39-when-to-use-which)
4. [Sequences](#4-sequences)
   - [4.1 What a Sequence Actually Is](#41-what-a-sequence-actually-is)
   - [4.2 Creating and Using Sequences Directly](#42-creating-and-using-sequences-directly)
   - [4.3 serial vs GENERATED ... AS IDENTITY](#43-serial-vs-generated--as-identity)
   - [4.4 Why Sequences Skip Numbers](#44-why-sequences-skip-numbers)
   - [4.5 Sequences and Transactions](#45-sequences-and-transactions)
   - [4.6 Resetting, Cycling, and Ownership](#46-resetting-cycling-and-ownership)
   - [4.7 Sequences in Concurrent, High-Throughput Systems](#47-sequences-in-concurrent-high-throughput-systems)
5. [Indexing](#5-indexing)
   - [5.1 Why Indexes Exist](#51-why-indexes-exist)
   - [5.2 The Default: B-tree](#52-the-default-b-tree)
   - [5.3 Other Index Types](#53-other-index-types)
   - [5.4 Multi-Column (Composite) Indexes](#54-multi-column-composite-indexes)
   - [5.5 Partial Indexes](#55-partial-indexes)
   - [5.6 Expression Indexes](#56-expression-indexes)
   - [5.7 Unique Indexes and Constraints](#57-unique-indexes-and-constraints)
   - [5.8 Covering Indexes: INCLUDE](#58-covering-indexes-include)
   - [5.9 How to Tell If an Index Is Being Used](#59-how-to-tell-if-an-index-is-being-used)
   - [5.10 Building and Maintaining Indexes](#510-building-and-maintaining-indexes)
   - [5.11 The Cost of Indexes](#511-the-cost-of-indexes)
   - [5.12 Finding Missing or Useless Indexes](#512-finding-missing-or-useless-indexes)
6. [Partitioning](#6-partitioning)
   - [6.1 What Problem Partitioning Solves](#61-what-problem-partitioning-solves)
   - [6.2 The Three Partitioning Strategies](#62-the-three-partitioning-strategies)
   - [6.3 Range Partitioning](#63-range-partitioning)
   - [6.4 List Partitioning](#64-list-partitioning)
   - [6.5 Hash Partitioning](#65-hash-partitioning)
   - [6.6 Sub-Partitioning](#66-sub-partitioning)
   - [6.7 Indexes, Keys and Constraints on Partitioned Tables](#67-indexes-keys-and-constraints-on-partitioned-tables)
   - [6.8 Partition Pruning](#68-partition-pruning)
   - [6.9 Attaching, Detaching and Rolling Old Data Off](#69-attaching-detaching-and-rolling-old-data-off)
   - [6.10 Default Partitions](#610-default-partitions)
   - [6.11 Declarative Partitioning vs Old-Style Inheritance Partitioning](#611-declarative-partitioning-vs-old-style-inheritance-partitioning)
   - [6.12 When to Partition (and When Not To)](#612-when-to-partition-and-when-not-to)
7. [How These Features Work Together](#7-how-these-features-work-together)
8. [Hands-On Exercises](#8-hands-on-exercises)
9. [Quick Reference Cheat Sheet](#9-quick-reference-cheat-sheet)

---

## 1. Sample Data

We will build up sample tables as each topic needs them, but here is a small base you can keep around for the views and indexing sections.

```sql
CREATE TABLE customers (
    id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name     text NOT NULL,
    country  text NOT NULL,
    is_vip   boolean NOT NULL DEFAULT false
);

CREATE TABLE orders (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id bigint NOT NULL REFERENCES customers (id),
    order_date  date NOT NULL,
    status      text NOT NULL DEFAULT 'pending',
    total       numeric(10,2) NOT NULL
);

INSERT INTO customers (name, country, is_vip) VALUES
    ('Alice', 'US', true),
    ('Bob',   'UK', false),
    ('Carol', 'US', false),
    ('Dave',  'IN', true);

INSERT INTO orders (customer_id, order_date, status, total) VALUES
    (1, '2026-01-05', 'shipped',  120.00),
    (1, '2026-02-14', 'shipped',   75.50),
    (2, '2026-01-20', 'pending',   40.00),
    (3, '2026-03-01', 'cancelled', 60.00),
    (4, '2026-03-10', 'shipped',  300.00);
```

---

## 2. Table Inheritance

### 2.1 What Problem Does Inheritance Solve?

Imagine you are designing a database for a company that sells both physical products (which need a `weight` and `warehouse_location`) and digital products (which need a `download_url` and `file_size_mb`). Both kinds of products share a lot in common: a `name`, a `price`, and a `sku`.

You have a few options:

- **One big table** with all columns, leaving irrelevant columns `NULL` for each type (a "digital" row has `NULL` weight, a "physical" row has `NULL` download_url). This works, but the table becomes messy and it is easy to insert nonsensical combinations.
- **Separate tables** with no relationship between them, duplicating the shared columns (`name`, `price`, `sku`) in both. If you want "all products regardless of type", you need to `UNION` them yourself every time.
- **Table inheritance**, where you define a `products` table with the shared columns, and then create `physical_products` and `digital_products` tables that **inherit** from it, automatically getting all of the parent's columns, plus their own extra ones.

Table inheritance is PostgreSQL's built-in way of modeling a "this table is a special case of that table" relationship, and it lets you query "all products" or "just the physical ones" as you prefer.

### 2.2 How It Works

Think of the parent table as defining a **template**, and each child table as "template plus extras."

```sql
CREATE TABLE products (
    id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku   text NOT NULL,
    name  text NOT NULL,
    price numeric(10,2) NOT NULL
);

CREATE TABLE physical_products (
    weight_kg          numeric(6,2),
    warehouse_location text
) INHERITS (products);

CREATE TABLE digital_products (
    download_url  text,
    file_size_mb  numeric(8,2)
) INHERITS (products);
```

After this, `physical_products` actually has five columns: the three it inherited (`id`, `sku`, `name`, `price`) plus its own two (`weight_kg`, `warehouse_location`). You did not have to retype the shared columns; PostgreSQL copied their definitions in automatically when the child table was created.

```sql
INSERT INTO physical_products (sku, name, price, weight_kg, warehouse_location)
VALUES ('PHY-001', 'Coffee Mug', 12.99, 0.35, 'Aisle 4');

INSERT INTO digital_products (sku, name, price, download_url, file_size_mb)
VALUES ('DIG-001', 'E-book: PostgreSQL Basics', 9.99, 'https://example.com/ebook.pdf', 4.2);
```

Notice that both rows physically live in their own child tables, but conceptually they are also rows of `products`, because `products` is their parent.

### 2.3 Querying Inherited Tables

This is the part that surprises people the first time they see it. If you query the **parent** table, PostgreSQL by default gives you rows from the parent **and every child**, combined:

```sql
SELECT * FROM products;
```

```
 id | sku      | name                       | price
----+----------+----------------------------+-------
  1 | PHY-001  | Coffee Mug                 | 12.99
  2 | DIG-001  | E-book: PostgreSQL Basics  |  9.99
```

Even though we never inserted directly into `products`, both rows appear when we query it, because PostgreSQL automatically scans all the child tables too. This is extremely useful: it means application code that only cares about "give me all products and their price" does not need to know or care how many product subtypes exist.

If you want **only** the rows that were inserted directly into the parent table itself (excluding children), add `ONLY`:

```sql
SELECT * FROM ONLY products;   -- returns zero rows here, since we never insert into products directly
```

And of course, if you want just one subtype, you simply query the child table directly:

```sql
SELECT * FROM physical_products;   -- just the Coffee Mug, with its extra weight/location columns
```

A helpful way to think about it: **querying the parent means "give me everything, generically." Querying a child means "give me this specific kind, with its specific extra detail."**

You can find out which actual table a row came from using the hidden `tableoid` system column:

```sql
SELECT tableoid::regclass AS actual_table, id, sku, name FROM products;
```

```
 actual_table       | id | sku     | name
--------------------+----+---------+---------------------------
 physical_products   |  1 | PHY-001 | Coffee Mug
 digital_products    |  2 | DIG-001 | E-book: PostgreSQL Basics
```

### 2.4 What Is NOT Inherited

This is the section that trips people up the most, so read it carefully. When you inherit from a parent table, you get its **columns**, but you do **not** automatically get:

- **Primary keys** defined on the parent. If the parent has a `PRIMARY KEY`, that constraint is not enforced across the parent-plus-children set. Each child would need its own primary key, and PostgreSQL cannot guarantee uniqueness *across* all the children combined.
- **Unique constraints** on the parent, for the same reason.
- **Foreign keys pointing to the parent.** You cannot make another table reference `products(id)` and have that reference satisfied by a row that actually lives in `physical_products`. Foreign keys only look at the exact table named.
- **Indexes** on the parent are not automatically built on the children (though each child can have its own copy of similar indexes).

In our example above, `products.id` was declared `PRIMARY KEY`, but this only applies to rows inserted directly into `products` (which we never do). Nothing stops `physical_products` and `digital_products` from both having a row with `id = 1`. If you truly need global uniqueness across a parent and all its children, you need to build that yourself, often with a shared sequence (see section 4) used by every child table's default, plus a trigger or manual discipline, since PostgreSQL does not provide it for free.

This limitation is the single biggest reason why classic table inheritance is not recommended for "is-a" relationships between independent business entities, and it is a large part of why **declarative partitioning** (section 6) was built as a more disciplined alternative for the specific case of splitting one logical table into physical pieces.

### 2.5 Adding and Removing Inheritance

You can also make an **existing** table become a child of another table after the fact, as long as its columns are compatible:

```sql
ALTER TABLE physical_products INHERIT products;
ALTER TABLE physical_products NO INHERIT products;   -- undo it
```

Dropping the parent table normally fails if children exist, unless you cascade:

```sql
DROP TABLE products CASCADE;   -- also drops physical_products and digital_products!
```

Because that is destructive, PostgreSQL requires you to be explicit about it.

### 2.6 Multiple Inheritance

Unlike some object-oriented systems, PostgreSQL genuinely supports a table inheriting from **more than one** parent at once, combining all of their columns:

```sql
CREATE TABLE named_things (id bigint PRIMARY KEY, name text);
CREATE TABLE priced_things (price numeric(10,2));

CREATE TABLE gadgets (sku text) INHERITS (named_things, priced_things);
-- gadgets ends up with: id, name, price, sku
```

If two parents happen to define a column with the exact same name and type, PostgreSQL merges them into a single column rather than complaining. This feature exists, but it is rarely used in practice, and most style guides recommend avoiding it because it makes the true "shape" of a table harder to see at a glance.

### 2.7 Why Inheritance Fell Out of Favor

Table inheritance was one of PostgreSQL's original, distinctive features, dating back to its academic roots as an object-relational database. In practice, though, most teams today reach for it far less than they used to, for a combination of reasons:

- The lack of enforced uniqueness and foreign keys across the parent-child set (section 2.4) means the database cannot fully protect your data's integrity the way it normally would.
- `jsonb` (covered in an earlier guide) now handles a lot of the "different subtypes need different extra fields" use case more flexibly, without needing separate tables at all.
- **Declarative partitioning** (section 6), introduced in PostgreSQL 10 and steadily improved since, solves the "one logical table split into physical pieces" problem more safely and with better planner support, which was historically the most common real-world use of inheritance.
- Query planning across many inheriting children can be slower than an equivalent partitioned table, especially with older PostgreSQL versions.

### 2.8 When It Still Makes Sense

Inheritance has not disappeared, and it is still a reasonable tool for a genuinely small number of cases:

- **Modeling true subtype hierarchies** where you rarely need cross-subtype uniqueness, such as different kinds of logged events, or different kinds of geometric shapes in a mapping application, where each subtype's rows are naturally always queried either "as a whole" or "as its specific type," and you are comfortable enforcing uniqueness yourself if you need it.
- **Legacy databases** that already use it, where migrating away is not worth the risk or effort.
- Certain extensions and specialized tools still use inheritance internally.

If you are starting a new design and you are tempted to reach for inheritance to split up one big table by date, category, or region purely for **size and performance** reasons, use partitioning (section 6) instead. If you are tempted to reach for it to model "several kinds of the same real-world thing" with genuinely different structured attributes, seriously consider whether separate tables joined by a foreign key, or a shared table with a `jsonb` column for the type-specific extras, would serve you better with fewer surprises.

---

## 3. Views

### 3.1 What Is a View, Really?

A **view** is a saved query that behaves like a table when you read from it. It does not store its own data (with one exception explained in section 3.5); every time you `SELECT` from a view, PostgreSQL substitutes in the view's underlying query and runs it fresh.

Think of a view as a **named shortcut**. Instead of typing out a complicated join or calculation every time, you define it once, give it a name, and from then on you (or your teammates, or your reporting tool) can just query that name as if it were an ordinary table.

### 3.2 Creating and Using Views

```sql
CREATE VIEW shipped_orders AS
SELECT o.id, c.name AS customer_name, o.order_date, o.total
FROM orders o
JOIN customers c ON c.id = o.customer_id
WHERE o.status = 'shipped';
```

Now, this:

```sql
SELECT * FROM shipped_orders WHERE total > 100;
```

behaves exactly as if you had written:

```sql
SELECT id, customer_name, order_date, total
FROM (
    SELECT o.id, c.name AS customer_name, o.order_date, o.total
    FROM orders o
    JOIN customers c ON c.id = o.customer_id
    WHERE o.status = 'shipped'
) AS shipped_orders
WHERE total > 100;
```

PostgreSQL actually rewrites your query this way internally (this is why the view is not "storing" anything: it is a template that gets pasted in). One important consequence follows directly from this: **a view always reflects the current, live data** in the underlying tables. If a new order gets shipped a second from now, `shipped_orders` will include it the very next time anyone queries the view, with no extra work needed.

Views are enormously useful for:

- **Simplifying complexity.** Analysts or application developers who need "orders with customer names" do not need to know or remember the join every time.
- **Providing a stable interface.** If you later restructure your underlying tables, you may be able to update the view's definition so that everything depending on the view keeps working unchanged.
- **Restricting access to data**, by exposing only certain columns or rows through the view, and granting people permission on the view instead of the underlying tables (see section 3.7 for important caveats here).

### 3.3 Updatable Views

Perhaps surprisingly, you can sometimes `INSERT`, `UPDATE`, or `DELETE` through a view, not just `SELECT` from it. PostgreSQL will automatically figure out how to translate your change into the correct change on the underlying table, but only if the view is "simple enough" for that translation to be unambiguous.

A view is **automatically updatable** if it satisfies all of the following:

- It is based on exactly **one** underlying table or another updatable view (no joins between multiple tables).
- It does not use `GROUP BY`, `HAVING`, `DISTINCT`, `LIMIT`, `OFFSET`, set operations (`UNION`, etc.), or window functions.
- Every column it exposes maps directly to a real column of the underlying table (not a computed expression, in general, although PostgreSQL is somewhat flexible about this for `INSERT`/`UPDATE` targeting specific columns).

```sql
CREATE VIEW us_customers AS
SELECT id, name, is_vip
FROM customers
WHERE country = 'US';

UPDATE us_customers SET is_vip = true WHERE name = 'Carol';
-- PostgreSQL translates this into: UPDATE customers SET is_vip = true WHERE name = 'Carol' AND country = 'US'
```

If your view is more complex, for example it joins two tables or aggregates data, PostgreSQL usually cannot figure out an unambiguous translation, and attempting to modify through it raises an error like `cannot update view "..." because it is not updatable`. In those cases, you can still make the view updatable manually using an `INSTEAD OF` trigger, which is a small function you write yourself that tells PostgreSQL exactly what to do on the real tables whenever someone tries to insert, update, or delete through the view. That is a more advanced technique, generally used only when a genuinely complex view really needs to support writes.

### 3.4 WITH CHECK OPTION

Here is a subtlety worth understanding well. Suppose you update a row through the `us_customers` view such that it would no longer satisfy the view's own `WHERE country = 'US'` condition:

```sql
UPDATE us_customers SET country = 'CA' WHERE name = 'Carol';
```

By default, PostgreSQL **allows** this. The row is updated, `country` becomes `'CA'`, and the row then silently "disappears" from the view the next time you query it, because it no longer matches the filter. This can be surprising: from the point of view of someone only ever working through `us_customers`, a row they just successfully updated seems to have vanished.

If you want to prevent this, that is, to enforce that any row you insert or update through the view must **still** satisfy the view's own conditions afterward, add `WITH CHECK OPTION`:

```sql
CREATE VIEW us_customers AS
SELECT id, name, is_vip, country
FROM customers
WHERE country = 'US'
WITH CHECK OPTION;

UPDATE us_customers SET country = 'CA' WHERE name = 'Carol';
-- ERROR: new row violates check option for view "us_customers"
```

This is a good habit whenever a view represents a restricted "slice" of a table that some role should never be able to write their way out of.

### 3.5 Materialized Views

A regular view, as we said, stores no data. It reruns its query every single time. If the underlying query is expensive, for example, it aggregates millions of rows, this cost is paid on **every** read.

A **materialized view** solves this by actually storing the query's result on disk, like a snapshot, and continuing to show you that same snapshot until you explicitly ask PostgreSQL to recompute it.

```sql
CREATE MATERIALIZED VIEW customer_order_summary AS
SELECT c.id, c.name, count(o.id) AS order_count, coalesce(sum(o.total), 0) AS total_spent
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
GROUP BY c.id, c.name;
```

The first time you create it, PostgreSQL runs the query and saves the results, just like creating a regular table from a `SELECT`. From then on:

```sql
SELECT * FROM customer_order_summary;   -- instant: just reads the stored snapshot, no recomputation
```

This is fast because you are reading pre-computed data, exactly like reading a normal table. The tradeoff is that this snapshot will **not** automatically update as `orders` and `customers` change. If Alice places a new order, `customer_order_summary` will keep showing her old totals until you explicitly refresh it.

Materialized views suit situations where:

- The underlying query is expensive (heavy aggregation, several large joins).
- The data does not need to be perfectly up-to-the-second: a dashboard refreshed every hour, a report generated nightly, or a summary recalculated after a batch job.
- You are willing to trade some staleness for a large speed improvement.

### 3.6 Refreshing Materialized Views

```sql
REFRESH MATERIALIZED VIEW customer_order_summary;
```

This completely recomputes the view's contents from scratch. During a plain `REFRESH`, PostgreSQL locks the materialized view so that no one can read from it while it is being rebuilt, which briefly makes it unavailable.

If you need the view to remain readable by others while it refreshes (common on a live production system), you can refresh it concurrently instead, at the cost of needing a unique index first:

```sql
CREATE UNIQUE INDEX idx_cos_id ON customer_order_summary (id);
REFRESH MATERIALIZED VIEW CONCURRENTLY customer_order_summary;
```

`CONCURRENTLY` works by computing the new results into a temporary area and then comparing them row-by-row against the existing data, updating only the rows that actually changed, rather than replacing the whole thing at once. This is slower in raw compute time, but it never blocks concurrent readers, which is usually the more important property for a view people are actively querying throughout the day.

There is no automatic refresh schedule built into PostgreSQL itself. In practice, teams refresh materialized views using a cron job, a scheduled task, or a trigger-based system, depending on their needs.

### 3.7 Views and Security: security_barrier and security_invoker

Two more advanced settings matter once views are used for security purposes (for example, to hide certain rows or columns from certain users):

- **`security_barrier`** prevents PostgreSQL from being overly clever in a way that could otherwise leak data. Normally, the query planner is free to reorder operations for speed, including pushing functions from the outer query down into the view's own `WHERE` clause before it runs. Ordinarily that is a helpful optimization, but if the view exists specifically to filter out rows a user should not see, and the pushed-down function has a side effect (like logging its input, or deliberately raising an error to leak information), this reordering could let a user infer values from rows they are not supposed to see, before the view's own filter had a chance to exclude them. Marking a view `security_barrier` tells the planner to always apply the view's own filtering first, closing this loophole:

```sql
CREATE VIEW safe_customers WITH (security_barrier) AS
SELECT id, name FROM customers WHERE country = 'US';
```

- **`security_invoker`** (PostgreSQL 15+) changes *whose* permissions are checked when the view is queried. By default, a view runs with the permissions of whoever **created** (owns) it, meaning a user with no direct access to the underlying `customers` table can still query it successfully through a view they have been granted access to, because the view itself "vouches" for them using the owner's privileges. Setting `security_invoker = true` instead makes the view check the querying user's **own** permissions on the underlying tables, which is usually the more intuitive and safer default in row-level-security setups:

```sql
CREATE VIEW safe_customers WITH (security_invoker = true) AS
SELECT id, name FROM customers WHERE country = 'US';
```

### 3.8 Managing Views

```sql
-- See its definition
\d shipped_orders
\sv shipped_orders

-- Replace its definition (only allowed to add columns at the end, or change the query logic; cannot remove/reorder existing output columns this way)
CREATE OR REPLACE VIEW shipped_orders AS
SELECT o.id, c.name AS customer_name, o.order_date, o.total, o.status
FROM orders o
JOIN customers c ON c.id = o.customer_id
WHERE o.status IN ('shipped', 'delivered');

-- Rename
ALTER VIEW shipped_orders RENAME TO fulfilled_orders;

-- Remove
DROP VIEW fulfilled_orders;
DROP MATERIALIZED VIEW customer_order_summary;
```

### 3.9 When to Use Which

| Situation | Use |
|---|---|
| You want a reusable, always-current shortcut for a common query | Regular view |
| You want to hide columns or rows from certain users | Regular view, likely with `security_barrier` and/or `security_invoker` |
| The underlying query is slow and does not need to be perfectly current | Materialized view |
| You need the "view" to be writable through complex logic | Regular view with an `INSTEAD OF` trigger |
| You just need to reuse a subquery within a single statement | A CTE (`WITH ...`) is usually simpler; it does not persist beyond the one query |

---

## 4. Sequences

### 4.1 What a Sequence Actually Is

A **sequence** is a small, special-purpose database object whose entire job is to hand out numbers, one at a time, in increasing order, and to never hand out the same number twice, even if many different users or processes are asking for numbers from it at the exact same instant. It is exactly the tool you want behind the scenes whenever you need something like an auto-incrementing primary key.

It helps to picture a sequence as a **ticket dispenser** at a busy counter. Anyone can walk up and pull the next ticket. The dispenser guarantees that no two people ever get the same ticket number, and it does not care whether the tickets are ever actually all used; a ticket, once printed, is gone, whether or not the person who took it stays around.

### 4.2 Creating and Using Sequences Directly

```sql
CREATE SEQUENCE invoice_number_seq
    START WITH 1000
    INCREMENT BY 1;

SELECT nextval('invoice_number_seq');   -- 1000, and internally moves on to 1001 next time
SELECT nextval('invoice_number_seq');   -- 1001
SELECT currval('invoice_number_seq');   -- 1001 (the last value THIS session obtained)
```

- `nextval(...)` is the function you call to actually get a new number. Every call advances the sequence.
- `currval(...)` just tells you the last number **your own database session** received; it does not advance anything, and it will raise an error if you have not called `nextval` at least once yet in that session.
- You can even ask what the next value will be, without consuming it, using `setval` with the `is_called` argument set appropriately, though this is a less common need.

Sequences are most often used inside a column's `DEFAULT`, so that you rarely need to call `nextval` yourself:

```sql
CREATE TABLE invoices (
    id      bigint DEFAULT nextval('invoice_number_seq') PRIMARY KEY,
    amount  numeric(10,2)
);

INSERT INTO invoices (amount) VALUES (49.99);   -- id automatically becomes 1002
```

### 4.3 serial vs GENERATED ... AS IDENTITY

Writing out `CREATE SEQUENCE` and wiring it into a `DEFAULT` by hand, as above, works, but PostgreSQL offers two shorthand ways to get the same "auto-incrementing column" behavior without doing it manually.

**The older shorthand: `serial`**

```sql
CREATE TABLE legacy_orders (
    id serial PRIMARY KEY,
    note text
);
```

Behind the scenes, PostgreSQL expands this single line into roughly:

```sql
CREATE SEQUENCE legacy_orders_id_seq;
CREATE TABLE legacy_orders (
    id integer NOT NULL DEFAULT nextval('legacy_orders_id_seq'),
    note text
);
ALTER SEQUENCE legacy_orders_id_seq OWNED BY legacy_orders.id;
```

`serial` (4-byte range) has siblings `smallserial` (2-byte) and `bigserial` (8-byte). It has been available since very early PostgreSQL versions, so you will see it constantly in older tutorials, existing databases, and other people's code.

**The modern, SQL-standard way: identity columns** (PostgreSQL 10+)

```sql
CREATE TABLE orders_v2 (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    note text
);
```

This achieves the same practical result (an auto-populated, ever-increasing integer column, backed by a sequence PostgreSQL manages for you) but is generally the **recommended** choice today, for a few concrete reasons:

- `serial` is not really its own data type; it is just a convenient shorthand at table-creation time, and this occasionally causes confusing behavior around things like `pg_dump` or column type introspection. Identity columns are a proper, standard SQL feature with cleaner semantics.
- With `GENERATED ALWAYS AS IDENTITY`, PostgreSQL will, by default, actively **refuse** an explicit value in an `INSERT` (`ERROR: cannot insert into column "id"`), which helps catch application bugs where code accidentally tries to set an ID it should not be setting. If you occasionally do need to supply your own value on purpose (for example, restoring a specific historical record), you can override this explicitly:

```sql
INSERT INTO orders_v2 (id, note) OVERRIDING SYSTEM VALUE VALUES (500, 'backfilled');
```

- With `GENERATED BY DEFAULT AS IDENTITY`, PostgreSQL behaves more like old-style `serial`: it will quietly accept an explicit value if you provide one, and only generates one automatically when you leave the column out.

```sql
CREATE TABLE orders_v3 (
    id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    note text
);
INSERT INTO orders_v3 (id, note) VALUES (999, 'explicit id, no error');
```

**In short: for any new table you are designing today, prefer `GENERATED ALWAYS AS IDENTITY` (or `GENERATED BY DEFAULT AS IDENTITY` if you genuinely need to sometimes supply your own values), and reserve `serial` for reading and maintaining older code that already uses it.**

### 4.4 Why Sequences Skip Numbers

This surprises almost everyone the first time they notice it: you insert 5 rows and expect IDs 1 through 5, but instead you see 1, 2, 3, 7, 8, with a gap. This is completely normal and by design, not a bug.

The reason is that a sequence's entire purpose is to be extremely fast and safe to call from many simultaneous database connections at once, and to guarantee it never hands out a duplicate. To achieve that, `nextval()` deliberately does **not** participate in your transaction's rollback behavior at all. The moment you call it, that number is permanently consumed and gone, regardless of what happens next:

```sql
BEGIN;
INSERT INTO orders_v2 (note) VALUES ('will be rolled back');   -- consumes, say, id 42
ROLLBACK;                                                       -- the insert never happened...

INSERT INTO orders_v2 (note) VALUES ('actually saved');   -- ...but this gets id 43, NOT 42
```

If sequences instead tried to "give back" a number whenever a transaction rolled back, or whenever an application crashed mid-insert, they would need to coordinate much more heavily between all the different sessions trying to grab numbers at once, which would make them dramatically slower and would reintroduce exactly the kind of contention they exist to avoid. PostgreSQL's designers made a deliberate tradeoff: **sequences guarantee uniqueness and speed, but they never promise to be gap-free.**

The practical takeaway: never write application logic that assumes IDs are perfectly consecutive, that "the next order will definitely be ID 44," or that you can infer how many rows have ever been inserted by looking at the highest ID. Gaps from rollbacks, application errors, deliberate `setval` calls, and even ordinary server restarts (PostgreSQL may cache and discard a small batch of sequence values on shutdown) are all normal and expected.

### 4.5 Sequences and Transactions

Following on from the point above: calling `nextval()` is one of the few things in PostgreSQL that takes effect immediately and permanently, completely independent of whether your surrounding transaction eventually commits or rolls back. This is intentional, and it is what allows many different concurrent transactions to each grab their own unique number without ever having to wait for one another to finish.

Contrast this with almost everything else in PostgreSQL, where changes are invisible to everyone else until you `COMMIT`, and disappear entirely if you `ROLLBACK`. Sequences are a deliberate, narrow exception to that rule, made specifically so they can remain fast under heavy concurrent load.

### 4.6 Resetting, Cycling, and Ownership

```sql
-- Jump the sequence to a specific value (useful after bulk-loading data with explicit IDs)
SELECT setval('invoice_number_seq', 5000);              -- next call to nextval() will return 5001
SELECT setval('invoice_number_seq', 5000, false);       -- next call to nextval() will return 5000 itself

-- Restart from scratch
ALTER SEQUENCE invoice_number_seq RESTART WITH 1;

-- Change its step size, bounds, or make it wrap around after reaching its maximum
ALTER SEQUENCE invoice_number_seq INCREMENT BY 1 MINVALUE 1 MAXVALUE 999999 CYCLE;
```

`CYCLE` means that once the sequence reaches its maximum value, it wraps back around to its minimum and starts issuing those numbers again. This is almost never appropriate for a primary key (you absolutely do not want two different rows eventually sharing the same "unique" ID), but it can occasionally make sense for things like a repeating ticket or slot number where old values are guaranteed to be long gone by the time the sequence wraps.

**Ownership** matters when a sequence exists purely to serve one particular column (as with `serial` or identity columns). If a sequence is "owned by" a column, dropping that column (or the whole table) will automatically drop the sequence along with it, so you do not end up with orphaned sequence objects cluttering your database:

```sql
ALTER SEQUENCE invoice_number_seq OWNED BY invoices.id;
ALTER SEQUENCE invoice_number_seq OWNED BY NONE;   -- detach it, e.g. if it's meant to be shared
```

### 4.7 Sequences in Concurrent, High-Throughput Systems

By default, every single call to `nextval()` requires a tiny, very fast, but real coordination step to guarantee no two sessions ever receive the same number. Under normal workloads this is a complete non-issue, but on systems doing extremely high volumes of concurrent inserts, this can occasionally become a point of contention, since many sessions are all trying to grab a number from the same sequence at once.

PostgreSQL provides a `CACHE` option to help with exactly this scenario:

```sql
ALTER SEQUENCE invoice_number_seq CACHE 20;
```

With caching enabled, each session that calls `nextval()` grabs a whole **block** of, say, 20 numbers at once from the sequence (a fast, one-time coordination step), and then hands them out to that same session one at a time locally, without needing to coordinate with any other session again until that block runs out. This drastically reduces contention under heavy concurrent load.

The tradeoff is that this makes gaps (section 4.4) considerably larger and more likely: if a session grabs a cached block of 20 numbers and then, for whatever reason (a crash, a restart, simply finishing its work early), never actually uses all 20, those unused numbers are gone forever, skipped permanently. This is a reasonable and common tradeoff to make on a busy system, but it is worth understanding consciously rather than being surprised by it later.

---

## 5. Indexing

### 5.1 Why Indexes Exist

Imagine a phone book with a million entries, but with absolutely no alphabetical order: names are just written down in whatever order people happened to sign up. If someone asks you to find "Smith, John," your only real option is to start at page one and read every single entry until you either find it or reach the end. This is exactly what PostgreSQL does when it has to answer a query with no index available: it reads the entire table, row by row, checking every single one against your `WHERE` condition. This is called a **sequential scan**, and while it sounds inefficient, it is actually the *correct* and *fastest* approach when you genuinely need to look at most or all of the rows anyway (for example, computing a sum across an entire small table).

An **index** is a separate, auxiliary data structure that PostgreSQL builds and maintains alongside your table, specifically to make certain lookups dramatically faster, in exactly the same spirit as a phone book's alphabetical ordering, or a textbook's index at the back that tells you exactly which pages mention a particular topic without you having to read the whole book.

The tradeoff, and it is an important one to understand from the start, is that:

- An index makes certain **reads** (`SELECT` queries with matching `WHERE`, `JOIN`, or `ORDER BY` clauses) much faster, sometimes by many orders of magnitude on a large table.
- An index makes every **write** (`INSERT`, `UPDATE`, `DELETE`) to that table slightly slower, because PostgreSQL now has to keep the index itself up to date every single time the underlying data changes, in addition to writing the actual row.
- An index takes up additional disk space, sometimes a very significant amount for a large table with several indexes.

Because of this tradeoff, indexing is not a matter of "add as many as possible." It is a matter of thoughtfully indexing the columns your queries actually filter, join, or sort on frequently, and being comfortable leaving other columns unindexed.

### 5.2 The Default: B-tree

When you create an index without specifying a type, PostgreSQL uses a **B-tree** index, and this covers the large majority of everyday indexing needs.

```sql
CREATE INDEX idx_orders_customer_id ON orders (customer_id);
```

Conceptually, a B-tree organizes values into a balanced, sorted tree structure, similar in spirit to how a well-organized filing system with folders and subfolders lets you narrow down to the document you need in just a handful of steps, rather than checking every single document one at a time. This structure is what makes B-tree indexes excellent at:

- **Equality lookups:** `WHERE customer_id = 3`
- **Range lookups:** `WHERE order_date BETWEEN '2026-01-01' AND '2026-01-31'`, or `WHERE total > 100`
- **Sorting:** `ORDER BY order_date`, since the index already stores values in sorted order, PostgreSQL can sometimes read results directly off the index in the correct order without a separate sort step
- **Pattern matching that is anchored at the start of a string:** `WHERE name LIKE 'Al%'` (but generally not `WHERE name LIKE '%ice'`, since a search for something that could appear anywhere in the text cannot be narrowed down using an ordering)

You can watch the planner actually choose to use this index:

```sql
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 1;
```

```
Index Scan using idx_orders_customer_id on orders  (cost=0.15..8.17 rows=2 width=...)
  Index Cond: (customer_id = 1)
```

If this instead shows `Seq Scan`, either the table is small enough that PostgreSQL correctly judges a full scan to be just as fast (very common, and not a problem, on small tables), or there is some other reason the index cannot be used, which section 5.9 discusses further.

### 5.3 Other Index Types

B-tree is the right default for most columns, but PostgreSQL ships with several other index types, each built for a specific kind of data or a specific kind of question.

| Index type | Best suited for | Typical use case |
|---|---|---|
| **B-tree** | Equality, ranges, sorting | The default; most columns |
| **Hash** | Pure equality only (`=`), nothing else | Rarely chosen over B-tree today; B-tree does equality just as well and much more besides |
| **GIN** (Generalized Inverted Index) | Values that contain *multiple* searchable items inside them: arrays, `jsonb` documents, full-text search vectors | "Does this array contain X," "does this JSON document have this key," full-text search |
| **GiST** (Generalized Search Tree) | Geometric data, ranges that can overlap, nearest-neighbor searches | PostGIS spatial queries, exclusion constraints on overlapping time ranges |
| **SP-GiST** | Data with a natural, uneven, hierarchical structure | IP address ranges, certain text-prefix scenarios |
| **BRIN** (Block Range Index) | Enormous tables where a column's values roughly correlate with its physical storage order | A `created_at` timestamp column on a huge, append-only, time-ordered log table |

You specify a non-default type with `USING`:

```sql
CREATE INDEX idx_events_details ON events USING gin (details);       -- details is jsonb
CREATE INDEX idx_bookings_period ON bookings USING gist (during);    -- during is a tstzrange
CREATE INDEX idx_logs_created_at ON logs USING brin (created_at);
```

A quick, intuitive way to think about **GIN** versus **B-tree**: a B-tree index treats each row's value as one single, whole thing to sort and compare (like sorting whole names alphabetically). A GIN index is built for values that are really a *collection* of smaller things (the individual elements of an array, the individual keys of a JSON document, the individual words in a paragraph), and it lets you efficiently ask "which rows contain this particular smaller thing," which a plain B-tree simply cannot do well.

**BRIN** deserves a brief separate mention because its design tradeoff is unusual and specifically valuable for very large tables. Instead of recording the exact location of every single value (which is what B-tree does, and which is why B-tree indexes can grow quite large), a BRIN index only records, for each large physical range of the table (a "block range"), the minimum and maximum value seen in that range. This makes a BRIN index dramatically smaller than an equivalent B-tree, often by two or three orders of magnitude, at the cost of being less precise: it can only tell PostgreSQL "the value you want definitely isn't in these ranges, but might be in these other ranges," rather than pointing directly at exact rows. This tradeoff works out extremely well specifically when a column's values happen to naturally correlate with the physical order rows were inserted in, which is exactly the case for a timestamp column on a table where rows are only ever appended in time order and never reordered, such as a raw event log.

### 5.4 Multi-Column (Composite) Indexes

An index does not have to cover just one column. You can build one across several columns together:

```sql
CREATE INDEX idx_orders_customer_date ON orders (customer_id, order_date);
```

The important thing to understand here is **column order matters enormously**, and it is not simply "more columns is more thorough." Think of a composite index the same way you would think of a phone book sorted first by last name, and only *then*, within each last name, sorted by first name. This ordering makes it very fast to find "everyone named Smith" (using just the first sorted column), and just as fast to find "everyone named Smith with first name John" (using both columns together, since within all the Smiths, the Johns are also grouped together). But it does **not** help you efficiently find "everyone with first name John," regardless of last name, because Johns are scattered all throughout the book, one within each different last name group.

The same logic applies exactly to a composite database index. The index above, on `(customer_id, order_date)`, will happily and efficiently support:

```sql
WHERE customer_id = 1                               -- uses the index (leading column)
WHERE customer_id = 1 AND order_date = '2026-01-05'  -- uses the index (both columns, in order)
WHERE customer_id = 1 ORDER BY order_date            -- uses the index for filtering AND sorting
```

But it will generally **not** help at all with:

```sql
WHERE order_date = '2026-01-05'                      -- order_date alone, skipping customer_id: cannot use this index efficiently
```

The general rule of thumb: **put the column you filter on with plain equality (`=`) first, and a column you filter with a range or use for sorting afterward, next.** If you frequently query by `order_date` alone as well, you likely need a *separate* index just on `order_date`, in addition to the composite one, rather than expecting the composite index to serve both purposes.

### 5.5 Partial Indexes

Sometimes you only ever query for a specific, meaningful subset of a table's rows, and it would be wasteful to index the rest. A **partial index** includes a `WHERE` clause of its own, right in the index definition, so PostgreSQL only builds and maintains index entries for the rows that match it.

```sql
CREATE INDEX idx_orders_pending ON orders (order_date) WHERE status = 'pending';
```

This index is far smaller than a full index on every order, since presumably most orders eventually move out of the `'pending'` state and only a small, fairly constant fraction of the table is ever `'pending'` at any given moment. Because it is smaller, it is faster to search, faster to maintain on every write, and takes up less disk space, while still perfectly serving any query that filters on `status = 'pending'`:

```sql
SELECT * FROM orders WHERE status = 'pending' ORDER BY order_date;   -- can use the partial index directly
```

A very common real-world use of this pattern is efficiently enforcing "only one active row" style rules, such as ensuring a user can only have a single non-deleted account with a given email:

```sql
CREATE UNIQUE INDEX idx_active_email ON customers (name) WHERE is_vip = true;
```

(In a real system you would more likely do this with something like `deleted_at IS NULL`, but the `is_vip` example keeps it consistent with our running sample data.)

### 5.6 Expression Indexes

Normally, an index stores the raw value of a column. But you can instead index the **result of an expression or function** applied to a column, which lets PostgreSQL use the index even when your query applies that same transformation.

Consider a very common real-world annoyance: case-insensitive searching. Without any special handling, this query cannot use a normal index on `name`, because the index stores `'Alice'`, not `'alice'`, and PostgreSQL cannot know in advance that `lower('Alice')` equals `'alice'` without actually computing it for every row:

```sql
SELECT * FROM customers WHERE lower(name) = 'alice';   -- a plain index on "name" cannot help here
```

The fix is to index the *expression itself*, rather than the raw column:

```sql
CREATE INDEX idx_customers_lower_name ON customers (lower(name));

SELECT * FROM customers WHERE lower(name) = 'alice';   -- now this CAN use the index
```

PostgreSQL computes `lower(name)` once for every existing row when the index is built, and again for every new or changed row afterward, storing those lowercased values in the index itself. Then, whenever your query's `WHERE` clause contains that exact same expression, `lower(name)`, PostgreSQL recognizes the match and can use the index. This is a genuinely powerful and often underused technique: pretty much any deterministic expression can be indexed this way, not just `lower()`. For example, indexing `(price * quantity)` for a computed total, or indexing `(date_trunc('month', created_at))` to speed up "group by month" style queries.

### 5.7 Unique Indexes and Constraints

You may recall from an earlier guide that a `UNIQUE` constraint is enforced behind the scenes using exactly this same B-tree index mechanism. Creating a `UNIQUE` constraint and creating a unique index directly produce essentially the same result:

```sql
CREATE UNIQUE INDEX idx_customers_name ON customers (name);
-- is essentially equivalent, for enforcement purposes, to:
ALTER TABLE customers ADD CONSTRAINT uq_customers_name UNIQUE (name);
```

The practical difference is mostly about **intent and tooling**: a named constraint shows up cleanly in `\d` output and in tools that specifically look for constraints, and can be referenced by name in error messages and in `ALTER TABLE ... DROP CONSTRAINT`. A unique index created directly is more flexible; for instance, only a directly created unique index can also be a **partial** index (section 5.5), which a table-level `UNIQUE` constraint cannot be.

### 5.8 Covering Indexes: INCLUDE

Sometimes, PostgreSQL can answer your entire query using **only** the index itself, without ever needing to go and fetch the actual table row at all. This is called an **index-only scan**, and it is noticeably faster than a regular index scan, because reading data from the table itself (the "heap") is an extra step that an index-only scan can skip entirely.

For this to work, though, *every single column* your query needs, both in its `WHERE` clause and in its `SELECT` list, must be present somewhere in the index. Normally, adding a column purely so it is "available" in the index means adding it as a proper indexed (sorted) column, which also makes the index larger and changes its sort behavior in ways you might not want.

The `INCLUDE` clause solves this cleanly: it lets you attach extra columns to an index purely so their values are stored alongside it and available for an index-only scan, **without** those extra columns being part of the actual sorted, searchable structure of the index.

```sql
CREATE INDEX idx_orders_customer_covering
ON orders (customer_id)
INCLUDE (order_date, total);
```

Now, a query that filters on `customer_id` and only needs `order_date` and `total` in its output can be satisfied entirely from the index, never touching the `orders` table itself:

```sql
EXPLAIN ANALYZE
SELECT order_date, total FROM orders WHERE customer_id = 1;
```

```
Index Only Scan using idx_orders_customer_covering on orders  (cost=...)
  Index Cond: (customer_id = 1)
```

A quick but important caveat: even with a perfectly matching covering index, PostgreSQL can only actually skip visiting the table if it can also confirm, using its internal "visibility map," that the relevant table pages have no recently-changed rows that still need an extra visibility check. On a table that receives a lot of updates and deletes without being vacuumed frequently, you may see a plain `Index Scan` instead of the hoped-for `Index Only Scan`, even with an `INCLUDE`d covering index in place, until `VACUUM` has had a chance to bring the visibility map up to date.

### 5.9 How to Tell If an Index Is Being Used

The single most important tool for understanding indexing in practice is `EXPLAIN`, ideally combined with `ANALYZE` so it actually runs the query and shows real numbers rather than just estimates:

```sql
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 1;
```

Look for `Index Scan`, `Index Only Scan`, or `Bitmap Index Scan` (a variant used when PostgreSQL expects to need a moderate-to-large number of matching rows, first gathering matching row locations from the index, then visiting the table for all of them in a more disk-friendly order) as signs the index was used. `Seq Scan` means it read the whole table instead.

A perfectly healthy, well-indexed table can still show `Seq Scan` for some queries, and that is not automatically a problem to fix. Common, entirely normal reasons include:

- **The table (or the matching subset of rows) is genuinely tiny.** For a table with only a few hundred rows, reading the whole thing sequentially is often faster than the overhead of consulting an index at all, and PostgreSQL's planner correctly recognizes this.
- **The query would need to return a large fraction of the table anyway** (say, more than roughly 5-15%, though this varies). At that point, jumping around the table via an index scan is often *slower* overall than one smooth sequential read straight through it.
- **The column's statistics are stale.** PostgreSQL decides whether to use an index based partly on estimates of how many rows will match, gathered by `ANALYZE`. If a table has changed drastically since it was last analyzed (a lot of new data, or very different data), running `ANALYZE tablename;` manually can sometimes fix a surprising planner choice immediately.
- **A function or cast is applied to the column in a way the index cannot see through** (this is exactly the case that expression indexes, section 5.6, exist to fix).

### 5.10 Building and Maintaining Indexes

By default, `CREATE INDEX` takes a lock on the table that **blocks all writes** to it (though reads are still allowed) for as long as the index build takes. On a small table this is instantaneous and unnoticeable. On a large, busy production table, this can mean a noticeable outage for anything trying to write to that table.

```sql
CREATE INDEX CONCURRENTLY idx_orders_status ON orders (status);
```

`CONCURRENTLY` builds the index using a slower, more careful process that avoids taking that blocking lock, allowing normal reads and writes to continue against the table throughout. The tradeoffs are that it takes noticeably longer overall, it cannot be run inside an explicit transaction block, and, rarely, it can fail partway through and leave behind an unusable, "invalid" index that you then need to manually drop and retry:

```sql
DROP INDEX CONCURRENTLY idx_orders_status;   -- if a concurrent build failed and left an invalid index behind
```

In production systems, `CONCURRENTLY` is almost always worth using for any table that is actively being written to, and the extra build time is a small price for avoiding a write outage.

Indexes can also become bloated over time, especially on tables with heavy update and delete activity, in much the same way tables themselves can become bloated (as discussed in an earlier guide's coverage of `VACUUM`). Rebuilding an index reclaims that wasted space:

```sql
REINDEX INDEX idx_orders_status;                 -- rebuild a single index (blocks writes briefly by default)
REINDEX INDEX CONCURRENTLY idx_orders_status;     -- the non-blocking equivalent (PostgreSQL 12+)
REINDEX TABLE orders;                             -- rebuild every index on a table
```

### 5.11 The Cost of Indexes

It is worth restating plainly, since it is easy to forget once you have seen how much indexes help reads: **every index you add is also ongoing, permanent overhead on every future write to that table.** Each `INSERT` must add an entry to every index on the table. Each `UPDATE` that changes an indexed column must remove the old index entry and add a new one. Each `DELETE` must eventually clean up the corresponding index entries too (via vacuum).

This means a table with, say, ten indexes on it will insert new rows noticeably slower than the same table with two well-chosen indexes, simply because ten separate index structures all need to be updated on every single insert, not just one table. It also means every index is consuming disk space and, indirectly, memory (since PostgreSQL tries to cache frequently used index pages just like table pages).

The practical implication is that indexing is genuinely a balancing act, not a "more is always better" decision. Index the columns your actual, real queries filter, join, and sort on frequently. Do not reflexively index every column in a table "just in case," and periodically revisit whether indexes you added in the past are still earning their keep (see the next section).

### 5.12 Finding Missing or Useless Indexes

PostgreSQL keeps live statistics on how often each index actually gets used, which makes it straightforward to find indexes that may not be worth their ongoing write overhead:

```sql
-- Indexes that have rarely or never been used since the last stats reset
SELECT schemaname, relname AS table_name, indexrelname AS index_name, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan < 50
ORDER BY idx_scan;
```

A low `idx_scan` count on an index that has existed for a long time, on a table that is queried regularly, is a reasonable signal that the index may not be earning its keep and could be considered for removal, freeing up write performance and disk space. (Be cautious about indexes backing a `UNIQUE` or `PRIMARY KEY` constraint, though. Those may show low direct "scan" usage while still being essential for their constraint-enforcement role, so check `pg_constraint` before dropping anything.)

Finding genuinely **missing** indexes is less mechanical and usually comes down to watching `EXPLAIN ANALYZE` output on your slower, more important queries and noticing repeated `Seq Scan`s on large tables where you would expect an index to help, especially on foreign key columns, which PostgreSQL, as a reminder from an earlier guide, never indexes automatically for you.

---

## 6. Partitioning

### 6.1 What Problem Partitioning Solves

Picture a single `orders` table that has been steadily growing for years and now holds several hundred million rows. Even with excellent indexes, a table of this size brings its own set of problems that indexing alone cannot fully solve:

- **Maintenance operations become slow and heavy.** A `VACUUM`, an index rebuild, or even just gathering fresh statistics with `ANALYZE` has to work through the entire enormous table.
- **Deleting old data is expensive.** If your business rule is "we only need to keep 2 years of orders," running `DELETE FROM orders WHERE order_date < '2024-01-01'` against a huge table means finding and marking millions of individual rows as deleted, generating a correspondingly huge amount of dead space that then needs to be vacuumed.
- **Indexes themselves grow enormous** and can become slower to search and more expensive to maintain, simply due to sheer size.

**Partitioning** is PostgreSQL's answer to this: it lets you take one logical table, meaning the thing your application still thinks of and queries as a single table called `orders`, and physically split its data behind the scenes into several smaller physical tables, called **partitions**, based on some rule you define (most commonly a date range, or a category).

The genuinely important part is that this split is almost entirely invisible to anyone querying the table normally. `SELECT * FROM orders WHERE ...` still just works, exactly as it always did. PostgreSQL automatically figures out, behind the scenes, which of the smaller physical partitions actually need to be examined to answer your specific query, and, ideally, skips the rest entirely (this crucial optimization is called **partition pruning**, covered in section 6.8).

### 6.2 The Three Partitioning Strategies

PostgreSQL supports three different ways of deciding which partition a given row belongs in:

| Strategy | The rule for assigning a row to a partition | Typical use case |
|---|---|---|
| **RANGE** | Each partition owns a contiguous range of values (e.g., "January 2026," "February 2026") | Time-series data: orders, logs, events, measurements, anything naturally organized by date |
| **LIST** | Each partition owns an explicit, named list of values (e.g., "these specific countries") | Data naturally grouped into a known, fixed set of categories: country, region, status, tenant |
| **HASH** | PostgreSQL runs a hash function over the partitioning column and assigns the row to one of a fixed number of partitions based on the result, spreading rows roughly evenly | You mainly want to spread write load and table size evenly across several smaller pieces, with no natural range or category to split on |

### 6.3 Range Partitioning

This is by far the most common form of partitioning in practice, because so much real-world data (orders, logs, sensor readings, financial transactions) naturally accumulates over time, and queries very often care about a specific time window ("show me last month's orders," "archive anything older than a year").

```sql
CREATE TABLE orders_p (
    id          bigint GENERATED ALWAYS AS IDENTITY,
    customer_id bigint NOT NULL,
    order_date  date NOT NULL,
    status      text NOT NULL DEFAULT 'pending',
    total       numeric(10,2) NOT NULL,
    PRIMARY KEY (id, order_date)
) PARTITION BY RANGE (order_date);
```

Two things to notice immediately. First, the `PARTITION BY RANGE (order_date)` clause at the end tells PostgreSQL this table is not a normal table at all, but a **partitioned table**: essentially a "virtual" table definition with no storage of its own, which will always delegate its actual data to child partitions. Second, notice that the primary key had to include `order_date`, the partitioning column, alongside `id`. This is a firm PostgreSQL rule explained further in section 6.7.

Now we create the actual partitions, each one a normal-ish table that owns one slice of the date range:

```sql
CREATE TABLE orders_2026_01 PARTITION OF orders_p
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

CREATE TABLE orders_2026_02 PARTITION OF orders_p
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

CREATE TABLE orders_2026_03 PARTITION OF orders_p
    FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
```

The range for each partition is defined as **inclusive of its lower bound, and exclusive of its upper bound**. This might sound like a small technical detail, but it is precisely why it works so cleanly for consecutive ranges like months: January's partition owns everything from `2026-01-01` up to, but not including, `2026-02-01`, and February's partition picks up exactly where January left off, starting at `2026-02-01`. There is no gap, and no ambiguity about which partition owns the boundary date itself.

From here, you use `orders_p` completely normally:

```sql
INSERT INTO orders_p (customer_id, order_date, status, total)
VALUES (1, '2026-02-14', 'shipped', 75.50);
-- PostgreSQL automatically routes this row into the orders_2026_02 partition, with no extra effort on your part

SELECT * FROM orders_p WHERE order_date = '2026-02-14';
-- Also works exactly as expected, and, importantly, only needs to look inside orders_2026_02 to answer it
```

If you try to insert a row whose `order_date` does not fall into any partition you have defined yet (say, `2026-04-15`, before an April partition exists), PostgreSQL will reject it with a clear error, rather than silently losing the row or guessing where it should go. This means with range partitioning, you (or an automated job) need to keep creating new partitions ahead of time as new date ranges arrive, a topic covered further in section 6.9.

### 6.4 List Partitioning

List partitioning suits data that falls naturally into a known, fixed set of named categories, rather than a continuous range.

```sql
CREATE TABLE customers_p (
    id      bigint GENERATED ALWAYS AS IDENTITY,
    name    text NOT NULL,
    country text NOT NULL,
    PRIMARY KEY (id, country)
) PARTITION BY LIST (country);

CREATE TABLE customers_us PARTITION OF customers_p FOR VALUES IN ('US');
CREATE TABLE customers_uk PARTITION OF customers_p FOR VALUES IN ('UK');
CREATE TABLE customers_other PARTITION OF customers_p FOR VALUES IN ('IN', 'DE', 'FR', 'JP');
```

Notice that a single partition can claim **several** values at once (as `customers_other` does above), which is convenient for grouping many smaller, less common categories together into one partition rather than creating a separate tiny partition for every single one.

A very common, practical real-world use of list partitioning is **multi-tenant applications**, where each partition holds all the data for one specific customer organization (a "tenant"), which can make it straightforward to manage, back up, or even entirely delete one tenant's data as an isolated unit.

### 6.5 Hash Partitioning

Sometimes there is genuinely no natural range or category to split your data by; you simply have an enormous table and you want to spread it out into several roughly-equal-sized pieces purely to keep each individual piece more manageable, and possibly to spread the write workload across them.

```sql
CREATE TABLE events_p (
    id         bigint GENERATED ALWAYS AS IDENTITY,
    event_type text NOT NULL,
    payload    jsonb,
    PRIMARY KEY (id)
) PARTITION BY HASH (id);

CREATE TABLE events_p0 PARTITION OF events_p FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE events_p1 PARTITION OF events_p FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE events_p2 PARTITION OF events_p FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE events_p3 PARTITION OF events_p FOR VALUES WITH (MODULUS 4, REMAINDER 3);
```

Here, `MODULUS 4` means "split this data into 4 pieces total," and each partition's `REMAINDER` (0 through 3) says which one of those four pieces it is responsible for. PostgreSQL hashes each row's `id` value and uses the remainder of that hash to decide which partition the row belongs to, which, for a reasonably well-distributed column like an ID, tends to spread rows quite evenly across all four partitions.

The clear downside of hash partitioning, compared to range or list, is that it gives you **no natural, meaningful "old data" or "specific category" boundary** to work with. You cannot easily say "drop the oldest partition" the way you naturally can with range partitioning on a date, because a hash partition simply contains an arbitrary, evenly-spread quarter of all rows, mixed together regardless of when they were created. For this reason, hash partitioning is chosen specifically and only for the "spread the load evenly" use case, not as a general-purpose default.

### 6.6 Sub-Partitioning

A partition can itself be further partitioned, which is useful when a single partitioning dimension is not quite enough. A common real pattern is partitioning first by date range (for easy archival of old data), and then partitioning each month further by region or tenant:

```sql
CREATE TABLE orders_2026_01 PARTITION OF orders_p
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01')
    PARTITION BY LIST (status);

CREATE TABLE orders_2026_01_shipped PARTITION OF orders_2026_01 FOR VALUES IN ('shipped');
CREATE TABLE orders_2026_01_other   PARTITION OF orders_2026_01 FOR VALUES IN ('pending', 'cancelled');
```

This is a genuinely useful technique, but it also adds real complexity to your schema, so it is best reserved for cases where you have a clear, concrete reason two levels of splitting will help (for example, extremely large monthly volumes that still benefit from a second split), rather than applying it by default.

### 6.7 Indexes, Keys and Constraints on Partitioned Tables

This section explains a rule that catches almost everyone by surprise the first time they partition a table: **every unique constraint (including the primary key) on a partitioned table must include the partitioning column(s) as part of the key.**

The underlying reason is straightforward once you see it: PostgreSQL enforces `UNIQUE` and `PRIMARY KEY` constraints using an index, but each partition only has its *own* separate index, entirely independent from every other partition's index. There is no single, unified index spanning across all partitions at once. This means PostgreSQL genuinely has no way to check "is this ID unique across every partition combined," because doing so would require consulting every single partition's index on every single insert, defeating much of the performance benefit partitioning exists to provide in the first place. The only uniqueness PostgreSQL *can* practically guarantee is uniqueness **within a single partition**, and it can only be sure any given `(id, order_date)` combination stays within one specific partition if `order_date`, the partitioning column, is itself part of the key.

This is precisely why our `orders_p` example earlier declared `PRIMARY KEY (id, order_date)` rather than simply `PRIMARY KEY (id)`. In practice, this usually means you either need to accept a composite key like this, or generate your unique identifier using something that is already guaranteed to be globally unique on its own regardless of partition, such as a UUID.

The good news is that once you get past this one restriction, indexing partitioned tables is otherwise refreshingly convenient. Since PostgreSQL 11, you can create an index directly on the partitioned "parent," and PostgreSQL will automatically create a matching index on every existing partition, and will keep doing so automatically on every new partition you add in the future:

```sql
CREATE INDEX idx_orders_p_customer ON orders_p (customer_id);
-- Automatically creates idx_orders_p_customer on orders_2026_01, orders_2026_02, orders_2026_03, and any future partition
```

Foreign keys, `CHECK` constraints, and `NOT NULL` all also work naturally across a partitioned table's partitions, and are, unlike unique constraints, not subject to the same restriction about needing to include the partitioning column.

### 6.8 Partition Pruning

**Partition pruning** is the single most important performance benefit partitioning provides, and it is worth understanding concretely, not just as a buzzword. It refers to the planner's ability to look at your query's `WHERE` clause, recognize that it can only possibly match rows in certain specific partitions, and then skip examining the other partitions entirely, as if they simply were not part of the query at all.

```sql
EXPLAIN SELECT * FROM orders_p WHERE order_date = '2026-02-14';
```

```
Append
  ->  Seq Scan on orders_2026_02
        Filter: (order_date = '2026-02-14'::date)
```

Notice that only `orders_2026_02` shows up in the plan at all. `orders_2026_01` and `orders_2026_03` are not mentioned anywhere, because the planner correctly determined, just from looking at the query's `WHERE` clause and comparing it against each partition's defined range, that those two partitions could not possibly contain any matching rows, and so there was no reason to even look inside them. On a table with, say, five years of monthly partitions (sixty partitions total), a query for "just this month's data" that prunes down to a single relevant partition can be enormously faster than the same query run against one giant, unpartitioned table holding all five years at once, purely because there is so much less data to even consider.

Pruning works well for straightforward, direct comparisons on the partitioning column itself, using literal values or simple expressions PostgreSQL can evaluate ahead of time. It can be less effective, or fail to prune at all, in trickier cases, such as when the partitioning column is wrapped in a function call the planner cannot see through, or when the comparison value comes from a join to another table rather than a plain literal (though the planner has become progressively smarter about handling more of these cases in newer PostgreSQL versions). If you suspect pruning is not happening the way you expect on an important query, `EXPLAIN` (checking specifically which partitions actually appear in the plan) is always the way to confirm it directly, rather than assuming.

### 6.9 Attaching, Detaching and Rolling Old Data Off

This is where partitioning delivers its second enormous practical benefit, beyond just query speed: extremely cheap, near-instantaneous addition and removal of large chunks of data.

**Adding a brand-new partition** for an upcoming month, well ahead of time, is simply:

```sql
CREATE TABLE orders_2026_04 PARTITION OF orders_p
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
```

In a real production system, you would typically automate this, running a small scheduled job that creates the next month's (or next several months') partitions well in advance, so you never risk a failed insert simply because "next month's" partition had not been created yet.

**Removing old data** is where the real payoff becomes dramatic. Recall from section 6.1 that deleting old rows from one enormous, unpartitioned table means scanning for and marking potentially millions of individual rows as deleted, one at a time, and then still needing `VACUUM` to reclaim that space afterward. With partitioning, if "delete everything from January 2026" corresponds exactly to "delete the entire `orders_2026_01` partition," you can instead do this:

```sql
DROP TABLE orders_2026_01;
```

This is not scanning or marking individual rows at all. It is simply removing an entire physical table from disk, all at once, which for even a partition containing tens of millions of rows typically completes in well under a second, essentially regardless of how much data it actually contained.

If you would rather keep the old data around somewhere, just not as part of the live, actively-queried `orders_p` table anymore (perhaps to archive it into cheaper storage, or move it to a separate reporting database), you can **detach** it instead of dropping it outright:

```sql
ALTER TABLE orders_p DETACH PARTITION orders_2026_01;
```

After this, `orders_2026_01` becomes a completely ordinary, standalone table again, no longer connected to `orders_p` in any way, and, importantly, no longer scanned or considered at all when anyone queries `orders_p`. You are then free to do whatever you like with it: rename it, move it to another schema entirely, back it up separately, or eventually drop it once you are confident you do not need it any longer.

PostgreSQL 14 introduced `DETACH PARTITION ... CONCURRENTLY`, which performs this detachment without blocking ordinary reads and writes against the still-live `orders_p` table while it happens, which matters a great deal on a busy production system.

You can also **attach** an existing, already-populated standalone table as a new partition, which is a particularly handy technique for bulk-loading historical data efficiently: build and populate the table completely separately, entirely outside of the partitioned table, and only attach it to `orders_p` at the very end, once it is fully ready:

```sql
ALTER TABLE orders_p ATTACH PARTITION orders_2026_04
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
```

### 6.10 Default Partitions

Sometimes you cannot guarantee every possible incoming value will always match one of your defined partitions, whether because your categories genuinely are not fully known ahead of time, or simply as a safety net against a partition being created a little too late. A **default partition** catches any row that does not match any of the other, more specific partitions, rather than having the `INSERT` fail outright:

```sql
CREATE TABLE customers_default PARTITION OF customers_p DEFAULT;
```

Any row with a `country` value that is not `'US'`, `'UK'`, or one of the values already claimed by `customers_other` will land safely in `customers_default` rather than causing an error. This is a good safety net, but be aware of one important restriction: once a default partition exists and has rows in it, you cannot directly create a brand-new specific partition for a value that is already present in the default partition's data; you must first move those particular rows out of the default partition before PostgreSQL will let you carve out a proper dedicated partition for them.

### 6.11 Declarative Partitioning vs Old-Style Inheritance Partitioning

Before PostgreSQL 10 introduced the clean `PARTITION BY` syntax we have been using throughout this section (now generally called **declarative partitioning**), people achieved a similar effect manually using the plain table inheritance mechanism from section 2, combined with `CHECK` constraints on each child table and a hand-written trigger to route incoming rows to the correct child. This older technique still works today and you may well encounter it in older codebases, but declarative partitioning is unambiguously better for nearly every case now, since it:

- Handles routing incoming rows to the correct partition **automatically**, with no trigger for you to write and maintain yourself.
- Lets the query planner take much better advantage of partition pruning (section 6.8), since the planner has native, built-in understanding of how declarative partitions relate to one another, rather than having to infer it indirectly from `CHECK` constraints.
- Supports the convenient automatic-index-propagation behavior described in section 6.7.

If you come across old-style inheritance-based partitioning in an existing database, it is generally well worth planning a migration to declarative partitioning when the opportunity arises, rather than continuing to build new features on top of the older pattern.

### 6.12 When to Partition (and When Not To)

Partitioning is a genuinely powerful tool, but it adds real structural complexity to your schema, and it is not automatically beneficial for every table, even fairly large ones. A few honest guidelines:

**Partitioning tends to help a lot when:**

- The table is large enough that maintenance operations (`VACUUM`, index rebuilds, `ANALYZE`) or index sizes have become a genuine, measurable operational problem.
- You have a clear, natural, and consistently-used partitioning key, most commonly a date, that the majority of your important queries already filter on.
- You have a real, recurring need to bulk-delete or archive old data, where the ability to `DROP` or `DETACH` an entire partition, rather than run a slow `DELETE`, is a significant practical win.

**Partitioning is probably not worth it (yet) when:**

- The table is comfortably small enough that a plain index handles your query performance needs just fine. There is a genuine, non-trivial overhead and complexity cost to partitioning, and it is not free just because it sounds like a "best practice."
- Your queries do not consistently filter on any single, obvious column that would make a good partitioning key. Partitioning that most of your actual queries cannot take advantage of, because they filter on something else entirely, brings you all of the added complexity with little of the benefit, since pruning will rarely trigger.
- You need strict, guaranteed global uniqueness on a key that does not naturally include your partitioning column, and you are not able or willing to adjust your key design to accommodate the restriction described in section 6.7.

A reasonable rule of thumb many teams use: seriously start considering partitioning once a table's row count moves into the tens of millions and keeps climbing, or once you notice `VACUUM` or index maintenance operations on that specific table becoming a recurring, noticeable operational headache, rather than partitioning every table from day one purely on the assumption that it will eventually grow large.

---

## 7. How These Features Work Together

These five topics are often taught separately, but in a real, mature PostgreSQL system, they very frequently combine:

- A large, partitioned `orders` table (section 6) will still have **indexes** (section 5) created on it, and thanks to automatic index propagation, you only need to define each index once on the parent, and every partition gets a matching copy.
- Every partition, and indeed most tables in general, typically use an **identity column** (section 4) backed by a sequence to generate primary keys, keeping in mind the composite-key requirement that partitioning imposes (section 6.7).
- A **materialized view** (section 3.5) is a natural, common way to pre-compute an expensive summary (say, "total sales per month") across an enormous partitioned sales table, refreshed on a schedule, so that a dashboard querying that summary stays fast without having to scan the full history of raw data on every single page load.
- Plain **table inheritance** (section 2) is, as covered in section 6.11, the direct historical ancestor of today's declarative partitioning, and understanding its real limitations is exactly what makes it clear why declarative partitioning was designed the way it was.

Seeing how these pieces reinforce each other is often the point at which PostgreSQL's design starts to feel like a coherent, well-thought-out whole, rather than a list of separate, unrelated features to memorize individually.

---

## 8. Hands-On Exercises

**Exercise 1: Inheritance**

1. Recreate the `products` / `physical_products` / `digital_products` example from section 2.
2. Insert two rows into `physical_products` and one into `digital_products`.
3. Query `products` alone and confirm all three rows appear. Then query `ONLY products` and confirm zero rows appear.
4. Insert a row directly into `physical_products` with `id = 1`, and then a second, completely different row directly into `digital_products`, also with `id = 1`. Confirm PostgreSQL allows both, and explain, in your own words, why the parent's `PRIMARY KEY` did not prevent this.
5. Use `tableoid::regclass` to write a single query against `products` that reports which child table each row actually lives in.

**Exercise 2: Views**

1. Build the `shipped_orders` view from section 3.2 using the sample data in section 1.
2. Determine, using the rules in section 3.3, whether `shipped_orders` is automatically updatable. Test your prediction by attempting an `UPDATE` through it.
3. Create `us_customers` with `WITH CHECK OPTION`, then attempt to update a US customer's country to something else through the view, and observe the error.
4. Create a materialized view summarizing total order value per customer. Query it, then insert a new order for an existing customer, query the materialized view again (notice it has not changed), then `REFRESH` it and query it once more.

**Exercise 3: Sequences**

1. Create a table using `GENERATED ALWAYS AS IDENTITY`, insert three rows, and note the IDs assigned.
2. Start a transaction, insert a fourth row, then `ROLLBACK`. Insert a fifth row in a new statement and observe that its ID is not what you might naively expect, connecting this back to section 4.4.
3. Try inserting an explicit ID into the `GENERATED ALWAYS AS IDENTITY` column directly and observe the error; then retry using `OVERRIDING SYSTEM VALUE`.
4. Find the sequence backing your identity column (hint: `\d tablename` will show it, or query `pg_sequences`), and use `setval` to move it forward by 1000.

**Exercise 4: Indexing**

1. Load the `orders` table with a few thousand generated rows (`generate_series` is useful here) and run `EXPLAIN ANALYZE` on a query filtering by `customer_id` before creating any index. Note whether it uses a sequential scan.
2. Create a plain B-tree index on `customer_id`, re-run the same `EXPLAIN ANALYZE`, and compare the plan and the reported timing.
3. Create a composite index on `(customer_id, order_date)` and test which of the query patterns from section 5.4 do and do not use it.
4. Create a partial index for `status = 'pending'` orders only, and confirm with `EXPLAIN` that a query filtering on that status uses the smaller, partial index.
5. Create an expression index on `lower(status)` style data of your choosing, and demonstrate a query that can and cannot use it.

**Exercise 5: Partitioning**

1. Build the range-partitioned `orders_p` table from section 6.3, with partitions for three consecutive months.
2. Insert rows across all three months and confirm, using `SELECT tableoid::regclass, * FROM orders_p`, that each row landed in the correct partition automatically.
3. Run `EXPLAIN` on a query filtering to a single month and confirm, from the plan, that only one partition is scanned (partition pruning).
4. Attempt to insert a row for a month with no matching partition yet, and observe the error. Then create the missing partition and retry successfully.
5. `DETACH` one partition, confirm it is now a normal standalone table and no longer appears in queries against `orders_p`, then `DROP` a different partition entirely and note the difference between the two operations.

---

## 9. Quick Reference Cheat Sheet

**Inheritance**

```sql
CREATE TABLE child (extra_col text) INHERITS (parent);
SELECT * FROM parent;         -- includes rows from parent AND all children
SELECT * FROM ONLY parent;    -- excludes children
ALTER TABLE child INHERIT parent;
ALTER TABLE child NO INHERIT parent;
```

Remember: primary keys, unique constraints, and foreign keys on the parent do **not** apply across children.

**Views**

```sql
CREATE VIEW v AS SELECT ...;
CREATE OR REPLACE VIEW v AS SELECT ...;
CREATE VIEW v WITH (security_barrier) AS SELECT ...;
CREATE VIEW v WITH (security_invoker = true) AS SELECT ...;   -- 15+
CREATE VIEW v AS SELECT ... WITH CHECK OPTION;

CREATE MATERIALIZED VIEW mv AS SELECT ...;
REFRESH MATERIALIZED VIEW mv;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv;   -- needs a unique index first, does not block readers
```

**Sequences**

```sql
CREATE SEQUENCE s START WITH 1 INCREMENT BY 1;
SELECT nextval('s');   -- get the next number (never rolls back)
SELECT currval('s');   -- last number THIS session got
SELECT setval('s', 100);

col bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY     -- preferred, rejects explicit values by default
col bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY -- allows explicit values
col serial PRIMARY KEY                                  -- older shorthand, still common in legacy code
```

**Indexing**

```sql
CREATE INDEX idx ON t (col);                              -- default: B-tree
CREATE INDEX idx ON t USING gin (jsonb_col);               -- arrays, jsonb, full text
CREATE INDEX idx ON t USING gist (range_col);               -- geometry, ranges
CREATE INDEX idx ON t USING brin (timestamp_col);            -- huge, naturally-ordered tables
CREATE INDEX idx ON t (a, b);                                 -- composite: leading column matters
CREATE INDEX idx ON t (col) WHERE status = 'active';           -- partial
CREATE INDEX idx ON t (lower(col));                             -- expression
CREATE INDEX idx ON t (a) INCLUDE (b, c);                        -- covering, enables index-only scans
CREATE UNIQUE INDEX idx ON t (col);
CREATE INDEX CONCURRENTLY idx ON t (col);                          -- avoids blocking writes
REINDEX INDEX CONCURRENTLY idx;
EXPLAIN ANALYZE SELECT ...;                                          -- check what's actually being used
```

**Partitioning**

```sql
CREATE TABLE t (..., PRIMARY KEY (id, part_col)) PARTITION BY RANGE (part_col);
CREATE TABLE t_p1 PARTITION OF t FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

CREATE TABLE t (...) PARTITION BY LIST (category);
CREATE TABLE t_a PARTITION OF t FOR VALUES IN ('a', 'b');

CREATE TABLE t (...) PARTITION BY HASH (id);
CREATE TABLE t_0 PARTITION OF t FOR VALUES WITH (MODULUS 4, REMAINDER 0);

CREATE TABLE t_default PARTITION OF t DEFAULT;

CREATE INDEX idx ON t (col);            -- automatically propagates to every partition

ALTER TABLE t DETACH PARTITION t_p1;                    -- becomes a normal standalone table
ALTER TABLE t DETACH PARTITION t_p1 CONCURRENTLY;       -- non-blocking (14+)
ALTER TABLE t ATTACH PARTITION t_new FOR VALUES FROM (...) TO (...);
DROP TABLE t_p1;                                        -- instantly discards an entire partition's data

EXPLAIN SELECT ... WHERE part_col = ...;   -- confirm partition pruning: only relevant partitions appear
```

**Rule to remember**

| Feature | The one thing most people forget |
|---|---|
| Inheritance | Uniqueness and foreign keys do not span parent + children |
| Views | A plain view re-runs its query every time; only a materialized view stores a snapshot |
| Sequences | Gaps are normal and expected, not a bug |
| Indexing | Every index speeds up reads but slows down every write; composite index column order matters |
| Partitioning | Every unique key must include the partitioning column |

---

*Further reading: the official PostgreSQL documentation at <https://www.postgresql.org/docs/current/>: "Inheritance", "Views" (Create View, Rules), "Sequence Manipulation Functions", "Indexes", and "Table Partitioning".*
