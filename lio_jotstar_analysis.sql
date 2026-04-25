-- ================================================================
-- LIO JOTSTAR OTT PLATFORM MERGER ANALYSIS
-- Tool: MySQL
-- Description: SQL analysis to provide strategic insights
--              for the merger of LioCinema and Jotstar OTT platforms
-- ================================================================


-- ----------------------------------------------------------------
-- Q1: Total Users per Platform
-- Business Context: Compare total user base size before merger
-- ----------------------------------------------------------------

SELECT 
    platform,
    COUNT(DISTINCT user_id) AS total_users
FROM (
    SELECT 'LioCinema' AS platform, user_id FROM liocinema_db.subscribers
    UNION ALL
    SELECT 'Jotstar'   AS platform, user_id FROM jotstar_db.subscribers
) combined
GROUP BY platform
ORDER BY total_users DESC;

-- Result:  LioCinema = 183K | Jotstar = 45K
-- Insight: LioCinema has 4x larger user base than Jotstar


-- ----------------------------------------------------------------
-- Q2: Monthly User Growth Rate (Jan - Nov 2024)
-- Business Context: Track growth momentum of each platform
-- ----------------------------------------------------------------

WITH monthly_users AS (
    SELECT 
        platform,
        MONTH(subscription_date)             AS month_number,
        DATE_FORMAT(subscription_date, '%M') AS month_name,
        COUNT(user_id)                       AS new_users
    FROM (
        SELECT 'LioCinema' AS platform, user_id, subscription_date 
        FROM liocinema_db.subscribers
        UNION ALL
        SELECT 'Jotstar'   AS platform, user_id, subscription_date 
        FROM jotstar_db.subscribers
    ) combined
    GROUP BY platform, month_number, month_name
)
SELECT 
    platform,
    month_number,
    month_name,
    new_users,
    LAG(new_users) OVER (PARTITION BY platform ORDER BY month_number) AS prev_month_users,
    ROUND(
        (new_users - LAG(new_users) OVER (PARTITION BY platform ORDER BY month_number))
        / LAG(new_users) OVER (PARTITION BY platform ORDER BY month_number) * 100
    , 2) AS growth_pct
FROM monthly_users
ORDER BY platform, month_number;

-- Insight: LioCinema peaked at 27.12% growth in November 2024
-- Insight: Jotstar consistently below 2% monthly growth


-- ----------------------------------------------------------------
-- Q3: Content Library Comparison
-- Business Context: Understand content strengths of each platform
-- ----------------------------------------------------------------

SELECT 
    platform,
    language,
    content_type,
    COUNT(DISTINCT content_id) AS total_content
FROM (
    SELECT 'LioCinema' AS platform, language, content_type, content_id 
    FROM liocinema_db.contents
    UNION ALL
    SELECT 'Jotstar'   AS platform, language, content_type, content_id 
    FROM jotstar_db.contents
) combined
GROUP BY platform, language, content_type
ORDER BY platform, total_content DESC;

-- Insight: LioCinema stronger in regional languages (Tamil, Telugu, Malayalam)
-- Insight: Jotstar stronger in English and Sports content


-- ----------------------------------------------------------------
-- Q4: User Demographics
-- Business Context: Understand audience profile of each platform
-- ----------------------------------------------------------------

SELECT 
    platform,
    age_group,
    city_tier,
    subscription_plan,
    COUNT(DISTINCT user_id) AS total_users
FROM (
    SELECT 'LioCinema' AS platform, user_id, age_group, 
           city_tier, subscription_plan 
    FROM liocinema_db.subscribers
    UNION ALL
    SELECT 'Jotstar'   AS platform, user_id, age_group, 
           city_tier, subscription_plan 
    FROM jotstar_db.subscribers
) combined
GROUP BY platform, age_group, city_tier, subscription_plan
ORDER BY platform, total_users DESC;

-- Insight: LioCinema dominates Tier 2/3 cities with 18-24 age group on free plans
-- Insight: Jotstar stronger in Tier 1 cities with 25-34 professionals on premium plans


-- ----------------------------------------------------------------
-- Q5: Active vs Inactive Users
-- Business Context: Measure engagement levels across platforms
-- ----------------------------------------------------------------

