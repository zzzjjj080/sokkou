import SwiftUI
import SokkouCore

/// 画面に並べる1枚ぶん。
struct HandSlot: Identifiable {
    let id: Int
    let tile: Tile
    let isDrawn: Bool
    /// ヒントの枠を出すか
    let showsHintRing: Bool
    /// 同じ牌が並んだときの1枚目か。
    /// **枠も点数も、切る候補としては同じ1種なので1枚目にだけ出す。**
    let isFirstOfKind: Bool
    /// 自分が選んで切った牌か
    var isChosen: Bool = false
}

enum HandLayout {
    /// 手牌13枚 + ツモ牌を並べる。
    ///
    /// 本編と復習で同じ規則を使うため、ここ1か所にまとめている。
    /// 同じ牌が2枚あっても切る候補としては1種なので、**枠と点数はその種類の
    /// 1枚目にだけ出す。** 2枚目にも出すと、同じものが2つ光って
    /// 「別々の候補」に見えてしまう。
    static func slots(hand: [Tile], drawn: Tile?, hintKinds: [Tile] = []) -> [HandSlot] {
        var seen = Set<Tile>()
        var slots: [HandSlot] = []
        func make(id: Int, tile: Tile, isDrawn: Bool) -> HandSlot {
            let isFirst = seen.insert(tile).inserted
            return HandSlot(id: id, tile: tile, isDrawn: isDrawn,
                            showsHintRing: isFirst && hintKinds.contains(tile),
                            isFirstOfKind: isFirst)
        }
        for (index, tile) in hand.enumerated() {
            slots.append(make(id: index, tile: tile, isDrawn: false))
        }
        if let drawn {
            slots.append(make(id: 100, tile: drawn, isDrawn: true))
        }
        return slots
    }

    /// 選んだ牌に印を付ける。同じ牌が2枚あるときは1枚目に付く
    static func marking(_ slots: [HandSlot], chosen: Tile) -> [HandSlot] {
        var copy = slots
        if let index = copy.firstIndex(where: { $0.tile == chosen }) {
            copy[index].isChosen = true
        }
        return copy
    }
}

/// 牌1枚と、その上下に出る点数・枠。本編と復習で共通。
struct TileSlotView: View {
    let slot: HandSlot
    let evaluation: Evaluation?
    /// 回答後か（点数と結果の枠を出す）
    let isRevealed: Bool
    var accessibilityID: String? = nil
    var onTap: () -> Void = {}

    var body: some View {
        VStack(spacing: 4) {
            badge
            TileView(tile: slot.tile)
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(ringColor, lineWidth: 3.5).padding(1.75))
                .onTapGesture(perform: onTap)
                .accessibilityIdentifier(accessibilityID ?? "tile-\(slot.id)")
            Text(slot.isDrawn ? "ツモ" : " ")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.gold)
        }
        .padding(.horizontal, 2)
    }

    private var ringColor: Color {
        guard let evaluation else { return .clear }
        guard isRevealed else {
            return slot.showsHintRing ? Palette.hintRing : .clear
        }
        // 自分が切った牌の印だけは、たとえ2枚目でも消さない
        if slot.isChosen, !evaluation.isCorrect(slot.tile) { return Palette.chosen }
        guard slot.isFirstOfKind else { return .clear }
        if evaluation.isBest(slot.tile) { return Palette.goldFill }
        if evaluation.isCorrect(slot.tile) { return Palette.greenRing }
        if slot.isChosen { return Palette.chosen }
        return .clear
    }

    @ViewBuilder
    private var badge: some View {
        if isRevealed, slot.isFirstOfKind, let option = evaluation?.option(for: slot.tile) {
            Text(option.score.map { "\($0)" } ?? "戻し")
                .font(.system(size: option.score == nil ? 11 : 17, weight: .heavy))
                .monospacedDigit()
                // 「100」は3桁あり、隣の「戻し」に押されると2行に折れてしまう
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(badgeInk(option))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(badgeFill(option), in: RoundedRectangle(cornerRadius: 6))
        } else {
            Text(" ").font(.system(size: 17, weight: .heavy))
        }
    }

    private func badgeFill(_ option: DiscardOption) -> Color {
        guard let evaluation else { return Palette.neutralFill }
        if option.isShantenBack { return Palette.backFill }
        if evaluation.isBest(option.tile) { return Palette.goldFill }
        if evaluation.isCorrect(option.tile) { return Palette.greenFill }
        return Palette.neutralFill
    }

    private func badgeInk(_ option: DiscardOption) -> Color {
        guard let evaluation else { return Palette.onFill }
        return evaluation.isBest(option.tile) ? Palette.goldInk : Palette.onFill
    }
}
