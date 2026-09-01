import Foundation

/// 受け入れの内訳1件
public struct UkeireTile: Equatable, Sendable {
    public let tile: Tile
    /// 山に残っている枚数（4 − 手牌にある枚数）
    public let count: Int
}

/// 1つの打牌に対する評価
public struct DiscardOption: Equatable, Sendable {
    public let tile: Tile
    /// 切ったあとの13枚のシャンテン数
    public let shanten: Int
    public let ukeire: [UkeireTile]
    /// 引いてもシャンテンは進まないが、受け入れが広がる牌の枚数
    public let improvement: Int
    /// 最善を100点とした点数。採点対象外（シャンテン戻し）なら nil
    public let score: Int?
    /// この局面で到達できる最小シャンテンより後退しているか
    public var isShantenBack: Bool { score == nil }

    public var ukeireCount: Int { ukeire.reduce(0) { $0 + $1.count } }
    public var ukeireKinds: Int { ukeire.count }
}

/// 14枚に対する評価一式
public struct Evaluation: Equatable, Sendable {
    /// 点数の高い順。採点対象外の打牌は末尾にまとめる
    public let options: [DiscardOption]
    /// 最善（金枠）。誤差の範囲に収まる候補が複数あれば全部入る
    public let bestTiles: [Tile]
    /// 正解扱い（緑枠）。bestTiles を含む
    public let correctTiles: [Tile]
    public let minShanten: Int
    /// 何巡先まで読んだか
    public let lookahead: Int
    /// 最善を1枚に絞れなかったか
    public let isTiedTop: Bool

    public func option(for tile: Tile) -> DiscardOption? {
        options.first { $0.tile == tile }
    }
    public func isCorrect(_ tile: Tile) -> Bool { correctTiles.contains(tile) }
    public func isBest(_ tile: Tile) -> Bool { bestTiles.contains(tile) }
}

/// 打牌を採点する。
///
/// 判定は2段構え。
///  1. シャンテンを戻す打牌は採点の対象にしない
///  2. 残った候補を「あとN巡で聴牌できるか」の計算で並べ、最善を100点として点数化する
///
/// 1の理由は計算の限界。近似なしのモンテカルロと突き合わせると、この計算は
/// シャンテン数をまたぐ比較を外す（戻しを最善に選んだ20局面のうち15件で逆、
/// 平均1.60ポイント損）。判断できないものを勧めない側に倒している。
/// 同じシャンテン内であれば受け入れ枚数より優れている（30局面で23勝7敗、平均1.07ポイント）。
public final class Evaluator {
    /// 見えていない牌の総数。108 − 手牌13枚。受け入れ枚数の数え方と揃えてある
    static let unseen = 95.0
    /// 手を展開して枝を伸ばす段数
    static let expandLevels = 3
    /// これ以上の点数は順位を付けない（誤差の範囲）
    public static let tieScore = 98
    /// これ以上の点数を正解として先へ進める
    public static let okScore = 90

    private let shantenCalc: ShantenCalculator

    private struct ProbKey: Hashable { let hand: UInt64; let depth: Int8; let budget: Int8 }
    private struct Move { let weight: Int; let next: [Int] }
    private struct Steps { let shanten: Int; let moves: [Move]; let liveWeight: Int }

    private var stepCache: [UInt64: Steps] = [:]
    private var policyCache: [UInt64: Int] = [:]
    private var probCache: [ProbKey: Double] = [:]
    private var ukeireCache: [UInt64: Int] = [:]

    public init(shantenCalculator: ShantenCalculator = ShantenCalculator()) {
        self.shantenCalc = shantenCalculator
    }

    /// キャッシュが増えすぎたら捨てる。捨てても計算し直せるだけで結果は変わらない。
    public func trimCachesIfNeeded() {
        if probCache.count > 150_000 { probCache.removeAll(keepingCapacity: true) }
        if stepCache.count > 60_000 {
            stepCache.removeAll(keepingCapacity: true)
            policyCache.removeAll(keepingCapacity: true)
            ukeireCache.removeAll(keepingCapacity: true)
        }
    }

    // MARK: - 下ごしらえ

