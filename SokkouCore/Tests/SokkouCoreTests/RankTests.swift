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
        #expect(RankLadder.all[0].requirement == 100, "1段目はノーミス1局ぶん")
        #expect(RankLadder.all[60].display == "神速雀士 Lv1")
        #expect(RankLadder.all[60].requirement == 100_000, "61段目でノーミス1000局ぶん")
        #expect(RankLadder.all[69].display == "神速雀士 Lv10")
        #expect(RankLadder.all[69].requirement == 1_000_000, "70段目でノーミス10000局ぶん")
    }

    @Test("1回も最速していなければ称号なし")
    func noRankBeforeFirstFastest() {
        #expect(RankLadder.rank(forExperience: 0) == nil)
        #expect(RankLadder.rank(forExperience: 100)?.display == "見習い雀士 Lv1")
    }

    @Test("境界のちょうどで上がる")
    func promotesExactlyOnThreshold() {
        #expect(RankLadder.rank(forExperience: 999)?.display == "見習い雀士 Lv9")
        #expect(RankLadder.rank(forExperience: 1000)?.display == "見習い雀士 Lv10")
        #expect(RankLadder.rank(forExperience: 1100)?.display == "手なり雀士 Lv1")
        #expect(RankLadder.rank(forExperience: 24000)?.display == "速攻雀士 Lv3")
    }

    @Test("回数が増えて段位が下がることはない")
    func rankNeverGoesDown() {
        var previous = -1
        for n in stride(from: 0, through: 1_010_000, by: 137) {
            let current = RankLadder.all.firstIndex { $0 == RankLadder.rank(forExperience: n) } ?? -1
            #expect(current >= previous, "累計\(n)経験値で段位が下がった")
            previous = current
        }
    }

    @Test("最高位に達すると次が無くなる")
    func topRankHasNoNext() {
        #expect(RankLadder.next(forExperience: 1_000_000) == nil)
        #expect(RankLadder.rank(forExperience: 1_000_000) == RankLadder.top)
        #expect(RankLadder.top.display == "神速雀士 Lv10")
        let next = RankLadder.next(forExperience: 1000)
        #expect(next?.rank.display == "手なり雀士 Lv1")
        #expect(next?.remaining == 100)
    }

    // MARK: - 記録

    @Test("ノーミスの局は100経験値、回数と連続も伸びる")
    func fastestRoundsAccumulate() {
        var r = Records()
        r.finishRound(mistakes: 0)
        r.finishRound(mistakes: 0)
        #expect(r.experience == 200)
        #expect(r.fastestCount == 2)
        #expect(r.currentStreak == 2)
        #expect(r.bestStreak == 2)
    }

    @Test("外しても経験値は入るが、連続は切れる")
    func missBreaksOnlyTheStreak() {
        var r = Records()
        for _ in 0..<3 { r.finishRound(mistakes: 0) }
        let outcome = r.finishRound(mistakes: 1)
        #expect(outcome.gained == 50, "1回外したら半分")
        #expect(r.experience == 350)
        #expect(r.fastestCount == 3, "最速聴牌の回数は増えない")
        #expect(r.currentStreak == 0)
        #expect(r.bestStreak == 3, "最高記録は残る")
    }

    @Test("昇格した局だけ昇格を知らせる")
    func promotionIsReportedOnce() {
        var r = Records()
        let first = r.finishRound(mistakes: 0)     // 100経験値で見習い雀士 Lv1
        #expect(first.promotedTo?.display == "見習い雀士 Lv1")
        #expect(first.gained == 100)
        let second = r.finishRound(mistakes: 0)    // 200でLv2
        #expect(second.promotedTo?.display == "見習い雀士 Lv2")
        let third = r.finishRound(mistakes: 3)     // 12しか入らないので昇格しない
        #expect(third.gained == 12)
        #expect(third.promotedTo == nil, "半端な経験値では上がらない")
    }

    @Test("大きく外した局では段位に届かない")
    func missDoesNotPromote() {
        var r = Records()
        let outcome = r.finishRound(mistakes: 5)
        #expect(outcome.gained == 3)
        #expect(outcome.promotedTo == nil)
        #expect(outcome.wasFastest == false)
        #expect(r.rank == nil, "3経験値では最初の段位(100)に届かない")
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
        #expect(r.experience == 4200, "経験値が無い古い記録は、1回=100として引き継ぐ")
        #expect(r.rank?.display == "早見え雀士 Lv4", "4200はLv4(4100)を超え、Lv5(4500)には届かない")
    }

    @Test("空のJSONでも落ちずに初期状態になる")
    func decodesEmptyObject() throws {
        let r = try JSONDecoder().decode(Records.self, from: Data("{}".utf8))
        #expect(r == Records())
    }

    @Test("書いて読んで同じになる")
    func roundTrips() throws {
        var r = Records()
        for i in 0..<10 { r.finishRound(mistakes: i % 3) }
        let data = try JSONEncoder().encode(r)
        #expect(try JSONDecoder().decode(Records.self, from: data) == r)
    }

    @Test("連続が最高記録を超えた壊れた記録は、読み込み時に直る")
    func repairsInconsistentStreaks() throws {
        let broken = Data(#"{"experience":1000,"fastestCount":10,"currentStreak":7,"bestStreak":2}"#.utf8)
        let r = try JSONDecoder().decode(Records.self, from: broken)
        #expect(r.bestStreak == 7)
    }
}

