import os
import time

import pandas as pd

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INPUT_PATH = os.path.join(PROJECT_ROOT, "data", "user_behavior_sample.csv")
OUTPUT_PATH = os.path.join(PROJECT_ROOT, "data", "user_behavior_clean.csv")

KEY_COLUMNS = ["user_id", "item_id", "category_id", "behavior_type", "timestamp"]
VALID_BEHAVIORS = ["pv", "cart", "fav", "buy"]
START_DATE = "2017-11-25 00:00:00"
END_DATE = "2017-12-03 23:59:59"


def clean():
    df = pd.read_csv(INPUT_PATH, parse_dates=["datetime"])
    raw_rows = len(df)
    print(f"读取原始数据：{raw_rows:,} 行")

    # 1. 去重：同一用户在同一时刻对同一商品的同一行为只保留一条
    df = df.drop_duplicates(subset=KEY_COLUMNS)
    print(f"  去重后：{len(df):,} 行（删除 {raw_rows - len(df):,} 行）")

    # 2. 空值处理
    before = len(df)
    df = df.dropna(subset=KEY_COLUMNS + ["datetime"])
    print(f"  删除空值后：{len(df):,} 行（删除 {before - len(df):,} 行）")

    # 3. 行为类型校验
    before = len(df)
    df = df[df["behavior_type"].isin(VALID_BEHAVIORS)]
    print(f"  合法行为类型过滤后：{len(df):,} 行（删除 {before - len(df):,} 行）")

    # 4. 时间越界过滤
    before = len(df)
    df = df[df["datetime"].between(START_DATE, END_DATE)]
    print(f"  时间越界过滤后：{len(df):,} 行（删除 {before - len(df):,} 行）")

    # 5. 类型规范化 + 排序
    df = df.astype(
        {"user_id": "int32", "item_id": "int32", "category_id": "int32",
         "behavior_type": "category"}
    )
    df = df.sort_values(["user_id", "datetime"], ignore_index=True)

    return df, raw_rows


def main():
    start = time.time()
    df, raw_rows = clean()
    df.to_csv(OUTPUT_PATH, index=False)

    print("\n清洗完成")
    print(f"    输出文件：{OUTPUT_PATH}")
    print(f"    记录数：{raw_rows:,} -> {len(df):,}（保留 {len(df) / raw_rows:.2%}）")
    print(f"    user_id 数：{df['user_id'].nunique():,}")
    print(f"    时间范围：{df['datetime'].min()} ~ {df['datetime'].max()}")
    print(f"    行为分布：{df['behavior_type'].value_counts().to_dict()}")
    print(f"    耗时：{time.time() - start:.1f} 秒")


if __name__ == "__main__":
    main()
