import Foundation
import Testing
@testable import SokkouCore

/// 外し方の分類。**手で選んだ形で、狙った答えが出るかを見る。**
///
/// 判定は決め打ちの優先順位でできているので「正解」があるわけではない。
/// ここで守りたいのは、代表的な形が意図どおりに分かれることと、
/// 同じ手なら毎回同じ答えが返ること。
struct WeaknessTests {

    static func hand(_ text: String) -> TileCounts { ShantenTests.hand(text) }

    func role(_ text: String, _ tile: Tile) -> TileRole {
        WeaknessClassifier.role(of: tile, in: Self.hand(text))
    }

    // MARK: - 役割の判定

    @Test("浮いている牌は孤立")
    func findsIsolated() {
        // 1萬 は 2萬3萬 から離れている
        #expect(role("1456m", Tile(.man, 1)) == .isolated)
    }

    @Test("隣り合う2枚は両面、端なら辺張")
    func findsRuns() {
        #expect(role("34m", Tile(.man, 3)) == .ryanmen)
        #expect(role("12m", Tile(.man, 1)) == .penchan)
        #expect(role("89m", Tile(.man, 9)) == .penchan)
    }

    @Test("1つ飛ばしは嵌張")
    func findsKanchan() {
        #expect(role("35m", Tile(.man, 3)) == .kanchan)
    }

    @Test("2枚は対子、3枚は暗刻")
    func findsPairAndTriplet() {
        #expect(role("55m", Tile(.man, 5)) == .pair)
        #expect(role("555m", Tile(.man, 5)) == .triplet)
    }

    @Test("そろった順子は面子")
    func findsMeld() {
        #expect(role("345m", Tile(.man, 4)) == .meld)
    }

    @Test("4枚以上つながった塊は複合形")
    func findsComplex() {
        // 2234 は対子と両面が重なった形。対子ではなく複合形として見る
        #expect(role("2234m", Tile(.man, 2)) == .complex)
        // 3556 は1つ空きを挟んでつながっている
        #expect(role("3556m", Tile(.man, 5)) == .complex)
    }

    // MARK: - 外し方の分類

    func tag(_ text: String, chosen: Tile, best: Tile, back: Bool = false) -> WeaknessTag {
        WeaknessClassifier.tag(hand: Self.hand(text), chosen: chosen, best: best,
                               isShantenBack: back)
    }

