# 日次のランキング取得（このPCのタスクスケジューラから毎平日16:10に実行される）。
#
# kabutan が GitHub Actions の IP を 405 でブロックしているため、
# 取得だけは手元で行い、data/ を push する。push を受けた CI（daily-gainers-site.yml）が
# ビルド・X投稿・Cloudflare Pages への公開を行う。
#
# このスクリプトが動かなくなっても、CI 側の 17:00 JST の鮮度監視が
# 「データが古い」と Issue で知らせてくれる（黙って止まらない）。

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repo

$log = Join-Path $repo "run-daily.log"
"=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Add-Content $log

try {
    git pull --ff-only origin master 2>&1 | Add-Content $log

    & "$repo\.venv\Scripts\python.exe" src\build_site.py 2>&1 | Add-Content $log
    if ($LASTEXITCODE -ne 0) { throw "build_site.py failed (exit $LASTEXITCODE)" }

    git add data
    git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        git commit -m "chore: 値上がりランキングデータを更新" 2>&1 | Add-Content $log
        git push origin master 2>&1 | Add-Content $log
        "pushed new data" | Add-Content $log
    } else {
        "no new data to commit" | Add-Content $log
    }
    "OK" | Add-Content $log
} catch {
    "FAILED: $_" | Add-Content $log
    exit 1
}