    /// 手牌を1つの整数にする。辞書の鍵にするため。
    private func key(_ counts: [Int]) -> UInt64 {
        var parts: [UInt64] = [0, 0, 0]
        for suit in 0..<3 {
            var index: UInt64 = 0, place: UInt64 = 1
            for i in 0..<9 {
                index += UInt64(counts[suit * 9 + i]) * place
                place *= 5
            }
            parts[suit] = index
        }
        let span = UInt64(ShantenCalculator.suitPatternCount)
        return parts[0] &+ parts[1] &* span &+ parts[2] &* span &* span
    }

    private func shantenOf(_ counts: [Int]) -> Int { shantenCalc.shanten(counts: counts) }

    /// 同じ色で±2以内に手牌があるか。孤立牌を引いても面子手のシャンテンは進まないので、
    /// そこを調べずに済ませるための判定。七対子を見ないので近似ではなく厳密。
    private func isConnected(_ tile: Int, _ counts: [Int]) -> Bool {
        let suit = tile / 9, number = tile % 9
        for n in max(0, number - 2)...min(8, number + 2) where counts[suit * 9 + n] > 0 {
            return true
        }
        return false
    }

    private func drawCandidates(_ counts: [Int]) -> [Int] {
        var list: [Int] = []
        for t in 0..<Tile.kindCount where counts[t] < Tile.copiesPerTile && isConnected(t, counts) {
            list.append(t)
        }
        return list
    }

    /// シャンテンが進む牌の枚数
    private func ukeireCount(_ counts: inout [Int], shanten sh: Int) -> Int {
        var total = 0
        for t in drawCandidates(counts) {
            let remaining = Tile.copiesPerTile - counts[t]
            counts[t] += 1
            if shantenOf(counts) < sh { total += remaining }
            counts[t] -= 1
        }
        return total
    }

    private func cachedUkeire(_ counts: [Int], shanten sh: Int) -> Int {
        let k = key(counts)
        if let hit = ukeireCache[k] { return hit }
        var c = counts
        let value = ukeireCount(&c, shanten: sh)
        ukeireCache[k] = value
        return value
    }

    // MARK: - 2打目以降の打牌方針

    /// シャンテン最小、同じなら受け入れ最大、なお同じなら若い牌。
    /// 比べたいのは最初の1打なので、その先は同じ方針で揃える。
    private func policyDiscard(_ counts: inout [Int]) -> Int {
        let k = key(counts)
        if let hit = policyCache[k] { return hit }

        // メソッド名 shantenOf を隠さないよう別名にする(引き継ぎ書4-15の名前の衝突)
        var afterDiscard = [Int](repeating: 99, count: Tile.kindCount)
        var minShanten = 99
        for t in 0..<Tile.kindCount where counts[t] > 0 {
            counts[t] -= 1
            let sh = shantenOf(counts)
            counts[t] += 1
            afterDiscard[t] = sh
            minShanten = min(minShanten, sh)
        }
        var pick = -1, bestUkeire = -1
        for t in 0..<Tile.kindCount where afterDiscard[t] == minShanten {
            counts[t] -= 1
            let uk = ukeireCount(&counts, shanten: minShanten)
            counts[t] += 1
            if uk > bestUkeire { bestUkeire = uk; pick = t }
        }
        policyCache[k] = pick
        return pick
    }

    // MARK: - 探索

    private func steps(_ counts: inout [Int]) -> Steps {
        let k = key(counts)
        if let hit = stepCache[k] { return hit }

        let sh = shantenOf(counts)
        var moves: [Move] = []
        var liveWeight = 0
        if sh > 0 {
            for t in drawCandidates(counts) {
                let remaining = Tile.copiesPerTile - counts[t]
                counts[t] += 1
                if shantenOf(counts) < sh {
                    let drop = policyDiscard(&counts)
                    counts[drop] -= 1
                    moves.append(Move(weight: remaining, next: counts))
                    counts[drop] += 1
                    liveWeight += remaining
                }
                counts[t] -= 1
            }
        }
        let result = Steps(shanten: sh, moves: moves, liveWeight: liveWeight)
        stepCache[k] = result
        return result
    }

