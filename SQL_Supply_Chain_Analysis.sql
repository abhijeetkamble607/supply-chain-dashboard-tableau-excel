--            ===== daily sales trends =====

USE asap;

WITH yearly_sales AS (
    SELECT
        YEAR(STR_TO_DATE(f.`Date`, '%Y-%m-%d %H:%i:%s')) AS sales_year,
        COUNT(*) AS total_transactions
    FROM f_sales f
    WHERE f.`Transaction Type` = 'Purchase'
    GROUP BY YEAR(STR_TO_DATE(f.`Date`, '%Y-%m-%d %H:%i:%s'))
),

total_profit AS (
    SELECT 
        ROUND(SUM(`Price` * `Quantity on Hand`) * 0.15, 2) AS total_profit
    FROM f_inventory_adjusted
)

SELECT 
    ys.sales_year,
    ys.total_transactions,
    ROUND(
        (ys.total_transactions / (SELECT SUM(total_transactions) FROM yearly_sales))
        * (SELECT total_profit FROM total_profit),
        2
    ) AS estimated_profit
FROM yearly_sales ys
ORDER BY ys.sales_year;


--      	 ===== product wise sale =====

USE asap;

SELECT 
    CASE
        WHEN `Product Name` LIKE '%Laptop%' THEN 'Laptop'
        WHEN `Product Name` LIKE '%Mobile%' THEN 'Mobile'
        WHEN `Product Name` LIKE '%TV%' THEN 'Television'
        WHEN `Product Name` LIKE '%Camera%' THEN 'Camera'
        WHEN `Product Name` LIKE '%Headphone%' THEN 'Headphone'
        ELSE 'Other Products'
    END AS Product_Category,
    
    ROUND(SUM(`Price` * `Quantity on Hand`), 2) AS Total_Sales,
    ROUND(SUM((`Price` * `Quantity on Hand`) * 0.15), 2) AS Estimated_Profit  -- assuming ~15% margin

FROM f_inventory_adjusted
GROUP BY Product_Category
ORDER BY Total_Sales DESC;


-- 			===== purchase method wise sales =====

USE asap;

SELECT 
    `Purchase Method`,
    COUNT(`Order Number`) AS total_transactions
FROM f_sales
WHERE `Transaction Type` = 'Purchase'
GROUP BY `Purchase Method`
ORDER BY total_transactions DESC;


--       ===== region wise sale =====

USE asap;

WITH total_inventory AS (
    SELECT SUM(`Price` * `Quantity on Hand`) AS total_value
    FROM f_inventory_adjusted
)

SELECT 
    s.`Store Region` AS region_name,
    COUNT(f.`Order Number`) AS total_transactions,
    ROUND(SUM(ti.total_value) / 10, 2) AS estimated_sales,         -- divide to spread inventory value
    ROUND((SUM(ti.total_value) / 10) * 0.15, 2) AS estimated_profit -- apply 15% profit margin
FROM f_sales f
JOIN d_store s 
    ON f.`Store Key` = s.`Store Key`
CROSS JOIN total_inventory ti
WHERE f.`Transaction Type` = 'Purchase'
GROUP BY s.`Store Region`
ORDER BY estimated_sales DESC;


--    ===== sales growth =====

USE asap;

-- Step 1: Calculate Monthly Sales
WITH monthly_sales AS (
    SELECT
        YEAR(STR_TO_DATE(`Date`, '%Y-%m-%d %H:%i:%s')) AS sales_year,
        MONTH(STR_TO_DATE(`Date`, '%Y-%m-%d %H:%i:%s')) AS sales_month,
        COUNT(*) AS total_transactions
    FROM f_sales
    WHERE `Transaction Type` = 'Purchase'
    GROUP BY sales_year, sales_month
),

-- Step 2: Calculate Month-over-Month Sales Growth
sales_growth AS (
    SELECT
        sales_year,
        sales_month,
        total_transactions,
        LAG(total_transactions) OVER (ORDER BY sales_year, sales_month) AS prev_month_sales,
        ROUND(
            (
                (total_transactions - LAG(total_transactions) OVER (ORDER BY sales_year, sales_month))
                / LAG(total_transactions) OVER (ORDER BY sales_year, sales_month)
            ) * 100, 2
        ) AS monthly_growth_percent
    FROM monthly_sales
),

-- Step 3: Get Total Profit from Inventory 
profit_summary AS (
    SELECT 
        ROUND(SUM(`Price` * `Quantity on Hand`) * 0.15, 2) AS total_profit
    FROM f_inventory_adjusted
)

