"""
値上がりランキング上位銘柄の「その後の値動き」を14営業日分追跡する。

PJT003-quality-gainer-tracker の src/db/manager.py（Access DB版）の
save()/update_prices() のロジックを、JSONファイル1本で完結するように移植したもの。
"""
import json
from datetime import date
from pathlib import Path

import pandas as pd
import yfinance as yf

_DATA_DIR = Path(__file__).resolve().parent.parent / "data"
_TRACKING_PATH = _DATA_DIR / "tracking.json"

_TRACK_TOP_N = 10  # 値上がりランキング上位何件を追跡対象にするか
_DAYS = [f"d{n:02d}" for n in range(1, 15)]


def _load() -> list[dict]:
    if not _TRACKING_PATH.exists():
        return []
    return json.loads(_TRACKING_PATH.read_text(encoding="utf-8"))


def _save(entries: list[dict]) -> None:
    _TRACKING_PATH.write_text(
        json.dumps(entries, ensure_ascii=False, indent=2), encoding="utf-8"
    )


def add_new_picks(gainers_df: pd.DataFrame) -> None:
    """
    本日の値上がりランキング上位 _TRACK_TOP_N 件を追跡対象に追加する。

    スキップルール（PJT003と同じ冪等性ルール）:
    - 同日に既に登録済みの銘柄
    - 追跡中（いずれかのdNNが未記入）の銘柄
    """
    if gainers_df.empty:
        return

    entries = _load()
    today = str(date.today())

    same_day = {e["ticker"] for e in entries if e["rec_date"] == today}
    active = {
        e["ticker"] for e in entries
        if any(e["prices"].get(d) is None for d in _DAYS)
    }
    skip = same_day | active

    added = 0
    for row in gainers_df.head(_TRACK_TOP_N).itertuples():
        ticker = row.ticker
        if ticker in skip:
            continue
        entries.append({
            "ticker": ticker,
            "code": row.code,
            "name": row.name,
            "rec_date": today,
            "rec_close": float(row.close) if row.close is not None else None,
            "prices": {d: None for d in _DAYS},
        })
        added += 1

    if added:
        _save(entries)
        print(f"  追跡対象に{added}件を新規登録しました")


def update_prices() -> None:
    """追跡中（d14未記入）の銘柄について、当日までの終値でdNNを埋める。"""
    entries = _load()
    pending = [e for e in entries if any(e["prices"].get(d) is None for d in _DAYS)]
    if not pending:
        return

    from collections import defaultdict
    by_ticker: dict[str, list[dict]] = defaultdict(list)
    for e in pending:
        by_ticker[e["ticker"]].append(e)

    today_str = str(date.today())
    updated = 0

    for ticker, group in by_ticker.items():
        try:
            df = yf.download(ticker, period="45d", interval="1d", auto_adjust=True, progress=False)
            if df.empty:
                continue
            if isinstance(df.columns, pd.MultiIndex):
                df.columns = df.columns.droplevel(1)
            df.index = pd.to_datetime(df.index).strftime("%Y-%m-%d")
            dates_list = df.index.tolist()

            for entry in group:
                rec_date = entry["rec_date"]
                try:
                    base_idx = dates_list.index(rec_date)
                except ValueError:
                    later = [d for d in dates_list if d > rec_date]
                    if not later:
                        continue
                    base_idx = dates_list.index(later[0]) - 1

                changed = False
                for n, d_key in enumerate(_DAYS, start=1):
                    if entry["prices"].get(d_key) is not None:
                        continue
                    idx = base_idx + n
                    if idx < len(dates_list) and dates_list[idx] <= today_str:
                        entry["prices"][d_key] = round(float(df.iloc[idx]["Close"]), 2)
                        changed = True
                if changed:
                    updated += 1
        except Exception as e:
            print(f"  [WARN] {ticker} の価格更新に失敗: {e}")
            continue

    if updated:
        _save(entries)
        print(f"  {updated}件の追跡価格を更新しました")


def load_report_data() -> list[dict]:
    """レンダリング用に追跡データをそのまま返す（新しい順）。"""
    entries = _load()
    entries.sort(key=lambda e: e["rec_date"], reverse=True)
    return entries
