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
    /// 称号ごとの、Lv1〜Lv10に必要な累計回数。
    ///
    /// 決めた条件は3つ。
    ///   ・7称号 × 10レベル = 70段
    ///   ・61段目(神速雀士 Lv1)でちょうど1000回
    ///   ・70段目(神速雀士 Lv10)でちょうど10000回
    /// 称号ごとの担当範囲を先に置き、その中を等比で刻んで丸めてある。
    /// 単純な等比だと序盤30段が1回刻みに潰れて、3称号が一瞬で終わってしまうため。
    public static let table: [(title: String, steps: [Int])] = [
        ("見習い雀士", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
        ("手なり雀士", [11, 12, 14, 15, 17, 18, 21, 23, 25, 28]),
        ("早見え雀士", [30, 33, 37, 41, 45, 50, 55, 61, 68, 75]),
        ("一直線雀士", [80, 88, 97, 110, 120, 130, 140, 160, 170, 190]),
        ("速攻雀士",   [200, 220, 240, 270, 290, 320, 350, 390, 430, 470]),
        ("疾風雀士",   [500, 540, 580, 620, 670, 710, 770, 820, 880, 950]),
        ("神速雀士",   [1000, 1300, 1700, 2200, 2800, 3600, 4600, 6000, 7700, 10000]),
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
