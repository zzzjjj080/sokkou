import SwiftUI
import SokkouCore

/// 経験値メーター。
///
/// `gained` を渡すと、その局で増えたぶんを明るい色で重ねる。
/// どれだけ稼いだかが目で分かるようにするため。
struct ExperienceBar: View {
    let progress: RankProgress
    /// この局で増えた経験値。メイン画面では nil
    let gained: Int?

    private let gold = Color(red: 1, green: 0.835, blue: 0.290)
    private let fresh = Color(red: 0.55, green: 1, blue: 0.65)

    /// 増えるより前の位置。増えたぶんを重ねて見せるのに使う
    private var previousFraction: Double {
        guard let gained, progress.needed > 0 else { return progress.fraction }
        let before = Double(progress.earned - gained) / Double(progress.needed)
        return min(progress.fraction, max(0, before))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(progress.current?.display ?? "称号なし")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(gold)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let gained {
                    Text("+\(gained)")
                        .font(.system(size: 19, weight: .black)).monospacedDigit()
                        .foregroundStyle(fresh)
                }
                Text("\(progress.total) EXP")
                    .font(.system(size: 12, weight: .bold)).monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    // もともと溜まっていたぶん
                    Capsule().fill(gold)
                        .frame(width: max(0, geo.size.width * previousFraction))
                    // この局で増えたぶんだけ色を変えて重ねる
                    if gained != nil {
                        Capsule().fill(fresh)
                            .frame(width: max(0, geo.size.width * progress.fraction))
                            .mask(alignment: .leading) {
                                HStack(spacing: 0) {
                                    Color.clear
                                        .frame(width: geo.size.width * previousFraction)
                                    Color.black
                                }
                            }
                    }
                }
            }
            .frame(height: 12)

            if let remaining = progress.remaining, let next = progress.next {
                Text("次の \(next.display) まで あと \(remaining) EXP")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("最高位に到達しています")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(gold)
            }
        }
    }
}
