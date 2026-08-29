import SwiftUI
import SokkouCore

/// 経験値メーター。
///
/// `from` から `to` へ、途中の段位をまたぎながら伸びる。
/// 満タンになったら次の段位の空のバーに切り替わり、そこから残りが伸びる。
/// レベルが上がる瞬間もバーが見えている状態を保つため、
/// 表示している経験値そのものを少しずつ動かして、バーはそれを見ているだけにしてある。
struct ExperienceBar: View {
    /// 増える前の累計経験値
    let from: Int
    /// 増えたあとの累計経験値
    let to: Int
    /// 称号をこの中にも出すか。すでに画面の別の場所にあるなら false
    var showsTitle: Bool = true
    /// 表示された瞬間に伸ばすか
    var animates: Bool = false
    /// 段位が上がった瞬間に呼ばれる
    var onLevelUp: (() -> Void)? = nil

    @State private var displayed: Int = 0
    @State private var hasStarted = false

    private let gold = Color(red: 1, green: 0.835, blue: 0.290)
    private let fresh = Color(red: 0.55, green: 1, blue: 0.65)

    private var progress: RankProgress { RankLadder.progress(forExperience: displayed) }
    private var isGrowing: Bool { animates && displayed < to }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showsTitle {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(progress.current?.display ?? "称号なし")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(gold)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("\(displayed) EXP")
                        .font(.system(size: 12, weight: .bold)).monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(isGrowing || displayed != from ? fresh : gold)
                        .frame(width: max(0, geo.size.width * progress.fraction))
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
        .onAppear(perform: start)
    }

    private func start() {
        guard !hasStarted else { return }
        hasStarted = true
        displayed = animates ? from : to
        guard animates, to > from else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            let steps = 36
            let total = to - from
            var previousRank = RankLadder.rank(forExperience: from)
            for step in 1...steps {
                // 端数で止まらないよう、最後の1歩は必ず to にそろえる
                let value = step == steps ? to : from + total * step / steps
                withAnimation(.linear(duration: 0.028)) { displayed = value }
                let rank = RankLadder.rank(forExperience: value)
                if rank != previousRank {
                    previousRank = rank
                    onLevelUp?()
                    // 上がった瞬間は少し止めて、空になったバーを見せる
                    try? await Task.sleep(for: .milliseconds(260))
                }
                try? await Task.sleep(for: .milliseconds(28))
            }
        }
    }
}
