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
                 ? "すべて90点以上"
                 : "外した打牌 \(round.mistakes)回")
                .font(.system(size: 13))
                .foregroundStyle(round.mistakes == 0 ? green : .secondary)
        }
    }

    // MARK: - 段位と経験値メーター

    private var rankMeter: some View {
        VStack(alignment: .leading, spacing: 9) {
            // この局でいくら入ったか
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("獲得経験値")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
                Text("+\(outcome?.gained ?? 0)")
                    .font(.system(size: 40, weight: .black)).monospacedDigit()
                    .foregroundStyle(Color(red: 0.55, green: 1, blue: 0.65))
                Text(gainReason)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            ExperienceBar(progress: records.progress, gained: outcome?.gained,
                          showsTitle: false, animates: true)

            HStack(spacing: 14) {
                Label("連続 \(records.currentStreak)", systemImage: "flame.fill")
                Label("最高 \(records.bestStreak)", systemImage: "trophy.fill")
                Label("最速聴牌 \(records.fastestCount)回", systemImage: "bolt.fill")
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
        .frame(minWidth: 360)
    }

    /// 何点入ったのかの理由。半分ずつ減ることが伝わるようにする
    private var gainReason: String {
        switch round.mistakes {
        case 0: "ノーミス（満点）"
        case 1: "1回外して半分"
        default: "\(round.mistakes)回外した"
        }
    }

    // MARK: - 待ち

    private var waits: some View {
        VStack(alignment: .leading, spacing: 5) {
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
                Text("計\(round.waitCount)枚")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            // ここから何巡でツモれるか。山から戻さずに引くので超幾何分布
            HStack(spacing: 14) {
                ForEach(DrawChance.checkpoints, id: \.self) { turns in
                    let p = DrawChance.probability(waits: round.waitCount,
                                                   unseen: round.unseenTotal,
                                                   draws: turns)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(turns)巡")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text("\(Int((p * 100).rounded()))%")
                            .font(.system(size: 17, weight: .heavy)).monospacedDigit()
                            .foregroundStyle(.white)
                    }
                }
                Text("でツモれる")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
