import Foundation
import Testing
@testable import SokkouCore

/// 局の進行。乱数を固定できるので、同じ手順を何度でも再現できる。
struct RoundTests {

    let calc = ShantenCalculator()

    func newRound(seed: UInt64) -> (Round, SystemlessRandom) {
        var rng = SystemlessRandom(seed: seed)
        let round = Round(shantenCalculator: calc, rng: &rng)
        return (round, rng)
    }

    @Test("配牌は13枚で、3〜4向聴に収まる")
    func dealIsThirteenTilesInRange() {
        for seed in UInt64(1)...30 {
            let (round, _) = newRound(seed: seed)
            #expect(round.hand.total == 13)
            #expect(Round.dealtShantenRange.contains(calc.shanten(round.hand)),
                    "seed \(seed) の配牌が範囲外")
            #expect(round.turn == 0)
            #expect(round.drawn == nil)
            #expect(round.isFinished == false)
        }
    }

    @Test("ツモると14枚になり、巡目が進む")
    func drawMakesFourteen() {
        var (round, rng) = newRound(seed: 7)
        round.draw(shantenCalculator: calc, rng: &rng)
        #expect(round.turn == 1)
        #expect(round.drawn != nil)
        #expect(round.fourteen?.total == 14)
        #expect(round.hand.total == 13, "手牌13枚とツモ牌は分けて持つ")
    }

    @Test("切ると手が入れ替わり、巡目は進まない")
    func discardSwapsTheHand() {
        var (round, rng) = newRound(seed: 11)
        round.draw(shantenCalculator: calc, rng: &rng)
        let drawn = round.drawn!
        let target = round.hand.kinds.first { $0 != drawn }!
        round.discard(target, isCorrect: true, shantenCalculator: calc, waitsIfTenpai: [])
        #expect(round.hand.total == 13)
        #expect(round.drawn == nil)
        #expect(round.turn == 1, "打牌では巡目は進まない")
        #expect(round.hand[drawn] > 0, "ツモった牌が手に入っている")
    }

    @Test("直前に切った牌は次のツモで引かない")
    func neverDrawsWhatWasJustDiscarded() {
        var (round, rng) = newRound(seed: 3)
        for _ in 0..<12 {
            guard !round.isFinished else { break }
            round.draw(shantenCalculator: calc, rng: &rng)
            guard let drawn = round.drawn else { break }
            let target = round.hand.kinds.first { $0 != drawn } ?? drawn
            round.discard(target, isCorrect: true, shantenCalculator: calc, waitsIfTenpai: [])
            guard !round.isFinished else { break }
            round.draw(shantenCalculator: calc, rng: &rng)
            #expect(round.drawn != target, "切ったばかりの \(target) をすぐ引いた")
            guard let next = round.drawn else { break }
            let drop = round.hand.kinds.first { $0 != next } ?? next
            round.discard(drop, isCorrect: true, shantenCalculator: calc, waitsIfTenpai: [])
        }
    }

    @Test("外した回数が数えられ、ノーミスなら最速聴牌になる")
    func countsMistakes() {
        var (round, rng) = newRound(seed: 21)
        round.draw(shantenCalculator: calc, rng: &rng)
        let drop = round.hand.kinds.first { $0 != round.drawn }!
        round.discard(drop, isCorrect: false, shantenCalculator: calc, waitsIfTenpai: [])
        #expect(round.mistakes == 1)
        #expect(round.wasFastest == false, "終わっていないうちは最速聴牌ではない")
    }

    @Test("テンパイしたら局が終わる")
    func finishesOnTenpai() {
        let evaluator = Evaluator()
        var (round, rng) = newRound(seed: 5)
        var guardCount = 0
        while !round.isFinished && guardCount < 60 {
            guardCount += 1
            round.draw(shantenCalculator: calc, rng: &rng)
            guard let fourteen = round.fourteen else { break }
            let eval = evaluator.evaluate(hand: fourteen)
            let choice = eval.bestTiles[0]
            let after = fourteen.removing(choice)
            let waits = calc.shanten(after) <= 0 ? eval.option(for: choice)!.ukeire : []
            round.discard(choice, isCorrect: true, shantenCalculator: calc, waitsIfTenpai: waits)
        }
        #expect(round.isFinished, "60巡回してもテンパイしなかった")
        #expect(calc.shanten(round.hand) <= 0)
        #expect(round.wasFastest, "最善だけを選んだのでノーミス")
        #expect(round.waits.isEmpty == false, "待ちが記録されている")
    }

    @Test("同じ種を与えれば同じ局になる")
    func isReproducible() {
        let (a, _) = newRound(seed: 1234)
        let (b, _) = newRound(seed: 1234)
        #expect(a.hand == b.hand)
    }
}

