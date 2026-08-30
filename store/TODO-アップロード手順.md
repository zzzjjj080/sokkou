# アップロード手順（速攻何切る v1.0）

> **2026-08-30 21:30 審査提出完了。** 状態は「1.0 審査待ち」。
> 結果は最大48時間でメールが届く。
> Apple ID（アプリの数字）: `6804886358`

## こちらで済ませたこと

| 項目 | 状態 |
|---|---|
| App ID `com.zzzjjj080.Sokkou` | Explicit で登録済み |
| App Store Connect のアプリ登録 | 済み（iOS 1.0 提出準備中） |
| 使用許諾契約の同意 | 済み |
| バージョン / ビルド番号 | 1.0 / 1 |
| Deployment Target | 18.0 |
| 画面の向き | 横向き固定（Landscape Left / Right） |
| 権限（エンタイトルメント） | なし。使わない権限は削除済み |
| 動作確認用の抜け道 | Release ビルドに混入していないことを確認済み |
| Core のテスト | 71本すべて通過 |
| 掲載文面 | `store/` に用意済み |

---

## 残っている作業

### 1. スクリーンショット（完了）

**横向きは通る。** 6.5インチの欄に `2688 × 1242px` と明記されていた。
前2作で前例のなかった点はこれで解決。

`store/screenshots/` に5枚、2688×1242 で用意済み。そのままドラッグすればよい。

| ファイル | 中身 |
|---|---|
| 01.png | 最速で聴牌する一手を選ぶ（ヒントの赤枠） |
| 02.png | すべての牌に点数がつく（100点を選んだところ） |
| 03.png | なぜその牌が速いのかを確かめる（採点の内訳） |
| 04.png | ノーミスと精度で経験値が伸びる（昇格＋×1.50＋150） |
| 05.png | 70段の称号を上がっていく（段位一覧） |

撮り直すときは:

```bash
U=<シミュレータのUDID>            # iPhone 11 Pro Max = 6.5インチ = 1242×2688
rm -rf /tmp/sokkou-shots
cd ~/Claude/Sokkou/Sokkou
xcodebuild test -project Sokkou.xcodeproj -scheme Sokkou \
  -destination "platform=iOS Simulator,id=$U" \
  -only-testing:SokkouUITests/StoreScreenshots -derivedDataPath /tmp/sokkou-shot
swiftc -O ~/Claude/Sokkou/store/MakeScreenshots.swift -o /tmp/makeshots
/tmp/makeshots /tmp/sokkou-shots ~/Claude/Sokkou/store/screenshots
```

### 2. アーカイブとアップロード

```bash
cd ~/Claude/Sokkou/Sokkou
xcodebuild -project Sokkou.xcodeproj -scheme Sokkou -configuration Release \
  -destination 'generic/platform=iOS' -archivePath /tmp/Sokkou.xcarchive \
  -allowProvisioningUpdates archive

xcodebuild -exportArchive -archivePath /tmp/Sokkou.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath /tmp/sokkou-export \
  -allowProvisioningUpdates
```

`ExportOptions.plist` の `destination` が `upload` なので、
これだけで App Store Connect まで上がる（app-specific password も APIキーも不要）。
`Upload succeeded` が出れば成功。

### 3. 掲載情報の入力（本人）

`store/` のファイルをそのまま貼る。

| 欄 | ファイル |
|---|---|
| プロモーション用テキスト（170字） | `promotional.txt` |
| 概要（4000字） | `description.txt` |
| キーワード（100字・スペース禁止） | `keywords.txt` |
| App Review へのメモ | `review-notes.txt` |

そのほか手入力するもの:

- [ ] バージョン `1.0`（空欄になりがち）
- [ ] 著作権 `2026 Jin Nakamura`（© は不要）
- [ ] サポートURL（GitHub Pages。**公開してから**入れる。404を審査で踏ませない）
- [ ] ビルドを選択 → ビルド行の「管理」→ 暗号化「**いいえ**」
- [ ] 「**サインインが必要です**」のチェックを外す（ログイン不要のアプリ）
- [ ] 連絡先情報（名・姓・電話・メール）
- [ ] リリース方法（**手動**を推奨）
- [ ] 別ページ: アプリのプライバシー → ポリシーURL ＋「**データを収集しません**」
- [ ] 別ページ: 価格および配信状況 → **無料** ＋ **日本のみ**

### 4. 心構え

引き継ぎ書6章より。**初回提出は Guideline 2.1 で却下されると思っておく。**
前2作とも1回目は却下されている。返信は4000字制限。
却下されたら、まずビルドの中身を疑うこと。

---

## アップロード直前の確認コマンド

```bash
A=/tmp/Sokkou.xcarchive/Products/Applications/Sokkou.app
/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" $A/Info.plist   # 1.0
/usr/libexec/PlistBuddy -c "Print CFBundleVersion" $A/Info.plist              # 1
strings $A/Sokkou | grep -i "SOKKOU_QUICK_TENPAI"                            # 何も出ないこと
codesign -d --entitlements - $A                                              # 権限が無いこと
```


---

## 提出時に入力した内容（記録）

| 欄 | 値 |
|---|---|
| サポートURL | https://zzzjjj080.github.io/sokkou/ |
| プライバシーポリシーURL | https://zzzjjj080.github.io/sokkou/privacy.html |
| カテゴリ | ゲーム（ボード / パズル） |
| 年齢制限 | 4+（模擬ギャンブルは「なし」。賭けも点数のやり取りも無いため） |
| コンテンツ配信権 | サードパーティのコンテンツを含まない |
| データ収集 | 収集しない |
| 価格 | 無料 |
| リリース方法 | 手動 |

## 却下されたときの動き方

引き継ぎ書6章のとおり、**初回は Guideline 2.1 で却下されることを見込んでおく**。
前2作とも1回目は却下されている。

- 返信は4000字制限
- まずビルドの中身を疑う（今回は提出前に検査済み。動作確認用の抜け道なし、
  余計な権限なし、デモデータなし）
- 審査中に見つけた修正は、上げずに次のバージョンへ回す