SELECT 
    platform,
    subscription_plan,
    age_group,
    ROUND(AVG(CASE WHEN last_active_date IS NULL     THEN 1.0 ELSE 0 END) * 100, 2) AS active_rate_pct,
    ROUND(AVG(CASE WHEN last_active_date IS NOT NULL THEN 1.0 ELSE 0 END) * 100, 2) AS inactive_rate_pct
FROM (
    SELECT 'LioCinema' AS platform, user_id, subscription_plan,
           age_group, last_active_date
    FROM liocinema_db.subscribers
    UNION ALL
    SELECT 'Jotstar'   AS platform, user_id, subscription_plan,
           age_group, last_active_date
    FROM jotstar_db.subscribers
) combined
GROUP BY platform, subscription_plan, age_group
ORDER BY platform, inactive_rate_pct DESC;

-- Insight: VIP users 90% active vs Free users only 60% active
-- Insight: Older age groups (45+) have higher inactivity rates


-- ----------------------------------------------------------------
-- Q6: Watch Time Analysis
-- Business Context: Measure content engagement across platforms
-- ----------------------------------------------------------------

SELECT 
    platform,
    city_tier,
    device_type,
    ROUND(SUM(total_watch_time_mins) / COUNT(DISTINCT c.user_id) / 60, 2) AS avg_watch_time_hours
FROM (
    SELECT 'LioCinema' AS platform, s.city_tier, c.device_type,
           c.total_watch_time_mins, c.user_id
    FROM liocinema_db.content_consumption c
    JOIN liocinema_db.subscribers s ON c.user_id = s.user_id
    UNION ALL
    SELECT 'Jotstar'   AS platform, s.city_tier, c.device_type,
           c.total_watch_time_mins, c.user_id
    FROM jotstar_db.content_consumption c
    JOIN jotstar_db.subscribers s ON c.user_id = s.user_id
) combined
GROUP BY platform, city_tier, device_type
ORDER BY avg_watch_time_hours DESC;

-- Insight: Jotstar Tier 1 users average 394 hrs vs LioCinema 90 hrs
-- Insight: Mobile drives highest total watch time due to larger user base


-- ----------------------------------------------------------------
-- Q7: Inactivity Correlation with Watch Time
-- Business Context: Do less engaged users become inactive faster?
-- ----------------------------------------------------------------

SELECT 
    platform,
    user_status,
    subscription_plan,
    age_group,
    ROUND(COUNT(DISTINCT CASE 
        WHEN user_status = 'Inactive' THEN user_id END) * 100.0
        / COUNT(DISTINCT user_id), 2)                                       AS inactivity_rate_pct,
    ROUND(SUM(total_watch_time_mins) / COUNT(DISTINCT user_id) / 60, 2)    AS avg_watch_time_hours
FROM (
    SELECT 
        'LioCinema' AS platform,
        s.user_id,
        s.subscription_plan,
        s.age_group,
        CASE WHEN s.last_active_date IS NULL THEN 'Active' ELSE 'Inactive' END AS user_status,
        c.total_watch_time_mins
    FROM liocinema_db.subscribers s
    LEFT JOIN liocinema_db.content_consumption c ON s.user_id = c.user_id
    UNION ALL
    SELECT 
        'Jotstar' AS platform,
        s.user_id,
        s.subscription_plan,
        s.age_group,
        CASE WHEN s.last_active_date IS NULL THEN 'Active' ELSE 'Inactive' END AS user_status,
        c.total_watch_time_mins
    FROM jotstar_db.subscribers s
    LEFT JOIN jotstar_db.content_consumption c ON s.user_id = c.user_id
) combined
GROUP BY platform, user_status, subscription_plan, age_group
ORDER BY platform, inactivity_rate_pct DESC;

-- Insight: Inactive users watch 6x LESS than active users
-- Insight: Free plan has 45% inactivity — biggest churn risk
-- Insight: VIP users most loyal with only 8% inactivity


-- ----------------------------------------------------------------
-- Q8: Downgrade Trends
-- Business Context: Are users downgrading plans? Which platform more?
-- ----------------------------------------------------------------

