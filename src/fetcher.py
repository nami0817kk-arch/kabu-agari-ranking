"""
当日の株価ランキングを kabutan.jp から取得する。

PJT003-quality-gainer-tracker の src/data/ranking_fetcher.py の
_fetch_kabutan() 系ロジックを、当日取得のみに絞って移植したもの。
kabudragon（過去日backfill用）は v1 では不要なため含めない。

kabutan.jp/warning/ の一覧から確認した各ランキングのmode:
  2_1: 今日の上昇率（値上がり率ランキング）
  2_2: 今日の下落率（値下がり率ランキング）
  2_9: 本日の活況銘柄（約定回数ランキング。出来高そのものではない点に注意）
"""
import re
import time
from datetime import date

import requests
from bs4 import BeautifulSoup
import pandas as pd

_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "ja,en;q=0.9",
}

_KABUTAN_URL = "https://kabutan.jp/warning/?mode={mode}&market={market}"
_KABUTAN_MARKETS = [1, 2, 3]  # プライム, スタンダード, グロース
_ASOF_DATE_RE = re.compile(r'<time datetime="(\d{4}-\d{2}-\d{2})">終値</time>')

_MODE_GAINERS = "2_1"
_MODE_LOSERS = "2_2"
_MODE_ACTIVE = "2_9"

# 取得時に発生した通信エラーの記録。
# 「休場日で0件」と「取得先に拒否されて0件」を呼び出し元が区別するために使う。
# 後者を休場日扱いで握りつぶすと、CIが緑のままサイトの更新が止まる。
fetch_errors: list[str] = []


def _fetch_market_html(mode: str, market: int, retries: int = 3) -> str | None:
    url = _KABUTAN_URL.format(mode=mode, market=market)
    for attempt in range(retries):
        try:
            resp = requests.get(url, headers=_HEADERS, timeout=30)
            resp.raise_for_status()
            return resp.text
        except Exception as e:
            if attempt < retries - 1:
                time.sleep(3 * (attempt + 1))
            else:
                print(f"  [WARN] kabutan mode={mode} market={market} 取得失敗: {e}")
                fetch_errors.append(f"mode={mode} market={market}: {e}")
    return None


def _parse_market_html(html: str) -> pd.DataFrame:
    """
    kabutan の stock_table を解析する。列の意味はランキング種別で共通:
      13列 (プライム): code[0] name[1] market[2] _ _ close[5] _ 前日比[7] change%[8] metric[9]
      12列 (スタンダード/グロース): code[0] market[1] _ _ close[4] _ 前日比[6] change%[7] metric[8]

    metric 列は値上がり/値下がりランキングでは出来高、活況ランキングでは約定回数。
    """
    soup = BeautifulSoup(html, "lxml")
    tbl = soup.find("table", class_="stock_table")
    if tbl is None:
        return pd.DataFrame()

    rows = []
    for tr in tbl.find_all("tr"):
        tds = tr.find_all("td")
        n = len(tds)
        if n < 9:
            continue
        texts = [td.get_text(strip=True) for td in tds]

        try:
            code = texts[0]
            if not re.match(r"^\d{4}$", code):
                continue

            if n >= 13:
                name = texts[1]
                close = texts[5].replace(",", "")
                change_s = texts[8]
                metric_s = texts[9].replace(",", "")
            else:
                name = code
                close = texts[4].replace(",", "")
                change_s = texts[7]
                metric_s = texts[8].replace(",", "")

            change_pct = float(re.sub(r"[^0-9.\-]", "", change_s))

            rows.append({
                "ticker": code + ".T",
                "code": code,
                "name": name,
                "close": float(close) if close.replace(".", "").isdigit() else None,
                "change_pct": change_pct,
                "metric_value": int(metric_s) if metric_s.isdigit() else None,
            })
        except (IndexError, ValueError):
            continue

    return pd.DataFrame(rows) if rows else pd.DataFrame()


