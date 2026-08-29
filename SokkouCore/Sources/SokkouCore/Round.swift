import Foundation

/// 1局の進行。配牌からテンパイまで。
///
/// UIに依存しないので、乱数を差し替えれば同じ手順を何度でも再現できる。
public struct Round {
    /// 手牌13枚（ツモ牌は含まない）
    public private(set) var hand: TileCounts
    public private(set) var drawn: Tile?
    /// 何巡目か。1から始まる
    public private(set) var turn: Int
    /// この局で最善を外した回数
    public private(set) var mistakes: Int
    /// テンパイして局が終わったか
    public private(set) var isFinished: Bool
    /// 終わったときの待ち
    public private(set) var waits: [UkeireTile]

    /// 山に残っている枚数（見えていない牌）
    private var wall: [Int]
    /// 直前に切った牌。次のツモでは引かせない
    private var lastDiscard: Tile?

    /// ミスなくテンパイしたか
    public var wasFastest: Bool { isFinished && mistakes == 0 }

    /// まだ見えていない牌の総数。ツモれる確率の分母に使う
    public var unseenTotal: Int { wall.reduce(0, +) }

    /// 待ちの合計枚数
    public var waitCount: Int { waits.reduce(0) { $0 + $1.count } }

    /// 配牌は3〜4向聴のものだけを使う。近すぎても遠すぎても練習にならない。
    public static let dealtShantenRange = 3...4

    /// - Parameter shantenRange: 配牌に使うシャンテン数の範囲。
    ///   既定は3〜4向聴。動作確認で聴牌までを短くしたいときだけ狭める。
    public init<G: RandomNumberGenerator>(
        shantenCalculator: ShantenCalculator,
        rng: inout G,
        shantenRange: ClosedRange<Int> = Round.dealtShantenRange
    ) {
        var dealt: TileCounts?
        for _ in 0..<400 {
            let candidate = Round.dealThirteen(rng: &rng)
            let sh = shantenCalculator.shanten(candidate)
            if shantenRange.contains(sh) { dealt = candidate; break }
        }
        // 400回引いて当たらないことはまずないが、その場合は最後の1つを使う
        // 初期化の途中で self を触るとクロージャが self を捕まえるので、
        // いったんローカルに置いてから代入する
        let dealtHand = dealt ?? Round.dealThirteen(rng: &rng)
        var remaining = [Int](repeating: Tile.copiesPerTile, count: Tile.kindCount)
        for i in 0..<Tile.kindCount { remaining[i] -= dealtHand.counts[i] }
        hand = dealtHand
        wall = remaining
        turn = 0
        mistakes = 0
        isFinished = false
        waits = []
        drawn = nil
        lastDiscard = nil
    }

    private static func dealThirteen<G: RandomNumberGenerator>(rng: inout G) -> TileCounts {
        var wall: [Tile] = []
        for tile in Tile.all { wall.append(contentsOf: repeatElement(tile, count: Tile.copiesPerTile)) }
        wall.shuffle(using: &rng)
        return TileCounts(Array(wall.prefix(13)))
    }

    // MARK: - ツモ

    /// ツモ牌は山から一様には引かない。
    /// 「シャンテンが進む牌」を4割で優先し、残りも同種±2以内の牌から選ぶ。
    /// 練習として手が進みやすいようにした意図的な偏りで、実戦の分布とは違う。
    public mutating func draw<G: RandomNumberGenerator>(
        shantenCalculator: ShantenCalculator, rng: inout G
    ) {
        precondition(!isFinished, "終わった局ではツモれない")
        precondition(drawn == nil, "ツモ牌を持ったままツモれない")

        let current = shantenCalculator.shanten(hand)
        var advancing: [Tile] = [], connected: [Tile] = [], rest: [Tile] = []
        for tile in Tile.all where wall[tile.index] > 0 {
            if tile == lastDiscard { continue }        // 今切ったばかりの牌は引かせない
            var next = hand
            next.add(tile)
            if shantenCalculator.shanten(next) < current {
                advancing.append(tile)
            } else if hand.isConnected(to: tile) {
                connected.append(tile)
            } else {
                rest.append(tile)
            }
        }
        let pool: [Tile]
        if !advancing.isEmpty && !connected.isEmpty {
            pool = Double.random(in: 0..<1, using: &rng) < 0.4 ? advancing : connected
        } else if !advancing.isEmpty {
            pool = advancing
        } else if !connected.isEmpty {
            pool = connected
        } else {
            pool = rest
        }
        guard !pool.isEmpty else { return }

        // 山の残り枚数で重み付けする
        let total = pool.reduce(0) { $0 + wall[$1.index] }
        var point = Int.random(in: 0..<total, using: &rng)
        var picked = pool[pool.count - 1]
        for tile in pool {
            point -= wall[tile.index]
            if point < 0 { picked = tile; break }
        }

        drawn = picked
        wall[picked.index] -= 1
        lastDiscard = nil                              // 除外は直後の1回だけ
        turn += 1
    }

    /// ツモ牌を含む14枚
    public var fourteen: TileCounts? {
        guard let drawn else { return nil }
        return hand.adding(drawn)
    }

    // MARK: - 打牌

    /// 1枚切る。切ったあとテンパイなら局が終わる。
    /// `isCorrect` は採点結果を呼び出し側から渡す（Coreの中で二重に採点しないため）。
    public mutating func discard(_ tile: Tile, isCorrect: Bool,
                                 shantenCalculator: ShantenCalculator,
                                 waitsIfTenpai: [UkeireTile]) {
        precondition(!isFinished, "終わった局では切れない")
        guard var fourteen else { preconditionFailure("ツモ牌がない") }
        precondition(fourteen[tile] > 0, "持っていない牌は切れない")

        if !isCorrect { mistakes += 1 }
        fourteen.remove(tile)
        hand = fourteen
        drawn = nil
        lastDiscard = tile

        if shantenCalculator.shanten(hand) <= 0 {
            isFinished = true
            waits = waitsIfTenpai
        }
    }
}

extension TileCounts {
    /// 同じ色で±2以内に手牌があるか。将来ブロックになりうる牌かの目安。
    public func isConnected(to tile: Tile) -> Bool {
        let suit = tile.index / 9, number = tile.index % 9
        for n in max(0, number - 2)...min(8, number + 2) where counts[suit * 9 + n] > 0 {
            return true
        }
        return false
    }
}
