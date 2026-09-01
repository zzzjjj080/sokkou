import SwiftUI
import SokkouCore

/// 間違えた局面をまとめて解き直す画面。
struct ReviewView: View {
    @Bindable var game: GameModel
    @State var session: ReviewSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            if session.isFinished { summary } else { question }
        }
        .navigationTitle("復習")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("終わる") { finish() }
            }
        }
    }

    /// 正解できた局面を一覧から外してから閉じる
    private func finish() {
        for position in session.solved { game.retire(position) }
        dismiss()
    }

    // MARK: - 出題

    private var question: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                Text("\(session.position) / \(session.total)")
                    .font(.system(size: 20, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(Palette.gold)
                Text("正解 \(session.correctCount)")
                    .font(.system(size: 16, weight: .bold)).monospacedDigit()
                    .foregroundStyle(Palette.green)
                Spacer()
                if let previous = session.previousChoice, !session.hasAnswered {
                    Text("前回は \(previous.description) を選んで外しました")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 4)

            HStack(alignment: .bottom, spacing: 0) {
                ForEach(session.slots) { slot in
                    if slot.isDrawn { Spacer().frame(width: 20) }
                    TileSlotView(slot: slot,
                                 evaluation: session.evaluation,
                                 isRevealed: session.hasAnswered,
                                 onTap: { session.choose(slot.tile) })
                }
            }

            Spacer(minLength: 4)

            HStack(spacing: 14) {
                Text(verdict)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(verdictColor)
                    .lineLimit(2).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(session.position == session.total ? "結果を見る" : "次の局面へ") {
                    session.next()
                }
                .font(.system(size: 20, weight: .heavy))
                .buttonStyle(.borderedProminent)
                .disabled(!session.hasAnswered)
                .accessibilityIdentifier("review-next")
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 12)
    }

    private var verdict: String {
        guard let chosen = session.chosen, let evaluation = session.evaluation,
              let option = evaluation.option(for: chosen) else {
            return "最速で聴牌する1枚を選ぶ"
        }
        if option.isShantenBack { return "❌ シャンテンを戻す打牌（採点対象外）" }
        if evaluation.isBest(chosen) { return "🎉 100点! 最善の一手です" }
        if evaluation.isCorrect(chosen) { return "🎯 \(option.score ?? 0)点 — 正解" }
        return "😕 \(option.score ?? 0)点 — 最善は "
            + evaluation.bestTiles.map(\.description).joined(separator: "・")
    }

    private var verdictColor: Color {
        guard let chosen = session.chosen, let evaluation = session.evaluation
        else { return .secondary }
        return evaluation.isCorrect(chosen) ? Palette.green : Palette.miss
    }

    // MARK: - 結果

    private var summary: some View {
        VStack(spacing: 16) {
            Text("復習おわり")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(Palette.gold)
            Text("\(session.total)問中 \(session.correctCount)問 正解")
                .font(.system(size: 24, weight: .heavy)).monospacedDigit()
            Text(session.correctCount == 0
                 ? "正解できた局面は一覧から外れます。残りはまた出てきます。"
                 : "正解できた \(session.correctCount)件を一覧から外します。残りはまた出てきます。")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("閉じる") { finish() }
                .accessibilityIdentifier("review-close")
                .font(.system(size: 19, weight: .heavy))
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
        }
        .padding(30)
    }
}
