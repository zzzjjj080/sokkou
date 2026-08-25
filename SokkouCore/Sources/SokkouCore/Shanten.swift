import Foundation

/// 面子手(4面子1雀頭)のシャンテン数を数える。**七対子と国士は見ない。**
///
/// 数牌9枚の並びを5進数の整数にして、面子分解の結果を表に持つ。
/// 表が持つのは「面子をm個作ったときの搭子数の最大」5個だけ。
/// 文字列キーも辞書も通らないので、初めて見る手でも速い。
///
/// 表は約10MB。1インスタンスを使い回すこと。
public final class ShantenCalculator {
    /// 5^9。数牌9種それぞれ0〜4枚の並びを1つの整数で表す
    static let suitPatternCount = 1_953_125
    private static let unknown: Int8 = -2      // まだ計算していない
    private static let impossible: Int8 = -1   // その面子数は作れない

    private var profile: [Int8]

    public init() {
        profile = [Int8](repeating: Self.unknown, count: Self.suitPatternCount * 5)
    }

    /// 面子分解して「面子m個のときの搭子数の最大」を求める
    private func fillProfile(_ c9: inout [Int], base: Int) {
        var best = [Int8](repeating: Self.impossible, count: 5)

        func rec(_ i: Int, _ m: Int, _ d: Int) {
            if i >= 9 {
                let slot = min(m, 4)
                if Int8(d) > best[slot] { best[slot] = Int8(d) }
                return
            }
            if c9[i] == 0 { rec(i + 1, m, d); return }
            if c9[i] >= 3 { c9[i] -= 3; rec(i, m + 1, d); c9[i] += 3 }          // 刻子
            if c9[i] >= 2 { c9[i] -= 2; rec(i, m, d + 1); c9[i] += 2 }          // 対子
            if i + 2 < 9, c9[i] > 0, c9[i + 1] > 0, c9[i + 2] > 0 {             // 順子
                c9[i] -= 1; c9[i + 1] -= 1; c9[i + 2] -= 1
                rec(i, m + 1, d)
                c9[i] += 1; c9[i + 1] += 1; c9[i + 2] += 1
            }
            if i + 1 < 9, c9[i] > 0, c9[i + 1] > 0 {                            // 両面・辺張
                c9[i] -= 1; c9[i + 1] -= 1
                rec(i, m, d + 1)
                c9[i] += 1; c9[i + 1] += 1
            }
            if i + 2 < 9, c9[i] > 0, c9[i + 2] > 0 {                            // 嵌張
                c9[i] -= 1; c9[i + 2] -= 1
                rec(i, m, d + 1)
                c9[i] += 1; c9[i + 2] += 1
            }
            c9[i] -= 1; rec(i, m, d); c9[i] += 1                                // 使わずに進める
        }
        rec(0, 0, 0)
        for m in 0..<5 { profile[base + m] = best[m] }
    }

    /// その色の並びに対応する表の位置。未計算ならその場で埋める。
    private func profileBase(_ counts: [Int], suitOffset: Int) -> Int {
        var index = 0, place = 1
        for i in 0..<9 {
            index += counts[suitOffset + i] * place
            place *= 5
        }
        let base = index * 5
        if profile[base] == Self.unknown {
            var c9 = Array(counts[suitOffset..<(suitOffset + 9)])
            fillProfile(&c9, base: base)
        }
        return base
    }

    /// 雀頭を抜かない状態での「2×面子数 + 搭子数」の最大
    private func bestScore(_ counts: [Int]) -> Int {
        let a = profileBase(counts, suitOffset: 0)
        let b = profileBase(counts, suitOffset: 9)
        let c = profileBase(counts, suitOffset: 18)

        var merged = [Int8](repeating: Self.impossible, count: 5)
        for m1 in 0..<5 {
            let d1 = profile[a + m1]; if d1 < 0 { continue }
            for m2 in 0..<(5 - m1) {
                let d2 = profile[b + m2]; if d2 < 0 { continue }
                for m3 in 0..<(5 - m1 - m2) {
                    let d3 = profile[c + m3]; if d3 < 0 { continue }
                    let melds = m1 + m2 + m3
                    let partials = Int8(d1 + d2 + d3)
                    if partials > merged[melds] { merged[melds] = partials }
                }
            }
        }

        var best = 0
        for melds in 0..<5 {
            let partials = merged[melds]; if partials < 0 { continue }
            let effMelds = min(melds, 4)
            let effPartials = min(Int(partials), 4 - effMelds)
            best = max(best, 2 * effMelds + effPartials)
        }
        return best
    }

    /// シャンテン数。0で聴牌、-1で和了形。
    public func shanten(_ hand: TileCounts) -> Int { shanten(counts: hand.counts) }

    /// 種類ごとの枚数を直に受け取る版。探索の内側から呼ばれるのでこちらが本体。
    /// TileCounts を組み立て直すと、1回あたりの確保と検査で桁違いに遅くなる。
    public func shanten(counts input: [Int]) -> Int {
        var counts = input
        var best = 8 - bestScore(counts)
        // 雀頭を1つ決め打ちする分岐も見る
        for i in 0..<Tile.kindCount where counts[i] >= 2 {
            counts[i] -= 2
            let withPair = 8 - bestScore(counts) - 1
            counts[i] += 2
            if withPair < best { best = withPair }
        }
        return best
    }

    /// 聴牌しているか（13枚の手に対して使う）
    public func isTenpai(_ hand: TileCounts) -> Bool { shanten(hand) <= 0 }
}