    /// 展開を打ち切った先の見積り。1回のツモで進む確率を固定して、
    /// d回のうちsh回以上進む確率（二項分布の裾）を出す。
    private func tailProbability(shanten sh: Int, ukeire: Int, draws d: Int) -> Double {
        if sh <= 0 { return 1 }
        if d < sh { return 0 }
        let p = Double(ukeire) / Self.unseen
        if p <= 0 { return 0 }
        var cumulative = 0.0
        var binomial = 1.0
        for i in 0..<sh {
            cumulative += binomial * pow(p, Double(i)) * pow(1 - p, Double(d - i))
            binomial = binomial * Double(d - i) / Double(i + 1)
        }
        return max(0, 1 - cumulative)
    }

    /// あとd回ツモるあいだに聴牌できる確率。
    /// 枝を伸ばすのはシャンテンが進むツモだけで、手替わり・改良は数えない。
    private func tenpaiProbability(_ counts: inout [Int], draws d: Int, budget: Int) -> Double {
        let sh = shantenOf(counts)
        if sh <= 0 { return 1 }
        if d <= 0 { return 0 }
        if sh == 1 {
            // 1向聴では「進むツモ = 聴牌」で打牌の選択が要らないので閉じた式になる。
            // 探索の最下層はここが大半を占めるので、この近道が速度をほぼ決めている。
            let uk = cachedUkeire(counts, shanten: 1)
            return 1 - pow(1 - Double(uk) / Self.unseen, Double(d))
        }
        if budget <= 0 {
            return tailProbability(shanten: sh, ukeire: cachedUkeire(counts, shanten: sh), draws: d)
        }
        let cacheKey = ProbKey(hand: key(counts), depth: Int8(d), budget: Int8(budget))
        if let hit = probCache[cacheKey] { return hit }

        let st = steps(&counts)
        var total = 0.0
        for move in st.moves {
            var next = move.next
            total += Double(move.weight) / Self.unseen
                * tenpaiProbability(&next, draws: d - 1, budget: budget - 1)
        }
        total += (Self.unseen - Double(st.liveWeight)) / Self.unseen
            * tenpaiProbability(&counts, draws: d - 1, budget: budget)
        probCache[cacheKey] = total
        return total
    }

    /// 何巡先まで読むか。浅すぎると全部0、深すぎると全部100に張り付いて差が消える。
    static func lookahead(forShanten sh: Int) -> Int { max(2, min(12, sh * 2 + 2)) }

    // MARK: - 伸びしろ

    /// 引いてもシャンテンは進まないが、1枚切ったあとの受け入れが今より広がる牌。
    /// 探索が改良を数えないので、点数が同じになった打牌をここで分ける。
    /// 孤立牌を引いて別の孤立牌と入れ替える形も改良なので、27種すべてを見る。
    private func improvement(_ counts: inout [Int]) -> (count: Int, gain: Int) {
        let sh = shantenOf(counts)
        if sh <= 0 { return (0, 0) }
        let base = ukeireCount(&counts, shanten: sh)
        var count = 0, gain = 0
        for t in 0..<Tile.kindCount {
            let remaining = Tile.copiesPerTile - counts[t]
            if remaining <= 0 { continue }
            counts[t] += 1
            if shantenOf(counts) == sh {
                let drop = policyDiscard(&counts)
                counts[drop] -= 1
                let after = ukeireCount(&counts, shanten: sh)
                counts[drop] += 1
                if after > base {
                    count += remaining
                    gain += remaining * (after - base)
                }
            }
            counts[t] -= 1
        }
        return (count, gain)
    }

    // MARK: - 採点