    @Test("戻しは形を見るまでもなく戻し")
    func shantenBackWins() {
        #expect(tag("345m", chosen: Tile(.man, 4), best: Tile(.man, 3), back: true)
                == .shantenBack)
    }

    @Test("浮き牌どうしの比較は孤立牌の選び方")
    func isolatedPair() {
        // 1萬 と 9筒 はどちらも浮いている
        #expect(tag("1m456m9p", chosen: Tile(.man, 1), best: Tile(.pin, 9)) == .isolated)
    }

    @Test("ターツどうしの比較はターツ選択")
    func tartsuChoice() {
        // 34萬(両面) と 13筒(嵌張) のどちらを残すか
        #expect(tag("34m13p", chosen: Tile(.man, 3), best: Tile(.pin, 1)) == .tartsuChoice)
    }

    @Test("浮き牌を切ればよかったのにターツから切った")
    func brokeTartsu() {
        #expect(tag("34m9p", chosen: Tile(.man, 3), best: Tile(.pin, 9)) == .brokeTartsu)
    }

    @Test("対子が絡めば対子の扱い")
    func pairInvolved() {
        #expect(tag("55m9p", chosen: Tile(.man, 5), best: Tile(.pin, 9)) == .pair)
    }

    @Test("複合形が絡めば複合形の見切り")
    func complexInvolved() {
        #expect(tag("2234m9p", chosen: Tile(.man, 2), best: Tile(.pin, 9)) == .complex)
    }

    @Test("同じ手なら毎回同じ答えを返す")
    func isStable() {
        let first = tag("2234m13p9s", chosen: Tile(.pin, 1), best: Tile(.man, 2))
        for _ in 0..<5 {
            #expect(tag("2234m13p9s", chosen: Tile(.pin, 1), best: Tile(.man, 2)) == first)
        }
    }

    // MARK: - たまり場の集計

    func position(_ seed: Int, tag: WeaknessTag?) -> ReviewPosition {
        ReviewPosition(hand: [0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 + seed % 10, 20],
                       drawn: 9, chosen: 0, tag: tag)
    }

    @Test("形ごとに数えられる")
    func countsByTag() {
        var store = ReviewStore()
        for i in 0..<3 { store.record(position(i, tag: .tartsuChoice)) }
        for i in 3..<5 { store.record(position(i, tag: .isolated)) }
        #expect(store.tagCounts[.tartsuChoice] == 3)
        #expect(store.tagCounts[.isolated] == 2)
        #expect(store.topTag?.tag == .tartsuChoice)
        #expect(store.topTag?.count == 3)
    }

    @Test("形で絞って取り出せる")
    func filtersByTag() {
        var store = ReviewStore()
        for i in 0..<3 { store.record(position(i, tag: .tartsuChoice)) }
        for i in 3..<5 { store.record(position(i, tag: .pair)) }
        #expect(store.newestFirst(tag: .pair).count == 2)
        #expect(store.newestFirst(tag: nil).count == 5)
        #expect(store.newestFirst(tag: .complex).isEmpty)
    }

    @Test("分類の無い古い記録が混ざっても壊れない")
    func toleratesOldRecords() throws {
        var store = ReviewStore()
        store.record(position(0, tag: nil))
        store.record(position(1, tag: .pair))
        #expect(store.count == 2)
        #expect(store.tagCounts[.pair] == 1, "分類の無いものは数えない")
        #expect(store.topTag?.tag == .pair)
        // 書いて読んでも同じ
        let data = try JSONEncoder().encode(store)
        #expect(try JSONDecoder().decode(ReviewStore.self, from: data) == store)
    }

    @Test("tag の項目が無いJSONも読める")
    func decodesWithoutTag() throws {
        let json = """
        {"positions":[{"hand":[0,1,2,3,4,5,6,7,8,9,10,11,12],"drawn":20,"chosen":0}]}
        """
        let store = try JSONDecoder().decode(ReviewStore.self, from: Data(json.utf8))
        #expect(store.count == 1)
        #expect(store.positions.first?.tag == nil)
    }

    // MARK: - 壊れた記録

    @Test("14枚にならない記録は使えないと分かる")
    func rejectsBrokenRecords() {
        // 27種しかないので、それ以上の番号は牌にならない
        let broken = ReviewPosition(hand: [0, 1, 5, 5, 7, 8, 10, 11, 12, 18, 21, 24, 99],
                                    drawn: 25, chosen: 0)
        #expect(broken.isUsable == false, "牌にならない番号が混じれば弾く")

        let short = ReviewPosition(hand: [0, 1, 2], drawn: 25, chosen: 0)
        #expect(short.isUsable == false, "枚数が足りなければ弾く")

        let good = ReviewPosition(hand: [0, 1, 5, 5, 7, 8, 10, 11, 12, 18, 21, 24, 25],
                                  drawn: 25, chosen: 0)
        #expect(good.isUsable, "まともな記録は通す")
    }

    @Test("壊れた記録が混ざったJSONも読める")
    func decodesBrokenRecords() throws {
        let json = """
        {"positions":[
          {"hand":[0,1,5,5,7,8,10,11,12,18,21,24,99],"drawn":25,"chosen":0},
          {"hand":[0,1,5,5,7,8,10,11,12,18,21,24,25],"drawn":25,"chosen":0}
        ]}
        """
        let store = try JSONDecoder().decode(ReviewStore.self, from: Data(json.utf8))
        #expect(store.count == 2, "読むところでは落とさない")
        #expect(store.positions.filter(\.isUsable).count == 1, "使えるのは1件だけ")
    }
}
