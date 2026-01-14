DROP TABLE IF EXISTS products, product_manufactured_region, employee CASCADE;

CREATE TABLE product_manufactured_region (
    id SERIAL,
    region_name VARCHAR(25),
    region_code VARCHAR(10),
    established_year INTEGER
);

CREATE TABLE products (
    id SERIAL,
    product_name VARCHAR(100),
    product_code VARCHAR(10),
    product_quantity NUMERIC(10,2),
    manufactured_date DATE, 
    manufactured_region VARCHAR(25),
    added_by TEXT DEFAULT 'admin',
    created_date TIMESTAMP DEFAULT now()
);

INSERT INTO product_manufactured_region (region_name, region_code, established_year) VALUES 
('Europe', 'EU-01', 2010),
('APAC', 'AP-01', 2019),
('EMEA', 'EM-01', 2010),
('North America', 'NA-01', 2012); -- No products here!

INSERT INTO products (product_name, product_code, manufactured_region, product_quantity, manufactured_date) VALUES 
('Product 1', 'PRD1', 'Europe', 100.25, '2019-11-20'),
('Product 1', 'PRD2', 'EMEA', 92.25, '2019-11-01'),
('Product 2', 'PRD2', 'APAC', 12.25, '2019-11-01'),
('Product 3', 'PRD3', 'APAC', 25.25, '2019-11-02'),
('Product 5', 'PRD5', NULL, 11.11, '2020-12-12'); -- Orphan product!

-- =================================================================
-- 2. BASIC JOINS
-- =================================================================

-- 2.1 INNER JOIN
-- Returns only exact matches (Intersection).
-- 'North America' and 'Product 5' will be EXCLUDED.
SELECT p.product_name,
       p.product_code, 
       p.manufactured_region,
       mr.established_year
  FROM products p 
 INNER JOIN product_manufactured_region mr 
    ON mr.region_name = p.manufactured_region;

-- 2.2 LEFT JOIN (LEFT OUTER JOIN)
-- Returns everything from LEFT (Products) + matches from Right.
-- 'Product 5' appears with NULL year. 'North America' is excluded.
SELECT p.product_name,
       p.product_code, 
       p.manufactured_region,
       mr.established_year
  FROM products p 
  LEFT JOIN product_manufactured_region mr 
    ON mr.region_name = p.manufactured_region;

-- 2.3 RIGHT JOIN (RIGHT OUTER JOIN)
-- Returns everything from RIGHT (Regions) + matches from Left.
-- 'North America' appears. 'Product 5' is excluded.
SELECT p.product_name,
       p.product_code, 
       mr.region_name,
       mr.established_year
  FROM products p 
 RIGHT JOIN product_manufactured_region mr 
    ON mr.region_name = p.manufactured_region;

-- 2.4 FULL OUTER JOIN
-- Returns everything from BOTH tables.
-- Both 'Product 5' and 'North America' appear.
SELECT p.product_name,
       p.product_code, 
       p.manufactured_region AS prod_region,
       mr.region_name AS region_table_name
  FROM products p 
  FULL JOIN product_manufactured_region mr 
    ON mr.region_name = p.manufactured_region;

-- =================================================================
-- 3. SPECIAL JOINS
-- =================================================================

-- 3.1 CROSS JOIN
-- Cartesian Product. 5 products * 4 regions = 20 rows.
-- DANGEROUS on large tables!
SELECT p.product_name,
       mr.region_name
  FROM products p 
 CROSS JOIN product_manufactured_region mr;

-- 3.2 NATURAL JOIN
-- Joins automatically on columns with same name.
-- NOT RECOMMENDED for production (implicit & brittle).
SELECT * 
  FROM products 
 NATURAL JOIN product_manufactured_region; 
-- Note: It might return empty if no common columns exist or behave unexpectedly.

-- =================================================================
-- 4. OTHER JOINS
-- =================================================================

-- 4.1 SEMI-JOIN
-- Returns rows from Table A where a match exists in Table B.
-- Unlike Inner Join, it DOES NOT duplicate rows from A.
-- Use case: "Which regions have at least one product?"

SELECT * 
  FROM product_manufactured_region mr
 WHERE EXISTS (
    SELECT 1 
      FROM products p 
     WHERE p.manufactured_region = mr.region_name
 );

-- 4.2 ANTI-JOIN
-- Returns rows from Table A where NO match exists in Table B.
-- Use case: "Which regions have NO products?"
-- Pattern: LEFT JOIN + WHERE IS NULL

SELECT mr.region_name
  FROM product_manufactured_region mr
  LEFT JOIN products p 
    ON p.manufactured_region = mr.region_name
 WHERE p.id IS NULL; -- "North America" should appear here

-- 4.3 EQUI JOIN
SELECT mr.region_name
  FROM product_manufactured_region mr
  LEFT JOIN products p
    ON p.manufactured_region = mr.region_name;

-- 4.4 NON-EQUI JOIN (sign in the join key - <, >, >=, <=, !=).)
SELECT mr.region_name
  FROM product_manufactured_region mr
  LEFT JOIN products p
    ON p.manufactured_region != mr.region_name;

-- 4.5 SELF JOIN
-- Joining a table to itself (Hierarchies).

CREATE TABLE employee (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR (255) NOT NULL,
    last_name VARCHAR (255) NOT NULL,
    manager_id INT
);

INSERT INTO employee (employee_id, first_name, last_name, manager_id) VALUES
(1, 'Krzysiek', 'Bury', NULL),     -- The Boss
(2, 'Ania', 'Kowalska', 1),        -- Reports to 1
(3, 'Tomek', 'Sawyer', 1),         -- Reports to 1
(4, 'Jessica', 'Polska', 2);       -- Reports to 2

SELECT e.first_name || ' ' || e.last_name AS employee,
       m.first_name || ' ' || m.last_name AS manager
  FROM employee e
  LEFT JOIN employee m ON m.employee_id = e.manager_id
 ORDER BY manager;

-- 4.6 LATERAL JOIN
-- "For Each" loop in SQL.
-- Use Case: Find the most recently manufactured product for EACH region.

SELECT mr.region_name,
       top_product.product_name,
       top_product.manufactured_date
  FROM product_manufactured_region mr
  LEFT JOIN LATERAL (
      SELECT p.product_name, 
             p.manufactured_date
      FROM products p
      WHERE p.manufactured_region = mr.region_name -- Correlation here!
      ORDER BY p.manufactured_date DESC
      LIMIT 1
  ) top_product ON true;

-- =================================================================
-- 5. COMMON PITFALLS
-- =================================================================

-- 5.1 WHERE vs ON in Left Joins
-- Scenario: We want all products, and if they are from 2012 region, show the year.

-- CORRECT: Filter inside ON
-- Keeps non-matching products (Left Join behavior preserved)
SELECT p.product_name, mr.established_year
  FROM products p 
  LEFT JOIN product_manufactured_region mr 
    ON mr.region_name = p.manufactured_region
   AND mr.established_year = 2012;

-- INCORRECT: Filter inside WHERE
-- Acts like INNER JOIN (removes non-matches because NULL != 2012)
SELECT p.product_name, mr.established_year
  FROM products p 
  LEFT JOIN product_manufactured_region mr 
    ON mr.region_name = p.manufactured_region
 WHERE mr.established_year = 2012;

-- 5.2 The OR Trap
-- Performance killer: Forces Nested Loop Join usually.
SELECT p.product_name
  FROM products p
  LEFT JOIN product_manufactured_region mr 
    ON mr.region_name = p.manufactured_region
    OR mr.region_code = p.product_code; -- Avoid this pattern on large datasets!
