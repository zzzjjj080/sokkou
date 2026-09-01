import Foundation
import Testing
@testable import SokkouCore

/// 点数と金色の食い違いを見張る。
///
/// 「最善＝100点＝金色」が崩れると、画面を見た人が理由を探すことになる。
/// 完全同点を伸びしろで絞ったときに負けた側が100点のまま残っていた。
struct ScoreInvariantTests {

    /// いろいろな手を作る。特定の1局に頼らず、広く当たりに行く
    func hands(count: Int) -> [TileCounts] {
        var generator = SystemlessRandom(seed: 20260901)
        var out: [TileCounts] = []
        while out.count < count {
            var wall = [Int](repeating: Tile.copiesPerTile, count: Tile.kindCount)
            var hand = TileCounts()
            for _ in 0..<14 {
                let total = wall.reduce(0, +)
                var pick = Int(generator.next() % UInt64(total))
                var index = 0
                while pick >= wall[index] { pick -= wall[index]; index += 1 }
                wall[index] -= 1
                hand[Tile(index: index)!] += 1
            }
            out.append(hand)
        }
        return out
    }

    @Test("100点が付くのは最善だけ")
    func hundredMeansBest() {
        let evaluator = Evaluator()
        for hand in hands(count: 300) {
            let evaluation = evaluator.evaluate(hand: hand)
            for option in evaluation.options where option.score != nil {
                #expect((option.score == 100) == evaluation.isBest(option.tile),
                        "\(option.tile) が \(option.score!)点 なのに最善判定と食い違う")
            }
        }
    }

    @Test("最善はすべて100点")
    func bestAlwaysScoresHundred() {
        let evaluator = Evaluator()
        for hand in hands(count: 300) {
            let evaluation = evaluator.evaluate(hand: hand)
            for tile in evaluation.bestTiles {
                #expect(evaluation.option(for: tile)?.score == 100,
                        "最善の \(tile) が100点になっていない")
            }
        }
    }

    @Test("正解(90点以上)は最善を必ず含む")
    func correctIncludesBest() {
        let evaluator = Evaluator()
        for hand in hands(count: 200) {
            let evaluation = evaluator.evaluate(hand: hand)
            for tile in evaluation.bestTiles {
                #expect(evaluation.isCorrect(tile), "最善の \(tile) が正解に入っていない")
            }
        }
    }
}
