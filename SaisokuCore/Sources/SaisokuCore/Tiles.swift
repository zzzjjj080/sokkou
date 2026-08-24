import Foundation

/// 萬子・筒子・索子の3種類だけ。字牌は扱わない。
public enum Suit: Int, CaseIterable, Sendable, Codable {
    case man = 0, pin = 1, sou = 2

    public var label: String {
        switch self {
        case .man: "萬"
        case .pin: "筒"
        case .sou: "索"
        }
    }
}

/// 牌1種。0〜26の範囲外は作れない。
public struct Tile: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public let index: Int

    /// 範囲外なら nil。外から来た数値はこちらを通す。
    public init?(index: Int) {
        guard (0..<Tile.kindCount).contains(index) else { return nil }
        self.index = index
    }

    /// コード中で牌を書くとき用。number は 1...9。
    public init(_ suit: Suit, _ number: Int) {
        precondition((1...9).contains(number), "牌の数字は1〜9")
        self.index = suit.rawValue * 9 + number - 1
    }

    public static let kindCount = 27
    public static let copiesPerTile = 4

    public var suit: Suit { Suit(rawValue: index / 9)! }
    public var number: Int { index % 9 + 1 }
    public var isTerminal: Bool { number == 1 || number == 9 }

    public var description: String { "\(number)\(suit.label)" }
    public static func < (a: Tile, b: Tile) -> Bool { a.index < b.index }

    public static let all: [Tile] = (0..<kindCount).map { Tile(index: $0)! }
}

/// 手牌を「種類ごとの枚数」で持つ。並び順に意味を持たせない。
public struct TileCounts: Hashable, Sendable {
    public private(set) var counts: [Int]

    public init() { counts = [Int](repeating: 0, count: Tile.kindCount) }

    public init(_ tiles: [Tile]) {
        self.init()
        for t in tiles { counts[t.index] += 1 }
    }

    public subscript(tile: Tile) -> Int {
        get { counts[tile.index] }
        set {
            precondition((0...Tile.copiesPerTile).contains(newValue), "1種は0〜4枚")
            counts[tile.index] = newValue
        }
    }

    public subscript(index: Int) -> Int { counts[index] }

    public var total: Int { counts.reduce(0, +) }

    /// 山に残っている枚数の見積り。手牌に見えている分を4枚から引くだけ。
    /// 受け入れ枚数の数え方と揃えてある。
    public func unseen(of tile: Tile) -> Int { Tile.copiesPerTile - counts[tile.index] }

    public mutating func add(_ tile: Tile) {
        precondition(counts[tile.index] < Tile.copiesPerTile, "5枚目は持てない")
        counts[tile.index] += 1
    }

    public mutating func remove(_ tile: Tile) {
        precondition(counts[tile.index] > 0, "持っていない牌は切れない")
        counts[tile.index] -= 1
    }

    public func removing(_ tile: Tile) -> TileCounts {
        var c = self
        c.remove(tile)
        return c
    }

    public func adding(_ tile: Tile) -> TileCounts {
        var c = self
        c.add(tile)
        return c
    }

    /// 持っている牌の種類（重複なし・昇順）
    public var kinds: [Tile] {
        (0..<Tile.kindCount).compactMap { counts[$0] > 0 ? Tile(index: $0) : nil }
    }

    /// 表示や並べ替え用に1枚ずつ展開する
    public var tiles: [Tile] {
        var out: [Tile] = []
        for i in 0..<Tile.kindCount where counts[i] > 0 {
            out.append(contentsOf: repeatElement(Tile(index: i)!, count: counts[i]))
        }
        return out
    }
}
