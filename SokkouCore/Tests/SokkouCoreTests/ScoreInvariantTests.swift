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

/// 100点は必ず1種類だけ。
///
/// 同格を並べて出すと「100点が2つある」ことになり、
/// 100点＝いちばん速い1枚 という読み方が崩れる。
struct SingleHundredTests {

    let evaluator = Evaluator()

    func hands(count: Int) -> [TileCounts] {
        ScoreInvariantTests().hands(count: count)
    }

    @Test("100点はどの局面でもちょうど1種類")
    func exactlyOneHundred() {
        for hand in hands(count: 400) {
            let evaluation = evaluator.evaluate(hand: hand)
            let hundreds = evaluation.options.filter { $0.score == 100 }
            #expect(hundreds.count == 1, "100点が \(hundreds.count) 種類ある")
            #expect(evaluation.bestTiles.count == 1, "最善（金色）も1種類")
        }
    }

    @Test("同じ手なら毎回同じ牌が最善になる")
    func isStable() {
        for hand in hands(count: 80) {
            let first = evaluator.evaluate(hand: hand).bestTiles
            #expect(evaluator.evaluate(hand: hand).bestTiles == first)
        }
    }

    @Test("100点でない同点の牌は99点以下で、正解のまま")
    func tiedRunnersUpStayCorrect() {
        // 1萬2萬6萬6萬8萬9萬 / 2筒3筒4筒 / 1索4索7索8索8索
        // 1索切りと4索切りは聴牌までの速さが完全同点
        let eval = evaluator.evaluate(hand: EvaluatorTests.hand("126689m234p14788s"))
        let keep1s = Tile(.sou, 4)
        #expect(eval.option(for: keep1s)?.score == 99)
        #expect(eval.isBest(keep1s) == false)
        #expect(eval.isCorrect(keep1s), "同点なので正解のまま。止めずに先へ進める")
    }
}
