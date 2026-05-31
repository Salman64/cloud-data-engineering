-- ============================================================
--   ASSIGNMENT 04 — SET OPERATORS, CTEs, CONSTRAINTS & CASES
--   Database  : BikeStores
--   Topics    : UNION / UNION ALL / INTERSECT / EXCEPT
--               CTEs (Single & Multiple)
--               Constraints (PK, FK, NOT NULL, UNIQUE, CHECK)
--               CASE Expressions
-- ============================================================


-- ============================================================
--  SECTION A — SET OPERATORS
-- ============================================================

-- Q1.
-- The marketing team wants a single contact list of everyone in the system
-- — both staff members and customers.
-- Build a unified list showing full name and email for all of them.
-- Make sure no one is accidentally listed twice.

select 
	first_name+ ' ' + last_name as full_Name, email
from sales.staffs

union

select 
	first_name+ ' ' + last_name as full_Name, email
from sales.customers;

-- Q2.
-- The logistics team wants to know which states have BOTH
-- a store location AND customers living there.
-- Find those states.

select state
from 
	sales.stores

intersect

select state 
from 
	sales.customers;

-- Q3.
-- Management wants to identify stores that received zero orders
-- in the year 2018.
-- Find the store_ids that appear in sales.stores but did NOT
-- receive any orders in 2018.

select store_id 
from
	sales.stores

except 

select store_id
from
	sales.orders
where YEAR (order_date) = 2018;

-- ============================================================
--  SECTION B — CTEs
-- ============================================================

-- Q4.
-- The pricing team wants to flag overpriced products.
-- For each category, find all products whose list_price is
-- higher than the average list_price of their own category.
-- Show category_id, product_name, list_price, and the category average.

 with categoryAvg as (
    select 
        category_id,
        avg(list_price) as avg_price
    from production.products
    group by category_id
)
select 
    p.category_id,
    p.product_name,
    p.list_price,
    c.avg_price
from production.products p
join categoryAvg c
    on p.category_id = c.category_id
where p.list_price > c.avg_price;

-- Q5.
-- HR wants to reward the hardest-working staff member.
-- Find all staff members whose order count is higher than
-- the average order count across all staff.
-- Show staff_id and their order_count.

with cte_staff_or (staff_id,order_count) as
(
    select staff_id,
          count(order_id) as order_count
    from sales.orders 
    group by staff_id
) 
    select 
        staff_id,
        order_count
     from cte_staff_or
     where order_count > 
     (
        select avg(order_count)
        from cte_staff_or
     );

-- Q6.
-- The finance team needs a yearly performance report per store.
-- For each store and each year, calculate total revenue.
-- Then find only the years where a store's revenue
-- exceeded $1,000,000.
-- Show store_id, year, and total_revenue.

with cte_sy_revenue (store_id, years, total_revenue) 
as
(
    select o.store_id,
        Year(order_date) as years,
        sum(oi.quantity * oi.list_price * (1 -oi.discount)) as total_revenue
        from sales.orders o
        join sales.order_items oi
        on o.order_id = oi.order_id
        group by o.store_id,
        Year(order_date)
        

)
select 
    store_id,
    years,
    total_revenue
from cte_sy_revenue
where total_revenue >1000000;

-- ============================================================
--  SECTION C — CONSTRAINTS (DDL)
-- ============================================================

-- Q7.
-- The business wants to launch a customer loyalty program.
-- Below is the table structure. Your job is to add the correct constraints:
--   - Each card must have a unique card number (not auto-generated).
--   - The card must be linked to a valid customer in sales.customers.
--   - Points balance cannot be negative.
--   - Tier must be one of: 'Bronze', 'Silver', or 'Gold'.
--   - Join date is required and cannot be empty.
--   - If a customer is deleted, their loyalty card record should also be deleted.
--
-- Starter table (add your constraints here):
--
-- CREATE TABLE sales.loyalty_cards (
--     card_number   INT,
--     customer_id   INT,
--     points        INT,
--     tier          VARCHAR(10),
--     join_date     DATE
-- );
--
-- Once the table is created, run these inserts to verify your constraints work:
--
-- INSERT INTO sales.loyalty_cards VALUES (1001, 1,  500,  'Gold',   '2024-01-15');
-- INSERT INTO sales.loyalty_cards VALUES (1002, 2,  150,  'Silver', '2024-03-22');
-- INSERT INTO sales.loyalty_cards VALUES (1003, 3,  0,    'Bronze', '2024-06-01');
--
-- Also try these to confirm your constraints REJECT bad data:
-- INSERT INTO sales.loyalty_cards VALUES (1001, 4,  100,  'Gold',   '2024-07-01'); -- duplicate card_number
-- INSERT INTO sales.loyalty_cards VALUES (1004, 1,  -50,  'Silver', '2024-08-01'); -- negative points
-- INSERT INTO sales.loyalty_cards VALUES (1005, 5,  200,  'Diamond','2024-09-01'); -- invalid tier

