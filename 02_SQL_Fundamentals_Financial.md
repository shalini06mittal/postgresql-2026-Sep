**SQL for Financial Analytics**

**Lab 1 — SQL Fundamentals: SELECT → WHERE → ORDER BY → Functions → CASE → Aggregates**

*Financial Track · Onboarding Lab for New Graduates · Prerequisite to the Advanced Lab (Joins → Group By → Subqueries → Window Functions)*

Dataset: 4 tables — customers, accounts, categories, transactions

## Table of Contents

- [1. Introduction](#1-introduction)
  - [1.1 Learning Objectives](#11-learning-objectives)
  - [1.2 How This Lab Is Organized](#12-how-this-lab-is-organized)
  - [1.3 A Note on SQL Dialects](#13-a-note-on-sql-dialects)
- [2. Database Schema](#2-database-schema)
  - [2.1 customers](#21-customers)
  - [2.2 accounts](#22-accounts)
  - [2.3 categories](#23-categories)
  - [2.4 transactions](#24-transactions)
- [3. Setup Script — Create the Database and Schema](#3-setup-script--create-the-database-and-schema)
  - [3.1 Create a Database](#31-create-a-database)
  - [3.2 See All Databases](#32-see-all-databases)
  - [3.3 Switch to Your Database](#33-switch-to-your-database)
  - [3.4 Create the Tables](#34-create-the-tables)
  - [3.5 See All Tables and Columns](#35-see-all-tables-and-columns)
  - [3.6 Removing Things (Use with Care)](#36-removing-things-use-with-care)
- [4. Sample Data — Insert Statements](#4-sample-data--insert-statements)
  - [4.1 customers (10 rows)](#41-customers-10-rows)
  - [4.2 accounts (13 rows)](#42-accounts-13-rows)
  - [4.3 categories (8 rows)](#43-categories-8-rows)
  - [4.4 transactions (82 rows)](#44-transactions-82-rows)
- [5. How a SQL Query Is Read](#5-how-a-sql-query-is-read)
- [6. Part A — SELECT and FROM](#6-part-a--select-and-from)
- [7. Part B — Filtering Rows with WHERE](#7-part-b--filtering-rows-with-where)
- [8. Part C — Sorting, De-duplicating, and Limiting](#8-part-c--sorting-de-duplicating-and-limiting)
- [9. Part D — Calculated Columns and Built-in Functions](#9-part-d--calculated-columns-and-built-in-functions)
- [10. Part E — Conditional Logic with CASE](#10-part-e--conditional-logic-with-case)
- [11. Part F — Summarizing with Aggregate Functions](#11-part-f--summarizing-with-aggregate-functions)
- [12. Part G — NULLs and Changing Data (INSERT, UPDATE, DELETE)](#12-part-g--nulls-and-changing-data-insert-update-delete)
  - [12.1 Quick Reference: INSERT, UPDATE, DELETE](#121-quick-reference-insert-update-delete)
  - [12.2 Practice Questions](#122-practice-questions)
- [13. Part H — Review Challenges](#13-part-h--review-challenges)
- [14. What's Next: Where Single-Table SQL Runs Out](#14-whats-next-where-single-table-sql-runs-out)
- [15. Solutions](#15-solutions)
  - [15.1 Part A Solutions — SELECT and FROM](#151-part-a-solutions--select-and-from)
  - [15.2 Part B Solutions — Filtering with WHERE](#152-part-b-solutions--filtering-with-where)
  - [15.3 Part C Solutions — Sorting, DISTINCT, and LIMIT](#153-part-c-solutions--sorting-distinct-and-limit)
  - [15.4 Part D Solutions — Calculated Columns and Functions](#154-part-d-solutions--calculated-columns-and-functions)
  - [15.5 Part E Solutions — CASE](#155-part-e-solutions--case)
  - [15.6 Part F Solutions — Aggregate Functions](#156-part-f-solutions--aggregate-functions)
  - [15.7 Part G Solutions — NULLs, INSERT, UPDATE, DELETE](#157-part-g-solutions--nulls-insert-update-delete)
  - [15.8 Part H Solutions — Review Challenges](#158-part-h-solutions--review-challenges)

# 1. Introduction

Welcome to Lab 1. Every advanced technique in financial SQL — joins, grouping, subqueries, window functions — is built out of a small set of fundamentals: choosing columns, filtering rows, sorting, calculating new values, applying conditional logic, and summarizing. This lab teaches those fundamentals on the same four-table banking dataset used in the Advanced Lab, so that when you get there the schema, the data, and the vocabulary are already familiar and you can concentrate on the new ideas.

**Everything in this lab works on one table at a time.** The moment a question needs two tables at once, you have reached the boundary of this lab and the start of the Advanced Lab — Section 14 shows exactly where that boundary is.

## 1.1 Learning Objectives

By the end of this lab you will be able to:

- Retrieve data with `SELECT ... FROM`, choose specific columns, and rename them with aliases.
- Filter rows with `WHERE` using comparison operators, `AND` / `OR` / `NOT`, `IN`, `BETWEEN`, and `LIKE`.
- Sort results with `ORDER BY`, remove duplicates with `DISTINCT`, and return the top N rows with `LIMIT`.
- Create calculated columns using arithmetic, text functions, date functions, and `ROUND`.
- Apply conditional logic with `CASE` expressions.
- Summarize a whole table with `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`, and conditional aggregation.
- Create a database, list the databases and tables on a server, and inspect a table's columns.
- Understand `NULL`, test for it with `IS NULL`, and replace it with `COALESCE`.
- Change data safely with `INSERT`, `UPDATE`, and `DELETE` on a practice table.
- Recognize the questions that a single table cannot answer — and which advanced technique solves each one.

## 1.2 How This Lab Is Organized

Sections 6–12 (Parts A–G) each open with a short explanation of the concept, followed by numbered questions ordered from easiest to hardest. Part H (Section 13) mixes everything together as a review. Try to write each query yourself before checking Section 15, which contains a full solution, an explanation, and the **expected output** for every question so you can check your own results.

Questions are numbered Q1–Q51 continuously through the lab. Tips:

- Create the database and run the setup script (Section 3), then the inserts (Section 4), **once** before starting.
- Write queries in small steps: start with `SELECT * FROM table`, then add one clause at a time and re-run.
- If your result doesn't match, compare row counts first, then column names, then values.

## 1.3 A Note on SQL Dialects

The SQL here is standard ANSI SQL and runs on PostgreSQL, MySQL 8+, and SQL Server with only small differences, which are called out where they occur. The main ones:

| Task | PostgreSQL / MySQL | SQL Server |
| --- | --- | --- |
| Limit rows | `LIMIT 5` | `SELECT TOP 5 ...` or `FETCH FIRST 5 ROWS ONLY` |
| Year of a date | `EXTRACT(YEAR FROM d)` | `YEAR(d)` |
| String length | `LENGTH(s)` | `LEN(s)` |
| Join text | `CONCAT(a, b)` (also `a \|\| b` in PostgreSQL) | `CONCAT(a, b)` or `a + b` |

# 2. Database Schema

The dataset models a small retail bank. A customer can hold multiple accounts; each account has many transactions; each transaction belongs to a category (Salary, Groceries, Rent, etc.). It is exactly the same schema and data as the Advanced Lab.

Relationships:

- customers (1) → (many) accounts — one customer can have several accounts (checking, savings, credit card).
- accounts (1) → (many) transactions — one account has many transactions over time.
- categories (1) → (many) transactions — one category (e.g. “Groceries”) applies to many transactions.

In this lab you will mostly ignore these relationships and query each table on its own; in the Advanced Lab you will connect them with joins.

### 2.1 customers

| Column      | Type         | Description                         |
| ----------- | ------------ | ----------------------------------- |
| customer_id | INT, PK      | Unique identifier for the customer. |
| first_name  | VARCHAR(50)  | Customer's first name.              |
| last_name   | VARCHAR(50)  | Customer's last name.               |
| email       | VARCHAR(100) | Customer's email address.           |
| city        | VARCHAR(50)  | City of residence.                  |
| signup_date | DATE         | Date the customer joined the bank.  |

### 2.2 accounts

| Column       | Type                | Description                                                                |
| ------------ | ------------------- | -------------------------------------------------------------------------- |
| account_id   | INT, PK             | Unique identifier for the account.                                         |
| customer_id  | INT, FK → customers | Owner of the account.                                                      |
| account_type | VARCHAR(20)         | 'Checking', 'Savings', or 'Credit Card'.                                   |
| open_date    | DATE                | Date the account was opened.                                               |
| status       | VARCHAR(10)         | 'Active' or 'Inactive'.                                                    |
| balance      | DECIMAL(10,2)       | Current account balance snapshot (negative for credit card balances owed). |

### 2.3 categories

| Column         | Type        | Description                         |
| -------------- | ----------- | ----------------------------------- |
| category_id    | INT, PK     | Unique identifier for the category. |
| category_name  | VARCHAR(30) | e.g. 'Groceries', 'Salary', 'Rent'. |
| category_group | VARCHAR(10) | 'Income' or 'Expense'.              |

### 2.4 transactions

| Column         | Type                 | Description                                                     |
| -------------- | -------------------- | --------------------------------------------------------------- |
| transaction_id | INT, PK              | Unique identifier for the transaction.                          |
| account_id     | INT, FK → accounts   | Account the transaction posted to.                              |
| txn_date       | DATE                 | Date the transaction posted.                                    |
| amount         | DECIMAL(10,2)        | Positive for money in (Credit), negative for money out (Debit). |
| txn_type       | VARCHAR(10)          | 'Credit' or 'Debit'.                                            |
| category_id    | INT, FK → categories | Category the transaction belongs to.                            |
| description    | VARCHAR(100)         | Free-text note on the transaction.                              |

> **Two facts to remember:** (1) `amount` is **signed** — credits are positive, debits are negative. (2) `transactions` stores only a `category_id` number, not the category name.

# 3. Setup Script — Create the Database and Schema

Before you can create tables you need a **database** to hold them. A database server (PostgreSQL, MySQL, SQL Server) can host many databases side by side, and each database contains tables. The commands differ slightly by product, so each step below shows all three. Pick the one your team uses and follow that column.

## 3.1 Create a Database

```sql
CREATE DATABASE financial_lab;
```
This one statement is the same in PostgreSQL, MySQL, and SQL Server. (In MySQL, `CREATE SCHEMA financial_lab;` is a synonym.) Database names should be lowercase with underscores and no spaces. If it already exists you will get an error; MySQL also accepts `CREATE DATABASE IF NOT EXISTS financial_lab;`.

## 3.2 See All Databases

| Product | Command |
| --- | --- |
| PostgreSQL (psql) | `\l` — or in any SQL client: `SELECT datname FROM pg_database;` |
| MySQL | `SHOW DATABASES;` |
| SQL Server | `SELECT name FROM sys.databases;` — or `EXEC sp_databases;` |

You will also see system databases you did not create (for example `postgres`, `template0`, `mysql`, `information_schema`, `master`, `tempdb`). Leave those alone.

## 3.3 Switch to Your Database

New tables are created in whichever database is currently selected, so switch *before* running the setup script.

| Product | Command |
| --- | --- |
| PostgreSQL (psql) | `\c financial_lab` — PostgreSQL has no `USE`; you reconnect to the database instead. In a GUI such as pgAdmin, select the database in the tree and open a query window on it. |
| MySQL | `USE financial_lab;` |
| SQL Server | `USE financial_lab;` — in SSMS you can also pick it from the database dropdown. |

**Check where you are:** PostgreSQL `SELECT current_database();` · MySQL `SELECT DATABASE();` · SQL Server `SELECT DB_NAME();`

## 3.4 Create the Tables

Run this once, in the `financial_lab` database, to create the four tables. Foreign keys enforce the relationships described above.

```sql
CREATE TABLE customers (
    customer_id   INT PRIMARY KEY,
    first_name    VARCHAR(50) NOT NULL,
    last_name     VARCHAR(50) NOT NULL,
    email         VARCHAR(100),
    city          VARCHAR(50),
    signup_date   DATE
);

CREATE TABLE accounts (
    account_id    INT PRIMARY KEY,
    customer_id   INT NOT NULL REFERENCES customers(customer_id),
    account_type  VARCHAR(20) NOT NULL CHECK (account_type IN ('Checking','Savings', 'Credit Card')),
    open_date     DATE,
    status        VARCHAR(10) NOT NULL CHECK (status IN ('Active', 'Inactive')) DEFAULT 'Active',
    balance       DECIMAL(10,2) NOT NULL DEFAULT 0
); 

CREATE TABLE categories (
    category_id     INT PRIMARY KEY,
    category_name   VARCHAR(30) NOT NULL UNIQUE,
    category_group  VARCHAR(10) NOT NULL
);

CREATE TABLE transactions (
    transaction_id  INT PRIMARY KEY,
    account_id      INT NOT NULL REFERENCES accounts(account_id),
    txn_date        DATE NOT NULL,
    amount          DECIMAL(10,2) NOT NULL,
    txn_type        VARCHAR(10) NOT NULL,
    category_id     INT NOT NULL REFERENCES categories(category_id),
    description     VARCHAR(100)
);
```

> **Order matters.** `accounts` refers to `customers`, and `transactions` refers to `accounts` and `categories`, so a table must be created *after* the tables it references. The script above already does this. (Dropping goes in the opposite order — see 3.6.)

## 3.5 See All Tables and Columns

After the script runs, confirm that the four tables exist and inspect their structure.

| Task | PostgreSQL (psql) | MySQL | SQL Server |
| --- | --- | --- | --- |
| List tables | `\dt` | `SHOW TABLES;` | `SELECT name FROM sys.tables;` |
| Show a table's columns | `\d customers` | `DESCRIBE customers;` | `EXEC sp_help 'customers';` |

The **portable** way works on all three products because `INFORMATION_SCHEMA` is part of the SQL standard. Only the schema filter changes: `'public'` in PostgreSQL, your database name (`'financial_lab'`) in MySQL, and `'dbo'` in SQL Server.

```sql
-- List the tables
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'          -- MySQL: 'financial_lab'   SQL Server: 'dbo'
ORDER BY table_name;

-- List the columns of one table
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'customers'
ORDER BY ordinal_position;
```

Expected result of the first query:

| table_name |
| --- |
| accounts |
| categories |
| customers |
| transactions |

Expected result of the second query (data-type names vary slightly between products, e.g. `character varying` vs `varchar`):

| column_name | data_type | is_nullable |
| --- | --- | --- |
| customer_id | INTEGER | NO |
| first_name | VARCHAR | NO |
| last_name | VARCHAR | NO |
| email | VARCHAR | YES |
| city | VARCHAR | YES |
| signup_date | DATE | YES |

## 3.6 Removing Things (Use with Care)

Deleting structures is permanent, so double-check which database you are in first.

```sql
-- Remove the tables (children first, then parents, because of the foreign keys)
DROP TABLE transactions;
DROP TABLE accounts;
DROP TABLE categories;
DROP TABLE customers;

-- Remove the whole database (run this from a different database, not from inside it)
DROP DATABASE financial_lab;
```
In PostgreSQL and MySQL you can add `IF EXISTS` (for example `DROP TABLE IF EXISTS transactions;`) so the statement does nothing instead of failing when the object is missing. You do not need any of this to complete the lab — it is here for when you want to start over: drop everything, then re-run 3.4 and Section 4.

# 4. Sample Data — Insert Statements

Load the tables in this order (customers → accounts → categories → transactions) so foreign keys resolve correctly.

## 4.1 customers (10 rows)

```sql
INSERT INTO customers (customer_id, first_name, last_name, email, city, signup_date) VALUES (1, 'Alice', 'Johnson', 'alice.johnson@email.com', 'New York', '2022-01-15');
INSERT INTO customers (customer_id, first_name, last_name, email, city, signup_date) VALUES (2, 'Brian', 'Smith', 'brian.smith@email.com', 'Chicago', '2021-11-02');
INSERT INTO customers (customer_id, first_name, last_name, email, city, signup_date) VALUES (3, 'Carla', 'Diaz', 'carla.diaz@email.com', 'Austin', '2023-03-22');
INSERT INTO customers (customer_id, first_name, last_name, email, city, signup_date) VALUES (4, 'David', 'Chen', 'david.chen@email.com', 'Seattle', '2020-07-09');
INSERT INTO customers (customer_id, first_name, last_name, email, city, signup_date) VALUES (5, 'Emma', 'Wilson', 'emma.wilson@email.com', 'Boston', '2022-09-30');
INSERT INTO customers (customer_id, first_name, last_name, email, city, signup_date) VALUES (6, 'Farhan', 'Ali', 'farhan.ali@email.com', 'Houston', '2023-01-05');
INSERT INTO customers (customer_id, first_name, last_name, email, city, signup_date) VALUES (7, 'Grace', 'Kim', 'grace.kim@email.com', 'Denver', '2021-05-18');
INSERT INTO customers (customer_id, first_name, last_name, email, city, signup_date) VALUES (8, 'Henry', 'Lopez', 'henry.lopez@email.com', 'Miami', '2022-12-11');
INSERT INTO customers (customer_id, first_name, last_name, email, city, signup_date) VALUES (9, 'Isla', 'Brown', 'isla.brown@email.com', 'Portland', '2023-06-25');
INSERT INTO customers (customer_id, first_name, last_name, email, city, signup_date) VALUES (10, 'Jack', 'Turner', 'jack.turner@email.com', 'Atlanta', '2020-02-14');
```

## 4.2 accounts (13 rows)

Note: customer_id 10 (Jack Turner) has no account on purpose, and accounts 102, 105, 106, 110, 112, and 113 have no transactions — gaps you will meet again in the Advanced Lab.

```sql
INSERT INTO accounts (account_id, customer_id, account_type, open_date, status, balance) VALUES (101, 1, 'Checking', '2022-01-20', 'Active', 3500);
INSERT INTO accounts (account_id, customer_id, account_type, open_date, status, balance) VALUES (102, 1, 'Savings', '2022-02-01', 'Active', 12000);
INSERT INTO accounts (account_id, customer_id, account_type, open_date, status, balance) VALUES (103, 2, 'Checking', '2021-11-10', 'Active', 1800);
INSERT INTO accounts (account_id, customer_id, account_type, open_date, status, balance) VALUES (104, 3, 'Checking', '2023-03-25', 'Active', 500);
INSERT INTO accounts (account_id, customer_id, account_type, open_date, status, balance) VALUES (105, 3, 'Credit Card', '2023-04-01', 'Active', -750);
INSERT INTO accounts (account_id, customer_id, account_type, open_date, status, balance) VALUES (106, 4, 'Savings', '2020-07-15', 'Active', 25000);
INSERT INTO accounts (account_id, customer_id, account_type, open_date, status, balance) VALUES (107, 4, 'Checking', '2020-07-15', 'Active', 4200);
INSERT INTO accounts (account_id, customer_id, account_type, open_date, status, balance) VALUES (108, 5, 'Checking', '2022-10-01', 'Active', 2100);
INSERT INTO accounts (account_id, customer_id, account_type, open_date, status, balance) VALUES (109, 6, 'Credit Card', '2023-01-10', 'Active', -300);
INSERT INTO accounts (account_id, customer_id, account_type, open_date, status, balance) VALUES (110, 7, 'Savings', '2021-05-20', 'Active', 8000);
INSERT INTO accounts (account_id, customer_id, account_type, open_date, status, balance) VALUES (111, 7, 'Checking', '2021-05-20', 'Active', 1500);
INSERT INTO accounts (account_id, customer_id, account_type, open_date, status, balance) VALUES (112, 8, 'Checking', '2022-12-15', 'Inactive', 0);
INSERT INTO accounts (account_id, customer_id, account_type, open_date, status, balance) VALUES (113, 9, 'Credit Card', '2023-07-01', 'Active', -1200);
```

## 4.3 categories (8 rows)

```sql
INSERT INTO categories (category_id, category_name, category_group) VALUES (1, 'Salary', 'Income');
INSERT INTO categories (category_id, category_name, category_group) VALUES (2, 'Groceries', 'Expense');
INSERT INTO categories (category_id, category_name, category_group) VALUES (3, 'Entertainment', 'Expense');
INSERT INTO categories (category_id, category_name, category_group) VALUES (4, 'Utilities', 'Expense');
INSERT INTO categories (category_id, category_name, category_group) VALUES (5, 'Dining Out', 'Expense');
INSERT INTO categories (category_id, category_name, category_group) VALUES (6, 'Rent', 'Expense');
INSERT INTO categories (category_id, category_name, category_group) VALUES (7, 'Investment Income', 'Income');
INSERT INTO categories (category_id, category_name, category_group) VALUES (8, 'Shopping', 'Expense');
```

## 4.4 transactions (82 rows)

Transactions cover January–March 2025 and belong to seven accounts (101, 103, 104, 107, 108, 109, 111).

```sql
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (1, 101, '2025-01-01', 4500, 'Credit', 1, 'Monthly salary deposit');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (2, 101, '2025-01-02', -1500, 'Debit', 6, 'Rent payment');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (3, 101, '2025-01-05', -300, 'Debit', 2, 'Grocery shopping');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (4, 101, '2025-01-10', -120, 'Debit', 5, 'Dinner out');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (5, 101, '2025-01-15', -60, 'Debit', 3, 'Movie night');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (6, 101, '2025-01-20', -180, 'Debit', 4, 'Electricity & water bill');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (7, 101, '2025-02-01', 4500, 'Credit', 1, 'Monthly salary deposit');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (8, 101, '2025-02-02', -1500, 'Debit', 6, 'Rent payment');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (9, 101, '2025-02-05', -320, 'Debit', 2, 'Grocery shopping');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (10, 101, '2025-02-10', -95, 'Debit', 5, 'Dinner out');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (11, 101, '2025-02-15', -80, 'Debit', 3, 'Movie night');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (12, 101, '2025-02-20', -175, 'Debit', 4, 'Electricity & water bill');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (13, 101, '2025-03-01', 4500, 'Credit', 1, 'Monthly salary deposit');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (14, 101, '2025-03-02', -1500, 'Debit', 6, 'Rent payment');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (15, 101, '2025-03-05', -280, 'Debit', 2, 'Grocery shopping');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (16, 101, '2025-03-10', -140, 'Debit', 5, 'Dinner out');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (17, 101, '2025-03-15', -50, 'Debit', 3, 'Movie night');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (18, 101, '2025-03-20', -190, 'Debit', 4, 'Electricity & water bill');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (19, 103, '2025-01-01', 3800, 'Credit', 1, 'Monthly salary deposit');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (20, 103, '2025-01-06', -250, 'Debit', 2, 'Grocery shopping');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (21, 103, '2025-01-11', -90, 'Debit', 5, 'Restaurant');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (22, 103, '2025-01-18', -150, 'Debit', 4, 'Utility bill');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (23, 103, '2025-02-01', 3800, 'Credit', 1, 'Monthly salary deposit');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (24, 103, '2025-02-06', -260, 'Debit', 2, 'Grocery shopping');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (25, 103, '2025-02-11', -100, 'Debit', 5, 'Restaurant');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (26, 103, '2025-02-18', -155, 'Debit', 4, 'Utility bill');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (27, 103, '2025-02-22', -200, 'Debit', 8, 'Online shopping');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (28, 103, '2025-03-01', 3800, 'Credit', 1, 'Monthly salary deposit');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (29, 103, '2025-03-06', -240, 'Debit', 2, 'Grocery shopping');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (30, 103, '2025-03-11', -85, 'Debit', 5, 'Restaurant');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (31, 103, '2025-03-18', -148, 'Debit', 4, 'Utility bill');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (32, 104, '2025-01-01', 3000, 'Credit', 1, 'Monthly salary deposit');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (33, 104, '2025-01-07', -220, 'Debit', 2, 'Grocery shopping');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (34, 104, '2025-01-14', -100, 'Debit', 3, 'Concert ticket');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (35, 104, '2025-02-01', 3000, 'Credit', 1, 'Monthly salary deposit');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (36, 104, '2025-02-07', -230, 'Debit', 2, 'Grocery shopping');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (37, 104, '2025-02-14', -90, 'Debit', 3, 'Concert ticket');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (38, 107, '2025-01-01', 6000, 'Credit', 1, 'Monthly salary deposit');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (39, 107, '2025-01-02', -1800, 'Debit', 6, 'Rent payment');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (40, 107, '2025-01-05', -400, 'Debit', 2, 'Grocery shopping');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (41, 107, '2025-01-12', -180, 'Debit', 5, 'Family dinner');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (42, 107, '2025-01-19', -220, 'Debit', 4, 'Utility bill');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (43, 107, '2025-02-01', 6000, 'Credit', 1, 'Monthly salary deposit');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (44, 107, '2025-02-02', -1800, 'Debit', 6, 'Rent payment');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (45, 107, '2025-02-05', -420, 'Debit', 2, 'Grocery shopping');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (46, 107, '2025-02-12', -200, 'Debit', 5, 'Family dinner');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (47, 107, '2025-02-19', -225, 'Debit', 4, 'Utility bill');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (48, 107, '2025-02-24', -300, 'Debit', 8, 'New laptop bag');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (49, 107, '2025-03-01', 6000, 'Credit', 1, 'Monthly salary deposit');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (50, 107, '2025-03-02', -1800, 'Debit', 6, 'Rent payment');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (51, 107, '2025-03-05', -410, 'Debit', 2, 'Grocery shopping');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (52, 107, '2025-03-12', -170, 'Debit', 5, 'Family dinner');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (53, 107, '2025-03-19', -218, 'Debit', 4, 'Utility bill');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (54, 108, '2025-01-01', 3200, 'Credit', 1, 'Monthly salary deposit');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (55, 108, '2025-01-08', -260, 'Debit', 2, 'Grocery shopping');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (56, 108, '2025-01-16', -160, 'Debit', 4, 'Utility bill');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (57, 108, '2025-02-01', 3200, 'Credit', 1, 'Monthly salary deposit');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (58, 108, '2025-02-08', -270, 'Debit', 2, 'Grocery shopping');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (59, 108, '2025-02-16', -165, 'Debit', 4, 'Utility bill');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (60, 109, '2025-01-04', -300, 'Debit', 8, 'Online shopping');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (61, 109, '2025-01-13', -150, 'Debit', 5, 'Restaurant');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (62, 109, '2025-01-21', -80, 'Debit', 3, 'Streaming subscription');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (63, 109, '2025-02-04', -250, 'Debit', 8, 'Online shopping');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (64, 109, '2025-02-13', -130, 'Debit', 5, 'Restaurant');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (65, 109, '2025-02-21', -90, 'Debit', 3, 'Streaming subscription');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (66, 109, '2025-03-04', -280, 'Debit', 8, 'Online shopping');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (67, 109, '2025-03-13', -160, 'Debit', 5, 'Restaurant');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (68, 109, '2025-03-21', -70, 'Debit', 3, 'Streaming subscription');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (69, 111, '2025-01-01', 4000, 'Credit', 1, 'Monthly salary deposit');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (70, 111, '2025-01-02', -1300, 'Debit', 6, 'Rent payment');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (71, 111, '2025-01-06', -280, 'Debit', 2, 'Grocery shopping');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (72, 111, '2025-01-13', -100, 'Debit', 5, 'Lunch with friends');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (73, 111, '2025-02-01', 4000, 'Credit', 1, 'Monthly salary deposit');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (74, 111, '2025-02-02', -1300, 'Debit', 6, 'Rent payment');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (75, 111, '2025-02-06', -290, 'Debit', 2, 'Grocery shopping');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (76, 111, '2025-02-13', -110, 'Debit', 5, 'Lunch with friends');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (77, 111, '2025-02-25', 200, 'Credit', 7, 'Dividend payout');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (78, 111, '2025-03-01', 4000, 'Credit', 1, 'Monthly salary deposit');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (79, 111, '2025-03-02', -1300, 'Debit', 6, 'Rent payment');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (80, 111, '2025-03-06', -275, 'Debit', 2, 'Grocery shopping');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (81, 111, '2025-03-13', -95, 'Debit', 5, 'Lunch with friends');
INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) VALUES (82, 111, '2025-03-25', 150, 'Credit', 7, 'Dividend payout');
```

**Sanity check** — after loading, these counts should match:

```sql
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'accounts',     COUNT(*) FROM accounts
UNION ALL SELECT 'categories',   COUNT(*) FROM categories
UNION ALL SELECT 'transactions', COUNT(*) FROM transactions;
```

| table_name | row_count |
| --- | --- |
| customers | 10 |
| accounts | 13 |
| categories | 8 |
| transactions | 82 |

# 5. How a SQL Query Is Read

You *write* a query starting with `SELECT`, but the database *processes* it in a different order. Understanding this order explains many “why doesn't this work?” moments.

| Order written | Clause | Order the database logically evaluates it | What it does |
| --- | --- | --- | --- |
| 1 | `SELECT` | 3 | Chooses / calculates the output columns |
| 2 | `FROM` | 1 | Picks the table to read |
| 3 | `WHERE` | 2 | Filters individual rows |
| 4 | `ORDER BY` | 4 | Sorts the result |
| 5 | `LIMIT` | 5 | Keeps only the first N rows |

Practical consequences:

- `WHERE` runs before `SELECT`, so you **cannot use a column alias in `WHERE`** (repeat the expression instead).
- `ORDER BY` runs after `SELECT`, so it **can** use aliases.
- `LIMIT` runs last, so it only makes sense *after* a sensible `ORDER BY`.
- Later in Part F you'll see aggregates like `SUM()` — they run after `WHERE`, which is why `WHERE` filters rows *before* they are summed.

Every statement ends with a semicolon `;`, keywords are not case-sensitive (`select` = `SELECT`), and `--` starts a single-line comment.

# 6. Part A — SELECT and FROM

Every query begins with two questions: *what do I want to see?* (`SELECT`) and *where does it live?* (`FROM`). `SELECT` lists the columns; `FROM` names the table. A table is just rows and columns, and `SELECT` decides which columns come out.

- `SELECT *` returns every column — great for exploring.
- `SELECT col1, col2` returns only what you name, in the order you name it.
- `AS` renames a column in the output only; the table is not changed.
- Expressions and constants can appear in the `SELECT` list, not just column names.

**Q1.** Display every column and every row of the `customers` table.

**Q2.** Show only the first name, last name, and city of every customer.

**Q3.** From `accounts`, show `account_id`, `account_type`, and `balance`, but display the balance column under the name `current_balance`.

> ***Hint:*** *Put `AS new_name` straight after the column you want to rename.*

**Q4.** Show `account_id` and `balance` for every account, plus a third column called `currency` that contains the text `USD` on every row.

> ***Hint:*** *A constant such as `'USD'` can appear in the SELECT list just like a column name.*

# 7. Part B — Filtering Rows with WHERE

Real tables are big, and you rarely want every row. `WHERE` filters rows *before* they are returned. A condition evaluates to true or false for each row, and only the true ones survive.

- Comparisons: `=`, `<>`, `<`, `<=`, `>`, `>=`
- Combine conditions with `AND`, `OR`, and `NOT` (use parentheses when mixing AND with OR).
- `IN (a, b, c)` — matches any value in a list. `BETWEEN a AND b` — inclusive range.
- `LIKE 'pattern'` — text matching with `%` (any characters) and `_` (one character).
- Text and dates go in single quotes; numbers do not.
- Remember: in `transactions`, **debits are negative**.

**Q5.** List all customers who live in Chicago.

**Q6.** List the accounts with a balance greater than 5,000. Show `account_id`, `customer_id`, `account_type`, and `balance`.

**Q7.** List all **Active Checking** accounts. Show `account_id`, `customer_id`, and `balance`.

> ***Hint:*** *Two conditions, joined with AND.*

**Q8.** List all accounts that are either **Savings** or **Credit Card** accounts. First write it with `OR`, then rewrite it with `IN`.

**Q9.** Find the customers who signed up during calendar year 2022. Show `first_name`, `last_name`, and `signup_date`.

**Q10.** Find customers whose **last name ends with the letter n**.

> ***Hint:*** *Use the `%` wildcard on the side where you don't care what the text looks like.*

**Q11.** List the transactions whose description **contains the word “shopping”**. Show `transaction_id`, `description`, and `amount`.

**Q12.** List every **debit of more than 1,000** (money out). Show `transaction_id`, `account_id`, `txn_date`, `amount`, and `description`.

> ***Hint:*** *A debit of 1,500 is stored as -1500.*

**Q13.** List all accounts that are **not** Checking accounts.

**Q14.** List the **Active** accounts that are either a Credit Card **or** have a balance below 1,000. Show `account_id`, `account_type`, `status`, and `balance`.

> ***Hint:*** *You need parentheses around the OR.*

# 8. Part C — Sorting, De-duplicating, and Limiting

Once you have the right rows, you usually want them in a meaningful order, without repeats, and sometimes only the top few.

- `ORDER BY col [ASC | DESC]` sorts the result; list several columns to break ties.
- `SELECT DISTINCT` removes duplicate rows from the output.
- `LIMIT n` (or `TOP n` in SQL Server) returns only the first *n* rows — always pair it with `ORDER BY` so “first” means something.
- `OFFSET n` skips *n* rows, which is how “page 2” is built.
- When several rows tie on the sort column, add a unique column (like an ID) as a final tie-breaker so results are repeatable.

**Q15.** List customers ordered by signup date, **oldest first**. Show `customer_id`, `first_name`, `last_name`, and `signup_date`.

**Q16.** List all accounts sorted by balance from **highest to lowest**. Show `account_id`, `account_type`, and `balance`.

**Q17.** List all accounts sorted by `account_type` alphabetically, and **within each type** by balance from highest to lowest.

**Q18.** Which distinct account types does the bank offer (based on what's in the `accounts` table)?

**Q19.** List the distinct combinations of `account_type` and `status` that exist in the `accounts` table, sorted alphabetically.

**Q20.** Show the **5 largest debits** (biggest money-out transactions). Show `transaction_id`, `account_id`, `txn_date`, `amount`, and `description`.

> ***Hint:*** *Sort first, then limit. Which direction puts -1,800 before -100?*

**Q21.** Show the **5 most recent transactions**. Show `transaction_id`, `account_id`, `txn_date`, `amount`, and `description`. Break ties by highest `transaction_id`.

**Q22.** **Bonus — paging.** Using your query from Q20 (the 5 largest debits), show the **next** 5 (ranks 6–10).

> ***Hint:*** *Add an OFFSET clause to the same query.*

# 9. Part D — Calculated Columns and Built-in Functions

The `SELECT` list can do more than echo stored columns — it can compute new ones. This is how analysts turn raw data into the numbers stakeholders actually ask for.

- **Arithmetic:** `+ - * /` on numeric columns.
- **Math:** `ABS()`, `ROUND(x, places)`.
- **Text:** `CONCAT()`, `UPPER()`, `LOWER()`, `SUBSTRING()`, `LENGTH()`.
- **Dates:** `EXTRACT(YEAR FROM d)` / `YEAR(d)`; compare dates with `>=` and `<`.
- Give every calculated column an alias so the result has a sensible header.

**Q23.** For every **debit** transaction show `transaction_id`, `description`, `amount`, and a fourth column `amount_positive` that shows the same amount as a positive number.

**Q24.** Show each customer's `customer_id` and their **full name** in one column called `full_name` (e.g. “Alice Johnson”).

> ***Hint:*** *Three pieces to join: first name, a space, last name.*

**Q25.** For each customer show the name formatted as `LAST, First` (e.g. “JOHNSON, Alice”) as `formal_name`, and a 3-letter uppercase city code (e.g. “NEW”) as `city_code`.

> ***Hint:*** *Nest SUBSTRING inside UPPER.*

**Q26.** For the first 10 transactions (by `transaction_id`), show `transaction_id`, `txn_date`, and the **year** and **month** of the date as `txn_year` and `txn_month`.

> ***Hint:*** *EXTRACT(YEAR FROM some_date)*

**Q27.** List every transaction that posted in **February 2025**. Show `transaction_id`, `account_id`, `txn_date`, `amount`, and `description`, ordered by date.

> ***Hint:*** *Start of February is inclusive; start of March is exclusive.*

**Q28.** The bank pays **1.5% annual interest** on Savings accounts. For each Savings account show `account_id`, `balance`, and `annual_interest` (balance × 0.015, rounded to 2 decimals).

> ***Hint:*** *ROUND(expression, 2)*

# 10. Part E — Conditional Logic with CASE

Sometimes a value needs to be translated into something else depending on a rule — a balance into a “risk band,” an amount into “In” or “Out.” `CASE` is SQL's if/else:

```sql
CASE
    WHEN condition_1 THEN result_1
    WHEN condition_2 THEN result_2
    ELSE default_result
END
```

- Conditions are checked in order; the first true one wins.
- Always include `ELSE`, or unmatched rows return `NULL`.
- `CASE` can go in `SELECT`, `ORDER BY`, and — as you'll see in Part F — inside aggregate functions.

**Q29.** Label every account's balance in a column called `balance_band`: **Overdrawn** if below 0, **Low** if 0–999.99, **Moderate** if 1,000–9,999.99, and **High** if 10,000 or more. Show `account_id`, `account_type`, `balance`, and `balance_band`.

> ***Hint:*** *Order the WHEN branches from the most specific/lowest to the highest.*

**Q30.** For each transaction show `transaction_id`, `amount`, a `direction` column (**Money In** / **Money Out**), and a `size_label` column: **Large** if the absolute amount is 1,000 or more, **Medium** if 200 or more, otherwise **Small**.

**Q31.** Classify customers by how long they've been with the bank in a column `loyalty_tier`: **Veteran** if they signed up before 2021-01-01, **Established** if before 2022-01-01, otherwise **Newer**. Show `first_name`, `signup_date`, and `loyalty_tier`, oldest customers first.

**Q32.** **Bonus — custom sort order.** List all accounts so that **Checking** accounts come first, then **Savings**, then **Credit Card**, with ties broken by `account_id`. Show `account_id`, `account_type`, and `balance`.

# 11. Part F — Summarizing with Aggregate Functions

So far every query has returned one row per source row. **Aggregate functions** do the opposite: they scan many rows and return a single summary value.

| Function | Returns |
| --- | --- |
| `COUNT(*)` | Number of rows |
| `COUNT(col)` | Number of rows where `col` is not NULL |
| `COUNT(DISTINCT col)` | Number of unique non-NULL values |
| `SUM(col)` | Total |
| `AVG(col)` | Average |
| `MIN(col)` / `MAX(col)` | Smallest / largest |

- `WHERE` is applied first, then the aggregate is computed on the surviving rows.
- With no `GROUP BY`, an aggregate query returns exactly **one row** for the whole table. Getting one row *per customer* or *per category* needs `GROUP BY`, which is the very first topic of the Advanced Lab's Part B.

**Q33.** How many customers does the bank have?

**Q34.** How many accounts are **Active**?

**Q35.** What is the **total balance** across all Active accounts?

**Q36.** In one query, show the **lowest**, **highest**, and **average** account balance across all accounts (round the average to 2 decimals).

**Q37.** How many transactions posted in **January 2025**, and what is their **net amount** (sum of all credits and debits)?

**Q38.** Across **all** transactions, show `total_in` (sum of credits), `total_out` (sum of debits, as a positive number), and `net_flow`.

> ***Hint:*** *SUM(CASE WHEN ... THEN ... ELSE 0 END)*

**Q39.** How many **different accounts** have at least one transaction?

# 12. Part G — NULLs and Changing Data (INSERT, UPDATE, DELETE)

Two things every analyst must know before touching production data: how `NULL` behaves, and how to change rows safely.

- **NULL** means “unknown / missing.” It is *not* zero and *not* an empty string. Test it with `IS NULL` / `IS NOT NULL` — never `= NULL`.
- **COALESCE(x, default)** substitutes a default for `NULL`.
- **INSERT** adds rows, **UPDATE** changes existing rows, **DELETE** removes rows. `UPDATE` and `DELETE` without a `WHERE` hit *every* row.

Together, `INSERT`, `UPDATE`, and `DELETE` are called **DML** (Data Manipulation Language). They change the *data* inside tables, as opposed to `CREATE` / `DROP`, which change the tables themselves.

## 12.1 Quick Reference: INSERT, UPDATE, DELETE

The examples below use two practice tables: `customers_practice` (created in Q40) and `accounts_practice`, a copy of `accounts`. Create the second one like this:

```sql
CREATE TABLE accounts_practice (
    account_id    INT PRIMARY KEY,
    customer_id   INT NOT NULL,
    account_type  VARCHAR(20) NOT NULL,
    status        VARCHAR(10) NOT NULL,
    balance       DECIMAL(10,2) NOT NULL
);

INSERT INTO accounts_practice
SELECT account_id, customer_id, account_type, status, balance
FROM accounts;
```

**INSERT — add rows**

```sql
-- 1. One row. Always name the columns so the statement survives table changes.
INSERT INTO customers_practice (customer_id, first_name, last_name, email, city, signup_date)
VALUES (13, 'Maya', 'Singh', 'maya.singh@email.com', 'Austin', '2025-03-01');

-- 2. Several rows in one statement. Columns left out (email) become NULL or their DEFAULT.
INSERT INTO customers_practice (customer_id, first_name, last_name, city, signup_date)
VALUES (14, 'Noah',   'Reed', 'Miami',  '2025-03-05'),
       (15, 'Olivia', 'Cruz', 'Boston', '2025-03-09');

-- 3. Copy rows from a query (INSERT ... SELECT).
INSERT INTO customers_practice (customer_id, first_name, last_name, email, city, signup_date)
SELECT customer_id + 100, first_name, last_name, email, city, signup_date
FROM customers
WHERE city = 'Chicago';
```
Rules to remember: the number and order of values must match the column list; text and dates go in single quotes; a value for the primary key must be unique; and a *foreign key* value must already exist in the parent table.

**UPDATE — change existing rows**

```sql
-- 1. One column, one row.
UPDATE accounts_practice
SET    balance = balance + 100          -- the new value can be calculated from the old one
WHERE  account_id = 101;

-- 2. Several columns at once (separate them with commas).
UPDATE accounts_practice
SET    status  = 'Inactive',
       balance = 0
WHERE  account_id = 104;

-- 3. Many rows at once: pay 1.5% interest to every Active Savings account.
UPDATE accounts_practice
SET    balance = ROUND(balance * 1.015, 2)
WHERE  account_type = 'Savings'
  AND  status = 'Active';
```
Any `WHERE` condition you learned in Part B works here, and `CASE` (Part E) can be used inside `SET`.

**DELETE — remove rows**

```sql
-- 1. Delete the rows that match a condition.
DELETE FROM accounts_practice
WHERE  status = 'Inactive';

-- 2. Delete every row but keep the (now empty) table. Dangerous: there is no WHERE!
DELETE FROM accounts_practice;

-- 3. Same result, faster on big tables, but cannot be filtered with WHERE.
TRUNCATE TABLE accounts_practice;
```
`DELETE` removes rows; `TRUNCATE` empties the table; `DROP TABLE` removes the table itself.

**Safety habits that prevent expensive mistakes**

1. **Preview with `SELECT` first.** Write the same `WHERE` in a `SELECT`, check that the rows are the ones you mean, and only then change `SELECT *` to `DELETE` or turn it into an `UPDATE`.

   ```sql
   SELECT * FROM accounts_practice WHERE status = 'Inactive';   -- look first ...
   DELETE FROM accounts_practice WHERE status = 'Inactive';     -- ... then delete
   ```
2. **Use a transaction so you can undo.** Changes made inside a transaction are only permanent once you `COMMIT`; `ROLLBACK` throws them away.

   ```sql
   BEGIN;                                   -- MySQL: START TRANSACTION;   SQL Server: BEGIN TRANSACTION;
   DELETE FROM accounts_practice WHERE balance < 0;
   SELECT COUNT(*) FROM accounts_practice;  -- does the row count look right?
   ROLLBACK;                                -- changed your mind? undo. Happy? use COMMIT; instead.
   ```
3. **Know that constraints protect you.** On the real lab tables, `DELETE FROM customers WHERE customer_id = 1;` fails because accounts still refer to Alice, and inserting an account for a non-existent `customer_id` (say 99) fails the foreign key. The database refuses changes that would leave orphaned rows — this is a feature.
4. **Never practice on the lab tables.** Work on `customers_practice` / `accounts_practice`, and drop them when you finish (`DROP TABLE accounts_practice;`).

## 12.2 Practice Questions

The original lab tables contain no missing values, so in this part you will create a scratch copy called `customers_practice`, add a few customers with gaps, and work on that. **Do not run these statements against `customers`, `accounts`, `categories`, or `transactions`** — the Advanced Lab expects those tables unchanged. Run Q40–Q46 in order.

**Q40.** **Create a practice copy.** Create a table `customers_practice` with the same columns as `customers`, then copy all 10 customers into it and check the row count.

> ***Hint:*** *CREATE TABLE with the same column definitions, then INSERT INTO ... SELECT * FROM customers.*

**Q41.** **Insert two new customers** into `customers_practice`: (11, Kara Novak, **no email**, Dallas, 2025-01-10) and (12, Leo Park, leo.park@email.com, **no city**, 2025-02-01). Then display the two new rows.

> ***Hint:*** *Use the NULL keyword — not the text 'NULL' — for the missing values.*

**Q42.** **Find missing values.** List the customers in `customers_practice` that have no email on file. Then try `WHERE email = NULL` and explain why it returns nothing.

> ***Hint:*** *NULL needs its own operator: IS NULL.*

**Q43.** **NULLs and aggregates.** In one query show `COUNT(*)` as `all_rows`, `COUNT(email)` as `rows_with_email`, and `COUNT(city)` as `rows_with_city` for `customers_practice`.

**Q44.** **Replace NULLs for display.** For the new customers (`customer_id` > 10), show `first_name` and `city`, but display **Unknown** wherever the city is missing.

**Q45.** **Update rows.** Give Kara (customer 11) the email `kara.novak@email.com`, and set Leo's (customer 12) city to `Denver`. Then display both rows to confirm.

> ***Hint:*** *Two separate UPDATE statements, each with its own WHERE customer_id = ...*

**Q46.** **Delete rows and clean up.** Delete the customers that joined on or after 2025-01-01 from `customers_practice`, confirm only the original 10 remain, then drop the practice table.

> ***Hint:*** *Filter on signup_date.*

# 13. Part H — Review Challenges

These questions combine ideas from Parts A–G. Each can be answered with a single query on a single table.

**Q47.** **Watch list.** Compile a list of **Active** accounts with a balance **below 1,000**, most in-debt first. Show `account_id`, `customer_id`, `account_type`, and `balance`.

**Q48.** **Latest rent payments.** Show the 5 most recent transactions in category **6** (Rent) with `transaction_id`, `account_id`, `txn_date`, `amount`, and `description`. Break date ties by highest `transaction_id`.

> ***Hint:*** *Filter, sort, limit.*

**Q49.** **Grocery spend.** How much was spent on Groceries (category **2**) in February 2025 across all accounts? Show it as a positive number called `grocery_spend`.

**Q50.** **Savings snapshot.** For Savings accounts only, show the number of accounts (`savings_accounts`), their combined balance (`total_balance`), and the projected annual interest at 1.5% on that combined balance (`projected_interest`, rounded to 2 decimals).

**Q51.** **Quarterly cash-flow summary.** In a single row, show the total number of transactions (`txn_count`), `total_in`, `total_out` (positive), the `largest_credit`, and the `largest_debit` (as a positive number).

> ***Hint:*** *The largest debit is the smallest (most negative) number.*

# 14. What's Next: Where Single-Table SQL Runs Out

Try to answer each of the following using only what you've learned in this lab. Each one gets you *most* of the way — and then stops. That's the point: each “wall” is precisely the problem the next technique was invented to solve.

| # | Business question | Why single-table SQL gets stuck | Tool that solves it | Advanced Lab |
| --- | --- | --- | --- | --- |
| P1 | Which **city** does the owner of account 105 live in? | `accounts` has only a `customer_id`; the city lives in `customers`. You could look up customer 3 by hand, but you can't do it for all accounts at once. | **JOIN** | Part A |
| P2 | Show each transaction with its **category name**. | `transactions` stores only `category_id`. (Recall Q48, where you had to memorize that 6 = Rent.) | **JOIN** | Part A |
| P3 | What is the **total spending per customer** (or per category, or per month)? | Aggregates in Part F collapse the *whole table* into one row. You'd need to run a separate query for every customer. | **GROUP BY** | Part B |
| P4 | Which accounts have a balance **above the average balance**? | You can compute the average (Q36), but you'd then have to copy that number into a second query by hand — it goes stale the moment data changes. | **Subquery** | Part C |
| P5 | Show each transaction with a **running balance**, a **rank**, or the **previous transaction's amount**. | Each row needs to “see” other rows without collapsing them, which neither `WHERE` nor aggregates can do. | **Window function** | Part D |

**Ready for the Advanced Lab?** You should be comfortable with the following before you continue. If any of these feel shaky, revisit the part shown in brackets:

- [ ] Reading and writing `WHERE` conditions with `AND`, `OR`, `IN`, `LIKE` (Part B)
- [ ] Sorting with `ORDER BY` and getting a top-N with `LIMIT` (Part C)
- [ ] Extracting a month from a date and using aliases (Parts A, D)
- [ ] Writing a `CASE` expression, including inside `SUM()` (Parts E, F)
- [ ] Using `COUNT`, `SUM`, `AVG`, `MIN`, `MAX` and knowing how they treat `NULL` (Parts F, G)

# 15. Solutions

Each solution shows the query, its expected output (generated by running it against the sample data above), and a short explanation. Where a query returns many rows, only the first rows are shown. Remember: many questions can be written more than one way — if your query returns the same rows, it's correct.

## 15.1 Part A Solutions — SELECT and FROM

**Q1 — Every column of customers**

```sql
SELECT * FROM customers;
```

**Expected output:**

| customer_id | first_name | last_name | email | city | signup_date |
| --- | --- | --- | --- | --- | --- |
| 1 | Alice | Johnson | alice.johnson@email.com | New York | 2022-01-15 |
| 2 | Brian | Smith | brian.smith@email.com | Chicago | 2021-11-02 |
| 3 | Carla | Diaz | carla.diaz@email.com | Austin | 2023-03-22 |
| 4 | David | Chen | david.chen@email.com | Seattle | 2020-07-09 |
| 5 | Emma | Wilson | emma.wilson@email.com | Boston | 2022-09-30 |
| 6 | Farhan | Ali | farhan.ali@email.com | Houston | 2023-01-05 |
| 7 | Grace | Kim | grace.kim@email.com | Denver | 2021-05-18 |
| 8 | Henry | Lopez | henry.lopez@email.com | Miami | 2022-12-11 |
| 9 | Isla | Brown | isla.brown@email.com | Portland | 2023-06-25 |
| 10 | Jack | Turner | jack.turner@email.com | Atlanta | 2020-02-14 |

*10 rows.*

`SELECT *` means “all columns.” It is perfect for a first look at an unfamiliar table, but on the job you should list the columns you actually need — it is faster, clearer, and won't break if someone adds a column later.

---

**Q2 — Selecting specific columns**

```sql
SELECT first_name, last_name, city
FROM customers;
```

**Expected output:**

| first_name | last_name | city |
| --- | --- | --- |
| Alice | Johnson | New York |
| Brian | Smith | Chicago |
| Carla | Diaz | Austin |
| David | Chen | Seattle |
| Emma | Wilson | Boston |
| Farhan | Ali | Houston |
| Grace | Kim | Denver |
| Henry | Lopez | Miami |
| Isla | Brown | Portland |
| Jack | Turner | Atlanta |

*10 rows.*

Columns are returned in the order you list them, not the order they were defined in the table.

---

**Q3 — Column aliases**

```sql
SELECT account_id,
       account_type,
       balance AS current_balance
FROM accounts;
```

**Expected output:**

| account_id | account_type | current_balance |
| --- | --- | --- |
| 101 | Checking | 3500.00 |
| 102 | Savings | 12000.00 |
| 103 | Checking | 1800.00 |
| 104 | Checking | 500.00 |
| 105 | Credit Card | -750.00 |
| 106 | Savings | 25000.00 |
| 107 | Checking | 4200.00 |
| 108 | Checking | 2100.00 |
| 109 | Credit Card | -300.00 |
| 110 | Savings | 8000.00 |
| 111 | Checking | 1500.00 |
| 112 | Checking | 0.00 |
| 113 | Credit Card | -1200.00 |

*13 rows.*

`AS` gives a column a temporary name (an *alias*) for the duration of the query. Aliases make reports readable and become essential once you start calculating new columns in Part D.

---

**Q4 — A constant (literal) column**

```sql
SELECT account_id,
       balance,
       'USD' AS currency
FROM accounts;
```

**Expected output:**

| account_id | balance | currency |
| --- | --- | --- |
| 101 | 3500.00 | USD |
| 102 | 12000.00 | USD |
| 103 | 1800.00 | USD |
| 104 | 500.00 | USD |
| 105 | -750.00 | USD |
| 106 | 25000.00 | USD |
| 107 | 4200.00 | USD |
| 108 | 2100.00 | USD |
| 109 | -300.00 | USD |
| 110 | 8000.00 | USD |
| 111 | 1500.00 | USD |
| 112 | 0.00 | USD |
| 113 | -1200.00 | USD |

*13 rows.*

A literal value in the `SELECT` list is repeated on every row. Text literals use **single quotes**; double quotes are for identifiers in standard SQL.

---

## 15.2 Part B Solutions — Filtering with WHERE

**Q5 — Customers in Chicago**

```sql
SELECT *
FROM customers
WHERE city = 'Chicago';
```

**Expected output:**

| customer_id | first_name | last_name | email | city | signup_date |
| --- | --- | --- | --- | --- | --- |
| 2 | Brian | Smith | brian.smith@email.com | Chicago | 2021-11-02 |

`WHERE` keeps only the rows for which the condition is true. Text comparisons need single quotes, and in PostgreSQL `'chicago'` would *not* match `'Chicago'` because text comparison is case-sensitive there (MySQL and SQL Server are usually case-insensitive by default).

---

**Q6 — Balances above 5,000**

```sql
SELECT account_id, customer_id, account_type, balance
FROM accounts
WHERE balance > 5000;
```

**Expected output:**

| account_id | customer_id | account_type | balance |
| --- | --- | --- | --- |
| 102 | 1 | Savings | 12000.00 |
| 106 | 4 | Savings | 25000.00 |
| 110 | 7 | Savings | 8000.00 |

*3 rows.*

Comparison operators: `=`, `<>` (or `!=`), `<`, `<=`, `>`, `>=`. Numbers are written without quotes.

---

**Q7 — Active Checking accounts (AND)**

```sql
SELECT account_id, customer_id, balance
FROM accounts
WHERE account_type = 'Checking'
  AND status = 'Active';
```

**Expected output:**

| account_id | customer_id | balance |
| --- | --- | --- |
| 101 | 1 | 3500.00 |
| 103 | 2 | 1800.00 |
| 104 | 3 | 500.00 |
| 107 | 4 | 4200.00 |
| 108 | 5 | 2100.00 |
| 111 | 7 | 1500.00 |

*6 rows.*

`AND` requires *both* conditions to be true. Account 112 is a Checking account but is `Inactive`, so it is filtered out.

---

**Q8 — Savings or Credit Card accounts (IN / OR)**

```sql
SELECT account_id, customer_id, account_type, balance
FROM accounts
WHERE account_type IN ('Savings', 'Credit Card');

-- Equivalent, using OR:
-- WHERE account_type = 'Savings' OR account_type = 'Credit Card'
```

**Expected output:**

| account_id | customer_id | account_type | balance |
| --- | --- | --- | --- |
| 102 | 1 | Savings | 12000.00 |
| 105 | 3 | Credit Card | -750.00 |
| 106 | 4 | Savings | 25000.00 |
| 109 | 6 | Credit Card | -300.00 |
| 110 | 7 | Savings | 8000.00 |
| 113 | 9 | Credit Card | -1200.00 |

*6 rows.*

`IN (...)` is shorthand for a chain of `OR`s on the same column. It gets much more readable as the list grows. Note that you cannot write `account_type = 'Savings' OR 'Credit Card'` — each side of `OR` must be a complete condition.

---

**Q9 — Sign-ups in 2022 (BETWEEN)**

```sql
SELECT first_name, last_name, signup_date
FROM customers
WHERE signup_date BETWEEN '2022-01-01' AND '2022-12-31';
```

**Expected output:**

| first_name | last_name | signup_date |
| --- | --- | --- |
| Alice | Johnson | 2022-01-15 |
| Emma | Wilson | 2022-09-30 |
| Henry | Lopez | 2022-12-11 |

*3 rows.*

`BETWEEN a AND b` is **inclusive** on both ends. Dates are written as `'YYYY-MM-DD'` text literals. (Part D shows a safer pattern for timestamps.)

---

**Q10 — Last name ends in “n” (LIKE)**

```sql
SELECT first_name, last_name
FROM customers
WHERE last_name LIKE '%n';
```

**Expected output:**

| first_name | last_name |
| --- | --- |
| Alice | Johnson |
| David | Chen |
| Emma | Wilson |
| Isla | Brown |

*4 rows.*

`LIKE` matches text patterns: `%` stands for “any number of characters” (including none) and `_` stands for exactly one character. `'A%'` = starts with A, `'%n'` = ends with n, `'%shop%'` = contains shop.

---

**Q11 — Descriptions containing “shopping”**

```sql
SELECT transaction_id, description, amount
FROM transactions
WHERE description LIKE '%shopping%';
```

**Expected output:**

| transaction_id | description | amount |
| --- | --- | --- |
| 3 | Grocery shopping | -300.00 |
| 9 | Grocery shopping | -320.00 |
| 15 | Grocery shopping | -280.00 |
| 20 | Grocery shopping | -250.00 |
| 24 | Grocery shopping | -260.00 |
| 27 | Online shopping | -200.00 |
| 29 | Grocery shopping | -240.00 |
| 33 | Grocery shopping | -220.00 |
| 36 | Grocery shopping | -230.00 |
| 40 | Grocery shopping | -400.00 |

*…first 10 of 20 rows shown.*

A `%` on both sides means “contains.” Case sensitivity depends on the database (PostgreSQL's `LIKE` is case-sensitive; MySQL's usually is not). In PostgreSQL use `ILIKE` for case-insensitive matching.

---

**Q12 — Debits over 1,000 (watch the sign)**

```sql
SELECT transaction_id, account_id, txn_date, amount, description
FROM transactions
WHERE txn_type = 'Debit'
  AND amount < -1000;
```

**Expected output:**

| transaction_id | account_id | txn_date | amount | description |
| --- | --- | --- | --- | --- |
| 2 | 101 | 2025-01-02 | -1500.00 | Rent payment |
| 8 | 101 | 2025-02-02 | -1500.00 | Rent payment |
| 14 | 101 | 2025-03-02 | -1500.00 | Rent payment |
| 39 | 107 | 2025-01-02 | -1800.00 | Rent payment |
| 44 | 107 | 2025-02-02 | -1800.00 | Rent payment |
| 50 | 107 | 2025-03-02 | -1800.00 | Rent payment |
| 70 | 111 | 2025-01-02 | -1300.00 | Rent payment |
| 74 | 111 | 2025-02-02 | -1300.00 | Rent payment |
| 79 | 111 | 2025-03-02 | -1300.00 | Rent payment |

*9 rows.*

Remember how the data is stored: debits are **negative** numbers, so “more than 1,000 going out” is `amount < -1000`, not `amount > 1000`. Getting the sign right is one of the most common mistakes in financial queries.

---

**Q13 — Accounts that are not Checking (NOT)**

```sql
SELECT account_id, customer_id, account_type, balance
FROM accounts
WHERE account_type <> 'Checking';

-- Equivalent: WHERE NOT account_type = 'Checking'
-- Equivalent: WHERE account_type NOT IN ('Checking')
```

**Expected output:**

| account_id | customer_id | account_type | balance |
| --- | --- | --- | --- |
| 102 | 1 | Savings | 12000.00 |
| 105 | 3 | Credit Card | -750.00 |
| 106 | 4 | Savings | 25000.00 |
| 109 | 6 | Credit Card | -300.00 |
| 110 | 7 | Savings | 8000.00 |
| 113 | 9 | Credit Card | -1200.00 |

*6 rows.*

`<>` means “not equal.” You can also negate with `NOT`, `NOT IN`, `NOT LIKE`, and `NOT BETWEEN`.

---

**Q14 — Mixing AND with OR (parentheses)**

```sql
SELECT account_id, account_type, status, balance
FROM accounts
WHERE status = 'Active'
  AND (account_type = 'Credit Card' OR balance < 1000);
```

**Expected output:**

| account_id | account_type | status | balance |
| --- | --- | --- | --- |
| 104 | Checking | Active | 500.00 |
| 105 | Credit Card | Active | -750.00 |
| 109 | Credit Card | Active | -300.00 |
| 113 | Credit Card | Active | -1200.00 |

*4 rows.*

`AND` is evaluated before `OR`, so the parentheses are essential. Without them SQL reads the filter as `(status = 'Active' AND account_type = 'Credit Card') OR balance < 1000`, and inactive account 112 (balance 0) sneaks into the results. **When you mix AND and OR, always add parentheses.**

---

## 15.3 Part C Solutions — Sorting, DISTINCT, and LIMIT

**Q15 — Oldest customers first**

```sql
SELECT customer_id, first_name, last_name, signup_date
FROM customers
ORDER BY signup_date ASC;
```

**Expected output:**

| customer_id | first_name | last_name | signup_date |
| --- | --- | --- | --- |
| 10 | Jack | Turner | 2020-02-14 |
| 4 | David | Chen | 2020-07-09 |
| 7 | Grace | Kim | 2021-05-18 |
| 2 | Brian | Smith | 2021-11-02 |
| 1 | Alice | Johnson | 2022-01-15 |
| 5 | Emma | Wilson | 2022-09-30 |
| 8 | Henry | Lopez | 2022-12-11 |
| 6 | Farhan | Ali | 2023-01-05 |
| 3 | Carla | Diaz | 2023-03-22 |
| 9 | Isla | Brown | 2023-06-25 |

*10 rows.*

`ORDER BY` sorts the final result. `ASC` (ascending) is the default, so you may omit it. Without an `ORDER BY`, SQL makes **no promise** about row order.

---

**Q16 — Accounts by balance, highest first**

```sql
SELECT account_id, account_type, balance
FROM accounts
ORDER BY balance DESC;
```

**Expected output:**

| account_id | account_type | balance |
| --- | --- | --- |
| 106 | Savings | 25000.00 |
| 102 | Savings | 12000.00 |
| 110 | Savings | 8000.00 |
| 107 | Checking | 4200.00 |
| 101 | Checking | 3500.00 |
| 108 | Checking | 2100.00 |
| 103 | Checking | 1800.00 |
| 111 | Checking | 1500.00 |
| 104 | Checking | 500.00 |
| 112 | Checking | 0.00 |
| 109 | Credit Card | -300.00 |
| 105 | Credit Card | -750.00 |
| 113 | Credit Card | -1200.00 |

*13 rows.*

`DESC` reverses the sort. Negative balances (credit cards owed) naturally fall to the bottom.

---

**Q17 — Sorting by two columns**

```sql
SELECT account_id, account_type, balance
FROM accounts
ORDER BY account_type ASC, balance DESC;
```

**Expected output:**

| account_id | account_type | balance |
| --- | --- | --- |
| 107 | Checking | 4200.00 |
| 101 | Checking | 3500.00 |
| 108 | Checking | 2100.00 |
| 103 | Checking | 1800.00 |
| 111 | Checking | 1500.00 |
| 104 | Checking | 500.00 |
| 112 | Checking | 0.00 |
| 109 | Credit Card | -300.00 |
| 105 | Credit Card | -750.00 |
| 113 | Credit Card | -1200.00 |
| 106 | Savings | 25000.00 |
| 102 | Savings | 12000.00 |
| 110 | Savings | 8000.00 |

*13 rows.*

Add more sort keys separated by commas. SQL sorts by the first key, and only uses the next key to break ties. Each key gets its own `ASC`/`DESC`.

---

**Q18 — DISTINCT account types**

```sql
SELECT DISTINCT account_type
FROM accounts;
```

**Expected output:**

| account_type |
| --- |
| Checking |
| Savings |
| Credit Card |

*3 rows.*

`DISTINCT` removes duplicate rows from the result. 13 accounts collapse into 3 unique types.

---

**Q19 — DISTINCT combinations**

```sql
SELECT DISTINCT account_type, status
FROM accounts
ORDER BY account_type, status;
```

**Expected output:**

| account_type | status |
| --- | --- |
| Checking | Active |
| Checking | Inactive |
| Credit Card | Active |
| Savings | Active |

*4 rows.*

`DISTINCT` applies to the **whole row** of selected columns, not just the first one. Here it returns each unique *pair*. It is a fast way to discover what values a column can take — a habit worth building whenever you meet a new dataset.

---

**Q20 — Top 5 largest debits (ORDER BY + LIMIT)**

```sql
SELECT transaction_id, account_id, txn_date, amount, description
FROM transactions
WHERE txn_type = 'Debit'
ORDER BY amount ASC, transaction_id ASC
LIMIT 5;
```

**Expected output:**

| transaction_id | account_id | txn_date | amount | description |
| --- | --- | --- | --- | --- |
| 39 | 107 | 2025-01-02 | -1800.00 | Rent payment |
| 44 | 107 | 2025-02-02 | -1800.00 | Rent payment |
| 50 | 107 | 2025-03-02 | -1800.00 | Rent payment |
| 2 | 101 | 2025-01-02 | -1500.00 | Rent payment |
| 8 | 101 | 2025-02-02 | -1500.00 | Rent payment |

*5 rows.*

Debits are negative, so the *largest* debit is the most negative number — that means sorting `ASC`. `LIMIT 5` keeps only the first five rows after sorting. The second sort key (`transaction_id`) is a **tie-breaker**: three rent payments of -1,800 tie, and without it the database is free to return whichever it likes.

> **Dialect note:** `LIMIT n` works in PostgreSQL, MySQL, and SQLite. SQL Server uses `SELECT TOP 5 ...`; the ANSI standard form (PostgreSQL, SQL Server 2012+, Oracle 12c+) is `FETCH FIRST 5 ROWS ONLY`.

---

**Q21 — Five most recent transactions**

```sql
SELECT transaction_id, account_id, txn_date, amount, description
FROM transactions
ORDER BY txn_date DESC, transaction_id DESC
LIMIT 5;
```

**Expected output:**

| transaction_id | account_id | txn_date | amount | description |
| --- | --- | --- | --- | --- |
| 82 | 111 | 2025-03-25 | 150.00 | Dividend payout |
| 68 | 109 | 2025-03-21 | -70.00 | Streaming subscription |
| 18 | 101 | 2025-03-20 | -190.00 | Electricity & water bill |
| 53 | 107 | 2025-03-19 | -218.00 | Utility bill |
| 31 | 103 | 2025-03-18 | -148.00 | Utility bill |

*5 rows.*

“Most recent” = latest date first = `DESC`. Combining `ORDER BY ... DESC` with `LIMIT` is the standard “top N” / “latest N” pattern.

---

**Q22 — Next 5 rows (OFFSET)**

```sql
SELECT transaction_id, account_id, txn_date, amount, description
FROM transactions
WHERE txn_type = 'Debit'
ORDER BY amount ASC, transaction_id ASC
LIMIT 5 OFFSET 5;
```

**Expected output:**

| transaction_id | account_id | txn_date | amount | description |
| --- | --- | --- | --- | --- |
| 14 | 101 | 2025-03-02 | -1500.00 | Rent payment |
| 70 | 111 | 2025-01-02 | -1300.00 | Rent payment |
| 74 | 111 | 2025-02-02 | -1300.00 | Rent payment |
| 79 | 111 | 2025-03-02 | -1300.00 | Rent payment |
| 45 | 107 | 2025-02-05 | -420.00 | Grocery shopping |

*5 rows.*

`OFFSET 5` skips the first five rows. `LIMIT` + `OFFSET` is how applications build “page 2” of a report. The ANSI equivalent is `OFFSET 5 ROWS FETCH NEXT 5 ROWS ONLY`. Paging is only reliable when the `ORDER BY` is deterministic — which is why the tie-breaker matters.

---

## 15.4 Part D Solutions — Calculated Columns and Functions

**Q23 — ABS() for positive amounts**

```sql
SELECT transaction_id,
       description,
       amount,
       ABS(amount) AS amount_positive
FROM transactions
WHERE txn_type = 'Debit';
```

**Expected output:**

| transaction_id | description | amount | amount_positive |
| --- | --- | --- | --- |
| 2 | Rent payment | -1500.00 | 1500.00 |
| 3 | Grocery shopping | -300.00 | 300.00 |
| 4 | Dinner out | -120.00 | 120.00 |
| 5 | Movie night | -60.00 | 60.00 |
| 6 | Electricity & water bill | -180.00 | 180.00 |
| 8 | Rent payment | -1500.00 | 1500.00 |
| 9 | Grocery shopping | -320.00 | 320.00 |
| 10 | Dinner out | -95.00 | 95.00 |

*…first 8 of 64 rows shown.*

`ABS()` returns the absolute value. Any expression in the `SELECT` list creates a **calculated column** computed row by row — the table itself is never changed.

---

**Q24 — Concatenating a full name**

```sql
SELECT customer_id,
       CONCAT(first_name, ' ', last_name) AS full_name
FROM customers;
```

**Expected output:**

| customer_id | full_name |
| --- | --- |
| 1 | Alice Johnson |
| 2 | Brian Smith |
| 3 | Carla Diaz |
| 4 | David Chen |
| 5 | Emma Wilson |
| 6 | Farhan Ali |
| 7 | Grace Kim |
| 8 | Henry Lopez |
| 9 | Isla Brown |
| 10 | Jack Turner |

*10 rows.*

`CONCAT()` glues text together and works in PostgreSQL, MySQL, and SQL Server 2012+. The ANSI operator is `||` (`first_name || ' ' || last_name`) but MySQL and SQL Server do not use it for text by default. The `' '` in the middle is a literal single space.

---

**Q25 — Nesting text functions**

```sql
SELECT customer_id,
       CONCAT(UPPER(last_name), ', ', first_name) AS formal_name,
       UPPER(SUBSTRING(city, 1, 3))                AS city_code
FROM customers;
```

**Expected output:**

| customer_id | formal_name | city_code |
| --- | --- | --- |
| 1 | JOHNSON, Alice | NEW |
| 2 | SMITH, Brian | CHI |
| 3 | DIAZ, Carla | AUS |
| 4 | CHEN, David | SEA |
| 5 | WILSON, Emma | BOS |
| 6 | ALI, Farhan | HOU |
| 7 | KIM, Grace | DEN |
| 8 | LOPEZ, Henry | MIA |
| 9 | BROWN, Isla | POR |
| 10 | TURNER, Jack | ATL |

*10 rows.*

`UPPER()` / `LOWER()` change case, and `SUBSTRING(text, start, length)` extracts part of a string — positions start at **1**, not 0. Functions can be nested: the inner one runs first. Other handy ones: `LENGTH()` (`LEN()` in SQL Server), `TRIM()`, `REPLACE()`.

---

**Q26 — Extracting date parts**

```sql
SELECT transaction_id,
       txn_date,
       EXTRACT(YEAR  FROM txn_date) AS txn_year,
       EXTRACT(MONTH FROM txn_date) AS txn_month
FROM transactions
ORDER BY transaction_id
LIMIT 10;
```

**Expected output:**

| transaction_id | txn_date | txn_year | txn_month |
| --- | --- | --- | --- |
| 1 | 2025-01-01 | 2025 | 1 |
| 2 | 2025-01-02 | 2025 | 1 |
| 3 | 2025-01-05 | 2025 | 1 |
| 4 | 2025-01-10 | 2025 | 1 |
| 5 | 2025-01-15 | 2025 | 1 |
| 6 | 2025-01-20 | 2025 | 1 |
| 7 | 2025-02-01 | 2025 | 2 |
| 8 | 2025-02-02 | 2025 | 2 |
| 9 | 2025-02-05 | 2025 | 2 |
| 10 | 2025-02-10 | 2025 | 2 |

*10 rows.*

`EXTRACT(part FROM date)` pulls out `YEAR`, `MONTH`, `DAY`, etc., and works in PostgreSQL and MySQL. SQL Server uses `YEAR(txn_date)` and `MONTH(txn_date)`. You will use exactly this trick in the advanced lab to group spending by month.

---

**Q27 — Filtering a month with a half-open range**

```sql
SELECT transaction_id, account_id, txn_date, amount, description
FROM transactions
WHERE txn_date >= '2025-02-01'
  AND txn_date <  '2025-03-01'
ORDER BY txn_date, transaction_id;
```

**Expected output:**

| transaction_id | account_id | txn_date | amount | description |
| --- | --- | --- | --- | --- |
| 7 | 101 | 2025-02-01 | 4500.00 | Monthly salary deposit |
| 23 | 103 | 2025-02-01 | 3800.00 | Monthly salary deposit |
| 35 | 104 | 2025-02-01 | 3000.00 | Monthly salary deposit |
| 43 | 107 | 2025-02-01 | 6000.00 | Monthly salary deposit |
| 57 | 108 | 2025-02-01 | 3200.00 | Monthly salary deposit |
| 73 | 111 | 2025-02-01 | 4000.00 | Monthly salary deposit |
| 8 | 101 | 2025-02-02 | -1500.00 | Rent payment |
| 44 | 107 | 2025-02-02 | -1800.00 | Rent payment |

*…first 8 of 31 rows shown.*

This **half-open range** (`>=` the first day of the month, `<` the first day of the *next* month) is the safest way to filter a month. It works for `DATE` columns and also for timestamps with a time-of-day part, where `BETWEEN '2025-02-01' AND '2025-02-28'` would silently miss anything that posted after midnight on Feb 28.

---

**Q28 — Arithmetic and ROUND()**

```sql
SELECT account_id,
       balance,
       ROUND(balance * 0.015, 2) AS annual_interest
FROM accounts
WHERE account_type = 'Savings';
```

**Expected output:**

| account_id | balance | annual_interest |
| --- | --- | --- |
| 102 | 12000.00 | 180.00 |
| 106 | 25000.00 | 375.00 |
| 110 | 8000.00 | 120.00 |

*3 rows.*

Arithmetic (`+ - * /`) works directly on columns. `ROUND(x, 2)` rounds to two decimal places. Note the order of operations in the query: the `WHERE` filter picks the Savings rows first, then the calculation runs on just those rows.

---

## 15.5 Part E Solutions — CASE

**Q29 — Balance bands**

```sql
SELECT account_id,
       account_type,
       balance,
       CASE
           WHEN balance < 0     THEN 'Overdrawn'
           WHEN balance < 1000  THEN 'Low'
           WHEN balance < 10000 THEN 'Moderate'
           ELSE 'High'
       END AS balance_band
FROM accounts
ORDER BY account_id;
```

**Expected output:**

| account_id | account_type | balance | balance_band |
| --- | --- | --- | --- |
| 101 | Checking | 3500.00 | Moderate |
| 102 | Savings | 12000.00 | High |
| 103 | Checking | 1800.00 | Moderate |
| 104 | Checking | 500.00 | Low |
| 105 | Credit Card | -750.00 | Overdrawn |
| 106 | Savings | 25000.00 | High |
| 107 | Checking | 4200.00 | Moderate |
| 108 | Checking | 2100.00 | Moderate |
| 109 | Credit Card | -300.00 | Overdrawn |
| 110 | Savings | 8000.00 | Moderate |
| 111 | Checking | 1500.00 | Moderate |
| 112 | Checking | 0.00 | Low |
| 113 | Credit Card | -1200.00 | Overdrawn |

*13 rows.*

`CASE` is SQL's if / else-if / else. Conditions are tested **top to bottom** and the first one that is true wins — that's why we don't need to write `balance >= 0 AND balance < 1000`; anything negative was already caught by the first branch. Always finish with an `ELSE`, otherwise unmatched rows get `NULL`.

---

**Q30 — Two CASE columns at once**

```sql
SELECT transaction_id,
       amount,
       CASE WHEN amount > 0 THEN 'Money In' ELSE 'Money Out' END AS direction,
       CASE
           WHEN ABS(amount) >= 1000 THEN 'Large'
           WHEN ABS(amount) >= 200  THEN 'Medium'
           ELSE 'Small'
       END AS size_label
FROM transactions
ORDER BY transaction_id;
```

**Expected output:**

| transaction_id | amount | direction | size_label |
| --- | --- | --- | --- |
| 1 | 4500.00 | Money In | Large |
| 2 | -1500.00 | Money Out | Large |
| 3 | -300.00 | Money Out | Medium |
| 4 | -120.00 | Money Out | Small |
| 5 | -60.00 | Money Out | Small |
| 6 | -180.00 | Money Out | Small |
| 7 | 4500.00 | Money In | Large |
| 8 | -1500.00 | Money Out | Large |
| 9 | -320.00 | Money Out | Medium |
| 10 | -95.00 | Money Out | Small |

*…first 10 of 82 rows shown.*

You can have as many `CASE` columns as you like, and you can combine `CASE` with functions like `ABS()` from Part D. Using `ABS(amount)` lets one set of thresholds handle both credits and debits.

---

**Q31 — Customer loyalty tiers**

```sql
SELECT first_name,
       signup_date,
       CASE
           WHEN signup_date < '2021-01-01' THEN 'Veteran'
           WHEN signup_date < '2022-01-01' THEN 'Established'
           ELSE 'Newer'
       END AS loyalty_tier
FROM customers
ORDER BY signup_date;
```

**Expected output:**

| first_name | signup_date | loyalty_tier |
| --- | --- | --- |
| Jack | 2020-02-14 | Veteran |
| David | 2020-07-09 | Veteran |
| Grace | 2021-05-18 | Established |
| Brian | 2021-11-02 | Established |
| Alice | 2022-01-15 | Newer |
| Emma | 2022-09-30 | Newer |
| Henry | 2022-12-11 | Newer |
| Farhan | 2023-01-05 | Newer |
| Carla | 2023-03-22 | Newer |
| Isla | 2023-06-25 | Newer |

*10 rows.*

`CASE` works on dates and text just as well as on numbers. Turning raw values into business-friendly categories like this is one of the most common uses of `CASE` in reporting.

---

**Q32 — CASE inside ORDER BY**

```sql
SELECT account_id, account_type, balance
FROM accounts
ORDER BY CASE account_type
             WHEN 'Checking'    THEN 1
             WHEN 'Savings'     THEN 2
             ELSE 3
         END,
         account_id;
```

**Expected output:**

| account_id | account_type | balance |
| --- | --- | --- |
| 101 | Checking | 3500.00 |
| 103 | Checking | 1800.00 |
| 104 | Checking | 500.00 |
| 107 | Checking | 4200.00 |
| 108 | Checking | 2100.00 |
| 111 | Checking | 1500.00 |
| 112 | Checking | 0.00 |
| 102 | Savings | 12000.00 |
| 106 | Savings | 25000.00 |
| 110 | Savings | 8000.00 |
| 105 | Credit Card | -750.00 |
| 109 | Credit Card | -300.00 |
| 113 | Credit Card | -1200.00 |

*13 rows.*

Alphabetical order would put Checking, Credit Card, Savings. When you need a business-defined order, map each value to a sort number with `CASE` inside `ORDER BY`. This uses the *simple* form `CASE column WHEN value THEN ...`, which is a shorthand for equality tests.

---

## 15.6 Part F Solutions — Aggregate Functions

**Q33 — COUNT(*)**

```sql
SELECT COUNT(*) AS customer_count
FROM customers;
```

**Expected output:**

| customer_count |
| --- |
| 10 |

`COUNT(*)` counts rows. An aggregate function collapses many rows into **one** summary row.

---

**Q34 — COUNT with a WHERE filter**

```sql
SELECT COUNT(*) AS active_accounts
FROM accounts
WHERE status = 'Active';
```

**Expected output:**

| active_accounts |
| --- |
| 12 |

`WHERE` runs *before* the aggregate: it first keeps only the Active rows, then counts them.

---

**Q35 — SUM**

```sql
SELECT SUM(balance) AS total_active_balance
FROM accounts
WHERE status = 'Active';
```

**Expected output:**

| total_active_balance |
| --- |
| 56350.00 |

`SUM()` adds up a numeric column. Negative credit-card balances reduce the total, so this is a *net* figure.

---

**Q36 — MIN, MAX, and AVG together**

```sql
SELECT MIN(balance)           AS lowest_balance,
       MAX(balance)           AS highest_balance,
       ROUND(AVG(balance), 2) AS average_balance
FROM accounts;
```

**Expected output:**

| lowest_balance | highest_balance | average_balance |
| --- | --- | --- |
| -1200.00 | 25000.00 | 4334.62 |

You can use several aggregates in the same `SELECT`. `MIN` and `MAX` also work on dates and text. Keep this average in mind — in the advanced lab you'll find the accounts *above* it without having to copy the number by hand.

---

**Q37 — Aggregating a date range**

```sql
SELECT COUNT(*)    AS txn_count,
       SUM(amount) AS net_amount
FROM transactions
WHERE txn_date >= '2025-01-01'
  AND txn_date <  '2025-02-01';
```

**Expected output:**

| txn_count | net_amount |
| --- | --- |
| 28 | 16300.00 |

Combining a date-range `WHERE` (Part D) with aggregates gives quick month-level metrics. Because credits are positive and debits negative, a plain `SUM(amount)` is the net cash flow.

---

**Q38 — Conditional aggregation**

```sql
SELECT SUM(CASE WHEN amount > 0 THEN amount  ELSE 0 END) AS total_in,
       SUM(CASE WHEN amount < 0 THEN -amount ELSE 0 END) AS total_out,
       SUM(amount)                                      AS net_flow
FROM transactions;
```

**Expected output:**

| total_in | total_out | net_flow |
| --- | --- | --- |
| 67650.00 | 24366.00 | 43284.00 |

Putting a `CASE` **inside** an aggregate is called *conditional aggregation*: each row contributes to the sum only when its condition matches. It lets one pass over the table produce several different totals side by side. (`net_flow` = `total_in` − `total_out`, a useful sanity check.)

---

**Q39 — COUNT(DISTINCT ...)**

```sql
SELECT COUNT(DISTINCT account_id) AS accounts_with_activity
FROM transactions;
```

**Expected output:**

| accounts_with_activity |
| --- |
| 7 |

`COUNT(DISTINCT col)` counts unique values. Plain `COUNT(account_id)` would return 82 — one per transaction — because each account appears many times. Only 7 of the 13 accounts ever have activity in this dataset.

---

## 15.7 Part G Solutions — NULLs, INSERT, UPDATE, DELETE

**Q40 — Create a scratch table**

```sql
CREATE TABLE customers_practice (
    customer_id   INT PRIMARY KEY,
    first_name    VARCHAR(50) NOT NULL,
    last_name     VARCHAR(50) NOT NULL,
    email         VARCHAR(100),
    city          VARCHAR(50),
    signup_date   DATE
);

INSERT INTO customers_practice
SELECT * FROM customers;

SELECT COUNT(*) AS row_count
FROM customers_practice;
```

**Expected output:**

| row_count |
| --- |
| 10 |

You always practice data-changing statements (`INSERT`, `UPDATE`, `DELETE`) on a **scratch copy**, never on the shared lab tables — the rest of the lab (and the advanced lab) depends on the original data being untouched. `INSERT INTO ... SELECT ...` copies rows straight from a query.

---

**Q41 — INSERT new rows**

```sql
INSERT INTO customers_practice (customer_id, first_name, last_name, email, city, signup_date)
VALUES (11, 'Kara', 'Novak', NULL, 'Dallas', '2025-01-10'),
       (12, 'Leo',  'Park',  'leo.park@email.com', NULL, '2025-02-01');

SELECT *
FROM customers_practice
WHERE customer_id > 10;
```

**Expected output:**

| customer_id | first_name | last_name | email | city | signup_date |
| --- | --- | --- | --- | --- | --- |
| 11 | Kara | Novak | NULL | Dallas | 2025-01-10 |
| 12 | Leo | Park | leo.park@email.com | NULL | 2025-02-01 |

*2 rows.*

List the target columns, then the values in the same order. To store “unknown” use the keyword `NULL` (no quotes) — or simply leave the column out of the column list and it defaults to `NULL`. You can insert several rows in one statement by separating the value lists with commas.

---

**Q42 — IS NULL**

```sql
SELECT customer_id, first_name, last_name, email
FROM customers_practice
WHERE email IS NULL;

-- The common mistake (returns nothing):
SELECT customer_id, first_name, last_name, email
FROM customers_practice
WHERE email = NULL;
```

**Expected output:**

*Result of query 1:*

| customer_id | first_name | last_name | email |
| --- | --- | --- | --- |
| 11 | Kara | Novak | NULL |

*Result of query 2:*

| customer_id | first_name | last_name | email |
| --- | --- | --- | --- |

*0 rows.*

`NULL` means “unknown / no value,” and **nothing is equal to unknown — not even another NULL**. So `email = NULL` is never true and returns 0 rows. Use `IS NULL` and `IS NOT NULL`. This matters in finance: a `NULL` balance is not the same as a `0` balance.

---

**Q43 — COUNT(*) vs COUNT(column)**

```sql
SELECT COUNT(*)     AS all_rows,
       COUNT(email) AS rows_with_email,
       COUNT(city)  AS rows_with_city
FROM customers_practice;
```

**Expected output:**

| all_rows | rows_with_email | rows_with_city |
| --- | --- | --- |
| 12 | 11 | 11 |

`COUNT(*)` counts rows; `COUNT(column)` counts only rows where that column is **not NULL**. The same silent-skip rule applies to `SUM`, `AVG`, `MIN`, and `MAX` — they all ignore NULLs, so an `AVG` over a column with missing values is the average of the *known* values only.

---

**Q44 — COALESCE**

```sql
SELECT first_name,
       COALESCE(city, 'Unknown') AS city
FROM customers_practice
WHERE customer_id > 10;
```

**Expected output:**

| first_name | city |
| --- | --- |
| Kara | Dallas |
| Leo | Unknown |

*2 rows.*

`COALESCE(a, b, ...)` returns the first argument that is not NULL. It's the standard tool for supplying default values in reports. It also protects arithmetic: `NULL + 100` is `NULL`, but `COALESCE(x, 0) + 100` is never blank.

---

**Q45 — UPDATE with WHERE**

```sql
UPDATE customers_practice
SET email = 'kara.novak@email.com'
WHERE customer_id = 11;

UPDATE customers_practice
SET city = 'Denver'
WHERE customer_id = 12;

SELECT *
FROM customers_practice
WHERE customer_id > 10;
```

**Expected output:**

| customer_id | first_name | last_name | email | city | signup_date |
| --- | --- | --- | --- | --- | --- |
| 11 | Kara | Novak | kara.novak@email.com | Dallas | 2025-01-10 |
| 12 | Leo | Park | leo.park@email.com | Denver | 2025-02-01 |

*2 rows.*

`UPDATE table SET column = value WHERE condition`. **The `WHERE` clause is not optional in practice** — an `UPDATE` without one changes *every* row in the table. A good habit: write the `WHERE`, run it as a `SELECT` first to see which rows would change, then convert it to an `UPDATE`.

---

**Q46 — DELETE and DROP**

```sql
DELETE FROM customers_practice
WHERE signup_date >= '2025-01-01';

SELECT COUNT(*) AS remaining_rows
FROM customers_practice;

DROP TABLE customers_practice;
```

**Expected output:**

| remaining_rows |
| --- |
| 10 |

`DELETE FROM table WHERE condition` removes rows; like `UPDATE`, forgetting the `WHERE` affects every row. `DROP TABLE` removes the table itself. After this step the lab database is back to its original four tables. (In a real database you would normally wrap changes like these in a transaction — `BEGIN; ... COMMIT;` or `ROLLBACK;` — so a mistake can be undone.)

---

## 15.8 Part H Solutions — Review Challenges

**Q47 — Low-balance watch list**

```sql
SELECT account_id, customer_id, account_type, balance
FROM accounts
WHERE status = 'Active'
  AND balance < 1000
ORDER BY balance ASC;
```

**Expected output:**

| account_id | customer_id | account_type | balance |
| --- | --- | --- | --- |
| 113 | 9 | Credit Card | -1200.00 |
| 105 | 3 | Credit Card | -750.00 |
| 109 | 6 | Credit Card | -300.00 |
| 104 | 3 | Checking | 500.00 |

*4 rows.*

Filtering (Part B) + sorting (Part C). Inactive account 112 (balance 0) is correctly excluded by the status filter.

---

**Q48 — Five latest rent payments (and a limitation)**

```sql
SELECT transaction_id, account_id, txn_date, amount, description
FROM transactions
WHERE category_id = 6
ORDER BY txn_date DESC, transaction_id DESC
LIMIT 5;
```

**Expected output:**

| transaction_id | account_id | txn_date | amount | description |
| --- | --- | --- | --- | --- |
| 79 | 111 | 2025-03-02 | -1300.00 | Rent payment |
| 50 | 107 | 2025-03-02 | -1800.00 | Rent payment |
| 14 | 101 | 2025-03-02 | -1500.00 | Rent payment |
| 74 | 111 | 2025-02-02 | -1300.00 | Rent payment |
| 44 | 107 | 2025-02-02 | -1800.00 | Rent payment |

*5 rows.*

It works — but notice you had to *know* that category 6 means Rent. The `transactions` table only stores the number. Getting the name from the `categories` table requires a JOIN, which is where the advanced lab begins.

---

**Q49 — February grocery spend**

```sql
SELECT SUM(-amount) AS grocery_spend
FROM transactions
WHERE category_id = 2
  AND txn_date >= '2025-02-01'
  AND txn_date <  '2025-03-01';
```

**Expected output:**

| grocery_spend |
| --- |
| 1790.00 |

Combining a category filter, a half-open date range, and `SUM(-amount)` to flip the sign. This is a typical “one number for a dashboard tile” query.

---

**Q50 — Savings snapshot**

```sql
SELECT COUNT(*)                      AS savings_accounts,
       SUM(balance)                  AS total_balance,
       ROUND(SUM(balance) * 0.015, 2) AS projected_interest
FROM accounts
WHERE account_type = 'Savings';
```

**Expected output:**

| savings_accounts | total_balance | projected_interest |
| --- | --- | --- |
| 3 | 45000.00 | 675.00 |

You can do arithmetic on the *result* of an aggregate — here, multiplying the `SUM` by the interest rate.

---

**Q51 — One-row cash-flow summary**

```sql
SELECT COUNT(*)                                          AS txn_count,
       SUM(CASE WHEN amount > 0 THEN amount  ELSE 0 END) AS total_in,
       SUM(CASE WHEN amount < 0 THEN -amount ELSE 0 END) AS total_out,
       MAX(amount)                                       AS largest_credit,
       -MIN(amount)                                      AS largest_debit
FROM transactions;
```

**Expected output:**

| txn_count | total_in | total_out | largest_credit | largest_debit |
| --- | --- | --- | --- | --- |
| 82 | 67650.00 | 24366.00 | 6000.00 | 1800.00 |

A one-row executive summary built from conditional aggregation plus `MAX`/`MIN`. Because debits are stored as negatives, the *largest* debit is the **minimum** amount, and the leading minus sign turns it positive.

---
