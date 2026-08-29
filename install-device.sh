#!/bin/bash
# 接続中のiPhoneに最新のビルドを入れる。
# デバイス名に空白が入ると列位置がずれるので、UUID形式で抜く。
set -euo pipefail
cd "$(dirname "$0")/Sokkou"

# Apple Watch も " connected " に一致してしまうので、iPhone に絞る。
# ペアリング済みのWatchは "connected (no DDI)" と出るため、それも除く。
LINE=$(xcrun devicectl list devices | grep '(iPhone' | grep ' connected ' | grep -v 'no DDI' | head -1 || true)
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
