import Foundation

/// 称号とレベル。「速攻雀士 Lv3」のように人につける名前で表す。
///
/// 上がる条件は**最速聴牌の累計回数**だけ。割合は使わない。
/// 打った局数が増えるほど不利になる指標だと、気軽に打てなくなるため。
public struct Rank: Equatable, Sendable, Codable {
    public let title: String
    public let level: Int
    /// この段位に上がるのに必要な累計経験値
    public let requirement: Int

    public var display: String { "\(title) Lv\(level)" }
}

public enum RankLadder {
    /// 称号ごとの、Lv1〜Lv10に必要な累計経験値。
    /// 数字は「ノーミスで聴牌した回数」×100。ノーミス1局が100経験値なので、
    /// 満点を取り続けたときの上がり方は回数で数えていた頃と変わらない。
    /// 外すと半分以下しか入らないので、そのぶん遅くなる。
    ///
    /// 決めた条件は3つ。
    ///   ・7称号 × 10レベル = 70段
    ///   ・61段目(神速雀士 Lv1)でちょうど100000(ノーミス1000局ぶん)
    ///   ・70段目(神速雀士 Lv10)でちょうど1000000(ノーミス10000局ぶん)
    /// 称号ごとの担当範囲を先に置き、その中を等比で刻んで丸めてある。
    /// 単純な等比だと序盤30段が1局刻みに潰れて、3称号が一瞬で終わってしまうため。
    public static let table: [(title: String, steps: [Int])] = [
        ("見習い雀士", [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000]),
        ("手なり雀士", [1100, 1200, 1400, 1500, 1700, 1800, 2100, 2300, 2500, 2800]),
        ("早見え雀士", [3000, 3300, 3700, 4100, 4500, 5000, 5500, 6100, 6800, 7500]),
        ("一直線雀士", [8000, 8800, 9700, 11000, 12000, 13000, 14000, 16000, 17000, 19000]),
        ("速攻雀士",   [20000, 22000, 24000, 27000, 29000, 32000, 35000, 39000, 43000, 47000]),
        ("疾風雀士",   [50000, 54000, 58000, 62000, 67000, 71000, 77000, 82000, 88000, 95000]),
        ("神速雀士",   [100000, 130000, 170000, 220000, 280000, 360000, 460000, 600000, 770000, 1000000]),
    ]

    /// 表を「必要回数の昇順」に平らへ並べたもの
    public static let all: [Rank] = table.flatMap { entry in
        entry.steps.enumerated().map { i, need in
            Rank(title: entry.title, level: i + 1, requirement: need)
        }
    }

    /// いまの段位。経験値が最初の段位に届いていなければ nil。
    public static func rank(forExperience experience: Int) -> Rank? {
        all.last { experience >= $0.requirement }
    }

    /// 次の段位と、それまでの残り回数。最高位に達していれば nil。
    public static func next(forExperience experience: Int) -> (rank: Rank, remaining: Int)? {
        guard let next = all.first(where: { experience < $0.requirement }) else { return nil }
        return (next, next.requirement - experience)
    }

    public static var top: Rank { all[all.count - 1] }

    /// 次の段位までの進み具合。経験値メーターに使う。
    public static func progress(forExperience experience: Int) -> RankProgress {
        let current = rank(forExperience: experience)
        let upcoming = next(forExperience: experience)
        // いまの段位に入った経験値。まだ称号が無いうちは0から数える
        let floor = current?.requirement ?? 0
        let ceiling = upcoming?.rank.requirement
        return RankProgress(
            current: current,
            next: upcoming?.rank,
            earned: experience - floor,
            needed: ceiling.map { $0 - floor } ?? 0,
            total: experience
        )
    }
}

/// 段位の進み具合
public struct RankProgress: Equatable, Sendable {
    public let current: Rank?
    public let next: Rank?
    /// いまの段位に入ってから稼いだ経験値
    public let earned: Int
    /// 次の段位までに必要な経験値。最高位なら0
    public let needed: Int
    /// 累計経験値
    public let total: Int

    /// メーターの埋まり具合。最高位に達していれば満タン
    public var fraction: Double {
        guard needed > 0 else { return 1 }
        return min(1, max(0, Double(earned) / Double(needed)))
    }
    /// 次の段位まであと何経験値か。最高位なら nil
    public var remaining: Int? {
        guard needed > 0 else { return nil }
        return needed - earned
    }
    public var isMaxed: Bool { next == nil }
}
