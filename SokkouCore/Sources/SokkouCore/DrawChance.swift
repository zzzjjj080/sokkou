import Foundation

/// 聴牌してから、あと何巡でツモれるか。
///
/// 山から戻さずに引くので、超幾何分布で数える。
/// 1回ごとに (残り − 当たり) / 残り を掛け合わせ、一度も当たらない確率を出して1から引く。
///
/// **これは「山から続けて引いたら」の確率であって、実戦の自摸和了率ではない。**
/// 他家は考えない。当たり牌を取られることも、先に和了られて局が終わることもない前提。
/// 実戦ではここまでツモ番が回らないことが多いので、必ず高めに出る。
/// 画面にもその旨を書いてある。
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

    /// 画面に出す区切り。「何回引いたら」で数える。
    ///
    /// 巡目ではなく引いた回数で示す。以前は5巡・10巡・15巡と巡目で出していたが、
    /// 10巡目に聴牌した局で「15巡で55%」と、その局では起こりえない数字に見えていた。
    /// 「10回引いたら」なら仮定がはっきりしていて誤解しようがない。
    public static let checkpoints = [1, 5, 10]
}