-- Step 4: Combine Sales Growth and Profit
SELECT 
    CONCAT(sg.sales_year, '-', LPAD(sg.sales_month, 2, '0')) AS month_period,
    sg.total_transactions AS total_sales,
    sg.monthly_growth_percent AS sales_growth_percent,
    (SELECT ROUND(total_profit / 12, 2) FROM profit_summary) AS estimated_profit_per_month
FROM sales_growth sg
ORDER BY sg.sales_year, sg.sales_month;


--     ===== state wise sales =====

USE asap;

-- First, calculate total inventory once
WITH total_inventory AS (
    SELECT SUM(`Price` * `Quantity on Hand`) AS total_value
    FROM f_inventory_adjusted
)

-- Then use that value safely to estimate state-wise sales
SELECT 
    s.`Store State` AS state_name,
    COUNT(f.`Order Number`) AS total_transactions,
    ROUND(SUM(ti.total_value) / 20, 2) AS estimated_sales,
    ROUND((SUM(ti.total_value) / 20) * 0.15, 2) AS estimated_profit
FROM f_sales f
JOIN d_store s 
    ON f.`Store Key` = s.`Store Key`
JOIN total_inventory ti   
WHERE f.`Transaction Type` = 'Purchase'
GROUP BY s.`Store State`
ORDER BY estimated_sales DESC;


--     ===== top 5 store wise sales =====

USE asap;

WITH store_sales AS (
    SELECT
        s.`Store Name` AS store_name,
        COUNT(f.`Order Number`) AS total_transactions,
        COUNT(f.`Order Number`) * 1000 AS total_sales,          
        ROUND((COUNT(f.`Order Number`) * 1000) * 0.15, 2) AS estimated_profit  
    FROM f_sales f
    JOIN d_store s
        ON f.`Store Key` = s.`Store Key`
    WHERE f.`Transaction Type` = 'Purchase'
    GROUP BY s.`Store Name`
)
SELECT 
    store_name,
    total_transactions,
    total_sales,
    estimated_profit
FROM store_sales
ORDER BY total_sales DESC
LIMIT 5;


--    ===== total inventory,inventory value =====

USE asap;

WITH inventory_data AS (
    SELECT 
        `Product Name`,
        `Price`,
        `Quantity on Hand`,
        (`Price` * `Quantity on Hand`) AS inventory_value
    FROM f_inventory_adjusted
),

stock_status AS (
    SELECT 
        CASE
            WHEN `Quantity on Hand` = 0 THEN 'Out of Stock'
            WHEN `Quantity on Hand` < 50 THEN 'Under Stock'
            WHEN `Quantity on Hand` > 100 THEN 'Over Stock'
            ELSE 'In Stock'
        END AS category,
        COUNT(*) AS value
    FROM f_inventory_adjusted
    GROUP BY category
)

-- Combine Total, Value, and Stock Health
SELECT 'Total Inventory Quantity' AS category, 
       SUM(`Quantity on Hand`) AS value
FROM inventory_data

UNION ALL

SELECT 'Total Inventory Value' AS category, 
       ROUND(SUM(inventory_value), 2) AS value
FROM inventory_data

UNION ALL

SELECT category, value
FROM stock_status;


--     =====  total sales  =====

USE asap;

-- Step 1: Calculate yearly total sales
WITH yearly_sales AS (
    SELECT
        YEAR(STR_TO_DATE(`Date`, '%Y-%m-%d %H:%i:%s')) AS sales_year,
        COUNT(*) AS total_transactions
    FROM f_sales
    WHERE `Transaction Type` = 'Purchase'
    GROUP BY sales_year
),

-- Step 2: Calculate year-over-year growth
yearly_growth AS (
    SELECT
        sales_year,
        total_transactions,
        LAG(total_transactions) OVER (ORDER BY sales_year) AS prev_year_sales,
        ROUND(
            (
                (total_transactions - LAG(total_transactions) OVER (ORDER BY sales_year))
                / LAG(total_transactions) OVER (ORDER BY sales_year)
            ) * 100, 2
        ) AS yearly_growth_percent
    FROM yearly_sales
),

-- Step 3: Get total profit (from inventory)
profit_summary AS (
    SELECT 
        ROUND(SUM(`Price` * `Quantity on Hand`) * 0.15, 2) AS total_profit   
    FROM f_inventory_adjusted
)

-- Step 4: Combine all results
SELECT 
    y.sales_year,
    y.total_transactions AS total_sales,
    y.prev_year_sales AS previous_year_sales,
    y.yearly_growth_percent AS sales_growth_percent,
    p.total_profit AS estimated_profit
FROM yearly_growth y
CROSS JOIN profit_summary p
ORDER BY y.sales_year;

