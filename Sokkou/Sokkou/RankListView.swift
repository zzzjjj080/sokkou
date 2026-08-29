import SwiftUI
import SokkouCore

/// 段位の一覧。どこまで来たか、この先どれだけ残っているかを見る。
/// 未到達の称号は名前を伏せてある。
struct RankListView: View {
    let records: Records

    private let gold = Color(red: 1, green: 0.835, blue: 0.290)

    private var entries: [RankEntry] { RankLadder.entries(forExperience: records.experience) }
    private var reachedCount: Int { entries.filter(\.isReached).count }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("到達した段位")
                    Spacer()
                    Text("\(reachedCount) / \(entries.count)")
                        .font(.system(size: 17, weight: .heavy)).monospacedDigit()
                        .foregroundStyle(gold)
                }
                HStack {
                    Text("累計経験値")
                    Spacer()
                    Text("\(records.experience) EXP")
                        .monospacedDigit().foregroundStyle(.secondary)
                }
            } footer: {
                Text("まだ到達していない称号は伏せてあります。必要な経験値は先まで見えます。")
            }

            Section("段位") {
                ForEach(entries) { entry in
                    row(entry)
                }
            }
        }
        .navigationTitle("段位一覧")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ entry: RankEntry) -> some View {
        HStack(spacing: 10) {
            Text("\(entry.step)")
                .font(.system(size: 12, weight: .bold)).monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .trailing)

            Text(entry.displayName)
                .font(.system(size: 16, weight: entry.isCurrent ? .heavy : .regular))
                .foregroundStyle(entry.isCurrent ? gold
                                 : (entry.isReached ? .primary : .secondary))

            Spacer()

            Text("\(entry.rank.requirement) EXP")
                .font(.system(size: 13)).monospacedDigit()
                .foregroundStyle(.secondary)

            if entry.isCurrent {
                Text("いまここ")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Color(red: 0.14, green: 0.11, blue: 0.01))
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(gold, in: Capsule())
            } else if entry.isReached {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(red: 0.42, green: 0.85, blue: 0.55))
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
