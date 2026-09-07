import SwiftUI
import SokkouCore

/// 横画面で14枚を1列に並べる。縦だと牌が小さくなりすぎて絵柄が読めない。
struct ContentView: View {
    @Bindable var game: GameModel
    @State private var showsDetail = false
    @State private var showsSettings = false


    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
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
        // 初回だけ全画面で遊び方を出す。設定からいつでも読み直せる
        .fullScreenCover(isPresented: $game.needsIntroduction) {
            IntroductionView { game.needsIntroduction = false }
        }
    }

    // MARK: - 上段（段位と記録）

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            // 称号はここだけに出す。メーターの中にも書くと同じものが2つ並ぶ
            Text(game.records.rank?.display ?? "称号なし")
                .font(.system(size: 23, weight: .heavy))
                .foregroundStyle(Palette.gold)
                .lineLimit(1)
            // 経験値メーター。段位が上がる条件はこれだけなので常に出しておく
            ExperienceBar(from: game.records.experience, to: game.records.experience,
                          showsTitle: false)
                .frame(maxWidth: 340)
            stat("連続", "\(game.records.currentStreak)")
            stat("最高連続", "\(game.records.bestStreak)")
            Text("\(game.turn)巡目")
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(Palette.gold)
            Button { showsSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 22))
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            .accessibilityIdentifier("settings")
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

    private func tileSlot(_ slot: HandSlot) -> some View {
        TileSlotView(slot: slot,
                     evaluation: game.evaluation,
                     isRevealed: game.phase != .choosing,
                     accessibilityID: identifier(for: slot),
                     onTap: { game.choose(slot.tile) })
    }

    /// 画面確認用の目印。撮影では最善を、動作確認では**わざと外す牌**を選べるようにする。
    /// 90点以上は正解なので、「最善でない牌」を切っても外しにならないことがある。
    /// **DEBUGビルドでしか答えを教えないので、配布版はただの通し番号になる。**
    private func identifier(for slot: HandSlot) -> String {
        #if DEBUG
        if game.phase == .choosing, let evaluation = game.evaluation {
            if evaluation.isBest(slot.tile) { return "tile-best" }
            if !evaluation.isCorrect(slot.tile) { return "tile-miss" }
        }
        #endif
        return "tile-\(slot.id)"
    }

    // MARK: - 下段（判定とボタン）

    private var bottomRow: some View {
        HStack(alignment: .center, spacing: 14) {
            // 左利きなら、押す回数がいちばん多い「ツモる」を親指側へ持ってくる
            if game.isLeftHanded {
                drawButton
                sideButtons
                verdict
            } else {
                verdict
                sideButtons
                drawButton
            }
        }
    }

    private var verdict: some View {
        VStack(alignment: game.isLeftHanded ? .trailing : .leading, spacing: 3) {
            Text(verdictText)
                .font(.system(size: 21, weight: .heavy))
                .foregroundStyle(verdictColor)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            // 詳細を開かなくても「なぜ劣るのか」が分かるように、理由を1行
            if let why = explanation {
                Text(why)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .accessibilityIdentifier("explanation")
            }
        }
        .frame(maxWidth: .infinity,
               alignment: game.isLeftHanded ? .trailing : .leading)
    }

    /// 切った直後だけ出す。局が終わった画面や未回答では出さない
    private var explanation: String? {
        guard game.phase == .afterDiscard, !game.isBusy,
              let evaluation = game.evaluation, let chosen = game.chosen else { return nil }
        return Explanation.oneLiner(chosen: chosen, in: evaluation)
    }

    private var sideButtons: some View {
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
    }

    /// 一番大きく。既定では一番右（設定で左に移せる）
    private var drawButton: some View {
        Button { game.advance() } label: {
            Text(game.isBusy ? "少々お待ちください" : actionLabel)
                .font(.system(size: game.isBusy ? 15 : 26, weight: .heavy))
                .frame(width: 168, height: 74)
        }
        .buttonStyle(.borderedProminent)
        .disabled(game.phase == .choosing || game.isBusy)
        .accessibilityIdentifier("draw")
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
        if game.phase == .finished { return Palette.gold }
        if evaluation.isCorrect(chosen) { return Palette.green }
        return Palette.miss
    }

    private var actionLabel: String {
        game.phase == .finished ? "次の局へ" : "ツモる"
    }
}
