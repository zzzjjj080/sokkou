import Foundation
import Observation
import SokkouCore

/// 外した局面をまとめて解き直す1回ぶん。
///
/// 記録した点数は持ち越さず、**開くたびに採点し直す。**
/// 判定のしかたを変えても、古い局面がそのまま使える。
@MainActor
@Observable
final class ReviewSession: Identifiable {
    let positions: [ReviewPosition]
    /// どの形で絞っているか。nil ならすべて
    let tag: WeaknessTag?
    private let shantenCalculator: ShantenCalculator
    private let evaluator: Evaluator

    private(set) var index = 0
    private(set) var evaluation: Evaluation?
    private(set) var chosen: Tile?
    /// 今回正解できた局面。閉じるときに一覧から外す
    private(set) var solved: [ReviewPosition] = []
    private(set) var missed = 0

    init(positions: [ReviewPosition],
         tag: WeaknessTag? = nil,
         shantenCalculator: ShantenCalculator,
         evaluator: Evaluator) {
        self.positions = positions
        self.tag = tag
        self.shantenCalculator = shantenCalculator
        self.evaluator = evaluator
        load()
    }

    var total: Int { positions.count }
    var isFinished: Bool { index >= positions.count }
    var current: ReviewPosition? { isFinished ? nil : positions[index] }
    var hasAnswered: Bool { chosen != nil }
    /// 何問目か（1始まり）
    var position: Int { min(index + 1, total) }
    var correctCount: Int { solved.count }

    var slots: [HandSlot] {
        guard let current else { return [] }
        let base = HandLayout.slots(hand: current.handTiles, drawn: current.drawnTile)
        guard let chosen else { return base }
        return HandLayout.marking(base, chosen: chosen)
    }

    /// 前回この局面で選んだ牌
    var previousChoice: Tile? { current?.chosenTile }

    /// いま解いている局面の形
    var currentTag: WeaknessTag? { current?.tag }

    private func load() {
        guard let current, current.isUsable, let fourteen = current.fourteen else {
            evaluation = nil
            return
        }
        evaluator.trimCachesIfNeeded()
        evaluation = evaluator.evaluate(hand: fourteen)
        chosen = nil
    }

    func choose(_ tile: Tile) {
        guard !hasAnswered, let evaluation, let current,
              let fourteen = current.fourteen, fourteen[tile] > 0 else { return }
        Haptics.tap()
        chosen = tile
        if evaluation.isCorrect(tile) {
            solved.append(current)
            Haptics.correct()
        } else {
            missed += 1
            if evaluation.option(for: tile)?.isShantenBack == true {
                Haptics.shantenBack()
            } else {
                Haptics.incorrect()
            }
        }
    }

    func next() {
        guard hasAnswered else { return }
        index += 1
        load()
        if isFinished { Haptics.roundFinished() }
    }
}
