import SwiftUI
import SokkouCore

/// 聴牌したときの画面。
///
/// 今までは手牌が並んだままで、ツモを続けているのと見分けがつかなかった。
/// 局が終わったことが一目で分かるよう、画面ごと差し替える。
struct RoundResultView: View {
    let round: Round
    let records: Records
    let outcome: RoundOutcome?
    let onNext: () -> Void

    private let gold = Color(red: 1, green: 0.835, blue: 0.290)
    private let green = Color(red: 0.42, green: 0.85, blue: 0.55)

    /// この局の打牌数。1巡に1枚切るので巡目と同じ
    private var discards: Int { round.turn }
    private var correct: Int { discards - round.mistakes }

    var body: some View {
        VStack(spacing: 0) {
            headline
            Spacer(minLength: 8)
            HStack(alignment: .top, spacing: 22) {
                roundScore
                Divider().frame(height: 116).overlay(Color.white.opacity(0.15))
                rankMeter
            }
            Spacer(minLength: 8)
            HStack {
                waits
                Spacer()
                Button(action: onNext) {
                    Text("次の局へ")
                        .font(.system(size: 26, weight: .heavy))
                        .frame(width: 190, height: 74)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - 見出し

    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            if let promoted = outcome?.promotedTo {
                Text("🎊 昇格!")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(gold)
                Text(promoted.display)
                    .font(.system(size: 27, weight: .heavy))
                    .foregroundStyle(gold)
            } else if round.wasFastest {
                Text("🎉 最速聴牌!")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(gold)
            } else {
                Text("🀄 聴牌")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(.white)
            }
            Text("\(round.turn)巡目")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - この局の成績

    private var roundScore: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("この局の打牌")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(correct)")
                    .font(.system(size: 46, weight: .black)).monospacedDigit()
                    .foregroundStyle(round.mistakes == 0 ? green : .white)
                Text("/ \(discards)")
                    .font(.system(size: 22, weight: .bold)).monospacedDigit()
                    .foregroundStyle(.secondary)
                Text("が合格点")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            // 1打ずつの正誤を点で並べる。どこで外したかまでは持たないので数だけ
            HStack(spacing: 5) {
                ForEach(0..<discards, id: \.self) { index in
                    Circle()
                        .fill(index < correct ? green : Color(red: 0.85, green: 0.35, blue: 0.30))
                        .frame(width: 10, height: 10)
                }
            }
            Text(round.mistakes == 0
                 ? "すべて90点以上。最速で聴牌しました"
                 : "外した打牌 \(round.mistakes)回")
                .font(.system(size: 13))
                .foregroundStyle(round.mistakes == 0 ? green : .secondary)
        }
    }

    // MARK: - 段位と経験値メーター

    private var rankMeter: some View {
        let progress = records.progress
        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(progress.current?.display ?? "称号なし")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(gold)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("累計")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Text("\(progress.total)")
                        .font(.system(size: 26, weight: .black)).monospacedDigit()
                        .foregroundStyle(gold)
                    Text("回")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }

            // 経験値メーター
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(LinearGradient(colors: [gold.opacity(0.75), gold],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, geo.size.width * progress.fraction))
                }
            }
            .frame(height: 16)

            if let remaining = progress.remaining, let next = progress.next {
                Text("あと \(remaining)回 で \(next.display)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
            } else {
                Text("最高位に到達しています")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(gold)
            }

            HStack(spacing: 14) {
                Label("連続 \(records.currentStreak)", systemImage: "flame.fill")
                Label("最高 \(records.bestStreak)", systemImage: "trophy.fill")
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
        .frame(minWidth: 330)
    }

    // MARK: - 待ち

    private var waits: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("待ち")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary)
            ForEach(Array(round.waits.enumerated()), id: \.offset) { _, wait in
                HStack(spacing: 3) {
                    TileView(tile: wait.tile).frame(height: 54)
                    Text("\(wait.count)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
