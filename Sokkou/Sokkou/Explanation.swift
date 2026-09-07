import SokkouCore

/// 「なぜ最善より劣るのか」を1行で言う。
///
/// 詳細画面を開かなくても、判定の行を見ただけで理由が分かるようにする。
/// 長い説明は DetailSheet にあり、ここはその要点だけ。
enum Explanation {

    /// 選んだ牌が最善でないときの一言。最善そのものなら nil
    static func oneLiner(chosen: Tile, in evaluation: Evaluation) -> String? {
        guard !evaluation.isBest(chosen),
              let mine = evaluation.option(for: chosen),
              let bestTile = evaluation.bestTiles.first,
              let best = evaluation.option(for: bestTile) else { return nil }

        if mine.isShantenBack {
            return "\(shantenLabel(mine.shanten))に戻る打牌。速さだけでは良し悪しを決められない"
        }
        let ukeireDiff = mine.ukeireCount - best.ukeireCount
        if ukeireDiff < 0 {
            return "受け入れが\(-ukeireDiff)枚少ない（\(mine.ukeireCount)枚 対 \(best.ukeireCount)枚）"
        }
        if best.improvement > mine.improvement {
            let entry = ukeireDiff == 0 ? "受け入れは同じ" : "受け入れは\(ukeireDiff)枚多い"
            return "\(entry)でも、残した形の伸びしろが狭い（\(mine.improvement)枚 対 \(best.improvement)枚）"
        }
        return "受け入れも伸びしろも近いが、この先の形で差がつく"
    }
}
