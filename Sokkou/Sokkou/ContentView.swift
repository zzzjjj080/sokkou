import SwiftUI
import SokkouCore

/// 横画面で14枚を1列に並べる。縦だと牌が小さくなりすぎて絵柄が読めない。
struct ContentView: View {
    @Bindable var game: GameModel
    @State private var showsDetail = false
    @State private var showsSettings = false

    private let background = Color(red: 0.106, green: 0.122, blue: 0.141)
    private let panel = Color(red: 0.149, green: 0.169, blue: 0.200)

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            Group {
                if game.phase == .finished {
                    // 局が終わったら画面ごと差し替える。手牌が並んだままだと
                    // ツモを続けているのと見分けがつかない
                    RoundResultView(round: game.round,
                                    records: game.records,
                                    outcome: game.lastOutcome,
                                    onNext: { game.advance() })
                } else {
                    VStack(spacing: 0) {
                        header
                        Spacer(minLength: 4)
                        handRow    // 上下に Spacer を置いて画面の中央に来るようにする
                        Spacer(minLength: 4)
                        bottomRow
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .sheet(isPresented: $showsDetail) {
            if let evaluation = game.evaluation, let chosen = game.chosen {
                DetailSheet(evaluation: evaluation, chosen: chosen)
            }
        }
        .sheet(isPresented: $showsSettings) { SettingsSheet(game: game) }
    }

    // MARK: - 上段（段位と記録）

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(game.records.rank?.display ?? "称号なし")
                    .font(.system(size: 23, weight: .heavy))
                    .foregroundStyle(Color(red: 1, green: 0.835, blue: 0.290))
                if let next = game.records.nextRank {
                    Text("次の\(next.rank.display)まで あと\(next.remaining)回")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                } else {
                    Text("最高位").font(.system(size: 13)).foregroundStyle(.secondary)
                }
            }
            // 経験値メーター。段位が上がる条件はこれだけなので常に出しておく
            ExperienceBar(progress: game.records.progress, gained: nil)
                .frame(maxWidth: 340)
            stat("連続", "\(game.records.currentStreak)")
            stat("最高連続", "\(game.records.bestStreak)")
            Text("\(game.turn)巡目")
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(Color(red: 1, green: 0.835, blue: 0.290))
            Button { showsSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 22))
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 25, weight: .heavy)).monospacedDigit()
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .frame(minWidth: 74)
    }

    // MARK: - 手牌

    private var handRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(game.handSlots) { slot in
                if slot.isDrawn { Spacer().frame(width: 20) }
                tileSlot(slot)
            }
        }
    }

    private func tileSlot(_ slot: GameModel.HandSlot) -> some View {
        VStack(spacing: 4) {
            scoreBadge(for: slot.tile)
            TileView(tile: slot.tile)
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(ringColor(for: slot), lineWidth: 3.5).padding(1.75))
                .onTapGesture { game.choose(slot.tile) }
            Text(slot.isDrawn ? "ツモ" : " ")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(red: 1, green: 0.835, blue: 0.290))
        }
        .padding(.horizontal, 2)
    }

    /// 未回答のあいだはヒントの枠だけ、回答後は点数と結果の枠
    private func ringColor(for slot: GameModel.HandSlot) -> Color {
        let tile = slot.tile
        guard let evaluation = game.evaluation else { return .clear }
        if game.phase == .choosing {
            // 同じ牌が2枚あっても枠は1枚目だけ
            return slot.showsHintRing ? Color(red: 1, green: 0.231, blue: 0.188) : .clear
        }
        if evaluation.isBest(tile) { return Color(red: 1, green: 0.835, blue: 0.290) }
        if evaluation.isCorrect(tile) { return Color(red: 0.247, green: 0.627, blue: 0.373) }
        if slot.isChosen { return Color(red: 0.290, green: 0.490, blue: 1) }
        return .clear
    }

    @ViewBuilder
    private func scoreBadge(for tile: Tile) -> some View {
        if game.phase != .choosing, let option = game.evaluation?.option(for: tile) {
            Text(option.score.map { "\($0)" } ?? "戻し")
                .font(.system(size: option.score == nil ? 11 : 17, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(badgeText(option))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(badgeFill(option), in: RoundedRectangle(cornerRadius: 6))
        } else {
            Text(" ").font(.system(size: 17, weight: .heavy))
        }
    }

    private func badgeFill(_ option: DiscardOption) -> Color {
        guard let evaluation = game.evaluation else { return .gray }
        if option.isShantenBack { return Color(red: 0.35, green: 0.24, blue: 0.24) }
        if evaluation.isBest(option.tile) { return Color(red: 0.910, green: 0.725, blue: 0.227) }
        if evaluation.isCorrect(option.tile) { return Color(red: 0.180, green: 0.490, blue: 0.275) }
        return Color(red: 0.227, green: 0.251, blue: 0.282)
    }

    private func badgeText(_ option: DiscardOption) -> Color {
        guard let evaluation = game.evaluation else { return .white }
        return evaluation.isBest(option.tile) ? Color(red: 0.14, green: 0.11, blue: 0.01) : .white
    }

    // MARK: - 下段（判定とボタン）

    private var bottomRow: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(verdictText)
                .font(.system(size: 21, weight: .heavy))
                .foregroundStyle(verdictColor)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                Button("詳細") { showsDetail = true }
                    .font(.system(size: 15, weight: .bold))
                    .buttonStyle(.bordered)
                    .disabled(game.phase == .choosing || game.isBusy)
                Button("やり直す") { game.restart() }
                    .font(.system(size: 15, weight: .bold))
                    .buttonStyle(.bordered)
                    .disabled(game.isBusy)
            }

            // ツモるは一番右に、一番大きく
            Button { game.advance() } label: {
                Text(game.isBusy ? "少々お待ちください" : actionLabel)
                    .font(.system(size: game.isBusy ? 15 : 26, weight: .heavy))
                    .frame(width: 168, height: 74)
            }
            .buttonStyle(.borderedProminent)
            .disabled(game.phase == .choosing || game.isBusy)
        }
    }

    private var verdictText: String {
        if game.isBusy { return "少々お待ちください…" }
        guard game.phase != .choosing,
              let evaluation = game.evaluation, let chosen = game.chosen,
              let option = evaluation.option(for: chosen) else {
            return "最速で聴牌する1枚を選ぶ"
        }
        if game.phase == .finished {
            let waits = game.round.waits.map { "\($0.tile)(\($0.count))" }.joined(separator: "・")
            if let promoted = game.lastOutcome?.promotedTo {
                return "🎊 \(promoted.display) に昇格!  待ち \(waits)"
            }
            return game.round.wasFastest
                ? "🎉 最速聴牌!  \(game.turn)巡目  待ち \(waits)"
                : "🀄 \(game.turn)巡目で聴牌（外し \(game.round.mistakes)回）  待ち \(waits)"
        }
        if option.isShantenBack {
            return "❌ シャンテンを戻す打牌（採点対象外）"
        }
        let score = option.score ?? 0
        if evaluation.isBest(chosen) { return "🎉 100点! 最善の一手です" }
        if evaluation.isCorrect(chosen) { return "🎯 \(score)点 — 正解" }
        return "😕 \(score)点 — 最善は \(evaluation.bestTiles.map(\.description).joined(separator: "・"))"
    }

    private var verdictColor: Color {
        guard game.phase != .choosing, let evaluation = game.evaluation, let chosen = game.chosen
        else { return .secondary }
        if game.phase == .finished { return Color(red: 1, green: 0.835, blue: 0.290) }
        if evaluation.isCorrect(chosen) { return Color(red: 0.42, green: 0.85, blue: 0.55) }
        return Color(red: 1, green: 0.60, blue: 0.55)
    }

    private var actionLabel: String {
        game.phase == .finished ? "次の局へ" : "ツモる"
    }
}
