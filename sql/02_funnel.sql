-- 2.1 用户级漏斗总览：各环节人数、转化率与流失率
WITH user_flag AS (
    SELECT
        user_id,
        MAX(behavior_type = 'pv')   AS has_pv,
        MAX(behavior_type = 'cart') AS has_cart,
        MAX(behavior_type = 'fav')  AS has_fav,
        MAX(behavior_type = 'buy')  AS has_buy
    FROM user_behavior
    GROUP BY user_id
)
SELECT
    SUM(has_pv)                                            AS browse_uv,
    SUM(has_cart OR has_fav)                               AS intent_uv,
    SUM(has_buy)                                           AS buy_uv,
    ROUND(100 * SUM(has_cart OR has_fav) / SUM(has_pv), 2) AS browse_to_intent_pct,
    ROUND(100 * SUM(has_buy) / SUM(has_cart OR has_fav), 2) AS intent_to_buy_pct,
    ROUND(100 * SUM(has_buy) / SUM(has_pv), 2)             AS overall_conv_pct,
    ROUND(100 * (1 - SUM(has_cart OR has_fav) / SUM(has_pv)), 2) AS browse_loss_pct,
    ROUND(100 * (1 - SUM(has_buy) / SUM(has_cart OR has_fav)), 2) AS intent_loss_pct
FROM user_flag;


-- 2.2 两条路径对比：pv→cart→buy 与 pv→fav→buy
WITH user_flag AS (
    SELECT
        user_id,
        MAX(behavior_type = 'pv')   AS has_pv,
        MAX(behavior_type = 'cart') AS has_cart,
        MAX(behavior_type = 'fav')  AS has_fav,
        MAX(behavior_type = 'buy')  AS has_buy
    FROM user_behavior
    GROUP BY user_id
)
SELECT
    SUM(has_cart)                          AS cart_uv,
    SUM(has_cart AND has_buy)              AS cart_buy_uv,
    ROUND(100 * SUM(has_cart AND has_buy) / SUM(has_cart), 2) AS cart_to_buy_pct,
    SUM(has_fav)                           AS fav_uv,
    SUM(has_fav AND has_buy)               AS fav_buy_uv,
    ROUND(100 * SUM(has_fav AND has_buy) / SUM(has_fav), 2)   AS fav_to_buy_pct
FROM user_flag;


-- 2.3 类目维度漏斗：Top 10 类目（样本量 >= 200 条记录）
SELECT
    category_id,
    COUNT(*)                                                         AS records,
    COUNT(DISTINCT user_id)                                          AS uv,
    COUNT(DISTINCT CASE WHEN behavior_type = 'buy' THEN user_id END) AS buyer_uv,
    ROUND(100 * COUNT(DISTINCT CASE WHEN behavior_type = 'buy' THEN user_id END)
               / COUNT(DISTINCT user_id), 2)                         AS conv_pct
FROM user_behavior
GROUP BY category_id
HAVING COUNT(*) >= 200
ORDER BY uv DESC
LIMIT 10;


-- 2.4 时段维度漏斗：各小时的浏览人数、加购人数、购买人数与转化率
SELECT
    HOUR(event_time)                                                  AS hr,
    COUNT(DISTINCT user_id)                                           AS uv,
    COUNT(DISTINCT CASE WHEN behavior_type = 'cart' THEN user_id END) AS cart_uv,
    COUNT(DISTINCT CASE WHEN behavior_type = 'buy'  THEN user_id END) AS buyer_uv,
    ROUND(100 * COUNT(DISTINCT CASE WHEN behavior_type = 'buy' THEN user_id END)
               / COUNT(DISTINCT user_id), 2)                         AS conv_pct
FROM user_behavior
GROUP BY hr
ORDER BY hr;
