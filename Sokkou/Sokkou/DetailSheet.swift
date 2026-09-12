import SwiftUI
import SokkouCore

/// なぜその牌が速いのかを見せる。
/// 数字を並べるだけでは伝わらないので、比較表と一文の説明にしてある。
struct DetailSheet: View {
    let evaluation: Evaluation
    let chosen: Tile
    /// 切る前の14枚。**どんな局面だったかが見えないと、数字だけでは分からない**
    let hand: TileCounts
    @Environment(\.dismiss) private var dismiss

    private var chosenOption: DiscardOption? { evaluation.option(for: chosen) }
    private var bestOption: DiscardOption? {
        evaluation.bestTiles.first.flatMap { evaluation.option(for: $0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    handStrip
                    if let mine = chosenOption, let best = bestOption, mine.tile != best.tile {
                        // 主役はここ。何を引けば進むかの**違い**を見せる
                        ukeireFaces(mine: mine, best: best)
                        Text(reason(mine: mine, best: best))
                            .font(.system(size: 19))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                        comparison(mine: mine, best: best)
                    }
                    table
                }
                .padding(18)
                .frame(maxWidth: 860)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("採点の内訳")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .presentationBackground(Palette.panel)
    }

    // MARK: - 比較表

    private func comparison(mine: DiscardOption, best: DiscardOption) -> some View {
        VStack(spacing: 0) {
            row("", "あなた: \(mine.tile)切り", "最善: \(best.tile)切り", isHeader: true)
            row("切ったあとの手", shantenLabel(mine.shanten), shantenLabel(best.shanten),
                mineWins: mine.shanten < best.shanten, bestWins: best.shanten < mine.shanten)
            row("目先の受け入れ", "\(mine.ukeireCount)枚", "\(best.ukeireCount)枚",
                mineWins: mine.ukeireCount > best.ukeireCount,
                bestWins: best.ukeireCount > mine.ukeireCount)
            row("残した牌の伸びしろ", "\(mine.improvement)枚", "\(best.improvement)枚",
                mineWins: mine.improvement > best.improvement,
                bestWins: best.improvement > mine.improvement)
            row("点数", mine.score.map { "\($0)点" } ?? "対象外", "100点",
                mineWins: false, bestWins: true)
        }
        .background(Palette.faintFill, in: RoundedRectangle(cornerRadius: 10))
    }

    /// 点数の一覧に出す数。全部並べても読まないので上から3つ
    private static let tableLimit = 3

    // MARK: - 盤面

    /// 切る前の14枚。**どの牌を切ったのか、最善はどれかを牌の上に示す。**
    /// 数字の表だけでは、どんな局面だったのか思い出せない
    private var handStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("この14枚から")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(Array(hand.tiles.enumerated()), id: \.offset) { _, tile in
                        VStack(spacing: 3) {
                            Text(markLabel(for: tile))
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(markColor(for: tile) ?? .clear)
                            TileView(tile: tile)
                                .frame(height: 52)
                                .overlay(RoundedRectangle(cornerRadius: 5)
                                    .stroke(markColor(for: tile) ?? .clear, lineWidth: 2.5))
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.faintFill, in: RoundedRectangle(cornerRadius: 10))
    }

    private func markLabel(for tile: Tile) -> String {
        if tile == chosen { return "あなた" }
        if evaluation.isBest(tile) { return "最善" }
        return " "
    }

    private func markColor(for tile: Tile) -> Color? {
        if tile == chosen { return Palette.chosen }
        if evaluation.isBest(tile) { return Palette.gold }
        return nil
    }

    // MARK: - 受け入れの牌

    /// **何枚あるかより、どの牌かのほうが頭に残る。**
    ///
    /// 両方が受けられる牌は、どちらを切っても変わらないので薄く小さく置く。
    /// **片方だけが受けられる牌**に色を付けて、そこだけ見れば差が分かるようにする
    private func ukeireFaces(mine: DiscardOption, best: DiscardOption) -> some View {
        let mineKinds = Set(mine.ukeire.map(\.tile))
        let bestKinds = Set(best.ukeire.map(\.tile))
        let shared = mineKinds.intersection(bestKinds)
        let onlyMine = mine.ukeire.filter { !shared.contains($0.tile) }
        let onlyBest = best.ukeire.filter { !shared.contains($0.tile) }
        let gap = best.ukeireCount - mine.ukeireCount
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("何を引けば進むか")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(gap > 0 ? "最善のほうが \(gap)枚 広い"
                     : (gap < 0 ? "受け入れは \(-gap)枚 あなたが広い" : "受け入れは同じ枚数"))
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(gap > 0 ? Palette.green : .secondary)
            }
            faceRow("あなた: \(mine.tile)切り", only: onlyMine, tint: Palette.chosen,
                    total: mine.ukeireCount)
            faceRow("最善: \(best.tile)切り", only: onlyBest, tint: Palette.gold,
                    total: best.ukeireCount)
            if !shared.isEmpty {
                sharedRow(mine.ukeire.filter { shared.contains($0.tile) })
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.faintFill, in: RoundedRectangle(cornerRadius: 10))
    }