CREATE TABLE sales.loyalty_cards (
    card_number INT,
    customer_id INT,
    points INT NOT NULL,
    tier VARCHAR(10) NOT NULL,
    join_date DATE,

    CONSTRAINT PK_loyalty_cards
        PRIMARY KEY (card_number),

    CONSTRAINT CK_points
        CHECK (points >= 0),

    CONSTRAINT CK_tier
        CHECK (tier IN ('Bronze', 'Silver', 'Gold')),

    CONSTRAINT FK_loyalty_customer
        FOREIGN KEY (customer_id)
        REFERENCES sales.customers(customer_id)
        ON DELETE CASCADE
);
INSERT INTO sales.loyalty_cards VALUES (1001, 1,  500,  'Gold',   '2024-01-15');
INSERT INTO sales.loyalty_cards VALUES (1002, 2,  150,  'Silver', '2024-03-22');
INSERT INTO sales.loyalty_cards VALUES (1003, 3,  0,    'Bronze', '2024-06-01');

INSERT INTO sales.loyalty_cards VALUES (1001, 4,  100,  'Gold',   '2024-07-01'); -- duplicate card_number
INSERT INTO sales.loyalty_cards VALUES (1004, 1,  -50,  'Silver', '2024-08-01'); -- negative points
INSERT INTO sales.loyalty_cards VALUES (1005, 5,  200,  'Diamond','2024-09-01'); -- invalid tier

-- Q8.
-- The operations team realized that some orders in the database have
-- a shipped_date that is earlier than the order_date, which is impossible.
-- Add a rule to the table below that prevents this from happening.
-- Then try inserting a valid row and an invalid row to confirm it works.
--
-- Run this setup first:
--
-- CREATE TABLE test_orders (
--     order_id      INT PRIMARY KEY,
--     order_date    DATE NOT NULL,
--     shipped_date  DATE
-- );
--
-- INSERT INTO test_orders VALUES (1, '2024-01-10', '2024-01-13');
-- INSERT INTO test_orders VALUES (2, '2024-02-05', '2024-02-07');
-- INSERT INTO test_orders VALUES (3, '2024-03-01', NULL);
--
-- Now add the constraint using ALTER TABLE (do not recreate the table).
-- After adding it, test with:
-- INSERT INTO test_orders VALUES (4, '2024-04-10', '2024-04-08'); -- should FAIL
-- INSERT INTO test_orders VALUES (5, '2024-04-10', '2024-04-15'); -- should PASS

CREATE TABLE test_orders (
   order_id      INT PRIMARY KEY,
   order_date    DATE NOT NULL,
   shipped_date  DATE,

CONSTRAINT ck_shipped_date
	Check (shipped_date IS NULL OR shipped_date >= order_date
)
);

INSERT INTO test_orders VALUES (1, '2024-01-10', '2024-01-13');
INSERT INTO test_orders VALUES (2, '2024-02-05', '2024-02-07');
INSERT INTO test_orders VALUES (3, '2024-03-01', NULL);

-- Now add the constraint using ALTER TABLE (do not recreate the table).
-- After adding it, test with:
INSERT INTO test_orders VALUES (4, '2024-04-10', '2024-04-08'); -- should FAIL
INSERT INTO test_orders VALUES (5, '2024-04-10', '2024-04-15'); -- should PASS

-- ============================================================
--  SECTION D — CASE EXPRESSIONS
-- ============================================================

-- Q9.
-- The sales team wants to see how quickly each order was shipped.
-- Using the difference between shipped_date and order_date:
--   - 'Fast'     — shipped within 2 days
--   - 'Normal'   — shipped in 3 to 5 days
--   - 'Delayed'  — shipped after 5 days
--   - 'Pending'  — not yet shipped (shipped_date is NULL)
-- Show order_id, order_date, shipped_date, and shipping_speed.

select o.order_id, 
       o.order_date, 
	   o.shipped_date,
	   CASE 
	        WHEN DATEDIFF(DAY, o.order_date, o.shipped_date) >= 1 AND DATEDIFF(DAY, o.order_date, o.shipped_date) <= 2 THEN 'Fast'
			WHEN DATEDIFF(DAY, o.order_date, o.shipped_date) >= 3 AND DATEDIFF(DAY, o.order_date, o.shipped_date) <= 5THEN 'Normal'
			WHEN DATEDIFF(DAY, o.order_date, o.shipped_date) > 5 THEN 'Delayed'
			WHEN o.shipped_date is null THEN 'Pending'
	   END as shipping_speed
from sales.orders o

-- Q10.
-- The warehouse team wants to label stock levels for each product per store.
-- Using production.stocks:
--   - 'Out of Stock'  — quantity = 0
--   - 'Low Stock'     — quantity between 1 and 10
--   - 'Sufficient'    — quantity between 11 and 50
--   - 'Well Stocked'  — quantity above 50
-- Show store_id, product_id, quantity, and stock_status.
-- Sort by store_id, then quantity ascending.

select ps.store_id,
	   ps.product_id,
	   ps.quantity,
	case 
		when quantity =0 then 'Out of Stock'
		when quantity >=1 and quantity <=10 then 'Low Stock'
		when quantity >=11 and quantity <=50 then 'Sufficient' 
		when quantity > 50 then 'Well Stocked'
		End as stock_status
from production.stocks ps

-- ============================================================
--  END OF ASSIGNMENT 04
-- ============================================================