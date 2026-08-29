import Foundation

/// 1局でもらえる経験値。
///
/// **基準は聴牌までに外した回数だけ。** 何巡かかったかは見ない。
/// ノーミスが100で、外すたびに半分になる。最低でも1はもらえる。
///
///   0回 → 100 / 1回 → 50 / 2回 → 25 / 3回 → 12 / 4回 → 6 / 5回 → 3 / 6回以降 → 1
///
/// 半分ずつ減らすのは、1回外しただけで伸びが目に見えて鈍るようにするため。
/// 満点を狙わないと段位が上がらない、という手触りを作っている。
public enum Experience {
    public static let perfect = 100

    public static func gain(mistakes: Int) -> Int {
        precondition(mistakes >= 0, "外した回数が負になることはない")
        var value = perfect
        for _ in 0..<mistakes {
            value /= 2
            if value <= 1 { return 1 }
        }
        return value
    }
}
