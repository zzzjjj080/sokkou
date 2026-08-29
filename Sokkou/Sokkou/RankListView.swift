import SwiftUI
import SokkouCore

/// 段位一覧。称号ごとにまとめてある。
/// 70段を全部並べるとスクロールが長すぎて、どこまで来たかが掴めないため。
/// まだ届いていない称号は名前を伏せ、いくつ残っているかだけ分かるようにしてある。
struct RankListView: View {
    let records: Records

    private let gold = Color(red: 1, green: 0.835, blue: 0.290)
    private let green = Color(red: 0.42, green: 0.85, blue: 0.55)

    private var entries: [TitleEntry] { RankLadder.titleEntries(forExperience: records.experience) }

    var body: some View {
        List {
            Section {
                LabeledContent("いまの段位", value: records.rank?.display ?? "称号なし")
                LabeledContent("累計経験値", value: "\(records.experience) EXP")
                LabeledContent("到達した称号",
                               value: "\(entries.filter(\.isReached).count) / \(entries.count)")
            } footer: {
                Text("まだ届いていない称号は名前を伏せてあります。必要な経験値は先まで見えます。")
            }

            Section("称号") {
                ForEach(entries) { entry in
                    row(entry)
                }
            }
        }
        .navigationTitle("段位一覧")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ entry: TitleEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon(entry))
                .font(.system(size: 16))
                .foregroundStyle(entry.isCurrent ? gold
                                 : (entry.isCompleted ? green : Color.secondary.opacity(0.5)))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.system(size: 17, weight: entry.isCurrent ? .heavy : .semibold))
                    .foregroundStyle(entry.isCurrent ? gold
                                     : (entry.isReached ? .primary : .secondary))
                Text("\(entry.firstRequirement) 〜 \(entry.lastRequirement) EXP")
                    .font(.system(size: 12)).monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if entry.isCurrent {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("いまここ")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color(red: 0.14, green: 0.11, blue: 0.01))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(gold, in: Capsule())
                    Text("\(entry.reachedLevels) / \(entry.levelCount)")
                        .font(.system(size: 12, weight: .bold)).monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            } else if entry.isCompleted {
                Text("制覇")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(green)
            }
        }
    }

    private func icon(_ entry: TitleEntry) -> String {
        if entry.isCurrent { return "figure.walk" }
        if entry.isCompleted { return "checkmark.seal.fill" }
        return "lock.fill"
    }
}