WITH plan_hierarchy AS (
    SELECT 'LioCinema' AS platform, 'Premium' AS plan, 3 AS level
    UNION ALL SELECT 'LioCinema', 'Basic',   2
    UNION ALL SELECT 'LioCinema', 'Free',    1
    UNION ALL SELECT 'Jotstar',   'VIP',     4
    UNION ALL SELECT 'Jotstar',   'Premium', 3
    UNION ALL SELECT 'Jotstar',   'Basic',   2
    UNION ALL SELECT 'Jotstar',   'Free',    1
),
all_subscribers AS (
    SELECT 'LioCinema' AS platform, user_id,
           subscription_plan, new_subscription_plan
    FROM liocinema_db.subscribers
    WHERE new_subscription_plan IS NOT NULL
    UNION ALL
    SELECT 'Jotstar'   AS platform, user_id,
           subscription_plan, new_subscription_plan
    FROM jotstar_db.subscribers
    WHERE new_subscription_plan IS NOT NULL
)
SELECT 
    s.platform,
    COUNT(DISTINCT CASE 
        WHEN new_plan.level < old_plan.level 
        THEN s.user_id END)                          AS total_downgrade_count,
    COUNT(DISTINCT s.user_id)                        AS total_users,
    ROUND(COUNT(DISTINCT CASE 
        WHEN new_plan.level < old_plan.level 
        THEN s.user_id END) * 100.0
        / COUNT(DISTINCT s.user_id), 2)              AS downgrade_pct
FROM all_subscribers s
JOIN  plan_hierarchy old_plan ON s.subscription_plan     = old_plan.plan AND s.platform = old_plan.platform
LEFT JOIN plan_hierarchy new_plan ON s.new_subscription_plan = new_plan.plan AND s.platform = new_plan.platform
GROUP BY s.platform
ORDER BY downgrade_pct DESC;

-- Insight: Both platforms show similar downgrade rates (~8%)
-- Insight: Plan pricing review recommended post-merger


-- ----------------------------------------------------------------
-- Q9: Upgrade Patterns
-- Business Context: Most common upgrade transitions per platform
-- ----------------------------------------------------------------

WITH plan_hierarchy AS (
    SELECT 'LioCinema' AS platform, 'Premium' AS plan, 3 AS level
    UNION ALL SELECT 'LioCinema', 'Basic',   2
    UNION ALL SELECT 'LioCinema', 'Free',    1
    UNION ALL SELECT 'Jotstar',   'VIP',     4
    UNION ALL SELECT 'Jotstar',   'Premium', 3
    UNION ALL SELECT 'Jotstar',   'Basic',   2
    UNION ALL SELECT 'Jotstar',   'Free',    1
),
all_subscribers AS (
    SELECT 'LioCinema' AS platform, user_id,
           subscription_plan, new_subscription_plan
    FROM liocinema_db.subscribers
    WHERE new_subscription_plan IS NOT NULL
    UNION ALL
    SELECT 'Jotstar'   AS platform, user_id,
           subscription_plan, new_subscription_plan
    FROM jotstar_db.subscribers
    WHERE new_subscription_plan IS NOT NULL
)
SELECT 
    s.platform,
    CONCAT(s.subscription_plan, ' → ', s.new_subscription_plan) AS upgrade_path,
    COUNT(DISTINCT s.user_id)                                    AS upgrade_count,
    ROUND(COUNT(DISTINCT s.user_id) * 100.0
        / SUM(COUNT(DISTINCT s.user_id)) 
          OVER (PARTITION BY s.platform), 2)                     AS pct_of_platform_upgrades
FROM all_subscribers s
JOIN      plan_hierarchy old_plan ON s.subscription_plan     = old_plan.plan AND s.platform = old_plan.platform
JOIN      plan_hierarchy new_plan ON s.new_subscription_plan = new_plan.plan AND s.platform = new_plan.platform
WHERE new_plan.level > old_plan.level
GROUP BY s.platform, upgrade_path
ORDER BY s.platform, upgrade_count DESC;

-- Insight: LioCinema: Free→Basic most common (price sensitive audience)
-- Insight: Jotstar: Free→Premium most common (metro users willing to pay more)


-- ----------------------------------------------------------------
-- Q10: Paid Users Distribution
-- Business Context: Monetization analysis across city tiers and age groups
-- ----------------------------------------------------------------

SELECT 
    platform,
    city_tier,
    age_group,
    ROUND(COUNT(DISTINCT CASE 
        WHEN subscription_plan IN ('Basic','Premium','VIP') 
        THEN user_id END) * 100.0
        / COUNT(DISTINCT user_id), 2)                AS paid_user_pct,
    ROUND(COUNT(DISTINCT CASE 
        WHEN subscription_plan = 'Premium' 
        THEN user_id END) * 100.0
        / COUNT(DISTINCT user_id), 2)                AS premium_user_pct
