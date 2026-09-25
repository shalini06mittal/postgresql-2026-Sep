-- for each manager get the count of direct reports and their total sales made by these direct reports
-- Alice -> Bob and Frank:  Sales -> Bob : 2, Frank: 4
-- select m.name, count(distinct e.id), sum(s.amount)
-- from employees e
-- join employees m on e.manager_id = m.id
-- left join sales s on s.emp_id = e.id
-- group by m.id , m.name;


-- select e.manager_id,count(e.id)
-- from employees e
-- group by e.manager_id;

-- Subqueries:
-- employees earning above the company average
-- scalar : one column one value
-- select name, salary
-- from employees
-- where salary > (select avg(salary) as average from employees);

-- select name, salary, t.average
-- from employees
-- cross join
-- (select avg(salary) as average from employees) t
-- where salary > t.average;

-- select name, salary , salary - (select avg(salary) as average from employees)
-- from employees;

-- ANY, ALL, IN

-- -- name of employees that belong to sales and hr
-- select name from employees
-- where dept_id in (select id from departments where name in ('Sales', 'HR'));

-- -- ANY / SOME: comparison satisfied by at least one value
-- SELECT name FROM employees
-- WHERE salary > ANY (SELECT salary FROM employees WHERE dept_id = 2);

-- -- ALL: comparison satisfied by every value
-- SELECT name FROM employees
-- WHERE salary > ALL (SELECT salary FROM employees WHERE dept_id = 2);

-- name of employees who made atleast one sale
-- select e.name
-- from employees e
-- where exists (select 1 from sales s where e.id = s.emp_id);

-- corelated subquery

-- employees earning the highest salary in their own department

-- select e.name, e.dept_id, e.salary
-- from employees e
-- where e.salary = (select max(salary) from employees where dept_id = e.dept_id);

-- subquery in having
-- select dept_id, sum(salary)
-- from employees
-- group by dept_id
-- having sum(salary) > (SELECT avg(salary) FROM employees);

-- CTE - common table expressions
-- with avg_salary as 
-- (SELECT avg(salary) as average FROM employees)

-- select dept_id, sum(salary)
-- from employees
-- group by dept_id
-- having sum(salary) > (select average from avg_salary);

-- WITH dept_stats AS (
--     SELECT dept_id, avg(salary) AS avg_salary, count(*) AS headcount
--     FROM employees
--     WHERE dept_id IS NOT NULL
--     GROUP BY dept_id
-- ),
-- big_depts AS (
--     SELECT dept_id FROM dept_stats WHERE headcount >= 3
-- )
-- SELECT e.name, e.salary, ds.avg_salary
-- FROM employees e
-- JOIN dept_stats ds USING (dept_id)
-- WHERE e.dept_id IN (SELECT dept_id FROM big_depts);

-- merge
-- create table m1(id int primary key, name varchar(50), salary int);
-- create table m2(id int primary key, name varchar(50), salary int);
-- insert into m1 values -- target
-- (1, 'Alice', 50),
-- (2, 'Bob', 60),
-- (3, 'Eve', 35);

-- insert into m2 values  -- source
-- (1, 'Alice', 50),
-- (2, 'Bob', 60),
-- (3, 'John', 45),
-- (4, 'John', 45);


-- merge into m1 as target
-- using m2 as source
-- on target.id = source.id

-- when matched then
-- 	update set name = source.name, salary = source.salary

-- when not matched then
-- 	insert (id, name, salary)

-- 	values (source.id, source.name, source.salary);


-- select * from m1;

-- window functions -> group by collapses the rows

-- select dept_id , avg(salary) from employees group by dept_id;

-- -- Window: every employee row, plus the department average alongside
-- SELECT name, dept_id, salary,
--        avg(salary) OVER (PARTITION BY dept_id) AS dept_avg
-- FROM employees;


-- index:
-- CREATE TABLE people (
--     id   INT PRIMARY KEY,
--     name VARCHAR(50),
--     city VARCHAR(50)
-- );

-- INSERT INTO people (id, name, city)
-- SELECT
--     n,
--     'Person_' || n,
--     CASE
--         WHEN n % 5 = 0 THEN 'Delhi'
--         WHEN n % 5 = 1 THEN 'Mumbai'
--         WHEN n % 5 = 2 THEN 'Pune'
--         WHEN n % 5 = 3 THEN 'Bangalore'
--         ELSE 'Chennai'
--     END
-- FROM generate_series(1, 100000) AS n;

-- SELECT COUNT(*) FROM people;

-- explain analyze
-- select name from people where city = 'Delhi';

-- create index idx_people_city on people (city);

-- inheritance

-- CREATE TABLE products (
--     id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
--     sku   text NOT NULL,
--     name  text NOT NULL,
--     price numeric(10,2) NOT NULL
-- );

-- CREATE TABLE physical_products (
--     weight_kg          numeric(6,2),
--     warehouse_location text
-- ) INHERITS (products);

-- CREATE TABLE digital_products (
--     download_url  text,
--     file_size_mb  numeric(8,2)
-- ) INHERITS (products);

-- INSERT INTO physical_products (id, sku, name, price, weight_kg, warehouse_location)
-- VALUES (1, 'PHY-001', 'Coffee Mug', 12.99, 0.35, 'Aisle 4');

-- INSERT INTO digital_products (id, sku, name, price, download_url, file_size_mb)
-- VALUES (2, 'DIG-001', 'E-book: PostgreSQL Basics', 9.99, 'https://example.com/ebook.pdf', 4.2);


-- select * from physical_products;

-- VIEWS : saved query and it behaves like a table whenever you need


-- create materialized view cust_transactions1 as 
-- select c.first_name, c.last_name,
-- 		a.account_type, a.status,
-- 		t.txn_date, t.amount, t.txn_type,
-- 		cat.category_name, cat.category_group
-- from customers c
-- join accounts a on c.customer_id = a.customer_id
-- join transactions t on a.account_id = t.account_id
-- join categories cat on cat.category_id = t.category_id;

-- refresh materialized view cust_transactions1 ;
-- select * from cust_transactions1 where txn_type='Credit';
-- INSERT INTO transactions (transaction_id, account_id, txn_date, amount, txn_type, category_id, description) 
-- VALUES (84, 101, '2026-01-01', 4500, 'Credit', 1, 'Monthly salary deposit');

-- Sequencing : it has to hand out the numbers

-- create sequence invoice_number_seq
-- start with 1000
-- increment by 1;

-- select nextval('invoice_number_seq');

-- create table invoices(
-- id bigint default nextval('invoice_number_seq') primary key, amount numeric(10,2)
-- );

-- insert into invoices(amount) values(23454.87), (23874.89);

-- select * from invoices;

-- select currval('invoice_number_seq');

CREATE TABLE legacy_orders (
    id serial PRIMARY KEY,
    note text
);

insert into legacy_orders(note) values('some not');
select currval('legacy_orders_id_seq');