/// テスト用の乱数。SystemRandomNumberGenerator と違い、種を固定できる。
struct SystemlessRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// 聴牌してからツモれる確率。山から戻さずに引くので超幾何分布で数える。
struct DrawChanceTests {

    @Test("待ちが無ければ0、ツモらなければ0")
    func zeroCases() {
        #expect(DrawChance.probability(waits: 0, unseen: 90, draws: 10) == 0)
        #expect(DrawChance.probability(waits: 4, unseen: 90, draws: 0) == 0)
    }

    @Test("1回ツモは 待ち / 見えていない枚数 そのもの")
    func singleDraw() {
        let p = DrawChance.probability(waits: 4, unseen: 100, draws: 1)
        #expect(abs(p - 0.04) < 1e-9)
    }

    @Test("ツモる回数が増えれば確率は上がる")
    func increasesWithDraws() {
        var previous = 0.0
        for draws in 1...18 {
            let p = DrawChance.probability(waits: 4, unseen: 90, draws: draws)
            #expect(p > previous, "\(draws)巡で下がった")
            #expect(p <= 1)
            previous = p
        }
    }

    @Test("待ちが広いほど確率は高い")
    func increasesWithWaits() {
        let narrow = DrawChance.probability(waits: 2, unseen: 90, draws: 10)
        let wide = DrawChance.probability(waits: 8, unseen: 90, draws: 10)
        #expect(wide > narrow)
    }

    @Test("戻さずに引くので、独立に引くより少しだけ高く出る")
    func withoutReplacementIsHigher() {
        let exact = DrawChance.probability(waits: 4, unseen: 90, draws: 10)
        let naive = 1 - pow(1 - 4.0 / 90.0, 10)     // 毎回同じ確率で引く場合
        #expect(exact > naive)
        #expect(exact - naive < 0.03, "差はわずかなはず")
    }

    @Test("山を引き切っても1を超えない")
    func neverExceedsOne() {
        #expect(DrawChance.probability(waits: 4, unseen: 4, draws: 1) == 1)
        #expect(DrawChance.probability(waits: 3, unseen: 5, draws: 99) <= 1)
    }
}

/// 確率を出す区切りは、残りのツモ回数を超えてはいけない。
/// ここを固定の5巡・10巡・15巡にしていたため、
/// 10巡目に聴牌した局でも「15巡で55%」という起こりえない数字を出していた。
struct DrawHorizonTests {

    @Test("残り巡数を超える区切りは出さない")
    func checkpointsFitInsideTheHand() {
        for remaining in 0...18 {
            for point in DrawChance.checkpoints(remainingDraws: remaining) {
                #expect(point <= remaining, "残り\(remaining)巡で\(point)巡を出した")
                #expect(point > 0)
            }
        }
    }

    @Test("残りが少なければ区切りも減る")
    func fewerCheckpointsNearTheEnd() {
        #expect(DrawChance.checkpoints(remainingDraws: 0).isEmpty)
        #expect(DrawChance.checkpoints(remainingDraws: 2) == [2])
        #expect(DrawChance.checkpoints(remainingDraws: 5) == [3, 5])
        #expect(DrawChance.checkpoints(remainingDraws: 12) == [3, 6, 12])
    }

    @Test("巡目が進むほど残りは減る")
    func remainingShrinksWithTurns() {
        let calc = ShantenCalculator()
        var rng = SystemlessRandom(seed: 31)
        var round = Round(shantenCalculator: calc, rng: &rng)
        #expect(round.remainingDraws == Round.maxDrawsPerHand)
        round.draw(shantenCalculator: calc, rng: &rng)
        #expect(round.remainingDraws == Round.maxDrawsPerHand - 1)
    }

    @Test("残り8巡・待ち4枚なら3割ほど。15巡ぶんの数字より低い")
    func realisticNumbers() {
        let eight = DrawChance.probability(waits: 4, unseen: 85, draws: 8)
        let fifteen = DrawChance.probability(waits: 4, unseen: 85, draws: 15)
        #expect(abs(eight - 0.33) < 0.02)
        #expect(fifteen > eight + 0.15, "前は起こりえない15巡の数字を出していた")
    }
}
