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

    /// 画面に出す区切りを「巡目」で返す。
    ///
    /// 5巡目・10巡目・15巡目のうち、まだ先にあるものと、最後の巡目。
    /// 「あと何巡」ではなく巡目そのもので示すのは、聴牌した時点から見て
    /// どこまで持つ話なのかが直感的に分かるため。
    ///
    /// **以前は5巡・10巡・15巡を固定で出していた。** そのため10巡目に
    /// 聴牌した局でも「15巡で55%」と、あと15回ツモれる前提の数字を出していた。
    /// 実際にはその時点で残りは8回しかない。
    ///
    /// - Parameters:
    ///   - currentTurn: 聴牌した巡目
    ///   - lastTurn: その局で自分が最後にツモれる巡目
    public static func turnCheckpoints(currentTurn: Int, lastTurn: Int) -> [Int] {
        guard currentTurn < lastTurn else { return [] }
        var turns = [5, 10, 15].filter { $0 > currentTurn && $0 < lastTurn }
        turns.append(lastTurn)
        return turns
    }
}