FROM (
    SELECT 'LioCinema' AS platform, user_id, subscription_plan,
           city_tier, age_group
    FROM liocinema_db.subscribers
    UNION ALL
    SELECT 'Jotstar'   AS platform, user_id, subscription_plan,
           city_tier, age_group
    FROM jotstar_db.subscribers
) combined
GROUP BY platform, city_tier, age_group
ORDER BY platform, city_tier, paid_user_pct DESC;

-- Insight: Jotstar monetizes 67% vs LioCinema 48% — 52% free users = huge upgrade opportunity!
-- Insight: Tier 1 + 25-34 age group = highest premium conversion across both platforms


-- ----------------------------------------------------------------
-- Q11: Revenue Analysis (Jan - Nov 2024)
-- Business Context: Total and monthly revenue per platform
-- ----------------------------------------------------------------

-- 11a. Total revenue per platform (simplified)
SELECT 
    platform,
    SUM(CASE 
        WHEN platform = 'LioCinema' AND subscription_plan = 'Basic'   THEN 69
        WHEN platform = 'LioCinema' AND subscription_plan = 'Premium' THEN 129
        WHEN platform = 'Jotstar'   AND subscription_plan = 'VIP'     THEN 159
        WHEN platform = 'Jotstar'   AND subscription_plan = 'Premium' THEN 359
        ELSE 0 END)                                  AS total_revenue
FROM (
    SELECT 'LioCinema' AS platform, user_id, subscription_plan
    FROM liocinema_db.subscribers
    UNION ALL
    SELECT 'Jotstar'   AS platform, user_id, subscription_plan
    FROM jotstar_db.subscribers
) combined
GROUP BY platform
ORDER BY total_revenue DESC;

-- 11b. Monthly revenue trend
SELECT 
    platform,
    MONTH(subscription_date)             AS month_number,
    DATE_FORMAT(subscription_date, '%M') AS month_name,
    SUM(CASE
        WHEN platform = 'LioCinema' AND subscription_plan = 'Basic'   THEN 69
        WHEN platform = 'LioCinema' AND subscription_plan = 'Premium' THEN 129
        WHEN platform = 'Jotstar'   AND subscription_plan = 'VIP'     THEN 159
        WHEN platform = 'Jotstar'   AND subscription_plan = 'Premium' THEN 359
        ELSE 0 END)                      AS monthly_revenue
FROM (
    SELECT 'LioCinema' AS platform, user_id, 
           subscription_plan, subscription_date
    FROM liocinema_db.subscribers
    WHERE YEAR(subscription_date) = 2024
    UNION ALL
    SELECT 'Jotstar'   AS platform, user_id, 
           subscription_plan, subscription_date
    FROM jotstar_db.subscribers
    WHERE YEAR(subscription_date) = 2024
) combined
GROUP BY platform, month_number, month_name
ORDER BY platform, month_number;

-- Note: This is a simplified revenue calculation using current plan only.
-- Accurate calculation would use TIMESTAMPDIFF to account for months
-- spent on each plan including upgrades and downgrades mid-period.
-- Insight: Jotstar generates higher revenue per user due to premium pricing (₹359 vs ₹129)


-- ================================================================
-- KEY FINDINGS SUMMARY
-- ================================================================
-- 1.  LioCinema 183K users (4x Jotstar) — mostly free tier (52% free!)
-- 2.  Jotstar 45K users — better monetization (67% paid)
-- 3.  LioCinema: Regional content strength (Tamil, Telugu, Malayalam)
-- 4.  Jotstar: Premium + Sports content — higher engagement (394 hrs vs 90 hrs)
-- 5.  Inactive users watch 6x less than active users
-- 6.  Free plan = 45% inactivity — biggest churn risk
-- 7.  VIP users most loyal — only 8% inactivity
-- 8.  Tier 1 + 25-34 age = highest premium conversion on both platforms
-- 9.  LioCinema upgrades: Free→Basic most common (price sensitive)
-- 10. Jotstar upgrades: Free→Premium most common (metro willingness to pay)
-- 11. Post-merger opportunity: Convert LioCinema free users to paid = massive revenue!
-- ================================================================
