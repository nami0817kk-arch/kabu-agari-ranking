# kabu-agari-ranking

日本株（東証プライム/スタンダード/グロース）の値上がり率・値下がり率・活況銘柄ランキングを
毎日自動取得し、静的サイトとして公開する。広告（Google AdSense想定）による収益化が目的。

公開URL: https://kabu-agari-ranking.pages.dev/

GitHub Actions が毎日平日 16:00 JST（大引け後）にランキングを取得・記録し、
Cloudflare Pages に自動デプロイする。

## ページ構成

- `/index.html` 値上がりランキング（本日）
- `/losers.html` 値下がりランキング（本日）
- `/active.html` 活況銘柄ランキング（本日、約定回数ベース）
- `/tracking.html` 実績：値上がり上位銘柄のその後14営業日の値動き追跡
- `/archive/{gainers,losers,active}/` 各ランキングの過去日アーカイブ
- `/about.html` `/privacy.html`

## 構成

```
src/
  fetcher.py     kabutan.jp から当日の値上がり/値下がり/活況ランキングを取得
  tracking.py    値上がり上位銘柄の14営業日パフォーマンス追跡（data/tracking.json）
  build_site.py  取得→data/*.json保存→追跡更新→サイトビルドのエントリポイント
  render.py      Jinja2テンプレートからoutput/に静的HTMLを生成
templates/       ページテンプレート（Jinja2）
static/          og-image.png など、ビルドのたびにoutput/へそのままコピーする静的アセット
data/            日別ランキング（YYYY-MM-DD.json）＋ tracking.json（追跡データ）
output/          ビルド成果物（gitignore対象、CI実行のたびに再生成）
```

## ローカルでの動作確認

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python src/build_site.py
```

`output/index.html` をブラウザで開いて確認する。

## 自動更新（GitHub Actions）

`.github/workflows/daily-gainers-site.yml` が平日 16:00 JST に自動実行し、
`data/*.json`（当日ランキング）と `data/tracking.json`（追跡データ）をコミット、
`output/` を Cloudflare Pages にデプロイする。
手動テストは GitHub の Actions タブから `workflow_dispatch` で実行できる。

市場休場日などでランキングが0件の場合は、`data/` への新規コミットをスキップする
（既存データは壊さない）。

## 実績追跡（tracking.py）

値上がりランキング上位10銘柄を毎日 `data/tracking.json` に登録し、
記録日を基準に14営業日分の終値（yfinance経由）を埋めていく。
d14まで埋まった銘柄は「追跡完了」として `/tracking.html` の
勝率・平均リターン集計と2週間後リターン上位5件に反映される。
同一銘柄が追跡中（d14未記入）の間は重複登録しない（PJT003と同じ冪等性ルール）。

## AdSense（要対応・TODO）

- `templates/base.html` に広告枠のプレースホルダーを設置済み（`data-ad-client="ca-pub-XXXXXXXXXXXXXXXX"`）。
  AdSenseアカウントの取得・審査申請はユーザー本人が行う必要がある。
  審査には一般的に、プライバシーポリシー・実際のコンテンツ・一定期間の運用実績が求められる。
- 審査通過後、`templates/base.html` の publisher ID・ad-slot ID を実際の値に置き換え、
  コメントアウトしている `<script>` タグを有効化する。

## 既知の制約・注意事項（v1時点）

- データ取得元（kabutan.jp）のスクレイピングは利用規約上のリスクを許容した上で採用している。
  今後規約変更や取得停止要請があった場合はデータ取得方法の見直しが必要。
- 「活況銘柄ランキング」はkabutan.jp上「本日の活況銘柄」（mode=2_9）を使用しており、
  実体は出来高（株数）ではなく約定回数によるランキングである点に注意（about.htmlに明記）。
- 掲載情報は投資助言ではない旨を `templates/about.html` に明記している。
- お問い合わせ先は未設定（保留中）。AdSense審査前に用意することを推奨。

## 由来

もとは `nami0817kk-arch/claude-code-dev` リポジトリ内の `PJT006-gainer-ranking-site` として
開発したが、公開URLをサイト内容に合ったものにするため本リポジトリに切り出した。
