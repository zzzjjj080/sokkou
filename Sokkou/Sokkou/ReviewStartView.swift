import SwiftUI
import SokkouCore

/// 復習の入口。**形で絞ってから解き直せる。**
///
/// 「よく外す形」が分かっても、そこだけ練習できなければ見るだけで終わる。
///
/// 横画面なので、1行ずつの一覧だと横に間延びして読みにくい。
/// **正方形に近い札を並べて**、どの形が何件あるかを一目で見比べられるようにする。
struct ReviewStartView: View {
    @Bindable var game: GameModel

    /// 横画面の幅なら4列がちょうどよい。狭ければ自動で減る
    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 230), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                card(tag: nil, count: game.reviewStore.count)
                ForEach(WeaknessTag.displayOrder, id: \.self) { tag in
                    if let count = counts[tag], count > 0 {
                        card(tag: tag, count: count)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            Text("切った牌と最善の牌が、手牌の中でどんな役割だったかで分けています。"
                 + "多い形が、いま練習すべきところです。"
                 + "復習で正解できた局面は一覧から外れます（最大\(ReviewStore.capacity)件）。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 10).padding(.bottom, 14)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("復習")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var counts: [WeaknessTag: Int] { game.reviewStore.tagCounts }

    /// 1枚の札。**「すべて」だけ金色**にして、まとめて解く道が先にあると分かるようにする
    @ViewBuilder
    private func card(tag: WeaknessTag?, count: Int) -> some View {
        if let session = game.makeReviewSession(tag: tag) {
            let isAll = tag == nil
            NavigationLink {
                ReviewView(game: game, session: session)
            } label: {
                VStack(spacing: 4) {
                    Spacer(minLength: 0)
                    Text(tag?.label ?? "すべて")
                        .font(.system(size: isAll ? 21 : 17, weight: .heavy))
                        .foregroundStyle(isAll ? Palette.goldInk : .primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2).minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(count)")
                            .font(.system(size: 27, weight: .black)).monospacedDigit()
                        Text("件").font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(isAll ? Palette.goldInk : Palette.gold)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .aspectRatio(1.35, contentMode: .fit)
                .background(isAll ? Palette.goldFill : Palette.panel,
                            in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(tag.map { "review-\($0.rawValue)" } ?? "review-all")
        }
    }
}
