import SwiftUI
import SokkouCore

struct SettingsSheet: View {
    @Bindable var game: GameModel
    @Environment(\.dismiss) private var dismiss
    @State private var showsResetConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("練習") {
                    Toggle("ヒント: 切る候補を5つに絞る", isOn: $game.showsHint)
                }
                Section {
                    Toggle("振動する", isOn: $game.hapticsEnabled)
                } header: {
                    Text("手ごたえ")
                } footer: {
                    Text("牌を押したとき、判定が出たとき、昇格したときに強さを変えて振動します。")
                }
                Section("段位") {
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
                    Button("記録をすべて消す", role: .destructive) {
                        showsResetConfirmation = true
                    }
                } header: {
                    Text("記録")
                } footer: {
                    Text("最速聴牌の累計 \(game.records.fastestCount)回 / 最高連続 \(game.records.bestStreak)回。"
                         + "消すと称号も最初からになります。")
                }
                Section("このアプリについて") {
                    LabeledContent("判定", value: "最善を100点として採点")
                    LabeledContent("正解の line", value: "90点以上")
                    Text("打点・役・ドラ・場況・待ちの良し悪しは考慮しません。字牌と赤5は使わず、七対子も考えません。")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
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
        }
    }
}
