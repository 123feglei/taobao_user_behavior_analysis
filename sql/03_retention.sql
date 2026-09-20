-- 3.1 留存矩阵：每个 cohort 在 day_n 的留存人数与留存率
WITH first_seen AS (
    SELECT user_id, MIN(DATE(event_time)) AS cohort_date
    FROM user_behavior
    GROUP BY user_id
),
cohort_activity AS (
    SELECT DISTINCT
        fs.cohort_date,
        fs.user_id,
        DATEDIFF(DATE(ub.event_time), fs.cohort_date) AS day_n
    FROM first_seen fs
    JOIN user_behavior ub ON ub.user_id = fs.user_id
),
daily AS (
    SELECT cohort_date, day_n, COUNT(DISTINCT user_id) AS users
    FROM cohort_activity
    WHERE day_n BETWEEN 0 AND 7
    GROUP BY cohort_date, day_n
)
SELECT
    cohort_date,
    day_n,
    users,
    ROUND(100 * users
               / MAX(CASE WHEN day_n = 0 THEN users END) OVER (PARTITION BY cohort_date), 2)
        AS retention_pct
FROM daily
ORDER BY cohort_date, day_n;


-- 3.2 关键留存指标：次日 / 3 日 / 7 日留存率
--     仅纳入有足够观察窗口的 cohort：
--     D1 需要 cohort_date <= 12-02，D3 需要 <= 11-30，D7 需要 <= 11-26
WITH first_seen AS (
    SELECT user_id, MIN(DATE(event_time)) AS cohort_date
    FROM user_behavior
    GROUP BY user_id
),
cohort_activity AS (
    SELECT
        fs.cohort_date,
        fs.user_id,
        DATEDIFF(DATE(ub.event_time), fs.cohort_date) AS day_n
    FROM first_seen fs
    JOIN user_behavior ub ON ub.user_id = fs.user_id
)
SELECT
    '次日留存(D1)' AS metric,
    COUNT(DISTINCT fs.user_id) AS base_users,
    COUNT(DISTINCT CASE WHEN ca.day_n = 1 THEN fs.user_id END) AS retained_users,
    ROUND(100 * COUNT(DISTINCT CASE WHEN ca.day_n = 1 THEN fs.user_id END)
               / COUNT(DISTINCT fs.user_id), 2) AS retention_pct
FROM first_seen fs
LEFT JOIN cohort_activity ca ON ca.user_id = fs.user_id
WHERE fs.cohort_date <= '2017-12-02'

UNION ALL

SELECT
    '3日留存(D3)',
    COUNT(DISTINCT fs.user_id),
    COUNT(DISTINCT CASE WHEN ca.day_n = 3 THEN fs.user_id END),
    ROUND(100 * COUNT(DISTINCT CASE WHEN ca.day_n = 3 THEN fs.user_id END)
               / COUNT(DISTINCT fs.user_id), 2)
FROM first_seen fs
LEFT JOIN cohort_activity ca ON ca.user_id = fs.user_id
WHERE fs.cohort_date <= '2017-11-30'

UNION ALL

SELECT
    '7日留存(D7)',
    COUNT(DISTINCT fs.user_id),
    COUNT(DISTINCT CASE WHEN ca.day_n = 7 THEN fs.user_id END),
    ROUND(100 * COUNT(DISTINCT CASE WHEN ca.day_n = 7 THEN fs.user_id END)
               / COUNT(DISTINCT fs.user_id), 2)
FROM first_seen fs
LEFT JOIN cohort_activity ca ON ca.user_id = fs.user_id
WHERE fs.cohort_date <= '2017-11-26';


-- 3.3 留存曲线（全体合并）：按距首访日的天数统计留存人数
WITH first_seen AS (
    SELECT user_id, MIN(DATE(event_time)) AS cohort_date
    FROM user_behavior
    GROUP BY user_id
),
cohort_activity AS (
    SELECT DISTINCT
        fs.user_id,
        DATEDIFF(DATE(ub.event_time), fs.cohort_date) AS day_n
    FROM first_seen fs
    JOIN user_behavior ub ON ub.user_id = fs.user_id
),
total AS (SELECT COUNT(DISTINCT user_id) AS uv FROM user_behavior)
SELECT
    ca.day_n,
    COUNT(DISTINCT ca.user_id) AS retained_users,
    ROUND(100 * COUNT(DISTINCT ca.user_id) / t.uv, 2) AS retention_pct
FROM cohort_activity ca
CROSS JOIN total t
WHERE ca.day_n BETWEEN 0 AND 7
GROUP BY ca.day_n, t.uv
ORDER BY ca.day_n;
