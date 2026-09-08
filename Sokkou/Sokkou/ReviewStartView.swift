import SwiftUI
import SokkouCore

/// 復習の入口。**形で絞ってから解き直せる。**
///
/// 「よく外す形」が分かっても、そこだけ練習できなければ見るだけで終わる。
struct ReviewStartView: View {
    @Bindable var game: GameModel

    var body: some View {
        List {
            Section {
                row(tag: nil, count: game.reviewStore.count)
            } footer: {
                Text("正解できなかった局面を、新しいものから最大\(ReviewStore.capacity)件まで残します。"
                     + "復習で正解できた局面は一覧から外れます。")
            }

            if !counts.isEmpty {
                Section {
                    ForEach(WeaknessTag.displayOrder, id: \.self) { tag in
                        if let count = counts[tag], count > 0 {
                            row(tag: tag, count: count)
                        }
                    }
                } header: {
                    Text("形で絞る")
                } footer: {
                    Text("切った牌と最善の牌が、手牌の中でどんな役割だったかで分けています。"
                         + "多い形が、いま練習すべきところです。")
                }
            }
        }
        .navigationTitle("復習")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var counts: [WeaknessTag: Int] { game.reviewStore.tagCounts }

    @ViewBuilder
    private func row(tag: WeaknessTag?, count: Int) -> some View {
        if let session = game.makeReviewSession(tag: tag) {
            NavigationLink {
                ReviewView(game: game, session: session)
            } label: {
                HStack {
                    Text(tag?.label ?? "すべて")
                        .fontWeight(tag == nil ? .semibold : .regular)
                    Spacer()
                    Text("\(count)件").foregroundStyle(.secondary).monospacedDigit()
                }
            }
            .accessibilityIdentifier(tag.map { "review-\($0.rawValue)" } ?? "review-all")
        }
    }
}
