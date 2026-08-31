"""
_parse_market_html のテスト。

kabutan.jp の HTML 構造が変わると、例外を投げずに「0件」や
「間違った列を読んだ値」を静かに返すのがこの関数の壊れ方なので、
列の並びを固定しておく。ネットワークには出ない。
"""
import sys
from pathlib import Path

import pandas as pd
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from fetcher import _parse_market_html  # noqa: E402


def _table(rows_html: str) -> str:
    return f'<table class="stock_table"><tbody>{rows_html}</tbody></table>'


def _row(cells: list[str]) -> str:
    return "<tr>" + "".join(f"<td>{c}</td>" for c in cells) + "</tr>"


# プライム: 13列 code[0] name[1] market[2] _ _ close[5] _ 前日比[7] change%[8] metric[9]
PRIME_ROW = [
    "7203", "トヨタ自動車", "東P", "15:30", "2,700",
    "2,850", "+150", "+150", "+5.56%", "1,234,500", "-", "-", "-",
]

# スタンダード/グロース: 12列 code[0] market[1] _ _ close[4] _ 前日比[6] change%[7] metric[8]
STANDARD_ROW = [
    "3969", "東S", "15:30", "1,000",
    "1,100", "+100", "+100", "+10.00%", "45,600", "-", "-", "-",
]


def test_プライムの行を列の意味どおりに読む():
    df = _parse_market_html(_table(_row(PRIME_ROW)))

    assert len(df) == 1
    got = df.iloc[0]
    assert got["ticker"] == "7203.T"
    assert got["code"] == "7203"
    assert got["name"] == "トヨタ自動車"
    assert got["close"] == 2850.0
    assert got["change_pct"] == pytest.approx(5.56)
    assert got["metric_value"] == 1234500


def test_12列の市場では銘柄名がコードのままになる():
    # 名前の列が無いので、_fill_names が後から個別ページで埋める前提。
    df = _parse_market_html(_table(_row(STANDARD_ROW)))

    assert len(df) == 1
    got = df.iloc[0]
    assert got["code"] == "3969"
    assert got["name"] == "3969"
    assert got["close"] == 1100.0
    assert got["change_pct"] == pytest.approx(10.0)


def test_値下がり行の変化率は負値になる():
    row = list(PRIME_ROW)
    row[8] = "-4.20%"
    df = _parse_market_html(_table(_row(row)))

    assert df.iloc[0]["change_pct"] == pytest.approx(-4.20)


def test_stock_tableが無ければ空のDataFrameを返す():
    # kabutan 側の改修・メンテ画面・エラーページで起きうる。例外にはしない。
    df = _parse_market_html("<html><body><p>ただいまメンテナンス中です</p></body></html>")

    assert isinstance(df, pd.DataFrame)
    assert df.empty


def test_銘柄コードでない行は読み飛ばす():
    # ヘッダ行や広告行が混ざっても、正しい行だけ残る。
    header = _row(["コード", "銘柄名", "市場", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-"])
    df = _parse_market_html(_table(header + _row(PRIME_ROW)))

    assert len(df) == 1
    assert df.iloc[0]["code"] == "7203"
