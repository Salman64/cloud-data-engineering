-- ============================================================
--   ASSIGNMENT 05 — INDEXES, VIEWS & WINDOW FUNCTIONS
--   Database  : BikeStores
--   Topics    : Indexes (Clustered & Non-Clustered)
--               Views
--               ROW_NUMBER / RANK / DENSE_RANK
--               LAG / LEAD
--               COALESCE
-- ============================================================


-- ============================================================
--  SECTION A — INDEXES
-- ============================================================

-- Q1.
-- The marketing team frequently runs campaigns filtered by brand.
-- They search products like this:
--
--   SELECT product_id, product_name, list_price
--   FROM production.products
--   WHERE brand_id = 3;
--
-- This query is slow. Create an appropriate index to fix it.
-- Then run the query to confirm it returns results correctly.

SELECT product_id, product_name, list_price
  FROM production.products
 WHERE brand_id = 3;

 CREATE NONCLUSTERED INDEX ix_products_brand_id
ON production.products(brand_id);

-- Q2.
-- The finance team runs a monthly report that filters orders
-- by a date range, for example:
--
--   SELECT order_id, customer_id, order_date
--   FROM sales.orders
--   WHERE order_date BETWEEN '2018-01-01' AND '2018-06-30';
--
-- Create an index to make this query more efficient.

SELECT order_id, customer_id, order_date
  FROM sales.orders
 WHERE order_date BETWEEN '2018-01-01' AND '2018-06-30';

 CREATE NONCLUSTERED INDEX ix_sales_order_date
ON sales.orders(order_date);

-- ============================================================
--  SECTION B — VIEWS
-- ============================================================

-- Q3.
-- The customer support team needs a daily list of all
-- pending and processing orders so they can follow up.
-- Create a view that shows:
--   order_id, customer full name, phone, email,
--   order_date, and order status as a readable label
--   (not a number — use 1=Pending, 2=Processing).
-- After creating it, query the view to see today's workload.

CREATE VIEW sales.vw_pending_processing_orders_list
(
    order_id,
    full_name,
    phone,
    email,
    order_date,
    Order_status
)
AS
SELECT
    o.order_id,
    c.first_name + ' ' + c.last_name AS full_name,
    c.phone,
    c.email,
    o.order_date,
    CASE o.order_status
        WHEN 1 THEN 'Pending'
        WHEN 2 THEN 'Processing'
        WHEN 3 THEN 'Rejected'
        WHEN 4 THEN 'Completed'
        ELSE 'Unknown'
    END AS Order_status
FROM sales.orders o
JOIN sales.customers c
    ON o.customer_id = c.customer_id
WHERE o.order_status IN (1, 2);


-- Q4.
-- The inventory manager wants a single view to monitor stock
-- across all stores without writing complex joins every time.
-- Create a view that shows:
--   store_name, product_name, brand_name, category_name, quantity
-- After creating it, query the view to find all products
-- that have fewer than 3 units remaining in any store.

CREATE VIEW vw_stock_store as 
select s.store_name, pp.product_name, b.brand_name, c.category_name, ps.quantity
from sales.stores s
join production.stocks ps
on s.store_id = ps.store_id
join production.products pp
on pp.product_id = ps.product_id
join production.brands b
on pp.brand_id = b.brand_id
join production.categories c
on pp.category_id = c.category_id

select * from vw_stock_store;

-- ============================================================
--  SECTION C — ROW_NUMBER, RANK & DENSE_RANK
-- ============================================================

-- Q5.
-- The sales director wants to see the top 2 best-selling products
-- per store based on total quantity sold.
-- Show store_id, product_id, total_quantity, and their rank within the store.
-- Return only rank 1 and rank 2 for each store.

WITH ProductSales AS
(
    select
        o.store_id,
        oi.product_id,
        SUM(oi.quantity) AS total_quantity
    from sales.orders o
    join sales.order_items oi
        on o.order_id = oi.order_id
    group by
        o.store_id,
        oi.product_id
),
RankedProducts AS
(
    select
        store_id,
        product_id,
        total_quantity,
        RANK() OVER
        (
            PARTITION BY store_id
            order by total_quantity DESC
        ) AS product_rank
    from ProductSales
)
select
    store_id,
    product_id,
    total_quantity,
    product_rank AS [rank]
from RankedProducts
where product_rank <= 2
order by
    store_id,
    product_rank,
    total_quantity DESC;

-- Q6.
-- The pricing team wants to find the 2nd most expensive product
-- in each category.
-- Show category_id, product_name, list_price, and their price rank
-- within the category.
-- Return only the products ranked 2nd in their category.

WITH RankedProductsByPrice AS
(
    select
        p.category_id,
        p.product_id,
        p.list_price,
        DENSE_RANK() OVER (partition by p.category_id order by p.list_price desc) AS Ranked_Product
    from production.products p
)
select
    category_id,
    product_id,
    list_price,
    Ranked_Product
from RankedProductsByPrice
where Ranked_Product = 2
order bY
    category_id,
    product_id,
    list_price DESC;

