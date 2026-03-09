-- 1. SETUP
DROP DATABASE IF EXISTS prod_sales;
CREATE DATABASE prod_sales;
-- \c prod_sales

-- 2. THE "GOOD" STATE
CREATE TABLE orders (
  order_id INT PRIMARY KEY,
  customer_name VARCHAR(30),
  amount DECIMAL(10,2),
  order_date TIMESTAMP NOT NULL
);

INSERT INTO orders (order_id, customer_name, amount, order_date)
VALUES (1, 'Alice', 150.00, '2026-03-01 14:00:00'),
       (2, 'Bob', 200.00, '2026-03-01 16:30:00');

-- Capture Safe Point
SELECT now() AS safe_point_in_time; 
-- Assume: '2026-03-05 16:00:00'
