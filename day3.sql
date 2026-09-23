-- UNIQUE KEY

-- ALLOWS DUPLICATE NULL
-- CREATE TABLE users (
--     id    bigint PRIMARY KEY,
--     email text UNIQUE
-- );

-- INSERT INTO users VALUES (1, 'alice@gmail.com');
-- INSERT INTO users VALUES (2, 'alice@gmail.com');
-- INSERT INTO users VALUES (3, null);
-- INSERT INTO users VALUES (4, null);

-- select * from users;

-- drop table users;

-- NOT ALLOW DUPLICATE NULL
-- CREATE TABLE users (
--     id    bigint PRIMARY KEY,
--     email text,
--     CONSTRAINT uq_users_email
--         UNIQUE NULLS NOT DISTINCT (email)
-- );

-- INSERT INTO users VALUES (1, 'alice@gmail.com');
-- INSERT INTO users VALUES (2, 'ALICE@gmail.com');
-- INSERT INTO users VALUES (3, null);
-- INSERT INTO users VALUES (4, null);

-- select * from users;

-- drop table users;
-- CASE SENSITIVE EXPRESSION INDEX UNIQUE CONSTRAINT
-- CREATE TABLE users (
--     id    bigint PRIMARY KEY,
--     email text
-- );

-- CREATE UNIQUE INDEX uq_users_lower_email ON users (lower(email));

-- INSERT INTO users VALUES (1, 'alice@gmail.com');
-- INSERT INTO users VALUES (2, 'ALICE@gmail.com');
-- INSERT INTO users VALUES (3, null);
-- INSERT INTO users VALUES (4, null);

-- select * from users;

-- PARTIAL UNIQUENESS
-- drop table users;
-- CREATE TABLE users (
--     id         bigint PRIMARY KEY,
--     username   text,
--     deleted_at timestamp
-- );

-- CREATE UNIQUE INDEX uq_active_username
-- ON users (username)
-- WHERE deleted_at IS NULL;

-- INSERT INTO users (id, username, deleted_at)
-- VALUES (20, 'SHALINI', NULL),
-- (22, 'alice', NULL),
-- (21, 'bob', '2026-01-01');

-- select * from users;

-- INSERT INTO users (id, username, deleted_at)
-- VALUES (24, 'bob', NULL);

-- 02_SQL_FINANCIAL_LAB : PRACTICE DQL
-- from then select
-- SELECT *  
-- from customers where city='Chicago' and signup_date='2022-12-11';

-- select * from customers where signup_date < '2022-12-31';

-- select * from customers where city in('Chicago', 'New York');

-- select * from transactions where txn_type='Credit' and (amount between 3000 and 4500);

-- select * from transactions where txn_type='Credit' and (amount > 3000 and amount <= 4500);

-- select count(*) from transactions where txn_type='Credit';

 -- select account_id, balance, 'USD' as currency from accounts;

 -- select * from customers where last_name like '%n';

 -- select * from customers where last_name like '%e_';

-- update transactions set description='grocery shopping at dmart' where transaction_id=15;
 -- select * from transactions where description like '%shopping%' order by transaction_id;

 -- select * from accounts where account_type <> 'Savings'; 

 -- select * from accounts where account_type NOT IN ('Savings'); 

 -- select * from transactions order by txn_type, category_id limit 20;

 -- select distinct account_type from accounts;

 -- Top 5 largest debits

 -- select * from transactions
 -- where txn_type='Debit'
 -- order by amount asc
 -- limit 5;

 -- 5 latest transactions

 -- select * from transactions
 -- order by txn_date desc
 -- limit 5;

-- use offset for pagination
-- select * from transactions
--  order by txn_date desc
--  limit 5 offset 5;

-- select amount, description, abs(amount) as AMT_POS
-- from transactions
-- where txn_type='Debit';

-- select customer_id, concat(first_name, ' ', last_name) as FULL_NAME from customers;

-- select customer_id, concat(upper(first_name), ' ', last_name) as FULL_NAME,
-- upper(substring(city,1,3)) as city_code, city
-- from customers;

-- DATE PARTS
-- select transaction_id, txn_date, extract(year from txn_date) as txn_year,
-- extract(month from txn_date) as txn_month,
-- to_char(txn_date, 'Month') as "Month",
-- to_char(txn_date, 'Mon') as "Abbr Month"
-- from transactions limit 20;

-- BASED ON BALANCE NEED TO GIVE THEM A BAND

-- select account_id, account_type,
-- balance,
-- 	case
-- 		when balance < 0 then 'overdrawn'
-- 		when balance < 1000 then 'low'
-- 		when balance < 10000 then 'moderate'
-- 		else 'high'
-- 	end as balance_band
-- from accounts;

-- select * 
-- from accounts 
-- order by 
-- 	case 
-- 		account_type
-- 		when 'Checking' then 1
-- 		when 'Savings' then 2
-- 		else 3
-- 	end, account_id;

--  aggregate functions : count, sum, min, max, avg

-- select count(*) from customers;

-- select count(email) as "have emails", count(*) as total from customers;
-- select min(balance), max(balance), avg(balance) from accounts;

-- select count(*) as "Count", sum(amount) as Amount
-- from transactions
-- where txn_date >= '2025-01-01'
--   AND txn_date <  '2025-02-01';

select sum(case when amount > 0 then amount else 0 end) as total_in ,
sum(case when amount < 0 then -amount else 0 end) as total_out,
sum(amount) as net_flow
from transactions;


 