def _extract_asof_date(html: str) -> str | None:
    """
    ページ内の「終値」日付表示（<time datetime="YYYY-MM-DD">終値</time>）から
    このランキングが実際にどの営業日の終値に基づくかを取得する。

    kabutan.jpは休場日にアクセスしても直近営業日のデータをそのまま表示するため、
    取得日（date.today()）をそのままラベルにすると休日実行時に日付がずれる。
    """
    m = _ASOF_DATE_RE.search(html)
    return m.group(1) if m else None


def _fetch_name(code: str) -> str:
    """kabutan の個別ページから日本語銘柄名を取得する。"""
    try:
        url = f"https://kabutan.jp/stock/?code={code}"
        resp = requests.get(url, headers=_HEADERS, timeout=10)
        soup = BeautifulSoup(resp.text, "lxml")
        h1 = soup.find("h1")
        if h1:
            return h1.get_text(strip=True).split("(")[0].strip()
        print(f"  [WARN] {code}: 個別ページに銘柄名が見つかりませんでした")
    except Exception as e:
        # 名前が引けなくてもランキング自体は出せるのでコードで代替する。
        # ただし黙って通すと、名前がコードのまま並んでいる原因が追えなくなる。
        print(f"  [WARN] {code}: 銘柄名の取得に失敗しました: {e}")
    return code


def _fill_names(df: pd.DataFrame) -> pd.DataFrame:
    """銘柄名がコード（数字4桁）になっている行を kabutan 個別ページで補完する。"""
    needs_name = df["name"].str.match(r"^\d{4}$")
    for idx, row in df[needs_name].iterrows():
        df.at[idx, "name"] = _fetch_name(row["code"])
        time.sleep(0.5)
    return df


def _fetch_ranking(mode: str, label: str, top_n: int) -> tuple[pd.DataFrame, str | None]:
    """3市場を集約した生データ（フィルタ・ソート前）と、実際の終値基準日を返す。"""
    print(f"  {label}取得中（kabutan.jp）...")
    all_rows = []
    asof_date = None
    for market in _KABUTAN_MARKETS:
        html = _fetch_market_html(mode, market)
        if html:
            if asof_date is None:
                asof_date = _extract_asof_date(html)
            df_m = _parse_market_html(html)
            if not df_m.empty:
                all_rows.append(df_m)
        time.sleep(1)

    if not all_rows:
        return pd.DataFrame(), asof_date

    df = (
        pd.concat(all_rows, ignore_index=True)
        .drop_duplicates("ticker")
        .reset_index(drop=True)
    )
    return df, asof_date


def _finalize(df: pd.DataFrame, rec_date: str | None) -> pd.DataFrame:
    df = _fill_names(df.reset_index(drop=True))
    df["rec_date"] = rec_date or str(date.today())
    df.insert(0, "rank", range(1, len(df) + 1))
    return df


def fetch_gainers(top_n: int = 30) -> pd.DataFrame:
    """値上がり率上位 top_n 件。columns: rank,ticker,code,name,close,change_pct,metric_value(出来高),rec_date"""
    df, asof_date = _fetch_ranking(_MODE_GAINERS, "値上がりランキング", top_n)
    if df.empty:
        return df
    df = df[df["change_pct"] > 0].sort_values("change_pct", ascending=False).head(top_n)
    return _finalize(df, asof_date)


def fetch_losers(top_n: int = 30) -> pd.DataFrame:
    """値下がり率上位 top_n 件（下落率が大きい順）。columns同上（change_pctは負値）。"""
    df, asof_date = _fetch_ranking(_MODE_LOSERS, "値下がりランキング", top_n)
    if df.empty:
        return df
    df = df[df["change_pct"] < 0].sort_values("change_pct", ascending=True).head(top_n)
    return _finalize(df, asof_date)


def fetch_active(top_n: int = 30) -> pd.DataFrame:
    """約定回数（取引の活発さ）上位 top_n 件。metric_valueは約定回数。"""
    df, asof_date = _fetch_ranking(_MODE_ACTIVE, "活況銘柄ランキング", top_n)
    if df.empty:
        return df
    df = df.sort_values("metric_value", ascending=False).head(top_n)
    return _finalize(df, asof_date)
