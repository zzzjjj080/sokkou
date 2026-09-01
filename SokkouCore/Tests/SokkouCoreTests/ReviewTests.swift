import Foundation
import Testing
@testable import SokkouCore

/// 外した局面のたまり場。あとでまとめて解き直すために取っておく。
struct ReviewTests {

    /// seed ごとに必ず別の局面を作る。
    ///
    /// idは「手牌とツモ牌を区別しない14枚」なので、単に2箇所を振るだけだと
    /// 裏返しの組み合わせが同じidになってしまう。**14枚の中身そのものが
    /// 別になる**ように、昇順の組(a ≤ b)で作る。
    static let variations: [(Int, Int)] = {
        var out: [(Int, Int)] = []
        for a in 10..<Tile.kindCount {
            for b in a..<Tile.kindCount { out.append((a, b)) }
        }
        return out      // 153通り
    }()

    func position(_ seed: Int, chosen: Int = 0) -> ReviewPosition {
        let (a, b) = Self.variations[seed % Self.variations.count]
        return ReviewPosition(hand: [0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, a, b],
                              drawn: 9, chosen: chosen)
    }

    @Test("テスト用の局面が seed ごとに別物になっている")
    func helperMakesDistinctPositions() {
        #expect(Self.variations.count >= 130, "テストで使う件数を賄えること")
        #expect(Set((0..<130).map { position($0).id }).count == 130)
    }

    @Test("覚えた順に溜まり、新しい順で取り出せる")
    func keepsOrder() {
        var store = ReviewStore()
        for i in 0..<3 { store.record(position(i)) }
        #expect(store.count == 3)
        #expect(store.newestFirst.first == store.positions.last)
    }

    @Test("上限は100件。超えたら古いものから捨てる")
    func capsAtOneHundred() {
        var store = ReviewStore()
        for i in 0..<130 { store.record(position(i)) }
        #expect(store.count == ReviewStore.capacity)
        // 最初の30件は押し出されている
        #expect(store.positions.contains(position(0)) == false)
        #expect(store.positions.contains(position(129)))
    }

    @Test("同じ14枚は二重に溜めない")
    func doesNotDuplicate() {
        var store = ReviewStore()
        store.record(position(5, chosen: 1))
        store.record(position(5, chosen: 2))
        #expect(store.count == 1, "選んだ牌が違っても同じ局面なら1件")
        #expect(store.positions.first?.chosen == 2, "新しいほうで上書きされる")
    }

    @Test("同じ局面を覚え直すと、いちばん新しい位置へ移る")
    func reRecordMovesToNewest() {
        var store = ReviewStore()
        for i in 0..<3 { store.record(position(i)) }
        store.record(position(0))
        #expect(store.newestFirst.first?.id == position(0).id)
        #expect(store.count == 3)
    }

    @Test("消せる")
    func removes() {
        var store = ReviewStore()
        for i in 0..<3 { store.record(position(i)) }
        store.remove(id: position(1).id)
        #expect(store.count == 2)
        store.removeAll()
        #expect(store.isEmpty)
    }

    @Test("手牌の並び順が違っても同じ局面とみなす")
    func orderDoesNotMatter() {
        let a = ReviewPosition(hand: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], drawn: 20, chosen: 0)
        let b = ReviewPosition(hand: [12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0], drawn: 20, chosen: 5)
        #expect(a.id == b.id)
    }

    @Test("14枚として採点にかけられる")
    func rebuildsFourteenTiles() {
        let p = position(7)
        #expect(p.fourteen?.total == 14)
        #expect(p.handTiles.count == 13)
        #expect(p.drawnTile != nil)
    }

    @Test("書いて読んで同じになる")
    func roundTrips() throws {
        var store = ReviewStore()
        for i in 0..<12 { store.record(position(i)) }
        let data = try JSONEncoder().encode(store)
        #expect(try JSONDecoder().decode(ReviewStore.self, from: data) == store)
    }

    @Test("空のJSONでも落ちない")
    func decodesEmptyObject() throws {
        let store = try JSONDecoder().decode(ReviewStore.self, from: Data("{}".utf8))
        #expect(store.isEmpty)
    }

    @Test("上限を超えた保存データは読み込み時に切り詰める")
    func trimsOversizedSavedData() throws {
        let many = (0..<150).map { position($0) }
        let data = try JSONEncoder().encode(ReviewStore(positions: many))
        let loaded = try JSONDecoder().decode(ReviewStore.self, from: data)
        #expect(loaded.count == ReviewStore.capacity)
    }
}
