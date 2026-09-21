# PostgreSQL Fundamentals: Teaching Guide

A practical introduction to how PostgreSQL works internally, what its limits are, how to use the `psql` client, and how to organize objects with schemas.

> **Version note:** Details below apply to modern PostgreSQL (14–18). Where behavior differs by version, it is called out.

---

## Table of Contents

1. [Process and Memory Architecture](#1-process-and-memory-architecture)
   - [1.1 Client/Server Model](#11-clientserver-model)
   - [1.2 Process Architecture](#12-process-architecture)
   - [1.3 Memory Architecture](#13-memory-architecture)
   - [1.4 On-Disk Layout](#14-on-disk-layout)
   - [1.5 Life of a Query](#15-life-of-a-query)
   - [1.6 MVCC, WAL and Checkpoints](#16-mvcc-wal-and-checkpoints)
   - [1.7 Key Configuration Parameters](#17-key-configuration-parameters)
2. [Database Limits](#2-database-limits)
   - [2.1 Hard Limits](#21-hard-limits)
   - [2.2 Data Type Ranges](#22-data-type-ranges)
   - [2.3 Practical (Soft) Limits](#23-practical-soft-limits)
3. [psql Commands](#3-psql-commands)
   - [3.1 Connecting](#31-connecting)
   - [3.2 Getting Help and Quitting](#32-getting-help-and-quitting)
   - [3.3 Listing and Describing Objects](#33-listing-and-describing-objects)
   - [3.4 Navigation and Connection Commands](#34-navigation-and-connection-commands)
   - [3.5 Output Formatting](#35-output-formatting)
   - [3.6 Working with Files and the Editor](#36-working-with-files-and-the-editor)
   - [3.7 Variables and Scripting](#37-variables-and-scripting)
   - [3.8 Import and Export with \copy](#38-import-and-export-with-copy)
   - [3.9 Handy Tips](#39-handy-tips)
4. [Schemas](#4-schemas)
   - [4.1 What Is a Schema?](#41-what-is-a-schema)
   - [4.2 Hierarchy: Cluster, Database, Schema, Object](#42-hierarchy-cluster-database-schema-object)
   - [4.3 Creating and Using Schemas](#43-creating-and-using-schemas)
   - [4.4 The search_path](#44-the-search_path)
   - [4.5 The public Schema and Security](#45-the-public-schema-and-security)
   - [4.6 System Schemas](#46-system-schemas)
   - [4.7 Privileges on Schemas](#47-privileges-on-schemas)
   - [4.8 Common Use Cases](#48-common-use-cases)
   - [4.9 Best Practices](#49-best-practices)
5. [Hands-On Exercises](#5-hands-on-exercises)
6. [Quick Reference Cheat Sheet](#6-quick-reference-cheat-sheet)

---

## 1. Process and Memory Architecture

### 1.1 Client/Server Model

PostgreSQL uses a **client/server** model with a **process-per-connection** design (not threads).

```
 +--------+     +--------+     +--------+
 | Client |     | Client |     | Client |
 +---+----+     +---+----+     +---+----+
     |              |              |
     +--------------+--------------+
                    |  TCP / Unix socket
             +------v-------+
             |  postmaster  |  (listens, forks)
             +------+-------+
       +------------+------------+
       |            |            |
 +-----v----+ +-----v----+ +-----v----+
 | backend  | | backend  | | backend  |   one per connection
 +-----+----+ +-----+----+ +-----+----+
       |            |            |
       +------------+------------+
                    |
        +-----------v-----------+
        |     Shared Memory     |
        +-----------+-----------+
                    |
        +-----------v-----------+
        |  Data files + WAL     |
        +-----------------------+
```

**Consequences of process-per-connection:**

- Strong isolation: one crashing backend does not corrupt others (though the postmaster restarts all backends after a crash to protect shared memory).
- Each connection costs memory and OS resources, so thousands of direct connections are expensive.
- Use a **connection pooler** (PgBouncer, pgcat, Odyssey) for high connection counts.

### 1.2 Process Architecture

| Process | Role |
|---|---|
| **postmaster** | Parent process. Listens for connections, forks a backend per client, starts and restarts background processes. |
| **backend** (a.k.a. postgres process) | Serves one client connection. Parses, plans, and executes queries. |
| **checkpointer** | Periodically flushes all dirty shared buffers to disk and writes a checkpoint record to WAL. |
| **background writer** (bgwriter) | Trickles dirty buffers to disk between checkpoints to reduce backend write stalls. |
| **WAL writer** | Flushes WAL buffers to the WAL files on disk. |
| **autovacuum launcher / workers** | Launcher schedules workers that run `VACUUM` and `ANALYZE` automatically. |
| **archiver** | Copies completed WAL segments to an archive location (if `archive_mode` is on). |
| **WAL sender / WAL receiver** | Streaming replication: sender on the primary, receiver on the standby. |
| **logical replication launcher / workers** | Manage logical replication subscriptions. |
| **startup process** | Performs crash recovery, and applies WAL on standbys. |
| **I/O workers** (PostgreSQL 18+) | Optional workers for asynchronous I/O (`io_method = worker`). |

> The old **stats collector** process was removed in PostgreSQL 15. Statistics now live in shared memory.

Inspect running processes:

```bash
ps aux | grep postgres
```

```sql
-- Sessions and background processes
SELECT pid, backend_type, state, query
FROM pg_stat_activity;
```

### 1.3 Memory Architecture

PostgreSQL memory is split into **shared** memory (allocated once at startup, used by all processes) and **local** memory (allocated per backend as needed).

#### Shared memory

| Area | Purpose | Main parameter |
|---|---|---|
| **Shared buffers** | Cache of table and index pages (8 KB blocks). | `shared_buffers` |
| **WAL buffers** | Holds WAL records before they are flushed. | `wal_buffers` |
| **Transaction status buffers** | Commit status (formerly CLOG), subtransactions, etc. | `transaction_buffers` and related (v17+) |
| **Lock tables** | Heavyweight locks and predicate locks. | `max_locks_per_transaction`, `max_connections` |
| **Process array, stats** | Per-process info and cumulative statistics. | — |

#### Local (per-backend) memory

| Area | Purpose | Parameter |
|---|---|---|
| **work_mem** | Sorts, hash joins, hash aggregates. **Per operation, per backend**, not per connection. | `work_mem` |
| **maintenance_work_mem** | `VACUUM`, `CREATE INDEX`, `ALTER TABLE ADD FOREIGN KEY`. | `maintenance_work_mem` |
| **autovacuum_work_mem** | Memory for each autovacuum worker (defaults to maintenance_work_mem). | `autovacuum_work_mem` |
| **temp_buffers** | Buffers for temporary tables. | `temp_buffers` |
| **Catalog / relation caches** | Cached metadata, plans for prepared statements. | — |

> **Warning:** A single complex query can use `work_mem` several times (one per sort/hash node). With many connections, total usage is roughly `connections x nodes x work_mem`. Size it carefully.

#### The OS page cache

PostgreSQL relies on the operating system's file cache in addition to `shared_buffers`, so data can be cached twice (double buffering). `effective_cache_size` does **not** allocate memory. It only tells the planner how much total cache (shared_buffers + OS cache) is likely available.

```
 Backend read request
        |
        v
 shared_buffers hit? --yes--> return page
        | no
        v
 OS page cache hit? --yes--> copy into shared_buffers
        | no
        v
 Read from disk
```

### 1.4 On-Disk Layout

The **data directory** (`PGDATA`) holds everything for one cluster:

| Path | Contents |
|---|---|
| `base/` | One subdirectory per database (named by OID) containing table and index files. |
| `global/` | Cluster-wide catalogs (e.g. `pg_database`, `pg_authid`). |
| `pg_wal/` | Write-ahead log segments (16 MB each by default). |
| `pg_xact/` | Transaction commit status. |
| `pg_tblspc/` | Symlinks to tablespaces. |
| `pg_stat/`, `pg_stat_tmp/` | Statistics files. |
| `postgresql.conf` | Main configuration. |
| `pg_hba.conf` | Client authentication rules. |
| `pg_ident.conf` | User name mapping. |
| `postgresql.auto.conf` | Settings written by `ALTER SYSTEM`. |
| `PG_VERSION` | Major version marker. |

**Storage concepts**

- **Page (block):** 8 KB by default. The unit of I/O.
- **Heap:** Table data is an unordered set of pages containing tuples.
- **TOAST:** Oversized values (over ~2 KB) are compressed and/or moved out-of-line to a side table.
- **Free Space Map (`_fsm`)** and **Visibility Map (`_vm`)** fork files help `VACUUM` and index-only scans.
- Large relations are split into **1 GB segment files**.

```sql
-- Where is a table on disk?
SELECT pg_relation_filepath('my_table');

-- How big is it?
SELECT pg_size_pretty(pg_total_relation_size('my_table'));
```

### 1.5 Life of a Query

1. **Connection and authentication:** postmaster forks a backend, checks `pg_hba.conf`.
2. **Parser:** checks syntax, builds a parse tree.
3. **Analyzer/Rewriter:** resolves names, expands views and rules.
4. **Planner/Optimizer:** chooses the cheapest plan using statistics (`pg_statistic`).
5. **Executor:** runs the plan, reading pages via shared buffers.
6. **Result** is streamed back to the client.

```sql
EXPLAIN ANALYZE
SELECT * FROM orders WHERE customer_id = 42;
```

### 1.6 MVCC, WAL and Checkpoints

**MVCC (Multi-Version Concurrency Control)**

- Readers do not block writers, and writers do not block readers.
- An `UPDATE` writes a **new tuple version**; the old one remains until no snapshot needs it.
- Each tuple carries `xmin` (creating transaction) and `xmax` (deleting/updating transaction).
- Dead tuples are reclaimed by **VACUUM**. Without it you get table **bloat**.

**WAL (Write-Ahead Logging)**

- Every change is written to WAL **before** the data page is modified on disk.
- Provides crash recovery, point-in-time recovery (PITR), and replication.
- On `COMMIT`, the WAL is flushed (controlled by `synchronous_commit`).

**Checkpoints**

- The checkpointer flushes dirty pages so recovery only needs to replay WAL after the last checkpoint.
- Triggered by `checkpoint_timeout` (default 5 min) or WAL volume (`max_wal_size`).

```
 UPDATE --> modify page in shared_buffers (dirty)
        --> write WAL record --> flush WAL on COMMIT
        --> later: bgwriter/checkpointer writes dirty page to data file
```

### 1.7 Key Configuration Parameters

| Parameter | Typical guidance |
|---|---|
| `shared_buffers` | Start around 25% of RAM on a dedicated server. |
| `work_mem` | Start small (4–64 MB); raise per-session for heavy queries. |
| `maintenance_work_mem` | 256 MB to 2 GB for faster vacuum and index builds. |
| `effective_cache_size` | Around 50–75% of RAM (planner hint only). |
| `max_connections` | Default 100. Prefer a pooler over huge values. |
| `wal_level` | `replica` (default); `logical` for logical replication. |
| `max_wal_size` / `checkpoint_timeout` | Tune to space out checkpoints. |
| `autovacuum` | Keep **on**. Tune per table if needed. |
| `random_page_cost` | Lower (e.g. 1.1) on SSD storage. |

```sql
SHOW shared_buffers;
SELECT name, setting, unit, context FROM pg_settings WHERE name LIKE '%mem%';
ALTER SYSTEM SET work_mem = '32MB';
SELECT pg_reload_conf();
```

> Parameters with context `postmaster` (e.g. `shared_buffers`, `max_connections`) require a **restart**. Others need only a reload.

---

## 2. Database Limits

### 2.1 Hard Limits

From the official PostgreSQL documentation (default 8 KB block size):

| Item | Upper Limit | Notes |
|---|---|---|
| Maximum database size | Unlimited | Bounded only by storage. |
| Maximum table size | **32 TB** | Can be raised with a larger block size at compile time. |
| Maximum row size | **1.6 TB** | Via TOAST; a single field is limited to 1 GB. |
| Maximum field (value) size | **1 GB** | Applies to `text`, `bytea`, etc. |
| Maximum rows per table | Limited by table size | About 4.29 billion pages (2^32 - 1) worth of tuples. |
| Maximum columns per table | **1,600** | Fewer in practice, depending on column types. |
| Maximum columns in a SELECT result | ~1,664 | Slightly above table limit. |
| Maximum columns per index | **32** | Compile-time setting. |
| Maximum indexes per table | Unlimited | Bounded by storage and write cost. |
| Maximum partition keys | **32** | Compile-time setting. |
| Maximum identifier length | **63 bytes** | Longer names are silently truncated. |
| Maximum number of databases | ~4.29 billion | Limited by OID space. |
| Maximum relations per database | ~4.29 billion | Limited by OID space. |

### 2.2 Data Type Ranges

| Type | Storage | Range |
|---|---|---|
| `smallint` | 2 bytes | -32,768 to 32,767 |
| `integer` | 4 bytes | -2,147,483,648 to 2,147,483,647 |
| `bigint` | 8 bytes | -9.22 x 10^18 to 9.22 x 10^18 |
| `numeric` | variable | Up to 131,072 digits before the decimal point, 16,383 after |
| `real` | 4 bytes | ~6 decimal digits precision |
| `double precision` | 8 bytes | ~15 decimal digits precision |
| `text` / `varchar` | variable | Up to 1 GB |
| `bytea` | variable | Up to 1 GB |
| `date` | 4 bytes | 4713 BC to 5874897 AD |
| `timestamp` / `timestamptz` | 8 bytes | 4713 BC to 294276 AD |
| `boolean` | 1 byte | true / false / null |
| `uuid` | 16 bytes | 128-bit identifier |

### 2.3 Practical (Soft) Limits

These are not enforced by PostgreSQL but matter in real systems:

- **Connections:** `max_connections` defaults to 100. Each one is a process. Use pooling.
- **Transaction ID wraparound:** Transaction IDs are 32-bit. `VACUUM` must "freeze" old rows before ~2 billion transactions pass, or the database will stop accepting writes to protect data. Monitor `age(datfrozenxid)`.
- **Table bloat:** Heavy update/delete workloads need healthy autovacuum.
- **Partitioning:** Consider it for tables reaching hundreds of GB.
- **Long transactions:** They hold back vacuum and can cause bloat and replication lag.
- **Index count:** Every index slows writes, so add only what queries need.

```sql
-- Check wraparound risk
SELECT datname, age(datfrozenxid) AS xid_age
FROM pg_database
ORDER BY xid_age DESC;

-- Sizes
SELECT pg_size_pretty(pg_database_size(current_database()));
```

---

## 3. psql Commands

`psql` is PostgreSQL's interactive terminal. It accepts two kinds of input:

- **SQL statements**, ended with a semicolon `;`
- **Meta-commands**, starting with a backslash `\` (processed by psql itself, no semicolon needed)

### 3.1 Connecting

```bash
psql -h localhost -p 5432 -U alice -d mydb
psql "postgresql://alice@localhost:5432/mydb"
psql -f script.sql mydb            # run a file
psql -c "SELECT now();" mydb       # run one command
psql -l                            # list databases
```

| Option | Meaning |
|---|---|
| `-h` | Host |
| `-p` | Port (default 5432) |
| `-U` | User name |
| `-d` | Database name |
| `-W` | Force password prompt |
| `-f` | Execute commands from a file |
| `-c` | Execute a single command and exit |
| `-l` | List databases and exit |
| `-X` | Do not read `~/.psqlrc` |
| `-A -t` | Unaligned, tuples-only output (good for scripts) |

Password handling: use the `PGPASSWORD` environment variable (less safe) or a `~/.pgpass` file (recommended, permissions `0600`).

### 3.2 Getting Help and Quitting

| Command | Description |
|---|---|
| `\?` | List all psql meta-commands |
| `\h` | List all SQL commands |
| `\h CREATE TABLE` | Syntax help for a specific SQL command |
| `\q` | Quit psql (or press `Ctrl+D`) |
| `\conninfo` | Show current connection details |
| `\password [user]` | Change a password securely |

### 3.3 Listing and Describing Objects

Append `+` to most commands for more detail (size, description, storage). Append a pattern to filter, e.g. `\dt sales.*`.

| Command | Description |
|---|---|
| `\l` / `\l+` | List databases |
| `\dn` / `\dn+` | List schemas |
| `\dt` / `\dt+` | List tables |
| `\dt *.*` | List tables in all schemas |
| `\d name` | Describe a table, view, index or sequence |
| `\d+ name` | Describe with extra detail |
| `\dv` | List views |
| `\dm` | List materialized views |
| `\di` | List indexes |
| `\ds` | List sequences |
| `\dE` | List foreign tables |
| `\df` / `\df+` | List functions |
| `\dT` | List data types |
| `\dx` | List installed extensions |
| `\du` / `\dg` | List roles |
| `\dp` (or `\z`) | Show table access privileges |
| `\ddp` | Show default privileges |
| `\db` | List tablespaces |
| `\dL` | List procedural languages |
| `\sf func` | Show a function's definition |
| `\sv view` | Show a view's definition |

### 3.4 Navigation and Connection Commands

| Command | Description |
|---|---|
| `\c dbname` | Connect to another database |
| `\c dbname username` | Connect as a different user |
| `\conninfo` | Current connection information |
| `\encoding` | Show or set client encoding |

### 3.5 Output Formatting

| Command | Description |
|---|---|
| `\x` | Toggle expanded (vertical) display |
| `\x auto` | Expanded only when the output is wide |
| `\timing` | Toggle query timing |
| `\a` | Toggle aligned / unaligned output |
| `\t` | Toggle tuples-only (hide headers and footers) |
| `\pset border 2` | Set table border style |
| `\pset null '(null)'` | Display NULLs visibly |
| `\pset format csv` | Output as CSV (also `html`, `json`-like via SQL, etc.) |
| `\H` | Toggle HTML output |
| `\pset pager off` | Disable the pager |

Example of expanded output:

```
mydb=# \x
Expanded display is on.
mydb=# SELECT * FROM users LIMIT 1;
-[ RECORD 1 ]-------------
id         | 1
name       | Alice
created_at | 2026-01-15 09:30:00
```

### 3.6 Working with Files and the Editor

| Command | Description |
|---|---|
| `\i file.sql` | Execute commands from a file |
| `\ir file.sql` | Like `\i`, but relative to the current script's location |
| `\o file.txt` | Send query output to a file (`\o` alone restores stdout) |
| `\e` | Edit the current query buffer in `$EDITOR` |
| `\ef func` | Edit a function definition |
| `\p` | Print the current query buffer |
| `\r` | Reset (clear) the query buffer |
| `\w file` | Write the query buffer to a file |
| `\s` | Show command history |
| `\! command` | Run a shell command (e.g. `\! ls`) |
| `\cd dir` | Change the working directory |

### 3.7 Variables and Scripting

```
\set myvar 42
SELECT :myvar;

\set name 'alice'
SELECT * FROM users WHERE username = :'name';   -- quoted as a literal
SELECT * FROM :"tablename";                      -- quoted as an identifier
```

| Command | Description |
|---|---|
| `\set` | List variables, or set one |
| `\unset name` | Remove a variable |
| `\echo text` | Print text (useful in scripts) |
| `\prompt` | Ask the user for input |
| `\if`, `\elif`, `\else`, `\endif` | Conditional execution in scripts |
| `\gset` | Store a query's result columns in variables |
| `\g` | Run the buffer (same as `;`); `\g file` writes output to a file |
| `\gx` | Run the buffer with expanded output |
| `\watch 5` | Re-run the current query every 5 seconds |

Useful built-in variables: `AUTOCOMMIT`, `ON_ERROR_STOP`, `ECHO`, `HISTSIZE`, `PROMPT1`.

```
\set ON_ERROR_STOP on
\set AUTOCOMMIT off
```

### 3.8 Import and Export with \copy

`\copy` runs on the **client**: it reads and writes files on the machine running psql. Server-side `COPY` reads/writes on the database server and needs elevated privileges.

```
\copy customers FROM 'customers.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM orders WHERE total > 100) TO 'big_orders.csv' WITH (FORMAT csv, HEADER true)
```

### 3.9 Handy Tips

- **Tab completion** works for commands, tables, and columns.
- **`~/.psqlrc`** runs at startup. Good place for `\timing on`, `\x auto`, and custom prompts.
- **Up/Down arrows** and `Ctrl+R` search the history.
- **`\watch`** is handy for lightweight monitoring:
  ```
  SELECT count(*) FROM pg_stat_activity \watch 2
  ```
- Run `psql -E` to see the SQL that psql runs behind each `\d` command, a great way to learn the system catalogs.

---

## 4. Schemas

### 4.1 What Is a Schema?

A **schema** is a **namespace** inside a database. It contains tables, views, indexes, sequences, functions, types, and other objects. Objects in different schemas can share the same name without conflict.

Think of it like folders in a file system: `sales.orders` and `archive.orders` are two different tables.

> Do not confuse PostgreSQL's "schema" (a namespace) with a "database schema" in the general sense (the structure of tables and columns).

### 4.2 Hierarchy: Cluster, Database, Schema, Object

```
Cluster (one PostgreSQL server instance, one PGDATA)
 |-- Database: app_db
 |    |-- Schema: public
 |    |    |-- table: users
 |    |-- Schema: sales
 |    |    |-- table: orders
 |    |    |-- view:  monthly_revenue
 |    |-- Schema: hr
 |         |-- table: employees
 |-- Database: analytics_db
      |-- Schema: public
```

- A connection is made to **one database** and cannot query another database directly (use foreign data wrappers or `dblink` for that).
- Within a database, you can query across **schemas** freely (subject to privileges).
- Every database starts with a `public` schema.

### 4.3 Creating and Using Schemas

```sql
-- Create
CREATE SCHEMA sales;
CREATE SCHEMA IF NOT EXISTS hr AUTHORIZATION hr_admin;

-- Create objects inside it
CREATE TABLE sales.orders (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id bigint NOT NULL,
    total       numeric(10,2),
    created_at  timestamptz DEFAULT now()
);

-- Qualified access: schema.object
SELECT * FROM sales.orders;

-- Rename and move
ALTER SCHEMA sales RENAME TO commerce;
ALTER TABLE public.temp_data SET SCHEMA commerce;

-- Drop
DROP SCHEMA commerce;            -- fails if not empty
DROP SCHEMA commerce CASCADE;    -- drops everything inside (dangerous!)
```

In `psql`:

```
\dn            -- list schemas
\dt sales.*    -- tables in the sales schema
\dt *.*        -- tables in all schemas
```

### 4.4 The search_path

When you write an **unqualified** name like `orders`, PostgreSQL looks through the schemas in `search_path`, in order, and uses the first match.

```sql
SHOW search_path;
-- "$user", public

-- Change for the current session
SET search_path TO sales, public;

-- Change persistently for a role or database
ALTER ROLE alice SET search_path = sales, public;
ALTER DATABASE app_db SET search_path = sales, public;
```

Key points:

- `"$user"` means "a schema named after the current user, if it exists".
- `pg_catalog` is always searched first implicitly, unless listed explicitly.
- **New objects are created in the first schema** in the search path that exists.
- Inspect the current creation target with `SELECT current_schema();`.

```sql
SET search_path TO sales;
CREATE TABLE customers (id int);   -- created as sales.customers
```

### 4.5 The public Schema and Security

Historically, every user could create objects in `public`. This led to a well-known security issue (CVE-2018-1058): a malicious user could plant objects that shadow trusted ones and trick other users or functions into running them.

**Changes in PostgreSQL 15+:**

- The `public` schema is owned by `pg_database_owner`.
- Ordinary users **no longer have `CREATE`** privilege on `public` by default.

**Hardening steps (recommended on any version):**

```sql
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
```

- Create dedicated schemas per application or team.
- Set `search_path` explicitly in `SECURITY DEFINER` functions.

### 4.6 System Schemas

| Schema | Purpose |
|---|---|
| `pg_catalog` | System catalogs (`pg_class`, `pg_attribute`, ...), built-in types and functions. |
| `information_schema` | SQL-standard views over metadata (`tables`, `columns`, ...). |
| `pg_toast` | Storage for oversized values (TOAST tables). |
| `pg_temp_N` | Per-session temporary tables. |
| `pg_toast_temp_N` | TOAST tables for temporary tables. |

```sql
-- Metadata queries
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog', 'information_schema');

SELECT schemaname, tablename FROM pg_tables WHERE schemaname = 'sales';
```

### 4.7 Privileges on Schemas

There are two schema-level privileges:

| Privilege | Meaning |
|---|---|
| `USAGE` | Allows accessing (looking up) objects within the schema. |
| `CREATE` | Allows creating new objects in the schema. |

Privileges on the schema **and** on the objects inside are both required. Having `SELECT` on a table is useless without `USAGE` on its schema.

```sql
CREATE ROLE reporting_user LOGIN PASSWORD 'change_me';

GRANT USAGE ON SCHEMA sales TO reporting_user;
GRANT SELECT ON ALL TABLES IN SCHEMA sales TO reporting_user;

-- Apply to tables created in the future
ALTER DEFAULT PRIVILEGES IN SCHEMA sales
    GRANT SELECT ON TABLES TO reporting_user;

-- Inspect
\dn+ sales
\dp sales.*
```

### 4.8 Common Use Cases

1. **Organizing a large database** by domain (`sales`, `hr`, `inventory`).
2. **Multi-tenant applications**: one schema per tenant (`tenant_acme`, `tenant_globex`) with identical structure. Simple isolation, but thousands of schemas increase catalog size and migration effort.
3. **Separating third-party or extension objects** from application objects (e.g. install extensions into an `extensions` schema).
4. **Access control:** grant different roles access to different schemas.
5. **Versioning API layers:** e.g. `api_v1`, `api_v2` views over the same tables.
6. **Staging and archival:** `staging`, `archive` schemas separate from production tables.

### 4.9 Best Practices

- Do not put application objects in `public`. Create purpose-specific schemas.
- Use **schema-qualified names** in application code and migrations where practical.
- Set `search_path` per role or database, not ad hoc in each query.
- Grant privileges to **roles**, not individual users, and use `ALTER DEFAULT PRIVILEGES`.
- Be careful with `DROP SCHEMA ... CASCADE`.
- Use consistent, lowercase names. Avoid quoted mixed-case identifiers.
- Schemas are **not a substitute for separate databases** when you need hard isolation, separate backups, or different extensions and settings per tenant.

---

## 5. Hands-On Exercises

**Exercise 1: Explore the architecture**

1. Run `ps aux | grep postgres` and identify the postmaster, checkpointer, background writer, WAL writer and autovacuum launcher.
2. In `psql`, run `SELECT pid, backend_type FROM pg_stat_activity;` and match the output to the processes above.
3. Run `SHOW shared_buffers;` and `SHOW work_mem;`. Compare them with your machine's RAM.

**Exercise 2: Find your data on disk**

```sql
SHOW data_directory;
CREATE TABLE demo (id int, note text);
INSERT INTO demo SELECT g, repeat('x', 100) FROM generate_series(1, 100000) g;
SELECT pg_relation_filepath('demo');
SELECT pg_size_pretty(pg_relation_size('demo'));
```

Locate the file under `data_directory`. What happens to the size after `DELETE FROM demo;` and then `VACUUM FULL demo;`?

**Exercise 3: Observe MVCC**

```sql
CREATE TABLE acct (id int PRIMARY KEY, bal int);
INSERT INTO acct VALUES (1, 100);
SELECT ctid, xmin, xmax, * FROM acct;
UPDATE acct SET bal = 200 WHERE id = 1;
SELECT ctid, xmin, xmax, * FROM acct;   -- note the changed ctid and xmin
```

**Exercise 4: psql fluency**

1. Turn on `\timing` and `\x auto`.
2. List all databases, then connect to another one with `\c`.
3. Use `\d+` on a table and identify its columns, indexes and storage.
4. Export a query to CSV using `\copy`.
5. Run `psql -E` and observe the SQL behind `\dt`.

**Exercise 5: Schemas and privileges**

```sql
CREATE SCHEMA shop;
CREATE TABLE shop.products (id serial PRIMARY KEY, name text);
CREATE ROLE intern LOGIN PASSWORD 'temp';

-- As intern (\c postgres intern), this should fail:
SELECT * FROM shop.products;

-- As the owner, grant access:
GRANT USAGE ON SCHEMA shop TO intern;
GRANT SELECT ON shop.products TO intern;
```

Then experiment with `SET search_path TO shop;` and confirm that `SELECT * FROM products;` works without qualification.

---

## 6. Quick Reference Cheat Sheet

**Architecture**

| Concept | One-liner |
|---|---|
| postmaster | Parent process; forks one backend per connection |
| shared_buffers | Shared page cache (start ~25% of RAM) |
| work_mem | Per sort/hash operation, per backend |
| WAL | Log first, write data later; enables recovery and replication |
| MVCC | Multiple row versions; VACUUM cleans dead ones |
| Checkpoint | Flush dirty pages; bounds recovery time |

**Limits**

| Item | Limit |
|---|---|
| Table size | 32 TB |
| Field size | 1 GB |
| Columns per table | 1,600 |
| Identifier length | 63 bytes |
| Columns per index | 32 |

**psql essentials**

```
\l  \c db  \dn  \dt  \d table  \d+ table  \du  \df  \dx
\x  \timing  \e  \i file  \o file  \copy  \set  \watch  \q
```

**Schema essentials**

```sql
CREATE SCHEMA s;
SET search_path TO s, public;
GRANT USAGE ON SCHEMA s TO role;
ALTER TABLE t SET SCHEMA s;
DROP SCHEMA s CASCADE;
```

---

*Further reading: the official PostgreSQL documentation at <https://www.postgresql.org/docs/current/>, especially the chapters on "Server Setup and Operation", "psql", "Data Definition (Schemas)", and "Appendix K: PostgreSQL Limits".*
