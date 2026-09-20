-- 6.1 类目下钻：按"流失用户数"排序，找贡献最大的类目
WITH cat AS (
    SELECT
        category_id,
        COUNT(*) AS records,
        COUNT(DISTINCT CASE WHEN behavior_type IN ('cart', 'fav') THEN user_id END) AS intent_uv,
        COUNT(DISTINCT CASE WHEN behavior_type = 'buy' THEN user_id END)            AS buy_uv
    FROM user_behavior
    GROUP BY category_id
)
SELECT
    category_id,
    records,
    intent_uv,
    buy_uv,
    intent_uv - buy_uv                                        AS lost_uv,
    ROUND(100 * buy_uv / intent_uv, 2)                        AS intent_to_buy_pct,
    ROUND(100 * (intent_uv - buy_uv)
               / SUM(intent_uv - buy_uv) OVER (), 2)          AS loss_contribution_pct
FROM cat
WHERE intent_uv >= 50
ORDER BY lost_uv DESC
LIMIT 10;


-- 6.2 时段下钻：各小时的意向转化率与流失规模（找最差时段）
WITH hour_stat AS (
    SELECT
        HOUR(event_time) AS hr,
        COUNT(DISTINCT user_id) AS uv,
        COUNT(DISTINCT CASE WHEN behavior_type IN ('cart', 'fav') THEN user_id END) AS intent_uv,
        COUNT(DISTINCT CASE WHEN behavior_type = 'buy' THEN user_id END)            AS buy_uv
    FROM user_behavior
    GROUP BY hr
)
SELECT
    hr,
    uv,
    intent_uv,
    buy_uv,
    intent_uv - buy_uv                 AS lost_uv,
    ROUND(100 * buy_uv / intent_uv, 2) AS intent_to_buy_pct
FROM hour_stat
WHERE intent_uv >= 30
ORDER BY intent_to_buy_pct ASC;


-- 6.3 用户频次分层下钻：不同活跃程度人群的购买表现
WITH u AS (
    SELECT
        user_id,
        COUNT(*)                         AS total_cnt,
        SUM(behavior_type = 'buy')       AS buy_cnt,
        COUNT(DISTINCT DATE(event_time)) AS active_days
    FROM user_behavior
    GROUP BY user_id
)
SELECT
    CASE
        WHEN total_cnt >= 100 THEN '高频(>=100次)'
        WHEN total_cnt >= 30  THEN '中频(30-99次)'
        ELSE '低频(<30次)'
    END                                 AS user_seg,
    COUNT(*)                            AS users,
    ROUND(AVG(total_cnt), 1)            AS avg_behaviors,
    ROUND(AVG(active_days), 1)          AS avg_active_days,
    ROUND(AVG(buy_cnt), 2)              AS avg_buy_cnt,
    ROUND(100 * SUM(buy_cnt > 0) / COUNT(*), 2) AS buyer_rate_pct
FROM u
GROUP BY user_seg
ORDER BY users DESC;


-- 6.4 维度组合下钻：用户频次分层 × 时段，找购买率最低的组合
--     注意：buyer_rate_pct = 该时段活跃用户中、在该时段内发生购买的用户占比，
--           同一用户在不同时段会重复计入，各行 uv 之和会大于总用户数。
--           本查询用于定位表现最差的组合，不等同于严格转化率。
WITH u AS (
    SELECT
        user_id,
        COUNT(*)                   AS total_cnt
    FROM user_behavior
    GROUP BY user_id
),
seg AS (
    SELECT
        user_id,
        CASE
            WHEN total_cnt >= 100 THEN '高频'
            WHEN total_cnt >= 30  THEN '中频'
            ELSE '低频'
        END AS user_seg
    FROM u
)
SELECT
    s.user_seg,
    CASE
        WHEN HOUR(b.event_time) BETWEEN 0  AND 5  THEN '凌晨(0-5)'
        WHEN HOUR(b.event_time) BETWEEN 6  AND 11 THEN '上午(6-11)'
        WHEN HOUR(b.event_time) BETWEEN 12 AND 17 THEN '下午(12-17)'
        ELSE '晚间(18-23)'
    END AS time_seg,
    COUNT(DISTINCT b.user_id) AS uv,
    COUNT(DISTINCT CASE WHEN b.behavior_type = 'buy' THEN b.user_id END) AS buyer_uv,
    ROUND(100 * COUNT(DISTINCT CASE WHEN b.behavior_type = 'buy' THEN b.user_id END)
               / COUNT(DISTINCT b.user_id), 2)                           AS buyer_rate_pct
FROM user_behavior b
JOIN seg s ON s.user_id = b.user_id
GROUP BY s.user_seg, time_seg
ORDER BY buyer_rate_pct ASC;
