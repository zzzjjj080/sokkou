import Foundation
import Testing
@testable import SokkouCore

/// シャンテン計算はこのアプリの土台。ここが狂うと採点も表示も全部意味を失う。
/// 表を引く実装は速いぶん読みにくいので、**素朴な実装を別に書いて突き合わせる。**
struct ShantenTests {

    let calc = ShantenCalculator()

    // MARK: - 素朴な参照実装（速度を考えず、読んで正しいと分かる形で書く）

    /// 1色9枚を面子分解して (面子数, 搭子数) の候補を全部返す
    static func decompose(_ c9: inout [Int], _ i: Int = 0) -> Set<Pair> {
        if i >= 9 { return [Pair(melds: 0, partials: 0)] }
        if c9[i] == 0 { return decompose(&c9, i + 1) }

        var results = Set<Pair>()
        if c9[i] >= 3 {
            c9[i] -= 3
            results.formUnion(decompose(&c9, i).map { $0.plusMeld })
            c9[i] += 3
        }
        if c9[i] >= 2 {
            c9[i] -= 2
            results.formUnion(decompose(&c9, i).map { $0.plusPartial })
            c9[i] += 2
        }
        if i + 2 < 9, c9[i] > 0, c9[i + 1] > 0, c9[i + 2] > 0 {
            c9[i] -= 1; c9[i + 1] -= 1; c9[i + 2] -= 1
            results.formUnion(decompose(&c9, i).map { $0.plusMeld })
            c9[i] += 1; c9[i + 1] += 1; c9[i + 2] += 1
        }
        if i + 1 < 9, c9[i] > 0, c9[i + 1] > 0 {
            c9[i] -= 1; c9[i + 1] -= 1
            results.formUnion(decompose(&c9, i).map { $0.plusPartial })
            c9[i] += 1; c9[i + 1] += 1
        }
        if i + 2 < 9, c9[i] > 0, c9[i + 2] > 0 {
            c9[i] -= 1; c9[i + 2] -= 1
            results.formUnion(decompose(&c9, i).map { $0.plusPartial })
            c9[i] += 1; c9[i + 2] += 1
        }
        c9[i] -= 1
        results.formUnion(decompose(&c9, i))
        c9[i] += 1
        return results
    }

    struct Pair: Hashable {
        let melds: Int, partials: Int
        var plusMeld: Pair { Pair(melds: melds + 1, partials: partials) }
        var plusPartial: Pair { Pair(melds: melds, partials: partials + 1) }
    }

    static func bestScore(_ counts: [Int]) -> Int {
        var man = Array(counts[0..<9]), pin = Array(counts[9..<18]), sou = Array(counts[18..<27])
        let a = decompose(&man), b = decompose(&pin), c = decompose(&sou)
        var best = 0
        for x in a { for y in b { for z in c {
            let melds = min(x.melds + y.melds + z.melds, 4)
            let partials = min(x.partials + y.partials + z.partials, 4 - melds)
            best = max(best, 2 * melds + partials)
        }}}
        return best
    }

    /// 参照実装のシャンテン数
    static func referenceShanten(_ hand: TileCounts) -> Int {
        var counts = hand.counts
        var best = 8 - bestScore(counts)
        for i in 0..<Tile.kindCount where counts[i] >= 2 {
            counts[i] -= 2
            best = min(best, 8 - bestScore(counts) - 1)
            counts[i] += 2
        }
        return best
    }

    // MARK: - 決まった手で確かめる

    /// "123m456p11s" のような書き方で手牌を作る
    static func hand(_ text: String) -> TileCounts {
        var counts = TileCounts()
        var digits: [Int] = []
        for ch in text {
            if let d = ch.wholeNumberValue, (1...9).contains(d) {
                digits.append(d)
            } else {
                let suit: Suit? = switch ch {
                case "m": .man
                case "p": .pin
                case "s": .sou
                default: nil
                }
                guard let suit else { continue }
                for d in digits { counts.add(Tile(suit, d)) }
                digits = []
            }
        }
        return counts
    }

    @Test("和了形は-1、聴牌は0")
    func knownComplete() {
        #expect(calc.shanten(Self.hand("123m456m789m123p11p")) == -1)  // 14枚の和了形
        #expect(calc.shanten(Self.hand("123m456m789m123p1p")) == 0)    // 13枚の聴牌
        #expect(calc.shanten(Self.hand("111m222m333m444m1p")) == 0)
        #expect(calc.shanten(Self.hand("123456789m123p1s")) == 0)
        #expect(calc.shanten(Self.hand("123m456m789m12p33s")) == 0)
    }

    @Test("バラバラの手はシャンテン数が大きい")
    func knownScattered() {
        // 123m 456m が面子、11m 雀頭、79m の搭子 → 8 - 2*2 - 1 - 1 = 2向聴
        #expect(calc.shanten(Self.hand("19m19p19s1234567m")) == 3)
    }

    @Test("七対子は数えない")
    func chiitoitsuIsIgnored() {
        // 7対子ちょうど。七対子を見るなら和了だが、面子手としては遠い
        let sevenPairs = Self.hand("1133557799m1133p")
        #expect(calc.shanten(sevenPairs) == Self.referenceShanten(sevenPairs))
        #expect(calc.shanten(sevenPairs) > 0)
    }

    @Test("検証に使った局面のシャンテン数")
    func positionsFromVerification() {
        // 3萬7萬7萬8萬 1筒3筒4筒7筒 1索2索4索6索8索9索 から3萬を切った13枚
        #expect(calc.shanten(Self.hand("778m1347p124689s")) == 3)
        // 同じ手から7萬を切ると雀頭が無くなって1つ戻る
        #expect(calc.shanten(Self.hand("378m1347p124689s")) == 4)
    }

    // MARK: - 素朴な実装との突き合わせ

    @Test("乱数の手牌で参照実装と一致する")
    func matchesReferenceOnRandomHands() {
        var rng = SeededRandom(seed: 20260824)
        for size in [1, 2, 5, 7, 10, 13, 14] {
            for _ in 0..<400 {
                let hand = Self.randomHand(size: size, rng: &rng)
                #expect(calc.shanten(hand) == Self.referenceShanten(hand),
                        "不一致: \(hand.tiles.map(\.description).joined())")
            }
        }
    }

    static func randomHand(size: Int, rng: inout SeededRandom) -> TileCounts {
        var wall: [Tile] = []
        for t in Tile.all { wall.append(contentsOf: repeatElement(t, count: Tile.copiesPerTile)) }
        for i in stride(from: wall.count - 1, to: 0, by: -1) {
            let j = rng.next(upperBound: i + 1)
            wall.swapAt(i, j)
        }
        return TileCounts(Array(wall.prefix(size)))
    }
}

/// テストを毎回同じ結果にするための乱数
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next(upperBound: Int) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Int((state >> 33) % UInt64(upperBound))
    }
}
