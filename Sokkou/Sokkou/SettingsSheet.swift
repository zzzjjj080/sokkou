import SwiftUI
import SokkouCore

/// 設定。**横画面なので、1行ずつの一覧だと横に間延びする。**
/// 復習の入口と同じように、札を並べて一目で見渡せるようにしてある。
///
/// 長い説明と投げ銭は「このアプリについて」の奥へ入れた。
/// 設定の入口に文章が並ぶと、何を触れるのかが埋もれる。
struct SettingsSheet: View {
    @Bindable var game: GameModel
    @Environment(\.dismiss) private var dismiss
    @State private var showsResetConfirmation = false
    @State private var showsIntroduction = false
    @State private var showsCoffee = false
    @State private var tipJar = TipJar(productID: TipJar.productID)

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 230), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    rankCard
                    reviewCard
                    toggleCard("ヒント", "切る候補を5つに絞る",
                               systemImage: "sparkles", isOn: $game.showsHint)
                    toggleCard("ツモるを左に", "左手で持つとき",
                               systemImage: "hand.point.left.fill", isOn: $game.isLeftHanded,
                               identifier: "left-handed")
                    toggleCard("振動する", "押したとき・判定・昇格",
                               systemImage: "iphone.radiowaves.left.and.right",
                               isOn: $game.hapticsEnabled)
                    actionCard("遊び方", "もう一度見る", systemImage: "book.fill") {
                        showsIntroduction = true
                    }
                    // 記録を消すはめったに使わないので、この奥へまとめた
                    navigationCard("その他", "判定の決まり・連絡先・記録",
                                   systemImage: "ellipsis.circle.fill") {
                        AboutView(game: game, tipJar: tipJar,
                                  onReset: { showsResetConfirmation = true })
                    }
                    // 最後の1枚。押してもらえるよう、いちばん目が止まる右下に置く
                    coffeeCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .background(Palette.background.ignoresSafeArea())
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
            .fullScreenCover(isPresented: $showsIntroduction) {
                IntroductionView { showsIntroduction = false }
            }
            // CoffeeTipSection は Form の中で使う部品なので、シートも一覧で作る
            .sheet(isPresented: $showsCoffee) {
                NavigationStack {
                    Form { CoffeeTipSection(tipJar: tipJar) }
                        .frame(maxWidth: 640).frame(maxWidth: .infinity)
                        .navigationTitle("コーヒーを奢る")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("閉じる") { showsCoffee = false }
                            }
                        }
                }
            }
        }
    }

    // MARK: - 札

    /// 投げ銭。**設定の最後の1枚**として、いちばん目が止まる右下に置く。
    /// 一覧の奥に埋めると、そもそも見つからない
    private var coffeeCard: some View {
        Button { showsCoffee = true } label: {
            SettingsCard(title: "コーヒーを奢る",
                         detail: tipJar.cups > 0 ? "\(tipJar.cups)杯 ありがとうございます"
                                                 : "気に入ったら開発者に",
                         systemImage: "cup.and.saucer.fill",
                         style: .coffee)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("coffee")
    }

    private var rankCard: some View {
        navigationCard("段位一覧", game.records.rank?.display ?? "称号なし",
                       systemImage: "rosette") {
            RankListView(records: game.records)
        }
    }

    @ViewBuilder
    private var reviewCard: some View {
        if game.reviewStore.isEmpty {
            SettingsCard(title: "復習", detail: "まだありません",
                         systemImage: "arrow.trianglehead.counterclockwise",
                         style: .disabled)
        } else {
            navigationCard("復習", "\(game.reviewStore.count)件",
                           systemImage: "arrow.trianglehead.counterclockwise",
                           style: .highlighted, identifier: "review-link") {
                ReviewStartView(game: game)
            }
        }
    }

    private func navigationCard<Destination: View>(
        _ title: String, _ detail: String, systemImage: String,
        style: SettingsCard.Style = .plain, identifier: String? = nil,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink { destination() } label: {
            SettingsCard(title: title, detail: detail, systemImage: systemImage, style: style)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier ?? title)
    }

    private func actionCard(_ title: String, _ detail: String, systemImage: String,
                            isDestructive: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SettingsCard(title: title, detail: detail, systemImage: systemImage,
                         style: isDestructive ? .destructive : .plain)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(title)
    }

    /// 入り切りの札。**札ごと押して切り替える。**
    /// 小さなスイッチを狙わせるより、札全体が的のほうが押しやすい
    private func toggleCard(_ title: String, _ detail: String, systemImage: String,
                            isOn: Binding<Bool>, identifier: String? = nil) -> some View {
        Button { isOn.wrappedValue.toggle() } label: {
            SettingsCard(title: title, detail: detail, systemImage: systemImage,
                         style: isOn.wrappedValue ? .on : .off)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier ?? title)
        .accessibilityValue(isOn.wrappedValue ? "オン" : "オフ")
    }
}

