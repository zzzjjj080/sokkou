import Foundation

/// あとで解き直すために取っておく局面。
///
/// 採点の結果は持たない。解き直すときにもう一度採点するので、
/// 判定のしかたを変えても古い局面がそのまま使える。
public struct ReviewPosition: Equatable, Sendable, Codable, Identifiable {
    /// 手牌13枚（ツモ牌を含まない）
    public let hand: [Int]
    /// ツモ牌
    public let drawn: Int
    /// そのとき自分が選んだ牌
    public let chosen: Int
    /// どんな形で外したか。**古い記録には入っていないので省略可**
    public let tag: WeaknessTag?

    public init(hand: [Int], drawn: Int, chosen: Int, tag: WeaknessTag? = nil) {
        self.hand = hand.sorted()
        self.drawn = drawn
        self.chosen = chosen
        self.tag = tag
    }

    /// 同じ14枚なら同じ局面とみなす。選んだ牌は区別に使わない
    public var id: String {
        (hand + [drawn]).sorted().map(String.init).joined(separator: ",")
    }

    public var handTiles: [Tile] { hand.compactMap(Tile.init(index:)) }
    public var drawnTile: Tile? { Tile(index: drawn) }
    public var chosenTile: Tile? { Tile(index: chosen) }
    /// 採点にかける14枚
    public var fourteen: TileCounts? {
        guard let drawnTile else { return nil }
        return TileCounts(handTiles).adding(drawnTile)
    }
}

/// 外した局面のたまり場。
///
/// 上限を超えたら**古いものから捨てる。** 直近の傾向を復習したいので、
/// 古い失敗より新しい失敗のほうが役に立つ。
public struct ReviewStore: Equatable, Sendable, Codable {
    public static let capacity = 100

    public private(set) var positions: [ReviewPosition]

    public init(positions: [ReviewPosition] = []) {
        self.positions = Array(positions.suffix(ReviewStore.capacity))
    }

    public var count: Int { positions.count }
    public var isEmpty: Bool { positions.isEmpty }

    /// 新しい順に取り出す
    public var newestFirst: [ReviewPosition] { positions.reversed() }

    /// 外した局面を覚える。同じ14枚はためない。
    public mutating func record(_ position: ReviewPosition) {
        positions.removeAll { $0.id == position.id }
        positions.append(position)
        if positions.count > ReviewStore.capacity {
            positions.removeFirst(positions.count - ReviewStore.capacity)
        }
    }

    public mutating func remove(id: String) {
        positions.removeAll { $0.id == id }
    }

    public mutating func removeAll() { positions.removeAll() }

    /// 形ごとの件数。分類の付いていない古い記録は数えない
    public var tagCounts: [WeaknessTag: Int] {
        positions.reduce(into: [:]) { counts, position in
            if let tag = position.tag { counts[tag, default: 0] += 1 }
        }
    }

    /// いちばん多く外している形。**同数なら表示順で先のもの**
    /// （出るたびに入れ替わると、見ている人が落ち着かないため）
    public var topTag: (tag: WeaknessTag, count: Int)? {
        let counts = tagCounts
        var best: (tag: WeaknessTag, count: Int)?
        for tag in WeaknessTag.displayOrder {
            guard let count = counts[tag] else { continue }
            if best == nil || count > best!.count { best = (tag, count) }
        }
        return best
    }

    /// 形で絞って新しい順に取り出す。nil ならすべて
    public func newestFirst(tag: WeaknessTag?) -> [ReviewPosition] {
        guard let tag else { return newestFirst }
        return newestFirst.filter { $0.tag == tag }
    }

    // MARK: - Codable（項目を足しても古い記録が読めるようにする）

    enum CodingKeys: String, CodingKey { case positions }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let saved = try container.decodeIfPresent([ReviewPosition].self, forKey: .positions) ?? []
        // 上限を後から減らしても壊れないよう、読み込み時に切り詰める
        positions = Array(saved.suffix(ReviewStore.capacity))
    }
}
