#!/bin/bash
# App内課金（投げ銭）の審査用スクリーンショットを撮って、読める向きにして出す。
#
# App Store Connect の課金製品は、審査用スクリーンショットが1枚無いと
# MISSING_METADATA のままで提出できない(引き継ぎ書 11-8)。
#
# ・価格を出すには .storekit が要る。simctl 起動では効かないので
#   スキーム経由の xcodebuild test から撮る(引き継ぎ書 11-9)
# ・撮れる画は横倒し。端末は縦のまま、アプリだけ横向きに描かれるため。
#   審査担当が見るものなので、ここで起こす
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="$PWD/store/iap-review"
SIM_NAME="Sokkou-Shot"

# 他の作業と同じシミュレータを使うと、別プロジェクトのテストランナーが
# 割り込んで撮影が壊れる(引き継ぎ書 4-59)。撮影用に1台用意する
UDID=$(xcrun simctl list devices | grep "$SIM_NAME (" | grep -oE '[0-9A-F-]{36}' | head -1 || true)
if [ -z "$UDID" ]; then
  RUNTIME=$(xcrun simctl list runtimes | grep -oE 'com.apple.CoreSimulator.SimRuntime.iOS-[0-9-]+' | tail -1)
  UDID=$(xcrun simctl create "$SIM_NAME" "iPhone 17 Pro" "$RUNTIME")
  echo "撮影用シミュレータを作りました: $UDID"
fi
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1
xcrun simctl ui "$UDID" appearance light

xcodebuild test -project Sokkou/Sokkou.xcodeproj -scheme Sokkou \
  -destination "platform=iOS Simulator,id=$UDID" \
  -only-testing:SokkouUITests/CoffeeTipShot \
  -derivedDataPath /tmp/sokkou-iap 2>&1 | grep -E "Test Case|error:" || true

RAW="$OUT/coffee-tip.png"
[ -f "$RAW" ] || { echo "撮れていません。テストの出力を見てください。"; exit 1; }

# ① 横倒しを起こす。人が見て確かめる用
W=$(sips -g pixelWidth "$RAW" | awk '/pixelWidth/{print $2}')
H=$(sips -g pixelHeight "$RAW" | awk '/pixelHeight/{print $2}')
FINAL="$OUT/coffee-tip-review.png"
if [ "$H" -gt "$W" ]; then
  sips -r -90 "$RAW" --out "$FINAL" >/dev/null
else
  cp "$RAW" "$FINAL"
fi

# ② 送る用。**Apple は受け取った画を反時計回りに90度回す。**
# そのまま上向きで送ると、向こうで横倒しになる。先に時計回りへ回して打ち消す。
# 縦横の寸法は端末の画面サイズと一致していないと IMAGE_INCORRECT_DIMENSIONS で弾かれる
# （余白を足して好きな大きさにする、はできない）
UPLOAD="$OUT/coffee-tip-upload.png"
sips -r 90 "$FINAL" --out "$UPLOAD" >/dev/null

echo
echo "人が見る用 : $FINAL"
echo "Appleに送る : $UPLOAD  ← 登録するのはこちら"
sips -g pixelWidth -g pixelHeight "$UPLOAD" | tail -2
echo "md5: $(md5 -q "$UPLOAD")"
