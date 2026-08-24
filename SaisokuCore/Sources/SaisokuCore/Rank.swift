import Foundation

/// 称号とレベル。「速攻雀士 Lv3」のように人につける名前で表す。
///
/// 上がる条件は**最速聴牌の累計回数**だけ。割合は使わない。
/// 打った局数が増えるほど不利になる指標だと、気軽に打てなくなるため。
public struct Rank: Equatable, Sendable, Codable {
    public let title: String
    public let level: Int
    /// この段位に上がるのに必要だった累計回数
    public let requirement: Int

    public var display: String { "\(title) Lv\(level)" }
}

public enum RankLadder {
    /// 称号ごとの、Lv1〜Lv5に必要な累計回数。
    /// 序盤は数局で上がり、後半はゆっくり伸びるようにしてある。
    public static let table: [(title: String, steps: [Int])] = [
        ("見習い雀士", [1, 3, 6, 10, 15]),
        ("手なり雀士", [20, 25, 30, 35, 40]),
        ("早見え雀士", [50, 60, 70, 80, 90]),
        ("一直線雀士", [105, 120, 135, 150, 165]),
        ("速攻雀士",   [185, 205, 225, 245, 265]),
        ("疾風雀士",   [290, 315, 340, 365, 390]),
        ("神速雀士",   [420, 450, 480, 510, 540]),
    ]

    /// 表を「必要回数の昇順」に平らへ並べたもの
    public static let all: [Rank] = table.flatMap { entry in
        entry.steps.enumerated().map { i, need in
            Rank(title: entry.title, level: i + 1, requirement: need)
        }
    }

    /// いまの段位。1回も最速聴牌していなければ nil。
    public static func rank(forFastestCount count: Int) -> Rank? {
        all.last { count >= $0.requirement }
    }

    /// 次の段位と、それまでの残り回数。最高位に達していれば nil。
    public static func next(forFastestCount count: Int) -> (rank: Rank, remaining: Int)? {
        guard let next = all.first(where: { count < $0.requirement }) else { return nil }
        return (next, next.requirement - count)
    }

    public static var top: Rank { all[all.count - 1] }
}
