#!/bin/bash
# 接続中のiPhoneに最新のビルドを入れる。
# デバイス名に空白が入ると列位置がずれるので、UUID形式で抜く。
set -euo pipefail
cd "$(dirname "$0")/Sokkou"

LINE=$(xcrun devicectl list devices | grep -m1 " connected " || true)
if [ -z "$LINE" ]; then
  echo "繋がっているiPhoneが見つかりません。USBで接続してください。"
  exit 1
fi
DEV=$(echo "$LINE" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')
echo "対象: $DEV"

xcodebuild -project Sokkou.xcodeproj -scheme Sokkou -configuration Debug \
  -destination "platform=iOS,id=$DEV" -derivedDataPath /tmp/sokkou-dev \
  -allowProvisioningUpdates build

APP=$(find /tmp/sokkou-dev/Build/Products -name "Sokkou.app" -maxdepth 3 | head -1)
xcrun devicectl device install app --device "$DEV" "$APP"
echo "入れ終わりました。ホーム画面から起動してください。"
