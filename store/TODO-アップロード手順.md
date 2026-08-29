# アップロード手順（速攻何切る v1.0）

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

### 1. スクリーンショット（未着手・要確認）

**横向きアプリのスクリーンショットが App Store Connect に通るか、前2作で前例がない。**
縦向きの寸法は 6.9インチ = 1320×2868。横向きなら 2868×1320 になるはずだが、
欄が出るかどうかを実物で確かめてから作る。

先にアップロードを済ませてしまい、App Store Connect の
スクリーンショット欄に何インチの枠が出るかを見てから作るのが早い。

撮る候補（5枚まで）:
1. 手牌を選ぶ画面（ヒントの赤枠が出ている状態）
2. 打牌した直後（点数がすべての牌に出ている状態）
3. 聴牌画面（獲得経験値とボーナス倍率、経験値メーター）
4. 採点の内訳（比較表）
5. 段位一覧

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