/// 設定の札1枚。復習の入口と同じ寸法にそろえてある
struct SettingsCard: View {
    enum Style { case plain, highlighted, on, off, destructive, disabled, coffee }

    let title: String
    let detail: String
    let systemImage: String
    var style: Style = .plain

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                Spacer(minLength: 0)
                if style == .on || style == .off {
                    Text(style == .on ? "オン" : "オフ")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(style == .on ? Palette.goldInk : Color.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(style == .on ? Palette.goldFill : Palette.neutralFill,
                                    in: Capsule())
                }
            }
            .foregroundStyle(accent)
            Spacer(minLength: 0)
            Text(title)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(style == .disabled ? .secondary : .primary)
                .lineLimit(2).minimumScaleFactor(0.7)
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(2).minimumScaleFactor(0.8)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .aspectRatio(1.35, contentMode: .fit)
        .background(background, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .stroke(style == .on ? Palette.gold.opacity(0.5) : .clear, lineWidth: 1.5))
        .opacity(style == .disabled ? 0.55 : 1)
    }

    private var accent: Color {
        switch style {
        case .destructive: Palette.miss
        case .coffee: .orange
        case .on, .highlighted: Palette.gold
        default: .secondary
        }
    }

    private var background: Color {
        switch style {
        case .highlighted: Palette.gold.opacity(0.18)
        case .coffee: Color.orange.opacity(0.16)
        default: Palette.panel
        }
    }
}

/// 長い説明・連絡先・投げ銭。**設定の入口から1つ奥へ。**
/// `CoffeeTipSection` は `Form` の中で使う部品なので、ここは一覧のままにする
struct AboutView: View {
    @Bindable var game: GameModel
    @Bindable var tipJar: TipJar
    /// 記録を消す。確認は設定の側で出す
    var onReset: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                LabeledContent("判定", value: "最善を100点として採点")
                LabeledContent("正解", value: "90点以上")
            } footer: {
                Text("打点・役・ドラ・場況・待ちの良し悪しは考慮しません。"
                     + "字牌と赤5は使わず、七対子も考えません。\n\n"
                     + "ツモは約4割の確率で手が進む牌を引きます。1局を短くするための調整で、"
                     + "実戦より早く聴牌します。聴牌したときに出る待ちの枚数と確率は"
                     + "調整なしの計算なので、そのまま実戦の目安に使えます。")
            }
            Section {
                LabeledContent("最速聴牌", value: "累計 \(game.records.fastestCount)回")
                LabeledContent("最高連続", value: "\(game.records.bestStreak)回")
            } header: {
                Text("記録")
            }
            Section {
                Button("記録をすべて消す", role: .destructive) {
                    dismiss()
                    onReset()
                }
            } footer: {
                Text("消すと称号も最初からになります。元に戻せません。")
            }
            FeedbackSection()
        }
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .navigationTitle("その他")
        .navigationBarTitleDisplayMode(.inline)
    }
}