    /// 片方だけが受けられる牌。**ここが差のすべて**なので色を付けて大きく出す
    private func faceRow(_ label: String, only: [UkeireTile], tint: Color,
                         total: Int) -> some View {
        let sorted = only.sorted {
            $0.count != $1.count ? $0.count > $1.count : $0.tile < $1.tile
        }
        return HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 140, alignment: .leading)
            if sorted.isEmpty {
                Text("ここだけの牌はなし")
                    .font(.system(size: 15)).foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(sorted.enumerated()), id: \.offset) { _, item in
                            HStack(spacing: 3) {
                                TileView(tile: item.tile).frame(height: 48)
                                    .overlay(RoundedRectangle(cornerRadius: 5)
                                        .stroke(tint, lineWidth: 2))
                                Text("\(item.count)")
                                    .font(.system(size: 15, weight: .heavy)).monospacedDigit()
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            Spacer(minLength: 0)
            Text("計\(total)枚")
                .font(.system(size: 15, weight: .heavy)).monospacedDigit()
        }
    }

    /// どちらを切っても受けられる牌。差には効かないので薄く小さく
    private func sharedRow(_ items: [UkeireTile]) -> some View {
        let sorted = items.sorted { $0.tile < $1.tile }
        return HStack(alignment: .center, spacing: 10) {
            Text("どちらも同じ")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(Array(sorted.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 2) {
                            TileView(tile: item.tile).frame(height: 30)
                            Text("\(item.count)")
                                .font(.system(size: 12)).monospacedDigit()
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .opacity(0.45)
            Spacer(minLength: 0)
        }
    }

    private func row(_ label: String, _ mine: String, _ best: String,
                     isHeader: Bool = false, mineWins: Bool = false, bestWins: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 170, alignment: .leading)
            Text(mine)
                .font(.system(size: isHeader ? 16 : 21, weight: mineWins ? .heavy : .regular))
                .foregroundStyle(isHeader ? Palette.heading
                                 : (mineWins ? .green : (bestWins ? .red : .primary)))
                .frame(maxWidth: .infinity)
            Text(best)
                .font(.system(size: isHeader ? 16 : 21, weight: bestWins ? .heavy : .regular))
                .foregroundStyle(isHeader ? Palette.gold
                                 : (bestWins ? .green : (mineWins ? .red : .primary)))
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .overlay(alignment: .top) {
            if !isHeader { Divider().opacity(0.25) }
        }
    }

    /// 差がどこから来ているのかを一言で
    private func reason(mine: DiscardOption, best: DiscardOption) -> String {
        let names = evaluation.bestTiles.map(\.description).joined(separator: "・")   // 必ず1枚
        if mine.isShantenBack {
            return "\(mine.tile)を切ると\(shantenLabel(mine.shanten))に戻ります。"
                + "この計算はシャンテン数をまたぐ比較を外すことが実測で分かっているため、"
                + "戻す打牌は採点の対象にしていません。"
        }
        let ukeireDiff = mine.ukeireCount - best.ukeireCount
        if ukeireDiff >= 0 && best.improvement > mine.improvement {
            return "目先の受け入れは\(mine.tile)切りのほうが"
                + (ukeireDiff > 0 ? "\(ukeireDiff)枚広い" : "同じ") + "。"
                + "それでも遅いのは、残した牌の伸びしろが狭いからです"
                + "（\(mine.improvement)枚 対 \(best.improvement)枚）。"
                + "入口の広さより、そのあと手が広がるかどうかが効きます。"
        }
        if ukeireDiff < 0 {
            return "\(mine.tile)切りは目先の受け入れが\(-ukeireDiff)枚せまく、"
                + "\(names)切りに届きません。"
        }
        return "シャンテン数も受け入れ枚数も近いのですが、"
            + "この先の形の差が積み重なって点数に開きが出ています。"
    }

    // MARK: - 全打牌の一覧

    private var table: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 全部並べても読まない。**上から3つで足りる**
            Text("点数の高い打牌")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            ForEach(Array(evaluation.options.prefix(Self.tableLimit).enumerated()),
                    id: \.offset) { _, option in
                HStack {
                    Text(option.tile.description)
                        .font(.system(size: 20, weight: .bold))
                        .frame(width: 58, alignment: .leading)
                    Text(option.score.map { "\($0)点" } ?? "—")
                        .font(.system(size: 20, weight: .bold)).monospacedDigit()
                        .frame(width: 76, alignment: .trailing)
                        .foregroundStyle(scoreColor(option))
                    Text(shantenLabel(option.shanten))
                        .font(.system(size: 16)).frame(width: 76, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    Text("\(option.ukeireKinds)種\(option.ukeireCount)枚")
                        .font(.system(size: 16)).frame(width: 108, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(mark(option)).font(.system(size: 15)).foregroundStyle(.secondary)
                }
                .padding(.vertical, 7)
                Divider().opacity(0.2)
            }
        }
    }

    private func scoreColor(_ option: DiscardOption) -> Color {
        if option.isShantenBack { return .secondary }
        if evaluation.isBest(option.tile) { return Palette.gold }
        if evaluation.isCorrect(option.tile) { return Palette.green }
        return .primary
    }

    private func mark(_ option: DiscardOption) -> String {
        if option.isShantenBack { return "戻し（対象外）" }
        if evaluation.isBest(option.tile) {
            // 100点は必ず1枚。ただし僅差で決めた回はそう断っておく
            return evaluation.isTiedTop ? "◎ 最善（僅差）" : "◎ 最善"
        }
        if evaluation.isCorrect(option.tile) { return "○ 正解圏" }
        return ""
    }
}

func shantenLabel(_ shanten: Int) -> String {
    shanten <= 0 ? "聴牌" : "\(shanten)向聴"
}
