import Foundation
import Testing
@testable import SokkouCore

/// 採点の芯。**Web版で近似なしのモンテカルロと突き合わせて確かめた局面**を、
/// そのままテストにしてある。ここが崩れたら判定が別物になる。
struct EvaluatorTests {

    let evaluator = Evaluator()
    static func hand(_ text: String) -> TileCounts { ShantenTests.hand(text) }

    // MARK: - 検証済みの局面

    /// 3萬7萬7萬8萬 / 1筒3筒4筒7筒 / 1索2索4索6索8索9索
    ///
    /// 雀頭候補の7萬を切って4向聴に戻すのが最善、とWeb版が出していた局面。
    /// モンテカルロでは1索切り(4向聴)が28.30%で最速だったが、
    /// 戻しは判断できないので採点対象外にする、と決めた。
    /// よって最善は3向聴を保つ側から選ばれる。
    @Test("戻しの打牌は最善にならない")
    func shantenBackIsNeverBest() {
        let eval = evaluator.evaluate(hand: Self.hand("3778m1347p124689s"))
        #expect(eval.minShanten == 3)

        // 4向聴に戻る打牌は採点対象外
        let backTile = Tile(.sou, 1)
        #expect(eval.option(for: backTile)?.shanten == 4)
        #expect(eval.option(for: backTile)?.isShantenBack == true)
        #expect(eval.option(for: backTile)?.score == nil)
        #expect(eval.isBest(backTile) == false)
        #expect(eval.isCorrect(backTile) == false)

        // 最善は必ず最小シャンテンを保つ打牌
        for tile in eval.bestTiles {
            #expect(eval.option(for: tile)?.shanten == eval.minShanten)
        }
    }

    /// 4萬8萬9萬9萬 / 1筒5筒6筒 / 1索2索4索4索5索8索9索
    ///
    /// Web版は2索切り(4向聴)を最善としていたが、モンテカルロでは
    /// 1筒切り(3向聴)が28.01%で全打牌中もっとも速かった。戻しを外すと一致する。
    @Test("実測で最速だった1筒切りが最善になる")
    func matchesMonteCarloOnTheSecondPosition() {
        let eval = evaluator.evaluate(hand: Self.hand("4899m156p1244589s"))
        #expect(eval.minShanten == 3)
        #expect(eval.bestTiles.contains(Tile(.pin, 1)), "実測で最速だった1筒切りが最善に入る")
        #expect(eval.option(for: Tile(.sou, 2))?.isShantenBack == true, "2索切りは4向聴に戻る")
    }

    /// 1萬2萬6萬6萬8萬9萬 / 2筒3筒4筒 / 1索4索7索8索8索
    ///
    /// 5ブロック足りていて1索と4索が余る形。Web版は両者を完全同点としたが、
    /// モンテカルロでは1索切り(4索を残す)が0.94ポイント速かった(z=13.3)。
    /// 伸びしろ(改良牌)で分けると1索38枚 対 4索34枚となり、実測と一致する。
    @Test("同点は伸びしろで分かれ、負けた側も正解のまま")
    func breaksExactTiesByImprovement() {
        let eval = evaluator.evaluate(hand: Self.hand("126689m234p14788s"))
        let keep4s = Tile(.sou, 1)      // 1索を切る = 4索を残す
        let keep1s = Tile(.sou, 4)      // 4索を切る = 1索を残す

        #expect(eval.option(for: keep4s)?.score == 100)
        #expect(eval.option(for: keep1s)?.score == 100, "聴牌までの速さは同点")
        #expect(eval.option(for: keep4s)!.improvement > eval.option(for: keep1s)!.improvement,
                "4索を残すほうが伸びしろが広い")
        #expect(eval.isBest(keep4s), "伸びしろで1索切りが最善")
        #expect(eval.isBest(keep1s) == false)
        #expect(eval.isCorrect(keep1s), "同点なので正解のまま。止めずに先へ進める")
    }

    // MARK: - 点数の決まり

    @Test("最善はちょうど100点")
    func bestIsExactlyOneHundred() {
        for text in ["3778m1347p124689s", "4899m156p1244589s", "126689m234p14788s"] {
            let eval = evaluator.evaluate(hand: Self.hand(text))
            let top = eval.options.first { !$0.isShantenBack }!
            #expect(top.score == 100)
            for tile in eval.bestTiles { #expect(eval.option(for: tile)?.score == 100) }
        }
    }

    @Test("正解は90点以上、最善は98点以上")
    func thresholdsHold() {
        let eval = evaluator.evaluate(hand: Self.hand("4899m156p1244589s"))
        for option in eval.options where !option.isShantenBack {
            let isCorrect = eval.isCorrect(option.tile)
            #expect(isCorrect == (option.score! >= Evaluator.okScore))
            if eval.isBest(option.tile) { #expect(option.score! >= Evaluator.tieScore) }
        }
    }

    @Test("採点対象外の打牌には点数が付かない")
    func shantenBackHasNoScore() {
        let eval = evaluator.evaluate(hand: Self.hand("4899m156p1244589s"))
        for option in eval.options {
            #expect((option.score == nil) == (option.shanten > eval.minShanten))
        }
    }

    @Test("並び順は点数の高い順で、戻しは末尾")
    func optionsAreSorted() {
        let eval = evaluator.evaluate(hand: Self.hand("4899m156p1244589s"))
        let scored = eval.options.prefix { !$0.isShantenBack }
        #expect(scored.count == eval.options.filter { !$0.isShantenBack }.count,
                "戻しが途中に混ざっている")
        let scores = scored.map { $0.score! }
        #expect(scores == scores.sorted(by: >))
    }

    // MARK: - 壊れていないことの確認

    @Test("最善は必ず正解に含まれる")
    func bestIsAlwaysCorrect() {
        var rng = SeededRandom(seed: 4242)
        for _ in 0..<12 {
            let hand = ShantenTests.randomHand(size: 14, rng: &rng)
            let eval = evaluator.evaluate(hand: hand)
            #expect(eval.bestTiles.isEmpty == false)
            for tile in eval.bestTiles { #expect(eval.isCorrect(tile)) }
        }
    }

    /// 採点はツモるたびに走る。遅いと画面が止まる。
    /// 数値はリリース構成で見ること。デバッグ構成は最適化が効かず50倍遅い。
    @Test("14枚の採点が実用的な速さで終わる")
    func evaluationIsFastEnough() {
        var rng = SeededRandom(seed: 99)
        let hands = (0..<20).map { _ in ShantenTests.randomHand(size: 14, rng: &rng) }
        let fresh = Evaluator()
        let start = Date()
        for hand in hands { _ = fresh.evaluate(hand: hand) }
        let elapsed = Date().timeIntervalSince(start)
        print("14枚の採点20回: \(Int(elapsed * 1000))ms / 1回あたり \(Int(elapsed * 1000 / 20))ms")
        #expect(elapsed < 60, "デバッグ構成を含めても60秒はかからないはず")
    }

    @Test("読む深さはシャンテン数で決まる")
    func lookaheadFollowsShanten() {
        #expect(Evaluator.lookahead(forShanten: 0) == 2)
        #expect(Evaluator.lookahead(forShanten: 1) == 4)
        #expect(Evaluator.lookahead(forShanten: 3) == 8)
        #expect(Evaluator.lookahead(forShanten: 6) == 12, "上限12で頭打ち")
    }
}
