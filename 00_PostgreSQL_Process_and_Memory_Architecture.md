# PostgreSQL Process and Memory Architecture

*A beginner-friendly walkthrough of what actually happens inside PostgreSQL when you run a query.*

---

## Table of Contents

**Part I — Orientation**
1. [The Big Picture](#1-the-big-picture)
2. [Two Questions, Two Architectures](#2-two-questions-two-architectures)

**Part II — Process Architecture**

3. [PostgreSQL Is a Process-Based Database](#3-postgresql-is-a-process-based-database)
4. [The Main Server Process and Its Children](#4-the-main-server-process-and-its-children)
5. [Backend vs. Background: The Key Distinction](#5-backend-vs-background-the-key-distinction)

**Part III — Memory Architecture**

6. [Two Categories of Memory](#6-two-categories-of-memory)
7. [Shared Memory and `shared_buffers`](#7-shared-memory-and-shared_buffers)
8. [Pages, Not Rows](#8-pages-not-rows)
9. [Local Memory: `work_mem` and `maintenance_work_mem`](#9-local-memory-work_mem-and-maintenance_work_mem)
10. [Memory Settings at a Glance](#10-memory-settings-at-a-glance)

**Part IV — Following a Query End to End**

11. [How a `SELECT` Travels Through PostgreSQL](#11-how-a-select-travels-through-postgresql)
12. [Query Execution: Parse, Analyze, Plan, Execute](#12-query-execution-parse-analyze-plan-execute)
13. [How an `UPDATE` Travels Through PostgreSQL](#13-how-an-update-travels-through-postgresql)

**Part V — Concurrency and Cleanup**

14. [MVCC: Multi-Version Concurrency Control](#14-mvcc-multi-version-concurrency-control)
15. [VACUUM: Reclaiming Obsolete Row Versions](#15-vacuum-reclaiming-obsolete-row-versions)
16. [Autovacuum: Automating the Cleanup](#16-autovacuum-automating-the-cleanup)

**Part VI — Durability and Persistence**

17. [Dirty Pages](#17-dirty-pages)
18. [WAL: Write-Ahead Logging](#18-wal-write-ahead-logging)
19. [The WAL Writer](#19-the-wal-writer)
20. [The Background Writer](#20-the-background-writer)
21. [Checkpoints](#21-checkpoints)
22. [Crash Recovery: Putting Durability Together](#22-crash-recovery-putting-durability-together)

**Part VII — Consolidation**

23. [The Restaurant Analogy](#23-the-restaurant-analogy)
24. [The Complete Picture](#24-the-complete-picture)
25. [Concept Reference Table](#25-concept-reference-table)
26. [The Five Things to Learn First](#26-the-five-things-to-learn-first)

---

# Part I — Orientation

## 1. The Big Picture

When you open a connection:

```bash
psql -h localhost -U postgres -d trading
```

and then run:

```sql
SELECT * FROM account;
```

a surprising amount happens between your keystroke and the result set.

At the highest level, the request flows downward through four layers:

```
                 Your Application
                       |
                       | SQL
                       ↓
              ┌─────────────────┐
              │    PostgreSQL   │
              │     Server      │
              └────────┬────────┘
                       |
              ┌────────▼────────┐
              │  Client/Server  │
              │    Processes    │
              └────────┬────────┘
                       |
             ┌─────────▼─────────┐
             │    Shared Memory  │
             │                   │
             │  Shared Buffers   │
             │  WAL Buffers      │
             └─────────┬─────────┘
                       |
                       ↓
                 Disk / Storage
```

Notice that disk sits at the *bottom*, not the middle. PostgreSQL works hard to avoid touching it. Most of this document is about the machinery that makes that avoidance safe.

## 2. Two Questions, Two Architectures

The architecture is easiest to learn if you separate two questions and answer them one at a time:

| Question | The answer is called |
|---|---|
| **Who does the work?** | Process architecture |
| **Where is data held while the work happens?** | Memory architecture |

They interlock constantly — processes are the only things that touch memory — but trying to learn both at once is what makes the topic feel overwhelming. We'll do processes first, because memory only makes sense once you know who is reaching into it.

---

# Part II — Process Architecture

## 3. PostgreSQL Is a Process-Based Database

Many databases handle concurrent clients with **threads** inside one large process. PostgreSQL traditionally takes a different approach: a **process-per-connection model**.

Suppose three applications connect:

```
Application 1 ──────→ PostgreSQL
Application 2 ──────→ PostgreSQL
Application 3 ──────→ PostgreSQL
```

PostgreSQL gives each of them its own operating-system process:

```
                 PostgreSQL
                     │
             PostgreSQL Server
                     │
       ┌─────────────┼─────────────┐
       ↓             ↓             ↓
   Backend        Backend       Backend
   Process 1      Process 2     Process 3
       │             │             │
    Client 1       Client 2      Client 3
```

A **backend process** handles one client connection and executes the SQL that arrives on it. When you type:

```sql
SELECT * FROM customers;
```

it is *your* backend process — not some shared worker pool — that parses, plans, and executes that statement.

> **Why this matters in practice:** because each connection costs a full OS process, connections are not free. This is the architectural reason PostgreSQL deployments so often sit behind a connection pooler such as PgBouncer.

## 4. The Main Server Process and Its Children

When PostgreSQL starts, it does not start a single process. It starts a **main server process** — think of it as the manager — which then launches everything else.

```
                 PostgreSQL
                Main Process
                     │
       ┌─────────────┼──────────────┐
       ↓             ↓              ↓
   Backend       Background     Background
   Processes      Processes      Processes
```

The main process doesn't execute your SQL. Its job is to listen for new connections, spawn a backend for each one, and supervise the background workers.

The most important processes to know:

**Backend processes**
Handle client connections and SQL execution.

```
Client
   ↓
Backend Process
   ↓
SQL execution
```

**WAL writer**
Writes write-ahead log information from memory out to disk. (Covered in §19.)

**Checkpointer**
Performs checkpoints — the coordinated flush points that bound crash recovery time. (Covered in §21.)

**Background writer**
Gradually writes modified ("dirty") pages from memory to disk. (Covered in §20.)

**Autovacuum processes**
Perform maintenance: removing obsolete row versions, updating statistics, and controlling table and index bloat. (Covered in §16.)

So the correct mental model is not:

```
PostgreSQL = one process
```

but rather:

```
PostgreSQL
   │
   ├── Main server process
   │
   ├── Backend processes
   │
   ├── WAL writer
   │
   ├── Checkpointer
   │
   ├── Background writer
   │
   └── Autovacuum processes
```

## 5. Backend vs. Background: The Key Distinction

These two words look similar and get confused constantly. The difference is *who they work for*.

**A backend process works for a client.**

```
psql ─────→ Backend
DBeaver ──→ Backend
App ──────→ Backend
```

**A background process works for PostgreSQL itself.**

```
WAL writer
Background writer
Checkpointer
Autovacuum
etc.
```

Two sentences worth committing to memory:

> **One client connection generally gets one PostgreSQL backend process.**
>
> **Background processes are server-level processes — not one per query, and not one per connection.**

Background processes exist once for the whole server (or as a small pool), and they serve every database and every connection at once.

---

# Part III — Memory Architecture

## 6. Two Categories of Memory

PostgreSQL memory splits into two broad categories:

```
PostgreSQL Memory
│
├── Shared Memory
│
└── Per-process / Local Memory
```

The simplest mental model:

> **Shared memory** = memory that many PostgreSQL processes can reach.
>
> **Local memory** = memory a single process allocates for its own work.

That distinction drives almost everything else, including how you size a server. Shared memory is allocated once. Local memory is allocated *per process*, and potentially several times over within a single complex query.

## 7. Shared Memory and `shared_buffers`

Shared memory is a region that every backend and background process can access:

```
                 Shared Memory
        ┌──────────────────────────┐
        │                          │
        │     Shared Buffers       │
        │                          │
        │     WAL Buffers          │
        │                          │
        │     Other shared data    │
        │                          │
        └──────────────────────────┘
             ↑       ↑       ↑
             │       │       │
          Backend Backend Backend
          Process  Process  Process
```

The piece that matters most is **`shared_buffers`**: PostgreSQL's main shared cache for database pages.

### Why a cache is necessary

Your table lives on disk:

```
Disk

customers table
----------------
page 1
page 2
page 3
page 4
...
```

Disk is dramatically slower than RAM. PostgreSQL does not want to repeat this for every query:

```
SQL
 ↓
Disk
 ↓
Read data
 ↓
Return
```

So it keeps frequently used pages resident in memory:

```
                 RAM
        ┌──────────────────┐
        │ shared_buffers   │
        │                  │
        │ customers page 1 │
        │ customers page 2 │
        │ orders page 7    │
        │ account page 3   │
        └────────┬─────────┘
                 │
                 ↓
                Disk
```

When a needed page is already cached, the disk trip disappears entirely:

```
Query
 ↓
Check shared_buffers
 ↓
Found!
 ↓
Use RAM
```

Finding the page in memory is a **buffer hit**. Having to fetch it from disk is a **buffer read**. The ratio between the two is one of the first things to look at when diagnosing slow queries.

## 8. Pages, Not Rows

Here is a concept that trips up newcomers:

> **PostgreSQL does not cache individual rows. It works in fixed-size pages.**

A PostgreSQL page is typically:

```
8 KB
```

A table on disk is simply a sequence of these pages:

```
customers table

Disk:
┌────────┬────────┬────────┬────────┐
│ Page 1 │ Page 2 │ Page 3 │ Page 4 │
│  8 KB  │  8 KB  │  8 KB  │  8 KB  │
└────────┴────────┴────────┴────────┘
```

So the correct mental model is:

```
Database
   ↓
Pages
   ↓
Memory / Disk
```

**not**:

```
Database
   ↓
individual rows
   ↓
RAM
```

This has a real consequence: reading one row means reading the entire 8 KB page that contains it. It's also why `shared_buffers` is measured in pages, and why updating a single row can mark a whole page as modified.

## 9. Local Memory: `work_mem` and `maintenance_work_mem`

Caching pages is only half the story. A query often needs scratch space of its own. Consider:

```sql
SELECT department, AVG(salary)
FROM employees
GROUP BY department;
```

PostgreSQL may need memory for:

- sorting
- hashing
- aggregation
- joins

That memory does **not** come from `shared_buffers`. It comes from the backend process's own local memory, governed most famously by **`work_mem`**.

```
                   Backend Process
                         │
            ┌────────────┴────────────┐
            │                         │
       shared buffers            work_mem
       shared data               query work
                                      │
                                sort / hash /
                                aggregation
```

### `work_mem` in action

```sql
SELECT *
FROM employees
ORDER BY salary;
```

PostgreSQL must sort the rows, and it will try to do that in memory:

```
Backend Process
       │
       └── Sort
            │
            └── work_mem
```

If the operation needs more than the allowed amount, PostgreSQL spills temporary data to disk:

```
Enough memory          Not enough memory
     ↓                        ↓
Sort in memory         Temporary files on disk
                              ↓
                           Slower
```

> **A sizing trap:** `work_mem` is a limit *per operation*, not per query and not per server. A single query with several sorts and hash joins, running across several parallel workers, can allocate many multiples of it — and every concurrent connection can do the same.

### `maintenance_work_mem`

Maintenance work gets its own, usually larger, budget:

```
PostgreSQL
     │
     ├── Normal query
     │      ↓
     │   work_mem
     │
     └── Maintenance
            ↓
     maintenance_work_mem
            │
            ├── VACUUM
            └── CREATE INDEX
```

It applies to operations such as:

```
VACUUM
CREATE INDEX
ALTER TABLE operations
```

For example, building this index can draw on maintenance memory:

```sql
CREATE INDEX idx_account_id
ON account(account_id);
```

The reason for a separate setting is that maintenance operations are few and infrequent, so they can afford to be generous — whereas `work_mem` is multiplied across every concurrent query.

## 10. Memory Settings at a Glance

| Memory | Think of it as | Scope |
|---|---|---|
| `shared_buffers` | Cache of database pages | Shared, allocated once |
| `work_mem` | Memory for query operations (sort, hash, aggregate) | Per operation, per process |
| `maintenance_work_mem` | Memory for maintenance operations | Per maintenance operation |
| WAL buffers | Holding area for WAL records before they're written | Shared, allocated once |

A conclusion worth drawing explicitly:

> Do **not** think "PostgreSQL uses 10 GB because `shared_buffers` is 10 GB."

Total memory use is `shared_buffers` **plus** whatever every active backend has allocated locally. On a busy server, that second term is not small.

---

# Part IV — Following a Query End to End

## 11. How a `SELECT` Travels Through PostgreSQL

Take:

```sql
SELECT *
FROM customers
WHERE customer_id = 10;
```

**Step 1 — The client sends SQL**

```
Application
     |
     | SELECT...
     ↓
Backend Process
```

**Step 2 — PostgreSQL parses the SQL**
It works out what the statement means.

**Step 3 — PostgreSQL builds an execution plan**
For example:

```
Index Scan
```

**Step 4 — PostgreSQL needs data**
Say the plan requires page 25. Before going anywhere near the disk, it checks:

```
shared_buffers
```

**Step 5 — Is the page already cached?**

If yes — a **buffer hit**:

```
shared_buffers
      ↓
   page 25
      ↓
  execute query
```

If no — a **buffer read**:

```
shared_buffers
      ↓
Not found
      ↓
Read page from disk
      ↓
Put page in shared_buffers
      ↓
Use page
```

Note the second-to-last step: the page is left in the cache, so the *next* query asking for it gets a hit.

## 12. Query Execution: Parse, Analyze, Plan, Execute

"Query execution" is simply **how PostgreSQL turns your SQL into actual work**. It's not a single step. Given:

```sql
SELECT *
FROM account
WHERE account_id = 101;
```

PostgreSQL proceeds roughly as:

```
SQL
 ↓
Parse
 ↓
Analyze
 ↓
Plan
 ↓
Execute
```

**Parse** — Is this valid SQL? This stage is purely about syntax.

**Analyze** — Does `account` exist? Does `account_id` exist? What are the data types? This stage resolves names against the system catalogs.

**Plan** — *How* should the data be fetched? The planner weighs alternatives:

```
Should I:

A. Scan the entire table?

OR

B. Use the index on account_id?
```

and picks the cheaper one based on table statistics:

```
Index Scan
```

**Execute** — The backend process now actually retrieves the required pages and rows:

```
Query
 ↓
Execution Plan
 ↓
Read required pages
 ↓
shared_buffers
 ↓
Return result
```

This is also why stale statistics hurt so much: a wrong estimate at the *Plan* stage produces a slow plan that executes perfectly correctly.

## 13. How an `UPDATE` Travels Through PostgreSQL

Reads are the easy case. Writes are where the interesting machinery lives, because a write must survive a crash. Our running example for the rest of this document:

```sql
UPDATE account
SET balance = 5000
WHERE account_id = 101;
```

Here is the whole journey at a glance. Every box in it is explained in the sections that follow.

```
                      CLIENT
                        │
                        │ SQL
                        ↓
                ┌───────────────┐
                │ Backend       │
                │ Process       │
                └───────┬───────┘
                        │
                Query Execution
                        │
            ┌───────────┴───────────┐
            ↓                       ↓
     shared_buffers                WAL
            │                       │
      Database pages           WAL buffers
            │                       │
            ↓                       ↓
        Dirty page              WAL writer
            │                       │
            ↓                       ↓
       Background             WAL files
         Writer                   │
            │                     │
            ↓                     ↓
          Disk  ←──────────── Checkpoint
            │
            ↓
         VACUUM
         Autovacuum
```

Two things to notice before we break it down:

1. The path **splits**. The change goes to the data page *and* to the WAL, and those two travel to disk by completely different routes at completely different times.
2. **MVCC** underpins all of it, allowing multiple transactions to run safely against the same rows.

---

# Part V — Concurrency and Cleanup

## 14. MVCC: Multi-Version Concurrency Control

This is arguably the single most important PostgreSQL concept.

> **MVCC = Multi-Version Concurrency Control.** When you `UPDATE` a row, PostgreSQL does not simply overwrite it. It writes a **new version** of the row and keeps the old one around.

Suppose:

```
Account 101

balance = 4000
```

You execute:

```sql
UPDATE account
SET balance = 5000
WHERE account_id = 101;
```

Conceptually:

```
Old version
balance = 4000

        ↓ UPDATE

New version
balance = 5000
```

The old version is not removed immediately — because another transaction may still legitimately need to see it.

### Why this is worth the trouble

Imagine two concurrent transactions.

**Transaction A:**

```sql
BEGIN;

SELECT balance
FROM account
WHERE account_id = 101;
```

It sees:

```
4000
```

Meanwhile **Transaction B**:

```sql
BEGIN;

UPDATE account
SET balance = 5000
WHERE account_id = 101;

COMMIT;
```

What should Transaction A see if it reads again? PostgreSQL's MVCC visibility rules decide which version each transaction is allowed to see, based on when that transaction started and its isolation level.

```
Transaction A
       ↓
can see appropriate row version

Transaction B
       ↓
creates another row version
```

The payoff is large:

> **Readers don't block writers, and writers don't block readers.**

Without MVCC, Transaction A's read would have to either block Transaction B's write or be blocked by it.

## 15. VACUUM: Reclaiming Obsolete Row Versions

MVCC buys concurrency, but it creates a problem. Once the old version:

```
balance = 4000
```

is no longer visible to **any active transaction**, it is pure dead weight. And updates accumulate:

```
UPDATE
UPDATE
UPDATE
UPDATE
UPDATE
...
```

Left alone, a heavily updated table would grow without bound while holding almost no live data. This condition is called **bloat**.

The answer is **VACUUM**:

> **VACUUM identifies and cleans up row versions that are no longer needed by any transaction.**

```
Account table

Old version → balance 4000  ← no longer needed
Old version → balance 4500  ← no longer needed
Current    → balance 5000
```

```
Before VACUUM:

4000 ❌
4500 ❌
5000 ✅


After cleanup:

5000 ✅
```

### One nuance that catches almost everyone

> **VACUUM normally makes space available for PostgreSQL to reuse. It does not generally shrink the physical table file on disk.**

So after a routine `VACUUM`, the table's size on disk usually stays the same — the freed space is simply available for future rows. Actually returning space to the operating system requires the far more disruptive `VACUUM FULL`, which rewrites the table and takes an exclusive lock.

## 16. Autovacuum: Automating the Cleanup

With millions of rows and constant writes, nobody wants a DBA typing:

```sql
VACUUM account;
```

every few minutes. So PostgreSQL ships with **autovacuum**: background processes that monitor tables and trigger maintenance when a table has accumulated enough changes to be worth cleaning.

```
Database
   │
   ├── account
   ├── customer
   ├── orders
   └── trades
          ↑
          │
    Autovacuum monitors
          │
          ↓
     VACUUM when needed
```

The chain of reasoning is worth holding as a single thought:

```
MVCC
 ↓
old row versions
 ↓
VACUUM
 ↓
Autovacuum automates VACUUM
```

Autovacuum is not optional housekeeping you can safely disable. It is the counterweight that makes MVCC sustainable.

---

# Part VI — Durability and Persistence

## 17. Dirty Pages

Return to the `UPDATE`. PostgreSQL located the relevant page and pulled it into memory:

```
Disk
   ↓
account page
   ↓
shared_buffers
```

then modified it **in memory**. Now:

```
Disk:

balance = 4000


RAM:

balance = 5000
```

A page whose in-memory copy is newer than its on-disk copy is called a **dirty page**:

```
RAM                         Disk

5000                        4000
 ↑                           ↑
dirty page                   old page
```

```
Memory version ≠ Disk version
```

This is normal and desirable — writing to disk on every single row change would destroy performance. But it raises an obvious question: what if the server crashes right now?

## 18. WAL: Write-Ahead Logging

The answer is **WAL — the Write-Ahead Log**, and its rule is simple:

> **The change is recorded in the WAL before the corresponding data page is written to disk.**

So the `UPDATE` fans out in two directions:

```
UPDATE
  │
  ├──────────────→ WAL record
  │
  ↓
Modify page in shared_buffers
```

The WAL record describes the change in enough detail to reproduce it:

```
WAL says:

"Account 101 changed
balance from 4000 to 5000"
```

### Why this is such a good trade

WAL writes are **sequential appends to a single file**. Data page writes are **scattered across the disk**. Sequential writing is far cheaper. By making the cheap, sequential write the one that must happen before commit, PostgreSQL gets durability without paying for random I/O on every transaction.

The expensive scattered writes still happen — just later, in bulk, by background processes. If the server crashes in the meantime, the WAL replays what was lost.

## 19. The WAL Writer

WAL records don't go straight to disk either. They land first in **WAL buffers**, a region of shared memory:

```
UPDATE
   ↓
WAL record
   ↓
WAL buffers
   ↓
WAL writer
   ↓
WAL files on disk
```

The **WAL writer** is the background process that moves WAL data from those buffers out to the WAL files.

Keep these two straight:

```
WAL
  = the logging mechanism (the records and the files)

WAL writer
  = the background process that writes those records out
```

They are named almost identically and are conceptually quite different — one is data, the other is a worker.

## 20. The Background Writer

Dirty pages also need to reach disk eventually. That's the **background writer**:

```
shared_buffers
      │
      │ dirty pages
      ↓
Background Writer
      │
      ↓
    Disk
```

Its purpose is to prevent dirty pages from piling up indefinitely, so it writes some of them out steadily over time.

> Think of it as **someone continuously tidying the workspace, instead of waiting until everything is a huge mess.**

The practical benefit: when a backend needs a free buffer, it's more likely to find a clean one it can reuse immediately, rather than having to stop and write a page out itself.

## 21. Checkpoints

A **checkpoint** is a larger, less frequent event, performed by the checkpointer process.

> **A checkpoint establishes a point from which PostgreSQL knows recovery can proceed, having flushed the required dirty data pages to disk.**

Think of it as writing down a **known-good recovery point**.

Imagine the WAL has accumulated:

```
WAL
│
├── UPDATE A
├── UPDATE B
├── UPDATE C
├── UPDATE D
├── UPDATE E
└── UPDATE F
```

At some point a checkpoint occurs:

```
WAL
│
├── A
├── B
├── C
├── D
├── E
├── F
│
└── CHECKPOINT
```

The checkpoint lets PostgreSQL conclude:

> "From this point forward, recovery doesn't need to replay an unlimited amount of history."

Without checkpoints, crash recovery would mean replaying WAL back to the beginning of time. With them, recovery starts at the last checkpoint. This is a direct trade-off: **frequent checkpoints mean fast recovery but more I/O spikes; infrequent checkpoints mean smoother I/O but longer recovery.**

### Background writer vs. checkpointer

Both write dirty pages to disk, which makes them easy to confuse:

| | Background writer | Checkpointer |
|---|---|---|
| **Rhythm** | Continuous trickle | Periodic, larger event |
| **Goal** | Keep clean buffers available | Bound crash recovery time |
| **Scope** | Some dirty pages | All dirty pages as of the checkpoint |

## 22. Crash Recovery: Putting Durability Together

Now the payoff. Suppose at some instant:

```
Memory:

account balance = 5000

Disk:

account balance = 4000

WAL:

"account 101 changed to 5000"
```

Then:

💥 **PostgreSQL crashes.**

Memory is gone. The disk still holds the stale value of 4000. But the WAL record survived — because it was written *first*.

On restart, PostgreSQL replays the WAL from the last checkpoint:

```
Disk
4000
  ↓
Read WAL
  ↓
Apply required changes
  ↓
5000
```

The committed change is recovered. This is why WAL is the foundation of PostgreSQL's durability — and it's the same mechanism that powers streaming replication and point-in-time recovery, since a replica is essentially a server continuously replaying WAL from a primary.

---

# Part VII — Consolidation

## 23. The Restaurant Analogy

If the components still feel abstract, map them onto a restaurant.

| PostgreSQL | Restaurant equivalent |
|---|---|
| **PostgreSQL server** | The restaurant itself |
| **Backend process** | A waiter serving one customer's order |
| **`shared_buffers`** | The working shelves and fridge — frequently needed ingredients kept close at hand |
| **Disk** | The warehouse: large, but slow to reach |
| **`work_mem`** | The counter space for preparing one order |
| **WAL** | The order log: *"Customer X ordered 2 pizzas and 1 drink"* — written down reliably before anything else is finalized |
| **Background processes** | Staff doing housekeeping: cleaning, restocking, recording transactions, checking, maintenance |

The order flows:

```
Customer
   ↓
Waiter
   ↓
Kitchen
```

The analogy also explains the pieces people find least intuitive. Why write the order down before making the food? Because if the kitchen catches fire, you still know what was ordered — that's WAL. Why does each waiter get their own counter space rather than sharing one? Because they'd collide constantly — that's `work_mem` being per-process. And why keep ingredients on the shelf instead of fetching from the warehouse each time? That's `shared_buffers`.

## 24. The Complete Picture

### Static architecture

```
                           APPLICATION
                                │
                                │ SQL
                                ↓
                       ┌─────────────────┐
                       │ Backend Process │
                       └────────┬────────┘
                                │
                   ┌────────────┴────────────┐
                   │                         │
                   ↓                         ↓
            Shared Memory              Local/Process
                   │                       Memory
                   │                         │
          ┌────────┴────────┐          ┌─────┴─────┐
          │                 │          │           │
   shared_buffers       WAL buffers  work_mem   other
          │
          ↓
     Database Pages
          │
          ↓
         DISK
          │
          ├── Tables
          ├── Indexes
          └── WAL files
```

And running alongside, serving the server itself:

```
          PostgreSQL
              │
       ┌──────┼────────┬──────────┐
       ↓      ↓        ↓          ↓
     WAL    Check-   Background  Auto-
   writer   pointer   writer      vacuum
```

### The life of an `UPDATE`

```
                       UPDATE
                          │
                          ↓
                  Query Execution
                          │
                          ↓
                  Backend Process
                          │
                          ↓
                  Find account page
                          │
                          ↓
                   shared_buffers
                          │
                          ↓
               MVCC creates new version
                          │
                ┌─────────┴─────────┐
                ↓                   ↓
          Dirty data page          WAL
                │                   │
                │             WAL buffers
                │                   │
                │              WAL writer
                │                   │
                │                   ↓
                │               WAL on disk
                │
                ↓
         Background Writer
                │
                ↓
            Data on disk
```

Meanwhile, in parallel:

```
MVCC
 ↓
old row versions accumulate
 ↓
Autovacuum
 ↓
VACUUM
 ↓
cleanup obsolete versions
```

And periodically:

```
Checkpoint
    ↓
helps establish a consistent recovery point
    ↓
makes crash recovery more manageable
```

## 25. Concept Reference Table

| Concept | Very simple meaning |
|---|---|
| **Backend process** | The process that runs *your* connection's SQL |
| **Background process** | A process that works for the server, not for a client |
| **Query execution** | How PostgreSQL parses, plans, and performs your SQL |
| **Page** | The 8 KB unit PostgreSQL reads, caches, and writes |
| **`shared_buffers`** | Shared cache of database pages |
| **`work_mem`** | Per-operation memory for sorts, hashes, and aggregates |
| **`maintenance_work_mem`** | Memory available for maintenance operations |
| **MVCC** | Keeps multiple row versions so transactions can run concurrently |
| **Dirty page** | A page changed in memory but not yet written to disk |
| **WAL** | Records changes *before* data pages, for durability and recovery |
| **WAL buffers** | Shared memory holding WAL records before they're written |
| **WAL writer** | Background process that writes WAL out to WAL files |
| **Background writer** | Gradually writes dirty pages to disk |
| **Checkpoint** | Establishes a recovery point and flushes dirty pages |
| **VACUUM** | Cleans up obsolete MVCC row versions |
| **Autovacuum** | Runs VACUUM and ANALYZE automatically when needed |

### The single most important relationship

```
                      UPDATE
                        ↓
                      MVCC
                        ↓
                New row version
                        ↓
                shared_buffers
                        ↓
                    Dirty page
                        ↓
              ┌─────────┴─────────┐
              ↓                   ↓
        Background writer        WAL
              ↓                   ↓
            Disk              WAL writer
                                  ↓
                                Disk


  Old MVCC versions
          ↓
     Autovacuum
          ↓
       VACUUM
```

And **checkpoint sits across the whole storage and recovery process**, helping PostgreSQL establish consistent recovery points.

## 26. The Five Things to Learn First

Don't try to memorize twenty configuration parameters. Make sure these five ideas are genuinely clear first — everything else in PostgreSQL architecture hangs off them.

```
1. PostgreSQL uses processes

             ↓

2. Backend process handles client SQL

             ↓

3. shared_buffers caches database pages

             ↓

4. work_mem supports query operations

             ↓

5. WAL provides durability/recovery
```

Once these are solid, MVCC, VACUUM, checkpoints, and the background writers all become answers to questions you can already ask yourself.
