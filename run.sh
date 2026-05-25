#!/usr/bin/env bash
set -euo pipefail

# -------------------------
# 取得日数（デフォルト 10）
# -------------------------
DAYS="${1:-10}"

# 保存先ディレクトリ
DIR="./output"
mkdir -p "$DIR"

# Cookie ファイル名
COOKIE="cookie.txt"

# 曜日
weekdays=(日 月 火 水 木 金 土)

echo "[INFO] Cookie 初期化中..."

# Cookie 初期化
curl -sSL -c "$COOKIE" \
  "https://www.iryou.teikyouseido.mhlw.go.jp/znk-web/juminkanja/S2310/initialize?pref=38" \
  -o /dev/null

# CSRF 取得
echo "[INFO] CSRF トークン取得中..."
C=$(curl -sSL -b "$COOKIE" -c "$COOKIE" \
  "https://www.iryou.teikyouseido.mhlw.go.jp/znk-web/juminkanja/S2700/initialize" \
  | grep -oP 'name="_csrf" value="\K[^"]+' | head -1)

if [[ -z "$C" ]]; then
  echo "[ERROR] CSRF トークン取得失敗"
  exit 1
fi

# 検索
echo "[INFO] 検索実行..."
curl -sSL -b "$COOKIE" -c "$COOKIE" \
  -d "_csrf=$C" \
  -d "_kyukyuNijiIryknCd=on" \
  -d "_shikuchosonCd=on" \
  -d "shikuchosonCd=202" \
  "https://www.iryou.teikyouseido.mhlw.go.jp/znk-web/juminkanja/S2700/search" \
  -o /dev/null

# -------------------------
# 今日から DAYS 日分ループ
# -------------------------
echo "[INFO] データ取得開始...（${DAYS}日分）"

for i in $(seq 0 "$DAYS"); do
    ymd=$(date -d "+$i day" +%Y%m%d)

    d=$(date -d "+$i day" +%Y/%-m/%-d)
    w=$(date -d "+$i day" +%w)
    weekday=${weekdays[$w]}
    selectDate="${d}（${weekday}）"

    encoded_selectDate=$(printf '%s' "$selectDate" | jq -sRr @uri)

    url="https://www.iryou.teikyouseido.mhlw.go.jp/znk-web/juminkanja/S2720/search?selectDate=${encoded_selectDate}&searchDate=${ymd}"

    echo "[INFO] 取得中: $ymd → ${DIR}/${ymd}.html"

    curl -sSL -b "$COOKIE" "$url" | hxnormalize -x | hxselect 'div.resultList' > "${DIR}/${ymd}.html"
done

echo "[INFO] 完了しました。"
