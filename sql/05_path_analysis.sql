-- 5.1 行为转移矩阵：前一次行为 → 当前行为的频次
WITH seq AS (
    SELECT
        user_id,
        behavior_type,
        LAG(behavior_type) OVER (
            PARTITION BY user_id ORDER BY event_time, item_id
        ) AS prev_behavior
    FROM user_behavior
)
SELECT
    prev_behavior,
    behavior_type,
    COUNT(*)                AS cnt,
    COUNT(DISTINCT user_id) AS users
FROM seq
WHERE prev_behavior IS NOT NULL
GROUP BY prev_behavior, behavior_type
ORDER BY cnt DESC;


-- 5.2 Top 20 三步行为路径（含"路径终点为购买"的比例）
WITH seq AS (
    SELECT
        user_id,
        behavior_type,
        LAG(behavior_type)    OVER w AS prev1,
        LAG(behavior_type, 2) OVER w AS prev2
    FROM user_behavior
    WINDOW w AS (PARTITION BY user_id ORDER BY event_time, item_id)
)
SELECT
    CONCAT(prev2, ' -> ', prev1, ' -> ', behavior_type) AS path,
    COUNT(*)                                             AS cnt,
    COUNT(DISTINCT user_id)                              AS users,
    ROUND(100 * SUM(behavior_type = 'buy') / COUNT(*), 2) AS end_with_buy_pct --最后一步为购买的比例
FROM seq
WHERE prev2 IS NOT NULL
GROUP BY path
ORDER BY cnt DESC
LIMIT 20;


-- 5.3 严格有序漏斗（对照 F2 的用户级漏斗）
--     只统计"首次浏览时间 < 首次加购时间 < 首次购买时间"的用户，
--     用于量化用户级漏斗中被高估的部分（用户级口径不要求行为按序发生）
WITH first_ts AS (
    SELECT
        user_id,
        MIN(CASE WHEN behavior_type = 'pv'   THEN event_ts END) AS pv_ts,
        MIN(CASE WHEN behavior_type = 'cart' THEN event_ts END) AS cart_ts,
        MIN(CASE WHEN behavior_type = 'buy'  THEN event_ts END) AS buy_ts
    FROM user_behavior
    GROUP BY user_id
)
SELECT
    COUNT(CASE WHEN pv_ts IS NOT NULL THEN 1 END)                  AS pv_uv,
    COUNT(CASE WHEN pv_ts IS NOT NULL AND cart_ts IS NOT NULL
                    AND pv_ts < cart_ts THEN 1 END)                AS pv_before_cart_uv,
    COUNT(CASE WHEN pv_ts IS NOT NULL AND cart_ts IS NOT NULL AND buy_ts IS NOT NULL
                    AND pv_ts < cart_ts AND cart_ts < buy_ts THEN 1 END) AS strict_pv_cart_buy_uv,
    ROUND(100 * COUNT(CASE WHEN pv_ts IS NOT NULL AND cart_ts IS NOT NULL AND buy_ts IS NOT NULL
                    AND pv_ts < cart_ts AND cart_ts < buy_ts THEN 1 END)
          / COUNT(CASE WHEN pv_ts IS NOT NULL THEN 1 END), 2)      AS strict_conv_pct
FROM first_ts;


-- 5.4 降级方案：购买用户 vs 未购买用户的行为特征对比
WITH u AS (
    SELECT
        user_id,
        COUNT(*)                         AS total_cnt,
        SUM(behavior_type = 'pv')        AS pv_cnt,
        SUM(behavior_type = 'cart')      AS cart_cnt,
        SUM(behavior_type = 'fav')       AS fav_cnt,
        SUM(behavior_type = 'buy')       AS buy_cnt,
        COUNT(DISTINCT DATE(event_time)) AS active_days
    FROM user_behavior
    GROUP BY user_id
)
SELECT
    CASE WHEN buy_cnt > 0 THEN '购买用户' ELSE '未购买用户' END AS grp,
    COUNT(*)                   AS users,
    ROUND(AVG(total_cnt), 1)   AS avg_total_cnt,
    ROUND(AVG(pv_cnt), 1)      AS avg_pv_cnt,
    ROUND(AVG(cart_cnt), 2)    AS avg_cart_cnt,
    ROUND(AVG(fav_cnt), 2)     AS avg_fav_cnt,
    ROUND(AVG(active_days), 1) AS avg_active_days
FROM u
GROUP BY grp
ORDER BY users DESC;
