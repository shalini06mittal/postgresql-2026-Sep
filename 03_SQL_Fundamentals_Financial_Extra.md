**SQL for Financial Analytics**

**A Hands-On Lab: Joins → Group By → Subqueries → Window Functions**

*Financial Track · Onboarding Lab for New Graduates*

Dataset: 4 tables — customers, accounts, categories, transactions

## Table of Contents

- [1. Introduction](#1-introduction)
  - [1.1 Learning Objectives](#11-learning-objectives)
  - [1.2 How This Lab Is Organized](#12-how-this-lab-is-organized)
- [2. Database Schema](#2-database-schema)
    - [2.1 customers](#21-customers)
    - [2.2 accounts](#22-accounts)
    - [2.3 categories](#23-categories)
    - [2.4 transactions](#24-transactions)
- [3. Setup Script — Create the Schema](#3-setup-script--create-the-schema)
- [4. Sample Data — Insert Statements](#4-sample-data--insert-statements)
  - [4.1 customers (10 rows)](#41-customers-10-rows)
  - [4.2 accounts (13 rows)](#42-accounts-13-rows)
  - [4.3 categories (8 rows)](#43-categories-8-rows)
  - [4.4 transactions (82 rows)](#44-transactions-82-rows)
- [5. SQL Practice: Joins vs Subqueries vs Window Functions](#5-sql-practice-joins-vs-subqueries-vs-window-functions)
- [SQL Practice: ADVANCE QUERIES](#sql-practice-advance-queries)
- [6. Part A — Joining Tables](#6-part-a--joining-tables)
- [7. Part B — Grouping and Aggregation](#7-part-b--grouping-and-aggregation)
- [8. Part C — Subqueries](#8-part-c--subqueries)
- [9. Part D — Window Functions](#9-part-d--window-functions)
- [10. Choosing the Right Tool](#10-choosing-the-right-tool)
- [11. Solutions](#11-solutions)
  - [11.1 Part A Solutions — Joins](#111-part-a-solutions--joins)
  - [11.2 Part B Solutions — Grouping and Aggregation](#112-part-b-solutions--grouping-and-aggregation)
  - [11.3 Part C Solutions — Subqueries](#113-part-c-solutions--subqueries)
  - [11.4 Part D Solutions — Window Functions](#114-part-d-solutions--window-functions)

# 1. Introduction

Welcome to the Financial Track SQL lab. Every task you'll do on the job — building a spend dashboard, reconciling accounts, flagging risky customers — comes down to combinations of four core techniques: joins, grouping/aggregation, subqueries, and window functions. This lab builds them up in that order, on a single realistic banking dataset, so you can see exactly where each technique starts to earn its keep and why the next one is needed.

## 1.1 Learning Objectives

- Combine data across related tables using INNER JOIN and LEFT JOIN.
- Summarize data with GROUP BY, aggregate functions, and HAVING.
- Use subqueries (scalar, IN, EXISTS, and derived tables) to filter or compare against computed values.
- Use window functions (ROW_NUMBER, RANK, SUM/AVG OVER, LAG) to compute running totals, rankings, and period-over-period changes without losing row-level detail.
- Recognize, for a given business question, which of the four tools is the natural fit — and why the others fall short.

## 1.2 How This Lab Is Organized

Part A through Part D each open with a short explanation of the concept and when it's the right tool, followed by a set of numbered questions ordered from easiest to hardest. Write your own query for each question before checking Section 7, which contains full solutions with explanations. The SQL in this lab uses standard ANSI syntax that runs, with no or minimal changes, on PostgreSQL, SQL Server, and MySQL 8+.

# 2. Database Schema

The dataset models a small retail bank. A customer can hold multiple accounts; each account has many transactions; each transaction belongs to a category (Salary, Groceries, Rent, etc.). This is a deliberately normalized, textbook “one-to-many-to-many” shape — exactly what you'll be joining and aggregating across in the exercises.

Relationships:

- customers (1) → (many) accounts — one customer can have several accounts (checking, savings, credit card).
- accounts (1) → (many) transactions — one account has many transactions over time.
- categories (1) → (many) transactions — one category (e.g. “Groceries”) applies to many transactions.

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
| status       | VARCHAR(10)         | 'Active' or 'Closed'.                                                      |
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

# 3. Setup Script — Create the Schema

Run this once to create the four tables. Foreign keys enforce the relationships described above.

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

Note: customer_id 10 (Jack Turner) has no row here on purpose — you'll use this to practice LEFT JOIN and anti-join patterns.

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

Note: accounts 112 (closed) and 113 have no transactions — another deliberate gap for NULL/LEFT JOIN handling.

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


# 5. SQL Practice: Joins vs Subqueries vs Window Functions

Schema: `customers`, `accounts`, `categories`, `transactions` (as given).

For each question, think about **what shape of answer you need** before picking a tool:
- **JOIN** → you need columns from two+ tables *combined side by side*, one row per matching pair.
- **Subquery** → you need to compare a row (or group) against a *computed scalar or set*, often filtering, and the comparison value isn't naturally "joinable" as a row.
- **Window function** → you need a per-row calculation that depends on *other rows in the same result set* (running totals, rank within a group, previous/next row) **while still keeping row-level detail**. The moment you hear "for each X, show Y and also its rank/running total/previous value **without collapsing rows**," think window function.

---
**Q1.** List every customer with their account type(s) and current balance.

**Q2.** Find customers who have never opened an account.

**Q3.** For customers with more than one account, show total balance across all their accounts.

**Q4.** For each account, show every transaction with a running (cumulative) balance of amounts, ordered by date.

**Q5.** Find customers whose total transaction amount is greater than the average total transaction amount across all customers.

**Q6.** For each account, find the single category the account spent the most money on.

**Q7.** List transactions where the amount is greater than the average transaction amount for that same account.

**Q8.** Find the second-highest-balance account for each customer.

**Q9.** List categories that have never appeared in any transaction.

**Q10.** For each customer, show every transaction date along with the number of days since their previous transaction.

- SOLUTIONS

**Q1.** List every customer with their account type(s) and current balance.

```sql
SELECT c.customer_id, c.first_name, c.last_name, a.account_type, a.balance
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id;
```

**Why JOIN:** We want customer columns and account columns living in the *same row*. No aggregation, no comparison against a computed value — just combining two tables on a key. A subquery would force us to pull account info one column at a time (ugly); a window function is irrelevant since nothing depends on "other rows."

---

**Q2.** Find customers who have never opened an account.

```sql
SELECT c.customer_id, c.first_name, c.last_name
FROM customers c
WHERE NOT EXISTS (
    SELECT 1 FROM accounts a WHERE a.customer_id = c.customer_id
);
```

**Why subquery (not JOIN):** This is a "prove absence" question. A plain JOIN only returns rows that *match* — it cannot directly express "no match exists" without an extra NULL-check trick (`LEFT JOIN ... WHERE a.account_id IS NULL`, which *is* a valid alternative, but conceptually it's still testing non-existence). `NOT EXISTS` states the intent directly. A window function makes no sense here — there is no per-row ranking or running calculation, just a yes/no membership test.

---

**Q3.** For customers with more than one account, show total balance across all their accounts.

```sql
SELECT c.customer_id, c.first_name, c.last_name, SUM(a.balance) AS total_balance
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING COUNT(a.account_id) > 1;
```

**Why JOIN + GROUP BY (not subquery, not window):** We need to *collapse* multiple account rows into one row per customer — that's exactly what GROUP BY does after a JOIN. A window function (`SUM() OVER (PARTITION BY customer_id)`) could compute the same total but would keep one row *per account*, then you'd need an extra step (DISTINCT or outer filter) to get one row per customer — more work for no benefit. A subquery isn't needed since nothing here is being compared to a separately-computed scalar.

---

**Q4.** For each account, show every transaction with a running (cumulative) balance of amounts, ordered by date.

```sql
SELECT account_id, transaction_id, txn_date, amount,
       SUM(amount) OVER (PARTITION BY account_id ORDER BY txn_date, transaction_id) AS running_total
FROM transactions;
```

**Why window function:** We must keep **every transaction row** visible *and* attach a value that depends on all prior rows *within the same account, in date order*. GROUP BY would collapse rows (losing transaction-level detail) — the opposite of what we want. A correlated subquery could technically compute this (`SUM(amount) WHERE account_id = t.account_id AND txn_date <= t.txn_date`), but it re-scans the table for every row, is slower, and is harder to read than `SUM() OVER (...)`, which was built exactly for this "cumulative, ordered, row-preserving" pattern.

---

**Q5.** Find customers whose total transaction amount is greater than the average total transaction amount across all customers.

```sql
SELECT customer_id, total_amount
FROM (
    SELECT a.customer_id, SUM(t.amount) AS total_amount
    FROM accounts a
    JOIN transactions t ON t.account_id = a.account_id
    GROUP BY a.customer_id
) per_customer
WHERE total_amount > (
    SELECT AVG(total_amount) FROM (
        SELECT a.customer_id, SUM(t.amount) AS total_amount
        FROM accounts a
        JOIN transactions t ON t.account_id = a.account_id
        GROUP BY a.customer_id
    ) x
);
```

**Why subquery (not just JOIN):** The filter condition (`> average of everyone`) requires a value computed by *aggregating across the whole result set first* — a JOIN alone has no way to compare a row against a value that itself depends on all rows. This is the classic "compare each group to an overall statistic" pattern, which is subquery territory. (Note: you *could* also write this with a window function — `AVG(total_amount) OVER ()` — since that also lets each row see an aggregate over the whole set without collapsing it. That's a legitimate alternative here, but the nested-subquery form above is often what's expected when the outer query needs to filter with `WHERE`, since window function results can't be used directly in `WHERE` — they'd require an extra wrapping query anyway, at which point the subquery approach is more direct.)

---

**Q6.** For each account, find the single category the account spent the most money on.

```sql
SELECT account_id, category_id, total_spent
FROM (
    SELECT t.account_id, t.category_id,
           SUM(t.amount) AS total_spent,
           ROW_NUMBER() OVER (PARTITION BY t.account_id ORDER BY SUM(t.amount) DESC) AS rn
    FROM transactions t
    WHERE t.txn_type = 'Debit'
    GROUP BY t.account_id, t.category_id
) ranked
WHERE rn = 1;
```

**Why window function (not plain JOIN/GROUP BY):** This is a "top-1 per group" problem. GROUP BY alone can give you the total per (account, category) pair, but it cannot then pick *only the top row per account* — `MAX()` would tell you the biggest total, not which category it belongs to, without another join back. `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)` ranks categories within each account in one pass, and we simply filter `rn = 1`. A join can't rank rows relative to each other — ranking is inherently a window-function job.

---

**Q7.** List transactions where the amount is greater than the average transaction amount for that same account.

**Option A — correlated subquery:**
```sql
SELECT t.*
FROM transactions t
WHERE t.amount > (
    SELECT AVG(t2.amount) FROM transactions t2 WHERE t2.account_id = t.account_id
);
```

**Option B — window function:**
```sql
SELECT *
FROM (
    SELECT t.*, AVG(t.amount) OVER (PARTITION BY t.account_id) AS avg_amount
    FROM transactions t
) x
WHERE amount > avg_amount;
```

**Why both exist here, and when each wins:** Both are legitimate; this question is designed to show the tradeoff. The correlated subquery re-runs `AVG()` for every single row (once per outer row) — clear to write, but potentially slow on large tables. The window function computes the per-account average *once per partition* internally and attaches it to every row in a single pass — generally faster and preferred for this kind of "compare row to its group's aggregate" task. Plain JOIN doesn't work at all here because there's no second table to join to — the comparison value comes from the *same* table, aggregated by a key, which is precisely what subqueries/window functions are for.

---

**Q8.** Find the second-highest-balance account for each customer.

```sql
SELECT customer_id, account_id, balance
FROM (
    SELECT a.customer_id, a.account_id, a.balance,
           DENSE_RANK() OVER (PARTITION BY a.customer_id ORDER BY a.balance DESC) AS rnk
    FROM accounts a
) ranked
WHERE rnk = 2;
```

**Why window function (not subquery):** "Nth highest per group" is a ranking problem, and ranking is defined *relative to other rows in the same partition* — the core use case for `RANK()`/`DENSE_RANK()`. Doing this with a correlated subquery is possible (`SELECT MAX(balance) WHERE balance < (SELECT MAX(balance) ... same customer)`) but gets awkward fast, especially with ties, and gets worse for "3rd highest," "4th highest," etc. `DENSE_RANK()` handles ties correctly and scales to any N by just changing the filter value. A plain JOIN has no concept of ranking at all.

---

**Q9.** List categories that have never appeared in any transaction.

```sql
SELECT c.category_id, c.category_name
FROM categories c
WHERE c.category_id NOT IN (
    SELECT DISTINCT t.category_id FROM transactions t
);
```

**Why subquery (not window function):** Same logic as Q2 — this is a set-membership / non-existence question ("is this category_id in the set of used category_ids?"), which is exactly what `NOT IN` / `NOT EXISTS` subqueries express. A window function operates *within* a result set to rank or aggregate rows that are already present — it has no way to represent "rows that don't exist in another table." (Tip: prefer `NOT EXISTS` over `NOT IN` in practice, since `NOT IN` behaves surprisingly if the subquery can return `NULL`.)

---

**Q10.** For each customer, show every transaction date along with the number of days since their previous transaction.

```sql
SELECT a.customer_id, t.transaction_id, t.txn_date,
       t.txn_date - LAG(t.txn_date) OVER (
           PARTITION BY a.customer_id ORDER BY t.txn_date, t.transaction_id
       ) AS days_since_previous
FROM transactions t
JOIN accounts a ON a.account_id = t.account_id;
```

**Why JOIN + window function together:** We need the JOIN just to get from `transactions` to `customer_id` (transactions only link directly to `accounts`). Once we have that combined row set, the actual question — "compare this row's date to the *previous* row's date, per customer" — needs `LAG()`, a window function built specifically for reaching into an adjacent row without a self-join. Doing this with a subquery would mean, for every transaction, re-querying for "the max date less than mine for this customer" — it works, but it's a slower and clumsier way to express "give me the previous row," which `LAG()` does natively.

---

**Quick decision guide**

| You need...                                                                   | Use                                                                  |
| ----------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| Columns from two+ tables in the same row                                      | **JOIN**                                                             |
| To test if something exists/doesn't exist in another table                    | **Subquery** (`EXISTS`/`NOT EXISTS`/`IN`)                            |
| To filter rows against a single computed value (avg, max, count)              | **Subquery**                                                         |
| A running total, moving average, or cumulative calculation                    | **Window function**                                                  |
| Rank, row number, or "top N per group" while keeping all rows                 | **Window function**                                                  |
| To compare each row to an aggregate of its own group, without collapsing rows | **Window function** (or correlated subquery — window usually faster) |
| The previous/next row's value within a group                                  | **Window function** (`LAG`/`LEAD`)                                   |
| To collapse many rows into one summary row per group                          | **GROUP BY** (with JOIN if needed), not a window function            |

# SQL Practice: ADVANCE QUERIES

# 6. Part A — Joining Tables

Every table above holds one slice of the picture: customers knows who someone is, accounts knows what they hold, transactions knows what moved. None of them alone can answer “which city does our biggest spender live in?” A JOIN stitches rows from two or more tables together on a matching key so you can query across that full picture in one go.

- INNER JOIN returns only rows that have a match on both sides — use it when a missing match means the row isn't relevant to the question.
- LEFT JOIN keeps every row from the left (“base”) table, filling in NULLs where there's no match on the right — use it when you specifically care about the unmatched cases (customers with no accounts, accounts with no transactions).

Try each question yourself before turning to Section 7.

**Q1.** List every account together with the first name, last name, and city of the customer who owns it.

**Q2.** List all customers and, where they exist, their account type and balance — including customers who don't have any account yet.

> ***Hint:*** *This is the same shape as Q1, but the join type has to change so that Jack Turner doesn't disappear from the results.*

**Q3.** Produce a full transaction log showing, for every transaction: the customer's full name, the account type, the transaction date, amount, and description.

> ***Hint:*** *You'll need to join three tables together — chain the joins on the keys that connect them.*

**Q4.** List each transaction's description, amount, and category name, but only for transactions in the 'Expense' category group.

**Q5.** Find every customer who does not have any account at all.

> ***Hint:*** *Start from a LEFT JOIN from customers to accounts, then filter for the rows where the join found nothing.*

# 7. Part B — Grouping and Aggregation

A join gives you more columns per row, but it doesn't reduce how many rows you have — join transactions to customers and you still have one row per transaction. GROUP BY takes the next step: it collapses many rows that share a value (e.g. all of one customer's transactions) into a single summary row, so you can use aggregate functions such as SUM, COUNT, and AVG. This is the tool for “how much / how many / on average” questions where you don't need to see the individual rows anymore.

- WHERE filters rows before grouping; HAVING filters groups after aggregation — use HAVING when your condition is on an aggregate value like SUM(amount).
- Whatever isn't wrapped in an aggregate function must appear in your GROUP BY clause.

**Q6.** For each customer, calculate their total spending (the sum of all debit transaction amounts, as a positive number).

> ***Hint:*** *Filter to txn_type = 'Debit' and remember amounts are stored as negative numbers — use SUM(-amount) or ABS().*

**Q7.** Count how many transactions fall into each category, ordered from most to least common.

**Q8.** For each account type, show total income and total expense side by side.

> ***Hint:*** *Use SUM(CASE WHEN txn_type = 'Credit' THEN amount ELSE 0 END) style conditional aggregation, joining transactions to accounts first.*

**Q9.** Find categories that have been used in more than 8 transactions, along with their average transaction amount.

> ***Hint:*** *This condition is on a group-level count, so it belongs in HAVING, not WHERE.*

**Q10.** For each customer, calculate total spending per calendar month (e.g. Alice — January — $2,240).

> ***Hint:*** *GROUP BY customer and by a month expression (e.g. DATE_TRUNC('month', txn_date) or TO_CHAR(txn_date,'YYYY-MM')). Keep this result in mind — Part D revisits it.*

# 8. Part C — Subqueries

Some questions need a value or a set of rows to be computed first, before your main filter can even be written — “accounts above the average balance” needs the average computed before you can compare anything to it. A subquery is a query nested inside another query that supplies exactly that: a single value, a list of values, or a whole derived table.

- Scalar subquery — returns a single value; usable anywhere a literal value could go, e.g. WHERE balance > (SELECT AVG(balance) FROM accounts).
- IN / NOT IN — the subquery returns a list of values to match against.
- EXISTS / NOT EXISTS — a correlated subquery (it references the outer row) that just checks whether any matching row exists; often faster than IN on large data and handles NULLs more safely.
- Derived table (subquery in FROM) — lets you aggregate first, then filter, join, or aggregate again on top of that result — useful when a single GROUP BY / HAVING can't express the logic.

A join alone can't do these, because a join doesn't compute a comparison value like “the average across everyone” — it can only match existing rows. A subquery computes that value first.

**Q11.** Find all accounts whose balance is greater than the average balance across all accounts.

> ***Hint:*** *A scalar subquery in the WHERE clause: WHERE balance > (SELECT AVG(balance) FROM accounts).*

**Q12.** Find the names of customers who hold at least one 'Credit Card' account.

> ***Hint:*** *Try it two ways: once with a subquery using IN, and once by rewriting it with EXISTS. Compare the two.*

**Q13.** Find customers who have never made a transaction in the 'Entertainment' category.

> ***Hint:*** *This is a NOT EXISTS correlated subquery: for each customer, check that no matching Entertainment transaction exists across any of their accounts.*

**Q14.** Find the category (or categories) with the single highest total expense amount.

> ***Hint:*** *Compute total expense per category in a derived table, then compare each row's total against MAX(total) from that same derived table in a subquery.*

**Q15.** Using a derived table (a subquery in the FROM clause) that computes each customer's total spending, list only the customers who have spent more than $2,000 in total.

> ***Hint:*** *Note this could also be written with GROUP BY ... HAVING directly — do that version too and compare. The derived-table version becomes essential once you need to join that summary back to other tables or aggregate it further.*

# 9. Part D — Window Functions

GROUP BY is powerful but destructive: once you group, the individual rows are gone. Real financial questions often need both at once — “show me every transaction, and next to each one, the running balance so far”, or “rank every customer by spend, but keep one row per customer with their details intact.” A window function computes an aggregate or ranking “over” a window of rows (a PARTITION, optionally ordered) without collapsing anything — every input row survives in the output.

- PARTITION BY divides rows into groups the way GROUP BY does, but each row keeps its own line in the output.
- ORDER BY inside OVER() controls running/cumulative calculations and ranking order.
- ROW_NUMBER() gives each row a unique sequential number; RANK() lets ties share a rank (and skips the next one).
- SUM()/AVG() OVER(... ORDER BY ...) with no frame defaults to a running/cumulative calculation up to the current row.
- LAG()/LEAD() reach into the previous/next row within the partition — ideal for period-over-period comparisons.

**Q16.** For each account, show every transaction with a running balance — the cumulative sum of amounts up to and including that transaction, ordered by date.

> ***Hint:*** *SUM(amount) OVER (PARTITION BY account_id ORDER BY txn_date, transaction_id).*

**Q17.** Rank customers by their total spending (highest spender = rank 1), keeping every customer in the output even if their spend ties with another's.

> ***Hint:*** *Build a CTE with total spend per customer (this is your Q6 query), then apply RANK() OVER (ORDER BY total_spend DESC) on top of it.*

**Q18.** For each customer, find their 3 largest individual transactions by amount.

> ***Hint:*** *ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY amount ASC) on debit amounts (most negative = largest expense), then filter to row number <= 3 in an outer query — window functions cannot be used directly in a WHERE clause.*

**Q19.** For each customer, show their total spend per month next to their spend from the previous month, and the dollar change between them.

> ***Hint:*** *Start from your Q10 monthly-spend result as a derived table/CTE, then apply LAG(total_spend) OVER (PARTITION BY customer_id ORDER BY month).*

**Q20.** For each customer, calculate a 3-month moving average of their monthly spend.

> ***Hint:*** *AVG(total_spend) OVER (PARTITION BY customer_id ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW).*

**Q21.** Bonus: split customers into four spending quartiles (1 = top spenders) based on total spend.

> ***Hint:*** *NTILE(4) OVER (ORDER BY total_spend DESC).*

# 10. Choosing the Right Tool

Before moving to the solutions, use this as a quick reference the next time you're staring at a business question and aren't sure where to start.

| Tool            | What it does                                                                                                                                       | Keeps row-level detail?       | Reach for it when…                                                                                                                                                            |
| --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| JOIN            | Combines columns from related tables into one result set.                                                                                          | Yes                           | You need data that lives in more than one table (e.g. a customer's name next to their transaction).                                                                           |
| GROUP BY        | Collapses many rows into one summary row per group.                                                                                                | No — rows are aggregated away | You need one summary number per category (totals, counts, averages) and don't need the individual rows anymore.                                                               |
| Subquery        | A query nested inside another query; runs first (or once per row for correlated subqueries) and feeds a value, set, or table into the outer query. | Depends on placement          | You need to filter or compare against a computed value (an average, a max, an existence check) before your main query can run, especially across multiple aggregation levels. |
| Window Function | Computes an aggregate/ranking ‘over’ a partition of rows, without collapsing them.                                                                 | Yes                           | You need a running total, rank, moving average, or period-over-period comparison alongside each individual row.                                                               |

A useful mental checklist:

- Do I need columns from more than one table? → JOIN.
- Do I need one summary row per group, and don't care about the individual rows anymore? → GROUP BY.
- Do I need to compare a row (or group) against a computed value, or check existence, before I can filter? → Subquery.
- Do I need a running total, rank, or comparison to a neighboring row, while still seeing every row? → Window function.
- Often the real answer is “all four, layered” — join to gather the columns, group to summarize, wrap it in a subquery/CTE, then apply a window function on top. That's exactly what Q17, Q19, and Q20 do.

# 11. Solutions

Try every question yourself first — the learning happens in the struggle, not in reading the answer. Each solution below includes a short “Why” note explaining the reasoning, not just the syntax.

## 11.1 Part A Solutions — Joins

**Q1 — Every account with its owner's name and city**

```sql
SELECT a.account_id, a.account_type, a.balance,
       c.first_name, c.last_name, c.city
FROM accounts a
INNER JOIN customers c ON a.customer_id = c.customer_id;
```

**Why:** Every account has exactly one owning customer, so an INNER JOIN is safe here — there's no case where we'd want an account row with a missing customer.

**Q2 — All customers, with accounts where they exist**

```sql
SELECT c.customer_id, c.first_name, c.last_name,
       a.account_type, a.balance
FROM customers c
LEFT JOIN accounts a ON c.customer_id = a.customer_id
ORDER BY c.customer_id;
```

**Why:** LEFT JOIN keeps customers (the left/base table) even when there's no matching account. Jack Turner (customer_id 10) appears once with account_type and balance both NULL.

**Q3 — Full transaction log with customer and account info**

```sql
SELECT c.first_name, c.last_name, a.account_type,
       t.txn_date, t.amount, t.description
FROM transactions t
INNER JOIN accounts a ON t.account_id = a.account_id
INNER JOIN customers c ON a.customer_id = c.customer_id
ORDER BY c.last_name, t.txn_date;
```

**Why:** A three-table chain: transactions link to accounts, accounts link to customers. Each JOIN uses the foreign key that connects those two tables.

**Q4 — Expense transactions with category name**

```sql
SELECT t.description, t.amount, cat.category_name
FROM transactions t
INNER JOIN categories cat ON t.category_id = cat.category_id
WHERE cat.category_group = 'Expense';
```

**Why:** The filter on category_group belongs in WHERE because it filters individual rows, not aggregated groups — there's no aggregation happening yet.

**Q5 — Customers with no account**

```sql
SELECT c.customer_id, c.first_name, c.last_name
FROM customers c
LEFT JOIN accounts a ON c.customer_id = a.customer_id
WHERE a.account_id IS NULL;
```

**Why:** This LEFT JOIN + IS NULL pattern is sometimes called an “anti-join”: keep only the left rows that found no match. Only Jack Turner qualifies in this dataset.

## 11.2 Part B Solutions — Grouping and Aggregation

**Q6 — Total spending per customer**

```sql
SELECT c.customer_id, c.first_name, c.last_name,
       SUM(-t.amount) AS total_spend
FROM customers c
JOIN accounts a ON c.customer_id = a.customer_id
JOIN transactions t ON a.account_id = t.account_id
WHERE t.txn_type = 'Debit'
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_spend DESC;
```

**Why:** Join first to bring customer, account, and transaction rows together, then GROUP BY the customer to collapse many transaction rows into one total per person. Debit amounts are stored negative, so SUM(-amount) reports spend as a positive figure.

**Q7 — Transaction count per category**

```sql
SELECT cat.category_name, COUNT(*) AS txn_count
FROM transactions t
JOIN categories cat ON t.category_id = cat.category_id
GROUP BY cat.category_name
ORDER BY txn_count DESC;
```

**Why:** COUNT(*) per group answers “how many”; no filtering on the aggregate is needed so HAVING isn't required here.

**Q8 — Income vs. expense by account type**

```sql
SELECT a.account_type,
       SUM(CASE WHEN t.txn_type = 'Credit' THEN t.amount ELSE 0 END) AS total_income,
       SUM(CASE WHEN t.txn_type = 'Debit' THEN -t.amount ELSE 0 END) AS total_expense
FROM accounts a
JOIN transactions t ON a.account_id = t.account_id
GROUP BY a.account_type;
```

**Why:** Conditional aggregation (SUM of a CASE expression) lets you compute two different sums from the same grouped rows in a single pass, instead of two separate grouped queries.

**Q9 — Categories used more than 8 times**

```sql
SELECT cat.category_name, COUNT(*) AS txn_count, AVG(t.amount) AS avg_amount
FROM transactions t
JOIN categories cat ON t.category_id = cat.category_id
GROUP BY cat.category_name
HAVING COUNT(*) > 8;
```

**Why:** COUNT(*) doesn't exist until after grouping, so it can't go in WHERE (which runs before grouping) — it has to go in HAVING, which filters the already-aggregated groups.

**Q10 — Monthly spend per customer**

```sql
SELECT c.customer_id, c.first_name, c.last_name,
       DATE_TRUNC('month', t.txn_date) AS spend_month,
       SUM(-t.amount) AS total_spend
FROM customers c
JOIN accounts a ON c.customer_id = a.customer_id
JOIN transactions t ON a.account_id = t.account_id
WHERE t.txn_type = 'Debit'
GROUP BY c.customer_id, c.first_name, c.last_name, DATE_TRUNC('month', t.txn_date)
ORDER BY c.customer_id, spend_month;

OR 

SELECT c.customer_id, c.first_name, c.last_name,
       to_char(DATE_TRUNC('month', t.txn_date), 'FMMonth') AS spend_month,
       SUM(-t.amount) AS total_spend
FROM customers c
JOIN accounts a ON c.customer_id = a.customer_id
JOIN transactions t ON a.account_id = t.account_id
WHERE t.txn_type = 'Debit'
GROUP BY c.customer_id, c.first_name, c.last_name, DATE_TRUNC('month', t.txn_date)
ORDER BY c.customer_id, DATE_TRUNC('month', t.txn_date);

```

**Why:** Grouping by both customer and month gives one row per customer per month. (In MySQL, replace DATE_TRUNC('month', t.txn_date) with DATE_FORMAT(t.txn_date, '%Y-%m-01').) Keep this query — Q19 and Q20 build directly on top of it.

## 11.3 Part C Solutions — Subqueries

**Q11 — Accounts above the average balance**

```sql
SELECT account_id, account_type, balance
FROM accounts
WHERE balance > (SELECT AVG(balance) FROM accounts);
```

**Why:** The scalar subquery runs once, produces a single number (the overall average), and the outer query compares every row against it. A join can't do this because there's no table of “averages” to join to — the value has to be computed first.

**Q12 — Customers with at least one credit card (two ways)**

```sql
-- Version 1: IN
SELECT first_name, last_name
FROM customers
WHERE customer_id IN (
    SELECT customer_id FROM accounts WHERE account_type = 'Credit Card'
);

-- Version 2: EXISTS (correlated)
SELECT first_name, last_name
FROM customers c
WHERE EXISTS (
    SELECT 1 FROM accounts a
    WHERE a.customer_id = c.customer_id AND a.account_type = 'Credit Card'
);
```

**Why:** IN checks membership in a fixed list computed once. EXISTS is correlated — it re-runs (conceptually) for each outer row, referencing c.customer_id — and stops as soon as it finds one match, which is why EXISTS tends to be the more efficient and NULL-safe choice on larger tables.

**Q13 — Customers who never spent on Entertainment**

```sql
SELECT c.first_name, c.last_name
FROM customers c
WHERE NOT EXISTS (
    SELECT 1
    FROM accounts a
    JOIN transactions t ON t.account_id = a.account_id
    JOIN categories cat ON t.category_id = cat.category_id
    WHERE a.customer_id = c.customer_id
      AND cat.category_name = 'Entertainment'
);
```

**Why:** NOT EXISTS asks, per customer, “does even one matching Entertainment transaction exist across any of their accounts?” and keeps the customer only if the answer is no. This correlated check across a multi-table path is exactly the kind of thing a plain join or GROUP BY can't express directly.

**Q14 — Category with the highest total expense**

```sql
SELECT category_name, total_expense
FROM (
    SELECT cat.category_name, SUM(-t.amount) AS total_expense
    FROM transactions t
    JOIN categories cat ON t.category_id = cat.category_id
    WHERE t.txn_type = 'Debit'
    GROUP BY cat.category_name
) cat_totals
WHERE total_expense = (SELECT MAX(total_expense) FROM (
    SELECT cat.category_name, SUM(-t.amount) AS total_expense
    FROM transactions t
    JOIN categories cat ON t.category_id = cat.category_id
    WHERE t.txn_type = 'Debit'
    GROUP BY cat.category_name
) inner_totals);
```

**Why:** This nests a derived table (aggregated category totals) inside a scalar subquery (the MAX of those totals), so it naturally returns every category tied for first place rather than an arbitrary single row the way ORDER BY ... LIMIT 1 would. In practice, you'd usually store the first derived table in a CTE (WITH cat_totals AS (...)) to avoid repeating it.

**Q15 — Customers who spent more than $2,000 (derived table)**

```sql
SELECT customer_id, first_name, last_name, total_spend
FROM (
    SELECT c.customer_id, c.first_name, c.last_name, SUM(-t.amount) AS total_spend
    FROM customers c
    JOIN accounts a ON c.customer_id = a.customer_id
    JOIN transactions t ON a.account_id = t.account_id
    WHERE t.txn_type = 'Debit'
    GROUP BY c.customer_id, c.first_name, c.last_name
) customer_spend
WHERE total_spend > 2000;

-- Equivalent using HAVING directly (no derived table needed for this simple case):
SELECT c.customer_id, c.first_name, c.last_name, SUM(-t.amount) AS total_spend
FROM customers c
JOIN accounts a ON c.customer_id = a.customer_id
JOIN transactions t ON a.account_id = t.account_id
WHERE t.txn_type = 'Debit'
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING SUM(-t.amount) > 2000;
```

**Why:** Both versions return the same rows here. The derived-table version is worth knowing because HAVING stops being enough once you need to join the summarized result to another table, rank it, or feed it into a window function — which is precisely what Part D does next.

## 11.4 Part D Solutions — Window Functions

**Q16 — Running balance per account**

```sql
SELECT account_id, txn_date, amount, description,
       SUM(amount) OVER (
           PARTITION BY account_id
           ORDER BY txn_date, transaction_id
       ) AS running_balance
FROM transactions
ORDER BY account_id, txn_date, transaction_id;
```

**Why:** PARTITION BY account_id restarts the running total for each account; ORDER BY inside OVER() makes SUM() accumulate row by row instead of summing the whole partition at once. Unlike GROUP BY, every transaction row still appears in the output.

**Q17 — Rank customers by total spend**

```sql
WITH customer_spend AS (
    SELECT c.customer_id, c.first_name, c.last_name, SUM(-t.amount) AS total_spend
    FROM customers c
    JOIN accounts a ON c.customer_id = a.customer_id
    JOIN transactions t ON a.account_id = t.account_id
    WHERE t.txn_type = 'Debit'
    GROUP BY c.customer_id, c.first_name, c.last_name
)
SELECT customer_id, first_name, last_name, total_spend,
       RANK() OVER (ORDER BY total_spend DESC) AS spend_rank
FROM customer_spend;
```

**Why:** The CTE reuses the Q6 logic to get one row per customer with their total spend, then RANK() OVER() assigns a position without collapsing any customer out of the result — which is the whole point versus just ORDER BY with no ranking column: everyone keeps their row, and ties share a rank.

**Q18 — Each customer's top 3 largest transactions**

```sql
SELECT customer_id, first_name, last_name, txn_date, amount, description
FROM (
    SELECT c.customer_id, c.first_name, c.last_name,
           t.txn_date, t.amount, t.description,
           ROW_NUMBER() OVER (
               PARTITION BY c.customer_id
               ORDER BY t.amount ASC
           ) AS rn
    FROM customers c
    JOIN accounts a ON c.customer_id = a.customer_id
    JOIN transactions t ON a.account_id = t.account_id
    WHERE t.txn_type = 'Debit'
) ranked
WHERE rn <= 3
ORDER BY customer_id, rn;
```

**Why:** Debit amounts are negative, so ORDER BY amount ASC puts the largest expenses first. ROW_NUMBER() must be wrapped in an outer query before you can filter on it in WHERE — window functions are evaluated after WHERE/GROUP BY/HAVING in the logical query order, so they can't be referenced directly in those clauses.

**Q19 — Month-over-month spend change**

```sql
WITH monthly_spend AS (
    SELECT c.customer_id, c.first_name, c.last_name,
           DATE_TRUNC('month', t.txn_date) AS spend_month,
           SUM(-t.amount) AS total_spend
    FROM customers c
    JOIN accounts a ON c.customer_id = a.customer_id
    JOIN transactions t ON a.account_id = t.account_id
    WHERE t.txn_type = 'Debit'
    GROUP BY c.customer_id, c.first_name, c.last_name, DATE_TRUNC('month', t.txn_date)
)
SELECT customer_id, first_name, last_name, spend_month, total_spend,
       LAG(total_spend) OVER (PARTITION BY customer_id ORDER BY spend_month) AS prev_month_spend,
       total_spend - LAG(total_spend) OVER (PARTITION BY customer_id ORDER BY spend_month) AS change
FROM monthly_spend
ORDER BY customer_id, spend_month;
```

**Why:** LAG() reaches back one row within each customer's partition (ordered by month) to pull the previous month's total onto the same row as the current month, so the subtraction can happen without a self-join. The first month for each customer shows NULL, since there's no prior month to compare to.

**Q20 — 3-month moving average of spend**

```sql
WITH monthly_spend AS (
    SELECT c.customer_id, c.first_name, c.last_name,
           DATE_TRUNC('month', t.txn_date) AS spend_month,
           SUM(-t.amount) AS total_spend
    FROM customers c
    JOIN accounts a ON c.customer_id = a.customer_id
    JOIN transactions t ON a.account_id = t.account_id
    WHERE t.txn_type = 'Debit'
    GROUP BY c.customer_id, c.first_name, c.last_name, DATE_TRUNC('month', t.txn_date)
)
SELECT customer_id, first_name, last_name, spend_month, total_spend,
       AVG(total_spend) OVER (
           PARTITION BY customer_id
           ORDER BY spend_month
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ) AS moving_avg_3mo
FROM monthly_spend
ORDER BY customer_id, spend_month;
```

**Why:** The explicit frame ROWS BETWEEN 2 PRECEDING AND CURRENT ROW tells AVG() to look at the current row plus the two before it within the same customer partition. For a customer's first or second month, the average is simply computed over however many prior months actually exist (1 or 2), not padded with zeros.

**Q21 (Bonus) — Spending quartiles**

```sql
WITH customer_spend AS (
    SELECT c.customer_id, c.first_name, c.last_name, SUM(-t.amount) AS total_spend
    FROM customers c
    JOIN accounts a ON c.customer_id = a.customer_id
    JOIN transactions t ON a.account_id = t.account_id
    WHERE t.txn_type = 'Debit'
    GROUP BY c.customer_id, c.first_name, c.last_name
)
SELECT customer_id, first_name, last_name, total_spend,
       NTILE(4) OVER (ORDER BY total_spend DESC) AS spend_quartile
FROM customer_spend;
```

**Why:** NTILE(4) splits the ordered rows into four roughly equal-sized buckets; quartile 1 holds the highest spenders since we ordered DESC. This is a common pattern for tiering customers for marketing or risk segmentation.

**End of lab.** Once these are comfortable, try combining techniques further: e.g. rank customers within their city, or flag any customer whose most recent month's spend is more than one standard deviation above their own historical average.
