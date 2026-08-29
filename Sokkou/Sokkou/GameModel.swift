import Foundation
import Observation
import SokkouCore

/// 画面が見る状態。判定と局の進行はCoreに任せ、ここは並べ替えと保存だけを持つ。
@MainActor
@Observable
final class GameModel {
    enum Phase: Equatable {
        /// 1枚選ぶところ
        case choosing
        /// 切ったあと。次のツモを待っている
        case afterDiscard
        /// テンパイして局が終わった
        case finished
    }

    // 表を持つので使い回す。作り直すと10MBの確保からやり直しになる
    private let shantenCalculator: ShantenCalculator
    private let evaluator: Evaluator
    private var rng = SystemRandomNumberGenerator()

    private(set) var round: Round
    private(set) var evaluation: Evaluation?
    private(set) var phase: Phase = .choosing
    private(set) var chosen: Tile?
    private(set) var records: Records
    /// 直前の局で起きたこと（昇格したかなど）
    private(set) var lastOutcome: RoundOutcome?
    /// 配牌や採点の最中。この間はボタンを押せなくする。
    /// 押しても反応が無いと二度押しされ、2局ぶん進んでしまうため
    private(set) var isBusy = false

    /// ヒント（切る候補をTOP5に絞る）
    var showsHint: Bool {
        didSet { UserDefaults.standard.set(showsHint, forKey: Keys.hint) }
    }
    var hapticsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hapticsEnabled, forKey: Keys.haptics)
            Haptics.isEnabled = hapticsEnabled
        }
    }

    private enum Keys {
        static let records = "records.v1"
        static let hint = "showsHint"
        static let haptics = "hapticsEnabled"
    }

    init() {
        let calculator = ShantenCalculator()
        shantenCalculator = calculator
        evaluator = Evaluator(shantenCalculator: calculator)

        let defaults = UserDefaults.standard
        showsHint = defaults.object(forKey: Keys.hint) as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        if let data = defaults.data(forKey: Keys.records),
           let saved = try? JSONDecoder().decode(Records.self, from: data) {
            records = saved
        } else {
            records = Records()
        }

        var generator = SystemRandomNumberGenerator()
        round = Round(shantenCalculator: calculator, rng: &generator,
                      shantenRange: GameModel.dealRange)
        rng = generator
        Haptics.isEnabled = hapticsEnabled
        drawTile()
    }

    // MARK: - 表示に使う値

    /// 画面に並べる1枚ぶん
    struct HandSlot: Identifiable {
        let id: Int
        let tile: Tile
        let isDrawn: Bool
        /// ヒントの枠を出すか
        let showsHintRing: Bool
        /// 自分が選んで切った牌か
        var isChosen: Bool = false
    }

    /// ヒントで枠を付ける牌の種類。上位5種まで、ただし**最低3種は出す**。
    ///
    /// 採点対象(シャンテンを戻さない打牌)が1〜2種しかない局面があり、
    /// そのままだと枠が1つしか付かずヒントの意味がなくなっていた。
    /// 足りないぶんは点数順に、対象外の打牌からでも埋める。
    static let hintMinimum = 3
    static let hintMaximum = 5

    var hintKinds: [Tile] {
        guard showsHint, phase == .choosing, let evaluation else { return [] }
        var kinds = evaluation.options
            .filter { !$0.isShantenBack }
            .prefix(GameModel.hintMaximum)
            .map(\.tile)
        if kinds.count < GameModel.hintMinimum {
            for option in evaluation.options where !kinds.contains(option.tile) {
                kinds.append(option.tile)
                if kinds.count == GameModel.hintMinimum { break }
            }
        }
        return kinds
    }

    /// 打牌後に見せる14枚。切った瞬間に手牌が入れ替わると、
    /// 自分が何を選んだのか画面から消えてしまうため、次のツモまで凍結して見せる。
    private var frozenSlots: [HandSlot]?

    /// 手牌13枚 + ツモ牌。
    /// 同じ牌が2枚あっても切る候補としては1つなので、**ヒントの枠は1枚目だけに付ける。**
    var handSlots: [HandSlot] {
        if let frozenSlots { return frozenSlots }
        let candidates = hintKinds
        var marked = Set<Tile>()
        var slots: [HandSlot] = []
        for (index, tile) in round.hand.tiles.enumerated() {
            let shows = candidates.contains(tile) && !marked.contains(tile)
            if shows { marked.insert(tile) }
            slots.append(HandSlot(id: index, tile: tile, isDrawn: false, showsHintRing: shows))
        }
        if let drawn = round.drawn {
            let shows = candidates.contains(drawn) && !marked.contains(drawn)
            slots.append(HandSlot(id: 100, tile: drawn, isDrawn: true, showsHintRing: shows))
        }
        return slots
    }

    var handTiles: [Tile] { round.hand.tiles }
    var drawnTile: Tile? { round.drawn }
    var turn: Int { round.turn }

    // MARK: - 進行

    private func drawTile() {
        frozenSlots = nil
        round.draw(shantenCalculator: shantenCalculator, rng: &rng)
        guard let fourteen = round.fourteen else { return }
        evaluator.trimCachesIfNeeded()
        evaluation = evaluator.evaluate(hand: fourteen)
        chosen = nil
        phase = .choosing
    }

    /// 牌を1枚選ぶ
    func choose(_ tile: Tile) {
        guard !isBusy, phase == .choosing,
              let evaluation, let fourteen = round.fourteen else { return }
        guard fourteen[tile] > 0 else { return }

        Haptics.tap()
        chosen = tile
        // 入れ替わる前の14枚を、選んだ牌に印を付けて残す
        frozenSlots = handSlots.map { slot in
            var copy = slot
            copy.isChosen = false
            return copy
        }
        if let index = frozenSlots?.firstIndex(where: { $0.tile == tile }) {
            frozenSlots?[index].isChosen = true
        }
        let isCorrect = evaluation.isCorrect(tile)
        let after = fourteen.removing(tile)
        let reachesTenpai = shantenCalculator.shanten(after) <= 0
        let waits = reachesTenpai ? (evaluation.option(for: tile)?.ukeire ?? []) : []

        round.discard(tile, isCorrect: isCorrect, isBest: evaluation.isBest(tile),
                      shantenCalculator: shantenCalculator, waitsIfTenpai: waits)

        if let option = evaluation.option(for: tile), option.isShantenBack {
            Haptics.shantenBack()
        } else if isCorrect {
            Haptics.correct()
        } else {
            Haptics.incorrect()
        }

        if round.isFinished {
            finishRound()
        } else {
            phase = .afterDiscard
        }
    }

    private func finishRound() {
        phase = .finished
        let outcome = records.finishRound(score: round.score)
        lastOutcome = outcome
        save()
        if outcome.promotedTo != nil {
            Haptics.promoted()
        } else if outcome.wasFastest {
            Haptics.fastest()
        } else {
            Haptics.roundFinished()
        }
    }

    /// 「ツモる」か「次の局へ」
    func advance() {
        guard !isBusy else { return }
        switch phase {
        case .choosing:
            break
        case .afterDiscard:
            Haptics.draw()
            run { self.drawTile() }
        case .finished:
            run { self.startNewRound() }
        }
    }

    /// 今の局を捨てて配牌からやり直す。記録は減らさない。
    func restart() {
        guard !isBusy else { return }
        run { self.startNewRound() }
    }

    /// 重い処理を、画面に「待っている」と出してから走らせる。
    /// そのまま呼ぶと終わるまで再描画されず、固まったように見えて二度押しを招く。
    private func run(_ work: @escaping () -> Void) {
        isBusy = true
        Task { @MainActor in
            await Task.yield()      // ここで一度描かせてから重い処理へ入る
            work()
            isBusy = false
        }
    }

    /// 配牌のシャンテン範囲。通常は3〜4向聴。
    /// 動作確認のときだけ、環境変数で聴牌までを短くできる。
    /// **DEBUGビルドでしか読まないので、配布版では必ず3〜4向聴になる。**
    static var dealRange: ClosedRange<Int> {
        #if DEBUG
        if ProcessInfo.processInfo.environment["SOKKOU_QUICK_TENPAI"] == "1" { return 1...1 }
        #endif
        return Round.dealtShantenRange
    }

    private func startNewRound() {
        lastOutcome = nil
        frozenSlots = nil
        round = Round(shantenCalculator: shantenCalculator, rng: &rng,
                      shantenRange: GameModel.dealRange)
        drawTile()
    }

    func resetRecords() {
        records.resetAll()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: Keys.records)
        }
    }
}
