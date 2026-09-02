#!/bin/bash
# 接続中のiPhoneに最新のビルドを入れる。
# デバイス名に空白が入ると列位置がずれるので、UUID形式で抜く。
set -euo pipefail
cd "$(dirname "$0")/Sokkou"

# 状態の書き方は Xcode の版で変わる（"connected" → "available (paired)"）。
# **状態の語で絞らず、「使えないもの」を除く**ほうが壊れにくい。
#   ・Apple Watch も一致してしまうので、モデル欄の "(iPhone" で絞る
#   ・手放した端末は "unavailable"、ペアリングだけの端末は "no DDI" と出る
#   ・"unavailable" は "available" を含むので、除いてから拾う
LINE=$(xcrun devicectl list devices \
  | grep '(iPhone' \
  | grep -v 'unavailable' \
  | grep -v 'no DDI' \
  | grep -E 'available|connected' | head -1 || true)
if [ -z "$LINE" ]; then
  echo "繋がっているiPhoneが見つかりません。USBで接続してください。"
  exit 1
fi
DEV=$(echo "$LINE" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')
echo "対象: $DEV"

# リリース構成で入れる。デバッグ構成は最適化が効かず50倍遅く、
# 採点のたびに固まって二度押しの原因になる(引き継ぎ書4-27)
xcodebuild -project Sokkou.xcodeproj -scheme Sokkou -configuration Release \
  -destination "platform=iOS,id=$DEV" -derivedDataPath /tmp/sokkou-dev \
  -allowProvisioningUpdates build

APP=$(find /tmp/sokkou-dev/Build/Products -name "Sokkou.app" -path "*Release*" -maxdepth 3 | head -1)
xcrun devicectl device install app --device "$DEV" "$APP"
echo "入れ終わりました。ホーム画面から起動してください。"