-- Q7.
-- The data team suspects there are duplicate customer records.
-- Use the test table below (already has duplicates built in).
-- Write a query to identify the duplicate rows
-- (same first_name, last_name, and phone).
-- Return only the duplicates — not the original/first occurrence.
--
-- Run this setup first:
--
-- CREATE TABLE test_customers (
--     customer_id  INT,
--     first_name   VARCHAR(50),
--     last_name    VARCHAR(50),
--     phone        VARCHAR(20),
--     city         VARCHAR(50)
-- );
--
-- INSERT INTO test_customers VALUES
--     (1,  'Ali',    'Khan',    '0300-1111111', 'Karachi'),
--     (2,  'Sara',   'Ahmed',   '0321-2222222', 'Lahore'),
--     (3,  'Ali',    'Khan',    '0300-1111111', 'Karachi'),   -- duplicate of 1
--     (4,  'Usman',  'Malik',   '0333-3333333', 'Islamabad'),
--     (5,  'Sara',   'Ahmed',   '0321-2222222', 'Lahore'),   -- duplicate of 2
--     (6,  'Sara',   'Ahmed',   '0321-2222222', 'Lahore'),   -- 3rd copy of 2
--     (7,  'Hina',   'Raza',    '0312-4444444', 'Peshawar');
--
-- Now write your query to find the duplicate rows.

CREATE TABLE test_customers (
     customer_id  INT,
     first_name   VARCHAR(50),
     last_name    VARCHAR(50),
     phone        VARCHAR(20),
     city         VARCHAR(50)
 );
--
 INSERT INTO test_customers VALUES
     (1,  'Ali',    'Khan',    '0300-1111111', 'Karachi'),
     (2,  'Sara',   'Ahmed',   '0321-2222222', 'Lahore'),
     (3,  'Ali',    'Khan',    '0300-1111111', 'Karachi'),   -- duplicate of 1
     (4,  'Usman',  'Malik',   '0333-3333333', 'Islamabad'),
     (5,  'Sara',   'Ahmed',   '0321-2222222', 'Lahore'),   -- duplicate of 2
     (6,  'Sara',   'Ahmed',   '0321-2222222', 'Lahore'),   -- 3rd copy of 2
     (7,  'Hina',   'Raza',    '0312-4444444', 'Peshawar');
--
-- Now write your query to find the duplicate rows.

with cte_row_num 
AS (
SELECT 
	customer_id,
   ROW_NUMBER() OVER (
	partition by first_name, last_name
	order by first_name
   ) row_num,
   first_name, 
   last_name, 
   city
FROM 
   test_customers
   )
select * 
from cte_row_num
where customer_id IN (select customer_id from cte_row_num where row_num > 1);

-- ============================================================
--  SECTION D — LAG, LEAD & COALESCE
-- ============================================================

-- Q8.
-- The finance team wants a month-by-month revenue report for 2017.
-- For each month, show total net sales and how much it grew or
-- dropped compared to the previous month.
-- Show month, net_sales, previous_month_sales, and the difference.
-- Net sales = SUM( quantity * list_price * (1 - discount) )

WITH cte_netsales_2017 AS(
	SELECT 
	month(o.order_date)  as month_order,
    sum(
		ot.quantity * ot.list_price * (1 - ot.discount)
	) as net_sales,
	year(o.order_date) as year_order
from sales.orders o
	 join sales.order_items ot
	 on ot.order_id =  o.order_id
where year(o.order_date) = 2017
group by 
		year(o.order_date), month(o.order_date)
)
--select * from cte_netsales_2017

SELECT 
	month_order,
	net_sales,
	LAG(net_sales,1) OVER (
		ORDER BY month_order
	) previous_month_sales
FROM 
	cte_netsales_2017;

-- Q9.
-- The product team wants to see each product's price compared to
-- the next cheaper product in the same category.
-- Show product_name, list_price, and the next lower price
-- in the same category.
-- Sort by category_id and list_price descending.

WITH RankedProductsByPrice AS
(
    SELECT
        p.category_id,
        p.product_name,
        p.list_price,
        LEAD(p.list_price, 1) OVER
        (
            PARTITION BY p.category_id
            ORDER BY p.list_price DESC
        ) AS lower_price
    FROM production.products p
)
SELECT
    category_id,
    product_name,
    list_price,
    lower_price
FROM RankedProductsByPrice
ORDER BY
    category_id,
    list_price DESC;

-- Q10.
-- The CRM team is cleaning up customer records.
-- Some customers have no phone number on file.
-- Show each customer's full name, phone, and email.
-- Replace any missing phone with their email address instead.
-- If both are missing, show 'No Contact Info'.
-- Sort by last_name, first_name.

select
    first_name+ ' '+last_name AS full_name,
    COALESCE(phone, email, 'No Contact Info') AS contact_info,
    email
from sales.customers
order by  last_name, first_name;

-- ============================================================
--  END OF ASSIGNMENT 05
-- ============================================================
