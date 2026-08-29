import Foundation

/// 保存する記録。
///
/// 段位が上がる条件は**累計経験値**だけ。割合(最善率)は持たない。
/// 打つほど下がる指標があると気軽に試せなくなるため。
///
/// 項目を足しても古い記録が読めるように、復号は1項目ずつ既定値で埋める。
/// `try? decode` は1つでも欠けると nil を返し、記録が丸ごと消える。
public struct Records: Equatable, Sendable, Codable {
    /// 累計経験値。段位はこれで決まる
    public private(set) var experience: Int
    /// 最速聴牌(その局のすべての打牌が正解)の累計回数。表示用
    public private(set) var fastestCount: Int
    /// いま何局連続で最速聴牌しているか
    public private(set) var currentStreak: Int
    /// これまでの最高連続記録
    public private(set) var bestStreak: Int

    public init(experience: Int = 0, fastestCount: Int = 0,
                currentStreak: Int = 0, bestStreak: Int = 0) {
        self.experience = experience
        self.fastestCount = fastestCount
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
    }

    public var rank: Rank? { RankLadder.rank(forExperience: experience) }
    public var nextRank: (rank: Rank, remaining: Int)? { RankLadder.next(forExperience: experience) }
    /// 経験値メーターに出す進み具合
    public var progress: RankProgress { RankLadder.progress(forExperience: experience) }

    /// 1局終わったときに呼ぶ。戻り値は「この局で起きたこと」。
    @discardableResult
    public mutating func finishRound(score: RoundScore) -> RoundOutcome {
        let before = experience
        let rankBefore = rank
        let gained = Experience.gain(score)
        experience += gained

        let wasFastest = score.mistakes == 0
        if wasFastest {
            fastestCount += 1
            currentStreak += 1
            bestStreak = max(bestStreak, currentStreak)
        } else {
            currentStreak = 0
        }

        return RoundOutcome(
            wasFastest: wasFastest,
            score: score,
            gained: gained,
            base: Experience.base(mistakes: score.mistakes),
            multiplier: Experience.multiplier(score),
            experienceBefore: before,
            experienceAfter: experience,
            promotedTo: rankBefore != rank ? rank : nil,
            isBestStreakUpdated: wasFastest && currentStreak == bestStreak && bestStreak >= 2
        )
    }

    public mutating func resetAll() { self = Records() }

    // MARK: - Codable(項目を足しても古い記録が読めるようにする)

    enum CodingKeys: String, CodingKey {
        case experience, fastestCount, currentStreak, bestStreak
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fastestCount = try c.decodeIfPresent(Int.self, forKey: .fastestCount) ?? 0
        currentStreak = try c.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        bestStreak = try c.decodeIfPresent(Int.self, forKey: .bestStreak) ?? 0
        // 経験値を導入する前の記録には experience が無い。
        // 当時は最速聴牌の回数で段位が決まっていたので、1回=100として引き継ぐ。
        // これが無いと、更新した瞬間に段位が称号なしへ戻ってしまう。
        experience = try c.decodeIfPresent(Int.self, forKey: .experience)
            ?? fastestCount * Experience.perfect
        // 連続が最高記録を超えた状態は作れないので、読み込み時に整える
        bestStreak = max(bestStreak, currentStreak)
    }
}

/// 1局が終わったときに画面へ伝えること
public struct RoundOutcome: Equatable, Sendable {
    public let wasFastest: Bool
    public let score: RoundScore
    /// この局でもらった経験値
    public let gained: Int
    /// 倍率をかける前の点数
    public let base: Int
    /// 金枠の割合から決まった倍率
    public let multiplier: Double
    public let experienceBefore: Int
    public let experienceAfter: Int
    /// この局で昇格したなら、その段位
    public let promotedTo: Rank?
    /// 自己ベストの連続記録を更新したか
    public let isBestStreakUpdated: Bool
}
