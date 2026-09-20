-- ============================================================
-- F1 大盘概览：流量规模、行为结构、日 / 小时趋势
-- 数据源：user_behavior（由 data/user_behavior_clean.csv 导入 MySQL）
-- 数据范围：2017-11-25 ~ 2017-12-03，共 9 天
-- 口径说明：
--   PV = behavior_type='pv' 的记录数（不去重）
--   UV = 有任意行为记录的独立用户数（count distinct user_id）
-- 注意：当前为按 user_id 抽样的 998 个用户 / 99,957 行，
--       用于验证口径与 SQL 逻辑，绝对值不代表平台全量。
-- ============================================================


-- 1.1 核心指标：PV / UV / 人均 PV / 购买用户数 / 整体转化率
SELECT
    SUM(behavior_type = 'pv')                                        AS pv,
    COUNT(DISTINCT user_id)                                          AS uv,
    ROUND(SUM(behavior_type = 'pv') / COUNT(DISTINCT user_id), 2)    AS pv_per_user,
    COUNT(DISTINCT CASE WHEN behavior_type = 'buy' THEN user_id END) AS buyer_uv,
    ROUND(100 * COUNT(DISTINCT CASE WHEN behavior_type = 'buy' THEN user_id END)
               / COUNT(DISTINCT user_id), 2)                         AS overall_conv_pct
FROM user_behavior;


-- 1.2 行为类型分布（记录数占比）
SELECT
    behavior_type,
    COUNT(*)                                         AS cnt,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM user_behavior
GROUP BY behavior_type
ORDER BY cnt DESC;


-- 1.3 日趋势：PV / UV / 加购用户 / 购买用户
SELECT
    DATE(event_time)                                                  AS dt,
    DAYNAME(event_time)                                               AS weekday,
    SUM(behavior_type = 'pv')                                         AS pv,
    COUNT(DISTINCT user_id)                                           AS uv,
    COUNT(DISTINCT CASE WHEN behavior_type = 'cart' THEN user_id END) AS cart_uv,
    COUNT(DISTINCT CASE WHEN behavior_type = 'buy'  THEN user_id END) AS buyer_uv
FROM user_behavior
GROUP BY dt, weekday
ORDER BY dt;


-- 1.4 小时分布：行为量与人数的时段特征
SELECT
    HOUR(event_time)                                 AS hr,
    COUNT(*)                                         AS cnt,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct,
    COUNT(DISTINCT user_id)                          AS uv
FROM user_behavior
GROUP BY hr
ORDER BY hr;


-- 1.5 工作日 / 周末对比（DAYOFWEEK：1=周日，7=周六）
SELECT
    CASE WHEN DAYOFWEEK(event_time) IN (1, 7) THEN '周末' ELSE '工作日' END AS day_type,
    COUNT(*)                                         AS cnt,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct,
    COUNT(DISTINCT user_id)                          AS uv,
    SUM(behavior_type = 'pv')                        AS pv
FROM user_behavior
GROUP BY day_type
ORDER BY cnt DESC;









