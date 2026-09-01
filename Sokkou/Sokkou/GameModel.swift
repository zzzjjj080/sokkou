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
    /// 外した局面のたまり場。あとでまとめて解き直す
    private(set) var reviewStore: ReviewStore

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

    /// ツモるボタンを左に置く。左手で持つ人のための入れ替え
    var isLeftHanded: Bool {
        didSet { UserDefaults.standard.set(isLeftHanded, forKey: Keys.leftHanded) }
    }

    /// 遊び方をまだ一度も見ていない
    var needsIntroduction: Bool {
        didSet { UserDefaults.standard.set(!needsIntroduction, forKey: Keys.introSeen) }
    }

    private enum Keys {
        static let records = "records.v1"
        static let hint = "showsHint"
        static let haptics = "hapticsEnabled"
        static let leftHanded = "isLeftHanded"
        static let introSeen = "hasSeenIntroduction"
        static let review = "review.v1"
    }

    init() {
        let calculator = ShantenCalculator()
        shantenCalculator = calculator
        evaluator = Evaluator(shantenCalculator: calculator)

        let defaults = UserDefaults.standard
        #if DEBUG
        // 動作確認のときだけ、初回起動と同じ状態から始められるようにする。
        // **DEBUGビルドでしか読まないので、配布版では消えない。**
        if ProcessInfo.processInfo.arguments.contains("-SOKKOU_RESET") {
            for key in [Keys.records, Keys.hint, Keys.haptics,
                        Keys.leftHanded, Keys.introSeen, Keys.review] {
                defaults.removeObject(forKey: key)
            }
        }
        #endif
        showsHint = defaults.object(forKey: Keys.hint) as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        isLeftHanded = defaults.object(forKey: Keys.leftHanded) as? Bool ?? false
        needsIntroduction = !(defaults.object(forKey: Keys.introSeen) as? Bool ?? false)
        #if DEBUG
        // 動作確認用の入口。**DEBUGビルドでしか読まないので、配布版では効かない。**
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-SOKKOU_LEFT_HANDED") {
            isLeftHanded = true
        }
        #endif
        if let data = defaults.data(forKey: Keys.review),
           let saved = try? JSONDecoder().decode(ReviewStore.self, from: data) {
            reviewStore = saved
        } else {
            reviewStore = ReviewStore()
        }
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
        #if DEBUG
        // 復習の画面を、決まった1局面で確かめられるようにする。
        // 1萬2萬6萬6萬8萬9萬 / 2筒3筒4筒 / 1索4索7索8索 + ツモ8索
        // （self が組み上がってからでないと reviewStore を書き換えられない）
        if arguments.contains("-SOKKOU_SEED_REVIEW") {
            reviewStore.record(ReviewPosition(hand: [0, 1, 5, 5, 7, 8, 10, 11, 12, 18, 21, 24, 25],
                                              drawn: 25, chosen: 0))
        }
        #endif
        drawTile()
    }

    // MARK: - 表示に使う値

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

    /// 手牌13枚 + ツモ牌。並べ方の規則は HandLayout に置いてある
    var handSlots: [HandSlot] {
        frozenSlots ?? HandLayout.slots(hand: round.hand.tiles, drawn: round.drawn,
                                        hintKinds: hintKinds)
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
        frozenSlots = HandLayout.marking(handSlots, chosen: tile)
        let isCorrect = evaluation.isCorrect(tile)
        let after = fourteen.removing(tile)
        let reachesTenpai = shantenCalculator.shanten(after) <= 0
        let waits = reachesTenpai ? (evaluation.option(for: tile)?.ukeire ?? []) : []

        // 切る前の14枚を控える。**discard すると drawn が手牌に入って nil になる**ので、
        // あとから復習用の局面を組み立てることはできない
        let missedPosition: ReviewPosition? = evaluation.isCorrect(tile) ? nil
            : round.drawn.map { drawn in
                ReviewPosition(hand: round.hand.tiles.map(\.index),
                               drawn: drawn.index, chosen: tile.index)
            }

        round.discard(tile, isCorrect: isCorrect, isBest: evaluation.isBest(tile),
                      shantenCalculator: shantenCalculator, waitsIfTenpai: waits)

        if let option = evaluation.option(for: tile), option.isShantenBack {
            Haptics.shantenBack()
        } else if isCorrect {
            Haptics.correct()
        } else {
            Haptics.incorrect()
        }

        if let missedPosition {
            reviewStore.record(missedPosition)
            saveReview()
        }

        if round.isFinished {
            finishRound()
        } else {
            phase = .afterDiscard
        }
    }

    /// 復習で正解できた局面は一覧から外す
    func retire(_ position: ReviewPosition) {
        reviewStore.remove(id: position.id)
        saveReview()
    }

    func clearReview() {
        reviewStore.removeAll()
        saveReview()
    }

    private func saveReview() {
        if let data = try? JSONEncoder().encode(reviewStore) {
            UserDefaults.standard.set(data, forKey: Keys.review)
        }
    }

    /// 復習を始める。局面が無ければ nil
    func makeReviewSession() -> ReviewSession? {
        guard !reviewStore.isEmpty else { return nil }
        return ReviewSession(positions: reviewStore.newestFirst,
                             shantenCalculator: shantenCalculator,
                             evaluator: evaluator)
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
