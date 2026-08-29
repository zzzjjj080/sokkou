import SwiftUI
import SokkouCore

/// なぜその牌が速いのかを見せる。
/// 数字を並べるだけでは伝わらないので、比較表と一文の説明にしてある。
struct DetailSheet: View {
    let evaluation: Evaluation
    let chosen: Tile
    @Environment(\.dismiss) private var dismiss

    private var chosenOption: DiscardOption? { evaluation.option(for: chosen) }
    private var bestOption: DiscardOption? {
        evaluation.bestTiles.first.flatMap { evaluation.option(for: $0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let mine = chosenOption, let best = bestOption, mine.tile != best.tile {
                        comparison(mine: mine, best: best)
                        Text(reason(mine: mine, best: best))
                            .font(.system(size: 14))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    table
                }
                .padding(18)
                .frame(maxWidth: 760)
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
        .presentationBackground(Color(red: 0.149, green: 0.169, blue: 0.200))
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
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }

    private func row(_ label: String, _ mine: String, _ best: String,
                     isHeader: Bool = false, mineWins: Bool = false, bestWins: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(mine)
                .font(.system(size: isHeader ? 12 : 14, weight: mineWins ? .heavy : .regular))
                .foregroundStyle(isHeader ? Color(red: 0.62, green: 0.75, blue: 1)
                                 : (mineWins ? .green : (bestWins ? .red : .primary)))
                .frame(maxWidth: .infinity)
            Text(best)
                .font(.system(size: isHeader ? 12 : 14, weight: bestWins ? .heavy : .regular))
                .foregroundStyle(isHeader ? Color(red: 1, green: 0.835, blue: 0.290)
                                 : (bestWins ? .green : (mineWins ? .red : .primary)))
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .overlay(alignment: .top) {
            if !isHeader { Divider().opacity(0.25) }
        }
    }

    /// 差がどこから来ているのかを一言で
    private func reason(mine: DiscardOption, best: DiscardOption) -> String {
        let names = evaluation.bestTiles.map(\.description).joined(separator: "・")
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
            Text("すべての打牌")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)
            ForEach(Array(evaluation.options.enumerated()), id: \.offset) { _, option in
                HStack {
                    Text(option.tile.description)
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 44, alignment: .leading)
                    Text(option.score.map { "\($0)点" } ?? "—")
                        .font(.system(size: 14, weight: .bold)).monospacedDigit()
                        .frame(width: 56, alignment: .trailing)
                        .foregroundStyle(scoreColor(option))
                    Text(shantenLabel(option.shanten))
                        .font(.system(size: 12)).frame(width: 60, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    Text("\(option.ukeireKinds)種\(option.ukeireCount)枚")
                        .font(.system(size: 12)).frame(width: 84, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(mark(option)).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                Divider().opacity(0.2)
            }
        }
    }

    private func scoreColor(_ option: DiscardOption) -> Color {
        if option.isShantenBack { return .secondary }
        if evaluation.isBest(option.tile) { return Color(red: 1, green: 0.835, blue: 0.290) }
        if evaluation.isCorrect(option.tile) { return Color(red: 0.42, green: 0.85, blue: 0.55) }
        return .primary
    }

    private func mark(_ option: DiscardOption) -> String {
        if option.isShantenBack { return "戻し（対象外）" }
        if evaluation.isBest(option.tile) {
            return evaluation.isTiedTop && evaluation.bestTiles.count > 1 ? "◎ 最善（同格）" : "◎ 最善"
        }
        if evaluation.isCorrect(option.tile) { return "○ 正解圏" }
        return ""
    }
}

func shantenLabel(_ shanten: Int) -> String {
    shanten <= 0 ? "聴牌" : "\(shanten)向聴"
}
