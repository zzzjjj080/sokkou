import Foundation

/// 聴牌してから、あと何巡でツモれるか。
///
/// 山から戻さずに引くので、超幾何分布で数える。
/// 1回ごとに (残り − 当たり) / 残り を掛け合わせ、一度も当たらない確率を出して1から引く。
///
/// **前提**
///  ・自分が引ける回数は1局18回まで（`Round.maxDrawsPerHand`）
///  ・他家は考えない。このアプリに他家はいないので、当たり牌を取られることも
///    先に和了られることもない。実戦の自摸和了率より高めに出る
///  ・アプリ自体は聴牌した時点で局を終えるので、この数字は
///    「実戦で続けたらどうなるか」の目安であって、アプリの動作ではない
public enum DrawChance {
    /// - Parameters:
    ///   - waits: 待ちの合計枚数（山に残っている当たり牌）
    ///   - unseen: まだ見えていない牌の総数
    ///   - draws: 何回ツモるか
    public static func probability(waits: Int, unseen: Int, draws: Int) -> Double {
        precondition(waits >= 0 && unseen >= 0 && draws >= 0)
        guard waits > 0, draws > 0, unseen > 0 else { return 0 }
        if waits >= unseen { return 1 }

        var miss = 1.0
        for i in 0..<draws {
            let remaining = unseen - i
            if remaining <= 0 { break }          // 山を引き切ったらそれ以上は増えない
            let blanks = remaining - waits
            if blanks <= 0 { return 1 }          // 残りが全部当たり
            miss *= Double(blanks) / Double(remaining)
        }
        return 1 - miss
    }

    /// 画面に出す区切り。「ここからあと何巡で」を返す。
    ///
    /// 5巡・10巡のうち残りツモ回数に収まるものと、最後に残り全部。
    /// 聴牌した巡目がいくつでも「ここから先」の話として読めるようにしている。
    ///
    /// **残り回数で頭打ちにするのが要点。** 以前は5・10・15を固定で出していたため、
    /// 10巡目に聴牌した局でも「15巡で55%」と、あと15回ツモれる前提の
    /// 数字を出していた。実際にはその時点で残りは8回しかない。
    ///
    /// - Parameter remainingDraws: この局であと何回ツモれるか
    public static func checkpoints(remainingDraws: Int) -> [Int] {
        guard remainingDraws > 0 else { return [] }
        var points = [5, 10].filter { $0 < remainingDraws }
        points.append(remainingDraws)
        return points
    }
}