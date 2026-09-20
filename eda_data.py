import time

import numpy as np
import pandas as pd

RAW_PATH = r"E:\taobao_yonghu_behavior_dataset\UserBehavior\UserBehavior.csv"
COLUMNS = ["user_id", "item_id", "category_id", "behavior_type", "timestamp"]
CHUNK_SIZE = 2000000


def preview(n=10):
    df = pd.read_csv(RAW_PATH, header=None, names=COLUMNS, nrows=n)
    print(f"--- 前 {n} 行 ---")
    print(df.to_string(index=False))
    print("\n--- 字段类型 ---")
    print(df.dtypes)
    return df


def profile():
    """2. 全量概况：分块扫描，统计行数/空值/独立用户数/时间范围等。"""
    total_rows = 0
    null_counts = pd.Series(0, index=COLUMNS, dtype="int64")
    behavior_counts = pd.Series(dtype="int64")
    daily_counts = pd.Series(dtype="int64")
    users, items, categories = set(), set(), set()
    ts_min, ts_max = None, None

    reader = pd.read_csv(
        RAW_PATH,
        header=None,
        names=COLUMNS,
        dtype={"user_id": "int32", "item_id": "int32",
               "category_id": "int32", "behavior_type": "category"},
        chunksize=CHUNK_SIZE,
    )
    for chunk in reader:
        total_rows += len(chunk)

        null_counts += chunk.isna().sum()

        # 独立用户 / 商品 / 类目数：分块去重后并入集合
        users.update(np.unique(chunk["user_id"].to_numpy()))
        items.update(np.unique(chunk["item_id"].to_numpy()))
        categories.update(np.unique(chunk["category_id"].to_numpy()))

        # 行为类型分布
        behavior_counts = behavior_counts.add(
            chunk["behavior_type"].value_counts(), fill_value=0
        )

        # 时间范围与按日记录数
        ts = chunk["timestamp"]
        ts_min = ts.min() if ts_min is None else min(ts_min, ts.min())
        ts_max = ts.max() if ts_max is None else max(ts_max, ts.max())
        daily_counts = daily_counts.add(
            pd.to_datetime(ts, unit="s").dt.date.value_counts(), fill_value=0
        )

        print(f"    已扫描 {total_rows:,} 行")

    return {
        "total_rows": total_rows,
        "null_counts": null_counts,
        "users": users,
        "items": items,
        "categories": categories,
        "behavior_counts": behavior_counts,
        "daily_counts": daily_counts,
        "ts_min": ts_min,
        "ts_max": ts_max,
    }


def main():
    start = time.time()

    preview(10)

    print("\n--- 全量概况（分块扫描中，请稍候）---")
    s = profile()

    print("\n========== 数据概况 ==========")
    print(f"总行数        : {s['total_rows']:,}")
    print(f"独立用户数    : {len(s['users']):,}")
    print(f"独立商品数    : {len(s['items']):,}")
    print(f"独立类目数    : {len(s['categories']):,}")
    print(f"时间范围      : {pd.to_datetime(s['ts_min'], unit='s')} ~ "
          f"{pd.to_datetime(s['ts_max'], unit='s')}")
    print(f"缺失值        : {s['null_counts'].sum()} 条")
    print(f"总行数/独立用户: {s['total_rows'] / len(s['users']):.1f} 行/人")

    print("\n--- 行为类型分布 ---")
    print(s["behavior_counts"].to_string())

    print("\n--- 按日记录数 ---")
    print(s["daily_counts"].sort_index().to_string())

    print(f"\n耗时：{time.time() - start:.1f} 秒")


if __name__ == "__main__":
    main()
