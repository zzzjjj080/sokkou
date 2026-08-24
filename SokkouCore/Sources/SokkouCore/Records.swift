import Foundation

/// 保存する記録。**最速聴牌の回数と連続記録だけを持つ。**
///
/// 割合(最善率)は持たない。本人が要らないと決めたのもあるが、
/// 打つほど下がる指標があると気軽に試せなくなるため。
///
/// 項目を足しても古い記録が読めるように、復号は1項目ずつ既定値で埋める。
/// `try? decode` は1つでも欠けると nil を返し、記録が丸ごと消える。
public struct Records: Equatable, Sendable, Codable {
    /// 最速聴牌(その局のすべての打牌が正解)の累計回数
    public private(set) var fastestCount: Int
    /// いま何局連続で最速聴牌しているか
    public private(set) var currentStreak: Int
    /// これまでの最高連続記録
    public private(set) var bestStreak: Int

    public init(fastestCount: Int = 0, currentStreak: Int = 0, bestStreak: Int = 0) {
        self.fastestCount = fastestCount
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
    }

    public var rank: Rank? { RankLadder.rank(forFastestCount: fastestCount) }
    public var nextRank: (rank: Rank, remaining: Int)? { RankLadder.next(forFastestCount: fastestCount) }

    /// 1局終わったときに呼ぶ。戻り値は「この局で起きたこと」。
    @discardableResult
    public mutating func finishRound(wasFastest: Bool) -> RoundOutcome {
        let rankBefore = rank
        if wasFastest {
            fastestCount += 1
            currentStreak += 1
            bestStreak = max(bestStreak, currentStreak)
        } else {
            currentStreak = 0
        }
        let rankAfter = rank
        return RoundOutcome(
            wasFastest: wasFastest,
            promotedTo: rankBefore != rankAfter ? rankAfter : nil,
            isBestStreakUpdated: wasFastest && currentStreak == bestStreak && bestStreak >= 2
        )
    }

    public mutating func resetAll() { self = Records() }

    // MARK: - Codable(項目を足しても古い記録が読めるようにする)

    enum CodingKeys: String, CodingKey {
        case fastestCount, currentStreak, bestStreak
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fastestCount = try c.decodeIfPresent(Int.self, forKey: .fastestCount) ?? 0
        currentStreak = try c.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        bestStreak = try c.decodeIfPresent(Int.self, forKey: .bestStreak) ?? 0
        // 連続記録が最高記録を超えた状態は作れないので、読み込み時に整える
        bestStreak = max(bestStreak, currentStreak)
    }
}

/// 1局が終わったときに画面へ伝えること
public struct RoundOutcome: Equatable, Sendable {
    public let wasFastest: Bool
    /// この局で昇格したなら、その段位
    public let promotedTo: Rank?
    /// 自己ベストの連続記録を更新したか
    public let isBestStreakUpdated: Bool
}
