-- ================================================================
-- LIO JOTSTAR OTT PLATFORM MERGER ANALYSIS
-- Author: Poojitha Kolli
-- Tool: MySQL
-- Description: SQL analysis for strategic merger decision
-- ================================================================

-- ----------------------------------------------------------------
-- QUESTION 1: Total Users per Platform
-- Business Context: Compare user base size before merger
-- ----------------------------------------------------------------
SELECT 'Jotstar' as Platform, 
       count(distinct user_id) as No_of_users 
FROM jotstar_db.subscribers
UNION ALL 
SELECT 'Liocinema' as Platform, 
       count(distinct user_id) 
FROM liocinema_db.subscribers;

-- Result: Jotstar=45K, LioCinema=183K
-- Insight: LioCinema has 4x larger user base

-- ----------------------------------------------------------------
-- QUESTION : Monthly User Growth Rate (Jan-Nov 2024)
-- Business Context: Track growth momentum of each platform
-- ----------------------------------------------------------------
WITH cte1 AS (
    SELECT 
        MONTH(subscription_date) AS month_number,  
        DATE_FORMAT(subscription_date, '%M') AS month_name,  
        COUNT(user_id) AS jotstar_users
    FROM jotstar_db.subscribers
    GROUP BY month_number, month_name
),
cte2 AS (
    SELECT 
        MONTH(subscription_date) AS month_number,  
        DATE_FORMAT(subscription_date, '%M') AS month_name,  
        COUNT(user_id) AS liocinema_users
    FROM liocinema_db.subscribers
    GROUP BY month_number, month_name
),
combined AS (
    SELECT 
        c1.month_number,  
        c1.month_name,  
        LAG(c1.jotstar_users) 
            OVER (ORDER BY c1.month_number) AS prev_jotstar_users,
        LAG(c2.liocinema_users) 
            OVER (ORDER BY c1.month_number) AS prev_liocinema_users,
        c1.jotstar_users,
        c2.liocinema_users
    FROM cte1 c1
    JOIN cte2 c2 ON c1.month_number = c2.month_number
)
SELECT 
    month_number,  
    month_name,  
    ROUND(((jotstar_users - prev_jotstar_users) 
        / prev_jotstar_users) * 100, 2) AS jotstar_growth_pct,  
    ROUND(((liocinema_users - prev_liocinema_users) 
        / prev_liocinema_users) * 100, 2) AS liocinema_growth_pct  
FROM combined  
ORDER BY month_number;

-- Insight: LioCinema peaked 27.12% Nov 2024
-- Jotstar consistently below 2% monthly


