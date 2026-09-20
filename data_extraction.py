"""
淘宝用户行为数据抽取脚本，
从约 3.4GB 的原始 CSV（UserBehavior.csv，无表头）中，按 user_id 随机抽样，
抽取约 10 万条行为记录。同一 user_id 的所有行为记录会被完整保留，
以保证后续留存分析、路径分析时用户行为序列不被切断。
原始数据字段顺序（无表头）：
    user_id, item_id, category_id, behavior_type, timestamp
输出字段：在原字段基础上，将秒级时间戳 timestamp 转成可读时间 datetime（格式 YYYY-MM-DD HH:MM:SS）
"""

import os
import time

import numpy as np
import pandas as pd

# ==================== 配置 ====================
RAW_PATH = r"E:\taobao_yonghu_behavior_dataset\UserBehavior\UserBehavior.csv"

# 处理后数据保存到项目根目录下的 data 文件夹
PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "data")
OUTPUT_PATH = os.path.join(OUTPUT_DIR, "user_behavior_sample.csv")

COLUMNS = ["user_id", "item_id", "category_id", "behavior_type", "timestamp"]

TARGET_ROWS = 100_000     # 目标抽取记录数（整用户保留，实际会略多于该值）
CHUNK_SIZE = 2_000_000    # 每批读取的行数
RANDOM_SEED = 42          # 随机种子，保证抽样可复现


def count_rows_per_user():
    """第一遍扫描：统计每个 user_id 的行为记录数。

    返回 (counts, total_rows)：
        counts      numpy 数组，counts[user_id] 即该用户的记录数
        total_rows  原始数据总行数
    """
    counts = np.zeros(1 << 20, dtype=np.int64)
    total_rows = 0

    reader = pd.read_csv(
        RAW_PATH,
        header=None,
        usecols=[0],
        names=["user_id"],
        dtype={"user_id": "int64"},
        chunksize=CHUNK_SIZE,
    )
    for chunk in reader:
        uids = chunk["user_id"].to_numpy()
        max_id = int(uids.max())

        # user_id 上界未知，动态扩容计数数组
        if max_id >= counts.size:
            new_counts = np.zeros(max(max_id + 1, counts.size * 2), dtype=np.int64)
            new_counts[: counts.size] = counts
            counts = new_counts

        counts += np.bincount(uids, minlength=counts.size)
        total_rows += len(uids)
        print(f"    已扫描 {total_rows:,} 行")

    return counts, total_rows


def select_users(counts):
    """随机抽取 user_id，累计记录数达到 TARGET_ROWS 为止。

    返回 (selected_flag, n_users, selected_rows)：
        selected_flag  布尔数组，标记哪些 user_id 被选中
        n_users        选中的 user_id 个数
        selected_rows  选中用户对应的记录数合计
    """
    rng = np.random.default_rng(RANDOM_SEED)

    user_ids = np.flatnonzero(counts)          # 所有出现过的 user_id
    rng.shuffle(user_ids)                      # 随机打乱，等价于按 user_id 随机抽样

    cum_rows = np.cumsum(counts[user_ids])     # 累加记录数
    n_users = int(np.searchsorted(cum_rows, TARGET_ROWS) + 1)
    n_users = min(n_users, len(user_ids))      # 防御：目标行数超过总量时全取

    selected_flag = np.zeros(counts.size, dtype=bool)
    selected_flag[user_ids[:n_users]] = True

    return selected_flag, n_users, int(cum_rows[n_users - 1])


def extract_rows(selected_flag):
    """第二遍扫描：捞出被选中 user_id 的全部记录（保留所有字段）。"""
    parts = []
    reader = pd.read_csv(
        RAW_PATH,
        header=None,
        names=COLUMNS,
        chunksize=CHUNK_SIZE,
    )
    for chunk in reader:
        uids = chunk["user_id"].to_numpy()
        mask = selected_flag[uids]             # 第一遍已确定取值上界，索引安全
        if mask.any():
            parts.append(chunk[mask])

    result = pd.concat(parts, ignore_index=True)
    return result.sort_values(["user_id", "timestamp"], ignore_index=True)


def main():
    start = time.time()

    if not os.path.exists(RAW_PATH):
        raise FileNotFoundError(f"未找到原始数据文件：{RAW_PATH}")
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print(f"原始数据：{RAW_PATH}")

    print("[1/2] 第一遍扫描：统计每个 user_id 的记录数 ...")
    counts, total_rows = count_rows_per_user()
    n_unique_users = int((counts > 0).sum())
    print(f"    总记录数：{total_rows:,}，独立 user_id 数：{n_unique_users:,}")

    print(f"[2/2] 第二遍扫描：抽取约 {TARGET_ROWS:,} 条记录（按 user_id 整用户保留）...")
    selected_flag, n_users, selected_rows = select_users(counts)
    print(f"    选中 user_id 数：{n_users:,}，对应记录数：{selected_rows:,}")

    result = extract_rows(selected_flag)

    # timestamp 为 Unix 秒级时间戳（北京时间），转换为可读时间
    result["datetime"] = (
        pd.to_datetime(result["timestamp"], unit="s", utc=True)
        .dt.tz_convert("Asia/Shanghai")
        .dt.tz_localize(None)
    )
    result = result[
        ["user_id", "item_id", "category_id", "behavior_type", "timestamp", "datetime"]
    ]
    result.to_csv(OUTPUT_PATH, index=False, header=True)

    behavior = result["behavior_type"].value_counts().to_dict()
    print("\n抽取完成")
    print(f"    输出文件：{OUTPUT_PATH}")
    print(f"    记录数：{len(result):,}，user_id 数：{result['user_id'].nunique():,}")
    print(f"    行为分布：{behavior}")
    print(f"    耗时：{time.time() - start:.1f} 秒")


if __name__ == "__main__":
    main()
