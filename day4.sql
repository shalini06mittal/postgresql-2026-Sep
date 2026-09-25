-- I want to get information dept name  and emp name
-- select e.name, d.name from employees e, departments d
-- where e.dept_id =  d.id;

-- where clause is ideally used for filtering
-- select e.name, d.name from 
-- employees e
-- join departments d
-- on e.dept_id =  d.id;

-- join 3 tables

-- select e.name, d.name, s.sale_date, amount from 
-- employees e
-- join departments d on e.dept_id =  d.id 
-- join sales s on s.emp_id=e.id
-- where s.amount > 500
-- order by s.amount desc;

-- order of execution : from / join, where, select and then last order by

-- get information of all employees irrespective they belong to a departmnet or not

-- select * from 
-- employees e
-- left join departments d on e.dept_id =  d.id ;

-- select * from 
-- employees e
-- right join departments d on e.dept_id =  d.id ;

-- select * from 
-- employees e
-- full outer join departments d on e.dept_id =  d.id ;

-- self join : where table joins itself
-- get the name of the employee and the name of the  manager they report to
-- select  concat(e.name, ' Reports To') as Name ,m.name as "Manager Name"
-- from employees e
-- join employees m
-- on m.id = e.manager_id;

-- "Debit"	"Lunch with friends"
-- "Debit"	"Utility bill"
-- "Debit"	"Streaming subscription"
-- "Debit"	"Family dinner"
-- "Debit"	"Concert ticket"
-- "Debit"	"Electricity & water bill"
-- "Debit"	"Movie night"
-- "Credit"	"Dividend payout"
-- "Debit"	"Restaurant"
-- "Debit"	"Dinner out"
-- "Debit"	"Rent payment"
-- "Debit"	"Grocery shopping"
-- "Debit"	"grocery shopping at dmart"
-- "Debit"	"Online shopping"
-- "Debit"	"New laptop bag"
-- "Credit"	"Monthly salary deposit"

-- distcint applies to the entire row for all the values in all the columns mentioned in select
-- select distinct txn_type, description, transaction_id from transactions;

-- select * from transactions;

-- find employees earning more than their colleagues in the same department


-- select distinct e1.name
-- from employees e1
-- join employees e2
-- on e1.dept_id = e2.dept_id and e1.salary > e2.salary; 

-- create table t1(id int primary key, data varchar(50));
-- create table t2(uid int primary key, metadata varchar(50), id int references t1(id));

-- insert into t1 values (1,'d1'),(2,'d2'),(3,'d3');

-- insert into t2 values (1,'d1 info', 1),(2,'d2 info', 2),(3,'d3 info', 1);


-- select data , metadata from t1 join t2 on t1.id = t2.id;

-- on can be replaced with shorthand using if pk and fk column name matches in both the tables.
-- select data , metadata from t1 join t2 using(id);

-- for null comparison never use = . Either use IS or EXISTS
-- select name from employees where dept_id is null;

-- for each manager get the count of direct reports and their total sales made by these direct reports

-- select dept_id, d.name, count(e.id) as "No Of Employees", sum(salary) as "Total Salary"
-- from employees e
-- join departments d on e.dept_id = d.id
-- where dept_id is not null
-- group by dept_id, d.name
-- having count(e.id) > 1
-- order by dept_id;

-- INSERT INTO employees VALUES
--     (9, 'Sam', NULL, NULL, 250000, '2016-03-01');
	

-- select  m.name, count(distinct e.id), sum(amount)
-- from employees e
--  join employees m
-- on e.manager_id = m.id
-- left join sales s on s.emp_id = e.id
-- -- join sales s on s.emp_id = e.id
-- group by m.id, m.name 
-- order by count(distinct e.id) desc;

-- SELECT m.name                        AS manager,
--        COUNT(DISTINCT r.id)          AS direct_reports,
--        COALESCE(SUM(s.amount), 0.00) AS team_sales
-- FROM employees m
-- JOIN employees r       ON r.manager_id = m.id
-- LEFT JOIN sales s      ON s.emp_id = r.id
-- GROUP BY m.id, m.name
-- ORDER BY team_sales DESC;

-- IN: membership in a subquery result
SELECT name, dept_id FROM employees
WHERE dept_id IN (SELECT id FROM departments WHERE name IN ('Sales', 'HR'));


SELECT id FROM departments WHERE name IN ('Sales', 'HR');

select * from employees;

select e.name, e.dept_id
from employees e, departments d where e.dept_id = d.id and d.name IN ('Sales', 'HR');

-- ANY / SOME: comparison satisfied by at least one value
-- SELECT name FROM employees
-- WHERE salary > ANY (SELECT salary FROM employees WHERE dept_id = 2);

-- -- ALL: comparison satisfied by every value
-- SELECT name FROM employees
-- WHERE salary > ALL (SELECT salary FROM employees WHERE dept_id = 2);



SELECT e.manager_id, e.name,
       COUNT(DISTINCT e.id) AS direct_reports,
       SUM(s.amount)        AS team_sales
FROM employees e
LEFT JOIN sales s ON s.emp_id = e.id
WHERE e.manager_id IS NOT NULL
GROUP BY e.manager_id, e.name
ORDER BY e.manager_id;

SELECT * FROM departments d
WHERE NOT exists (SELECT dept_id FROM employees e WHERE e.dept_id = d.id); 

SELECT name, dept_id, salary,
       avg(salary) OVER (PARTITION BY dept_id) AS dept_avg
FROM employees;

