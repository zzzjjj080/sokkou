import SwiftUI
import SokkouCore

struct SettingsSheet: View {
    @Bindable var game: GameModel
    @Environment(\.dismiss) private var dismiss
    @State private var showsResetConfirmation = false
    @State private var showsReviewClearConfirmation = false
    @State private var showsIntroduction = false
    @State private var tipJar = TipJar(productID: TipJar.productID)

    var body: some View {
        NavigationStack {
            // 横画面だと画面幅いっぱいに広がって行が間延びするので、中央に寄せて絞る。
            // 絞ってもスクロールは効く（実機と同じ向きで指を滑らせて確認済み）
            Form {
                Section {
                    NavigationLink {
                        RankListView(records: game.records)
                    } label: {
                        HStack {
                            Text("段位一覧")
                            Spacer()
                            Text(game.records.rank?.display ?? "称号なし")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    if let session = game.makeReviewSession() {
                        NavigationLink {
                            ReviewView(game: game, session: session)
                        } label: {
                            HStack {
                                Text("間違えた局面を復習")
                                Spacer()
                                Text("\(game.reviewStore.count)件").foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("review-link")
                    } else {
                        LabeledContent("間違えた局面を復習", value: "まだありません")
                            .foregroundStyle(.secondary)
                    }
                    if !game.reviewStore.isEmpty {
                        Button("復習の一覧を空にする", role: .destructive) {
                            showsReviewClearConfirmation = true
                        }
                    }
                } header: {
                    Text("復習")
                } footer: {
                    Text("正解できなかった局面を、新しいものから最大\(ReviewStore.capacity)件まで残します。"
                         + "復習で正解できた局面は一覧から外れます。")
                }
                Section("練習") {
                    Toggle("ヒント: 切る候補を5つに絞る", isOn: $game.showsHint)
                }
                Section {
                    Toggle("「ツモる」を左に置く", isOn: $game.isLeftHanded)
                        .accessibilityIdentifier("left-handed")
                } header: {
                    Text("持ち方")
                } footer: {
                    Text("左手で持つときに、いちばん押すボタンを親指側へ移します。")
                }
                Section {
                    Toggle("振動する", isOn: $game.hapticsEnabled)
                } header: {
                    Text("手ごたえ")
                } footer: {
                    Text("牌を押したとき、判定が出たとき、昇格したときに強さを変えて振動します。")
                }
                Section {
                    Button("記録をすべて消す", role: .destructive) {
                        showsResetConfirmation = true
                    }
                } header: {
                    Text("記録")
                } footer: {
                    Text("最速聴牌の累計 \(game.records.fastestCount)回 / 最高連続 \(game.records.bestStreak)回。"
                         + "消すと称号も最初からになります。")
                }
                Section {
                    Button("遊び方をもう一度見る") { showsIntroduction = true }
                    LabeledContent("判定", value: "最善を100点として採点")
                    LabeledContent("正解", value: "90点以上")
                } header: {
                    Text("このアプリについて")
                } footer: {
                    Text("打点・役・ドラ・場況・待ちの良し悪しは考慮しません。"
                         + "字牌と赤5は使わず、七対子も考えません。\n\n"
                         + "ツモは約4割の確率で手が進む牌を引きます。1局を短くするための調整で、"
                         + "実戦より早く聴牌します。聴牌したときに出る待ちの枚数と確率は"
                         + "調整なしの計算なので、そのまま実戦の目安に使えます。")
                }

                FeedbackSection()
                CoffeeTipSection(tipJar: tipJar)
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } }
            }
            .confirmationDialog("記録をすべて消しますか？", isPresented: $showsResetConfirmation,
                                titleVisibility: .visible) {
                Button("消す", role: .destructive) { game.resetRecords() }
                Button("やめる", role: .cancel) {}
            } message: {
                Text("最速聴牌の累計・連続記録・称号がすべて最初からになります。元に戻せません。")
            }
            .confirmationDialog("復習の一覧を空にしますか？", isPresented: $showsReviewClearConfirmation,
                                titleVisibility: .visible) {
                Button("空にする", role: .destructive) { game.clearReview() }
                Button("やめる", role: .cancel) {}
            } message: {
                Text("ためた\(game.reviewStore.count)件の局面を消します。段位と記録はそのままです。")
            }
            .fullScreenCover(isPresented: $showsIntroduction) {
                IntroductionView { showsIntroduction = false }
            }
        }
    }
}
