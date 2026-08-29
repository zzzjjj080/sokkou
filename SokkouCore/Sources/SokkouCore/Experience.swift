import Foundation

/// 1局の打牌の内訳
public struct RoundScore: Equatable, Sendable {
    /// この局に切った枚数
    public let discards: Int
    /// 合格点(90点)に届かなかった回数
    public let mistakes: Int
    /// 最善そのもの(100点・金枠)を選んだ回数
    public let bestChoices: Int

    public init(discards: Int, mistakes: Int, bestChoices: Int) {
        self.discards = discards
        self.mistakes = mistakes
        self.bestChoices = bestChoices
    }

    public var correctChoices: Int { discards - mistakes }
    /// 金枠を選べた割合。ボーナスはこれで決まる
    public var bestRate: Double {
        discards > 0 ? Double(bestChoices) / Double(discards) : 0
    }
}

/// 1局でもらえる経験値。
///
/// **基準は聴牌までに外した回数。** 何巡かかったかは見ない。
/// ノーミスが100で、外すたびに半分になる。最低でも1はもらえる。
///
///   0回 → 100 / 1回 → 50 / 2回 → 25 / 3回 → 12 / 4回 → 6 / 5回 → 3 / 6回以降 → 1
///
/// そのうえで、**最善そのもの(金枠)を選べた割合**を倍率として掛ける。
///
///   経験値 = 基準の点数 × (1 + 0.5 × 金枠の割合)
///
/// 割合にしているのは、枚数に比例させると打牌数の多い局ほど得になり、
/// 15巡かけて聴牌したほうが6巡で聴牌するより経験値が増えてしまうため。
/// 最速聴牌を目指すアプリでそれは筋が通らない。
///
/// 倍率よりミスのほうが重い。1ミスで全部金枠(75)でも、
/// ノーミスで全部緑(100)には届かない。まず外さない、その上で精度、の順。
public enum Experience {
    public static let perfect = 100
    /// 金枠をすべて選んだときの上乗せ
    public static let bonusWeight = 0.5

    /// 外した回数だけで決まる基準の点数
    public static func base(mistakes: Int) -> Int {
        precondition(mistakes >= 0, "外した回数が負になることはない")
        var value = perfect
        for _ in 0..<mistakes {
            value /= 2
            if value <= 1 { return 1 }
        }
        return value
    }

    /// 金枠の割合から決まる倍率。1.0〜1.5
    public static func multiplier(_ score: RoundScore) -> Double {
        1 + bonusWeight * score.bestRate
    }

    public static func gain(_ score: RoundScore) -> Int {
        max(1, Int(Double(base(mistakes: score.mistakes)) * multiplier(score)))
    }
}