    /// 14枚を採点する。
    public func evaluate(hand: TileCounts) -> Evaluation {
        precondition(hand.total == 14, "採点するのは14枚の手牌")
        let counts = hand.counts

        // まず全候補のシャンテン数と受け入れを出す
        struct Row {
            let tile: Tile
            var c13: [Int]
            let shanten: Int
            let ukeire: [UkeireTile]
            var probability: Double = 0
            var improvement: Int = 0
        }
        var rows: [Row] = []
        for tile in hand.kinds {
            var c13 = counts
            c13[tile.index] -= 1
            let sh = shantenOf(c13)
            var list: [UkeireTile] = []
            for t in drawCandidates(c13) {
                let remaining = Tile.copiesPerTile - c13[t]
                c13[t] += 1
                let advances = shantenOf(c13) < sh
                c13[t] -= 1
                if advances { list.append(UkeireTile(tile: Tile(index: t)!, count: remaining)) }
            }
            rows.append(Row(tile: tile, c13: c13, shanten: sh, ukeire: list))
        }

        let minShanten = rows.map(\.shanten).min()!
        let depth = Self.lookahead(forShanten: minShanten)

        // 採点するのはシャンテンを戻さない打牌だけ
        // 採点対象外の打牌には伸びしろも点数も要らないので計算しない
        for i in rows.indices where rows[i].shanten == minShanten {
            rows[i].improvement = improvement(&rows[i].c13).count
            rows[i].probability = tenpaiProbability(&rows[i].c13, draws: depth, budget: Self.expandLevels)
        }

        let pool = rows.filter { $0.shanten == minShanten }
        let bestProbability = pool.map(\.probability).max() ?? 0

        func points(_ p: Double) -> Int {
            guard bestProbability > 0 else { return 100 }   // 差が付かない局面では横並びにする
            return Int((p / bestProbability * 100).rounded())
        }

        // 完全同点の候補と、誤差の範囲に収まる候補
        let exact = pool.filter { $0.probability >= bestProbability - 1e-12 }
        let near = pool.filter { points($0.probability) >= Self.tieScore }
            .sorted { $0.probability > $1.probability }

        var bestRows: [Row]
        var isTiedTop: Bool
        if near.count == exact.count {
            // 差がまったく無い候補どうし。残した牌の伸びしろで分ける
            var candidates = exact
            if candidates.count > 1 {
                let maxCount = candidates.map(\.improvement).max()!
                candidates = candidates.filter { $0.improvement == maxCount }
            }
            bestRows = candidates
            isTiedTop = false
        } else {
            // 誤差の範囲に別の候補がいる。この幅では順位が当てにならないので絞らない
            bestRows = near
            isTiedTop = true
        }

        let correct = pool.filter { points($0.probability) >= Self.okScore }

        // **100点は最善だけに出す。**
        //
        // 素点のままだと2つのずれが出る。
        // ・完全同点を「残した牌の伸びしろ」で絞ったとき、負けた側も四捨五入で100になる
        // ・逆に同格が並ぶ局面では、最善なのに98や99と出る
        // どちらも「100点＝金色＝最善」を崩し、画面を見た人が理由を探すことになる。
        // 最善はそろって100点、それ以外は最大99点にそろえる。
        let bestTileSet = Set(bestRows.map(\.tile))

        func option(_ r: Row) -> DiscardOption {
            let score: Int?
            if r.shanten != minShanten {
                score = nil
            } else if bestTileSet.contains(r.tile) {
                score = 100
            } else {
                score = min(points(r.probability), 99)
            }
            return DiscardOption(
                tile: r.tile,
                shanten: r.shanten,
                ukeire: r.ukeire,
                improvement: r.improvement,
                score: score
            )
        }
        // 採点対象を点数順に、戻しは下へまとめる。
        // **確率順ではなく点数順に並べる。** 完全同点を伸びしろで分けたとき、
        // 確率だけで並べると99点の牌が100点より前に来てしまう
        let scored = pool.map(option).sorted {
            ($0.score ?? 0, $0.ukeireCount) > ($1.score ?? 0, $1.ukeireCount)
        }
        let back = rows.filter { $0.shanten > minShanten }
            .sorted { ($0.shanten, -$0.ukeire.reduce(0) { $0 + $1.count })
                    < ($1.shanten, -$1.ukeire.reduce(0) { $0 + $1.count }) }
            .map(option)

        return Evaluation(
            options: scored + back,
            bestTiles: bestRows.map(\.tile),
            correctTiles: correct.map(\.tile),
            minShanten: minShanten,
            lookahead: depth,
            isTiedTop: isTiedTop
        )
    }
}
