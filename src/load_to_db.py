"""
清洗后数据入库脚本

输入：data/user_behavior_clean.csv
数据库：默认 SQLite（data/taobao.db）

表结构 user_behavior：
    user_id       INTEGER   用户 ID
    item_id       INTEGER   商品 ID
    category_id   INTEGER   类目 ID
    behavior_type TEXT      行为类型：pv 浏览 / cart 加购 / fav 收藏 / buy 购买
    event_ts      INTEGER   行为时间戳（Unix 秒，北京时间）
    event_time    DATETIME  行为时间（可读格式）

"""

import argparse
import os
import time

import pandas as pd
from sqlalchemy import Index, MetaData, String, Table, create_engine, text

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INPUT_PATH = os.path.join(PROJECT_ROOT, "data", "user_behavior_clean.csv")
SQLITE_PATH = os.path.join(PROJECT_ROOT, "data", "taobao.db")
DEFAULT_DB_URL = f"sqlite:///{SQLITE_PATH}"

TABLE = "user_behavior"

# 常见查询维度建立索引，保证指标查询响应速度
INDEXES = {
    "idx_user_id": "user_id",
    "idx_item_id": "item_id",
    "idx_category_id": "category_id",
    "idx_behavior_type": "behavior_type",
    "idx_event_time": "event_time",
}


def load(db_url):
    engine = create_engine(db_url)

    df = pd.read_csv(INPUT_PATH, parse_dates=["datetime"])
    df = df.rename(columns={"timestamp": "event_ts", "datetime": "event_time"})
    print(f"读取清洗后数据：{len(df):,} 行")

    df.to_sql(
        TABLE, engine, if_exists="replace", index=False, chunksize=10000,
        dtype={"behavior_type": String(10)},
    )
    print(f"已写入表 {TABLE}")

    # 用 SQLAlchemy 的 Index.create 建索引，自动兼容 SQLite / MySQL
    table = Table(TABLE, MetaData(), autoload_with=engine)
    for name, column in INDEXES.items():
        Index(name, table.c[column]).create(engine, checkfirst=True)
    print(f"已建立索引：{', '.join(INDEXES)}")

    return engine


def verify(engine):
    """入库校验"""
    queries = {
        "总记录数": f"SELECT COUNT(*) FROM {TABLE}",
        "独立用户数(UV)": f"SELECT COUNT(DISTINCT user_id) FROM {TABLE}",
        "PV": f"SELECT COUNT(*) FROM {TABLE} WHERE behavior_type = 'pv'",
        "购买用户数": (
            f"SELECT COUNT(DISTINCT user_id) FROM {TABLE} WHERE behavior_type = 'buy'"
        ),
        "整体转化率": (
            f"SELECT ROUND(100.0 * COUNT(DISTINCT CASE WHEN behavior_type = 'buy' THEN user_id END)"
            f" / COUNT(DISTINCT user_id), 2) FROM {TABLE}"
        ),
    }
    print("\n--- 指标校验 ---")
    with engine.connect() as conn:
        for label, sql in queries.items():
            value = conn.execute(text(sql)).scalar()
            print(f"  {label}: {value}{'%' if label.endswith('率') else ''}")


def main():
    start = time.time()
    parser = argparse.ArgumentParser(description="将清洗后数据写入数据库")
    parser.add_argument("--url", default=DEFAULT_DB_URL, help="数据库连接串")
    args = parser.parse_args()

    if not os.path.exists(INPUT_PATH):
        raise FileNotFoundError(f"未找到清洗后数据：{INPUT_PATH}")

    engine = load(args.url)
    verify(engine)

    print(f"\n完成，耗时 {time.time() - start:.1f} 秒")
    if args.url.startswith("sqlite"):
        print(f"数据库文件：{SQLITE_PATH}")


if __name__ == "__main__":
    main()
