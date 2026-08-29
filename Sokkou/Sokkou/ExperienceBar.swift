import SwiftUI
import SokkouCore

/// 経験値メーター。
///
/// `gained` を渡すと、その局で増えたぶんを明るい緑で伸ばす。
/// `animates` が真なら、増える前の位置から今の位置まで伸びる。
/// どれだけ稼いだかを目で追えるようにするため。
struct ExperienceBar: View {
    let progress: RankProgress
    /// この局で増えた経験値。増分を見せないときは nil
    var gained: Int? = nil
    /// 称号をこの中にも出すか。すでに画面の別の場所に出ているなら false
    var showsTitle: Bool = true
    /// 表示された瞬間にゲージを伸ばすか
    var animates: Bool = false

    @State private var shownFraction: Double = 0

    private let gold = Color(red: 1, green: 0.835, blue: 0.290)
    private let fresh = Color(red: 0.55, green: 1, blue: 0.65)

    /// 増える前の位置
    private var previousFraction: Double {
        guard let gained, progress.needed > 0 else { return progress.fraction }
        let before = Double(progress.earned - gained) / Double(progress.needed)
        // 昇格した局は前の段位から持ち越すので、負にならないよう0で止める
        return min(progress.fraction, max(0, before))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showsTitle || gained != nil {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if showsTitle {
                        Text(progress.current?.display ?? "称号なし")
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(gold)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text("\(progress.total) EXP")
                        .font(.system(size: 12, weight: .bold)).monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    // 今回増えたぶん。伸びるのはここ
                    Capsule().fill(fresh)
                        .frame(width: max(0, geo.size.width * shownFraction))
                    // もともと溜まっていたぶんを上に重ねる
                    Capsule().fill(gold)
                        .frame(width: max(0, geo.size.width * previousFraction))
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
        .onAppear {
            // 増える前の位置から始めて、今の位置まで伸ばす
            shownFraction = animates ? previousFraction : progress.fraction
            guard animates else { return }
            withAnimation(.easeOut(duration: 0.9).delay(0.25)) {
                shownFraction = progress.fraction
            }
        }
    }
}
