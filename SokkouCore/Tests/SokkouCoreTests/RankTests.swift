import Foundation
import Testing
@testable import SokkouCore

/// 称号は「打った量」の記録なので、一度出した段位が後から下がってはいけない。
/// 記録の読み書きも、項目を足したときに消えないことを確かめる。
struct RankTests {

    // MARK: - 段位のはしご

    @Test("必要回数は必ず増えていく")
    func ladderIsStrictlyIncreasing() {
        let needs = RankLadder.all.map(\.requirement)
        #expect(needs == needs.sorted())
        #expect(Set(needs).count == needs.count, "同じ回数の段位が2つある")
    }

    @Test("称号ごとにLv1からLv10まである")
    func everyTitleHasTenLevels() {
        for entry in RankLadder.table {
            #expect(entry.steps.count == 10, "\(entry.title) のレベル数が10でない")
        }
        #expect(RankLadder.all.count == 70)
        for rank in RankLadder.all { #expect((1...10).contains(rank.level)) }
    }

    @Test("決めた3つの条件を満たしている")
    func satisfiesTheStatedConditions() {
        #expect(RankLadder.all[0].requirement == 1, "1段目は1回")
        #expect(RankLadder.all[60].display == "神速雀士 Lv1")
        #expect(RankLadder.all[60].requirement == 1000, "61段目でちょうど1000回")
        #expect(RankLadder.all[69].display == "神速雀士 Lv10")
        #expect(RankLadder.all[69].requirement == 10000, "70段目でちょうど10000回")
    }

    @Test("1回も最速していなければ称号なし")
    func noRankBeforeFirstFastest() {
        #expect(RankLadder.rank(forFastestCount: 0) == nil)
        #expect(RankLadder.rank(forFastestCount: 1)?.display == "見習い雀士 Lv1")
    }

    @Test("境界のちょうどで上がる")
    func promotesExactlyOnThreshold() {
        #expect(RankLadder.rank(forFastestCount: 9)?.display == "見習い雀士 Lv9")
        #expect(RankLadder.rank(forFastestCount: 10)?.display == "見習い雀士 Lv10")
        #expect(RankLadder.rank(forFastestCount: 10)?.display == "見習い雀士 Lv10")
        #expect(RankLadder.rank(forFastestCount: 11)?.display == "手なり雀士 Lv1")
        #expect(RankLadder.rank(forFastestCount: 240)?.display == "速攻雀士 Lv3")
    }

    @Test("回数が増えて段位が下がることはない")
    func rankNeverGoesDown() {
        var previous = -1
        for n in 0...10100 {
            let current = RankLadder.all.firstIndex { $0 == RankLadder.rank(forFastestCount: n) } ?? -1
            #expect(current >= previous, "累計\(n)回で段位が下がった")
            previous = current
        }
    }

    @Test("最高位に達すると次が無くなる")
    func topRankHasNoNext() {
        #expect(RankLadder.next(forFastestCount: 10000) == nil)
        #expect(RankLadder.rank(forFastestCount: 10000) == RankLadder.top)
        #expect(RankLadder.top.display == "神速雀士 Lv10")
        let next = RankLadder.next(forFastestCount: 10)
        #expect(next?.rank.display == "手なり雀士 Lv1")
        #expect(next?.remaining == 1)
    }

    // MARK: - 記録

    @Test("最速聴牌で回数と連続が伸びる")
    func fastestRoundsAccumulate() {
        var r = Records()
        r.finishRound(wasFastest: true)
        r.finishRound(wasFastest: true)
        #expect(r.fastestCount == 2)
        #expect(r.currentStreak == 2)
        #expect(r.bestStreak == 2)
    }

    @Test("外すと連続だけ切れて、累計と最高記録は残る")
    func missBreaksOnlyTheStreak() {
        var r = Records()
        for _ in 0..<3 { r.finishRound(wasFastest: true) }
        r.finishRound(wasFastest: false)
        #expect(r.fastestCount == 3, "累計は減らない")
        #expect(r.currentStreak == 0)
        #expect(r.bestStreak == 3, "最高記録は残る")
    }

    @Test("昇格した局だけ昇格を知らせる")
    func promotionIsReportedOnce() {
        var r = Records()
        let first = r.finishRound(wasFastest: true)     // 0 -> 1回目で見習い雀士 Lv1
        #expect(first.promotedTo?.display == "見習い雀士 Lv1")
        let second = r.finishRound(wasFastest: true)
        #expect(second.promotedTo?.display == "見習い雀士 Lv2", "1回ごとに上がる区間")
    }

    @Test("外した局では昇格しない")
    func missDoesNotPromote() {
        var r = Records()
        let outcome = r.finishRound(wasFastest: false)
        #expect(outcome.promotedTo == nil)
        #expect(outcome.wasFastest == false)
        #expect(r.rank == nil)
    }

    // MARK: - 保存(引き継ぎ書 4-21 の対策)

    @Test("項目が足りない古い記録でも読める")
    func decodesOldRecordsWithMissingFields() throws {
        // fastestCount しか無かった頃のJSONを直に置く
        let old = Data(#"{"fastestCount":42}"#.utf8)
        let r = try JSONDecoder().decode(Records.self, from: old)
        #expect(r.fastestCount == 42)
        #expect(r.currentStreak == 0)
        #expect(r.bestStreak == 0)
        #expect(r.rank?.display == "早見え雀士 Lv4", "42回はLv4(41回)を超え、Lv5(45回)には届かない")
    }

    @Test("空のJSONでも落ちずに初期状態になる")
    func decodesEmptyObject() throws {
        let r = try JSONDecoder().decode(Records.self, from: Data("{}".utf8))
        #expect(r == Records())
    }

    @Test("書いて読んで同じになる")
    func roundTrips() throws {
        var r = Records()
        for i in 0..<10 { r.finishRound(wasFastest: i % 3 != 0) }
        let data = try JSONEncoder().encode(r)
        #expect(try JSONDecoder().decode(Records.self, from: data) == r)
    }

    @Test("連続が最高記録を超えた壊れた記録は、読み込み時に直る")
    func repairsInconsistentStreaks() throws {
        let broken = Data(#"{"fastestCount":10,"currentStreak":7,"bestStreak":2}"#.utf8)
        let r = try JSONDecoder().decode(Records.self, from: broken)
        #expect(r.bestStreak == 7)
    }
}
