-- 4.1 各分层用户数、占比与特征均值
WITH last_active AS (
    SELECT
        user_id,
        DATEDIFF((SELECT MAX(DATE(event_time)) FROM user_behavior),
                 MAX(DATE(event_time))) AS recency
    FROM user_behavior
    GROUP BY user_id
),
buy_freq AS (
    SELECT user_id, SUM(behavior_type = 'buy') AS buy_cnt
    FROM user_behavior
    GROUP BY user_id
),
rf AS (
    SELECT l.user_id, l.recency, COALESCE(b.buy_cnt, 0) AS buy_cnt
    FROM last_active l
    LEFT JOIN buy_freq b ON b.user_id = l.user_id
),
scored AS (
    SELECT
        user_id,
        recency,
        buy_cnt,
        CASE WHEN recency <= AVG(recency) OVER () THEN 'R高' ELSE 'R低' END AS r_level,
        CASE WHEN buy_cnt >= AVG(buy_cnt) OVER () THEN 'F高' ELSE 'F低' END AS f_level
    FROM rf
)
SELECT
    CASE
        WHEN r_level = 'R高' AND f_level = 'F高' THEN '重要价值客户'
        WHEN r_level = 'R高' AND f_level = 'F低' THEN '重要发展客户'
        WHEN r_level = 'R低' AND f_level = 'F高' THEN '重要保持客户'
        ELSE '一般客户'
    END                                AS segment,
    COUNT(*)                           AS users,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS user_pct,
    ROUND(AVG(recency), 1)             AS avg_recency_days,
    ROUND(AVG(buy_cnt), 2)             AS avg_buy_cnt
FROM scored
GROUP BY segment
ORDER BY users DESC;


-- 4.2 分层阈值参考：R / F 的均值与分位数
WITH last_active AS (
    SELECT
        user_id,
        DATEDIFF((SELECT MAX(DATE(event_time)) FROM user_behavior),
                 MAX(DATE(event_time))) AS recency
    FROM user_behavior
    GROUP BY user_id
),
buy_freq AS (
    SELECT user_id, SUM(behavior_type = 'buy') AS buy_cnt
    FROM user_behavior
    GROUP BY user_id
)
SELECT
    ROUND(AVG(l.recency), 2)                             AS avg_recency,
    ROUND(AVG(COALESCE(b.buy_cnt, 0)), 2)                AS avg_buy_cnt,
    SUM(COALESCE(b.buy_cnt, 0) = 0)                      AS zero_buy_users,
    COUNT(*)                                             AS total_users
FROM last_active l
LEFT JOIN buy_freq b ON b.user_id = l.user_id;