/// 経験値メーター。段位の中でどこまで進んだかを出す。
struct RankProgressTests {

    @Test("称号が無いうちは最初の段位までを数える")
    func beforeFirstRank() {
        let p = RankLadder.progress(forExperience: 0)
        #expect(p.current == nil)
        #expect(p.next?.display == "見習い雀士 Lv1")
        #expect(p.earned == 0)
        #expect(p.needed == 100)
        #expect(p.remaining == 100)
        #expect(p.fraction == 0)
    }

    @Test("段位に入った直後は空、次の直前で満タンに近づく")
    func fillsWithinTheRank() {
        // 早見え雀士 Lv1 = 3000、Lv2 = 3300。300で1段
        let justPromoted = RankLadder.progress(forExperience: 3000)
        #expect(justPromoted.current?.display == "早見え雀士 Lv1")
        #expect(justPromoted.earned == 0)
        #expect(justPromoted.needed == 300)
        #expect(justPromoted.fraction == 0)

        let almost = RankLadder.progress(forExperience: 3200)
        #expect(almost.current?.display == "早見え雀士 Lv1")
        #expect(almost.earned == 200)
        #expect(almost.remaining == 100)
        #expect(abs(almost.fraction - 2.0 / 3.0) < 0.0001)
    }

    @Test("メーターは0から1の外へ出ない")
    func fractionStaysInRange() {
        for n in stride(from: 0, through: 1_100_000, by: 149) {
            let f = RankLadder.progress(forExperience: n).fraction
            #expect(f >= 0 && f <= 1, "累計\(n)経験値でメーターが範囲外(\(f))")
        }
    }

    @Test("最高位ではメーターが満タンで、次が無い")
    func maxedOut() {
        let p = RankLadder.progress(forExperience: 1_000_000)
        #expect(p.isMaxed)
        #expect(p.next == nil)
        #expect(p.remaining == nil)
        #expect(p.fraction == 1)
        #expect(p.current == RankLadder.top)
    }

    @Test("累計はそのまま持っている")
    func keepsTotal() {
        #expect(RankLadder.progress(forExperience: 13700).total == 13700)
    }
}

/// 経験値の入り方。外すたびに半分になるので、満点を狙わないと伸びない。
struct ExperienceTests {

    @Test("ノーミスは100、外すたびに半分")
    func halvesPerMistake() {
        #expect(Experience.gain(mistakes: 0) == 100)
        #expect(Experience.gain(mistakes: 1) == 50)
        #expect(Experience.gain(mistakes: 2) == 25)
        #expect(Experience.gain(mistakes: 3) == 12)
        #expect(Experience.gain(mistakes: 4) == 6)
        #expect(Experience.gain(mistakes: 5) == 3)
    }

    @Test("どれだけ外しても最低1はもらえる")
    func neverZero() {
        for mistakes in 0...40 {
            #expect(Experience.gain(mistakes: mistakes) >= 1, "\(mistakes)回外して0になった")
        }
        #expect(Experience.gain(mistakes: 6) == 1)
        #expect(Experience.gain(mistakes: 20) == 1)
    }

    @Test("外すほど減る。増えることはない")
    func neverIncreases() {
        for mistakes in 1...30 {
            #expect(Experience.gain(mistakes: mistakes) <= Experience.gain(mistakes: mistakes - 1))
        }
    }

    @Test("1回外すと、段位が上がるのに倍の局数がかかる")
    func mistakesSlowProgressDown() {
        var perfect = Records()
        var sloppy = Records()
        for _ in 0..<10 {
            perfect.finishRound(mistakes: 0)
            sloppy.finishRound(mistakes: 1)
        }
        #expect(perfect.experience == 1000)
        #expect(sloppy.experience == 500)
        #expect(perfect.rank?.display == "見習い雀士 Lv10")
        #expect(sloppy.rank?.display == "見習い雀士 Lv5")
    }
}
