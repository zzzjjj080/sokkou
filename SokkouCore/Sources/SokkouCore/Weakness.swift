import Foundation

/// 手牌の中で、その牌がどんな役割だったか。
///
/// **決め打ちの優先順位で分ける。** 2334 のように1枚が対子とターツの
/// 両方に属する形があるので、多少粗くても**同じ手なら毎回同じ答え**を返すことを
/// 優先している。
public enum TileRole: Sendable, Equatable {
    /// 3枚以上ある
    case triplet
    /// 4枚以上つながった塊の一部（2234・3556 など）
    case complex
    /// ちょうど2枚
    case pair
    /// 隣り合う2枚。両端が伸びる（34 など）
    case ryanmen
    /// 1つ飛ばし（35 など）
    case kanchan
    /// 端に寄った隣接（12・89）
    case penchan
    /// すでに3枚そろって順子になっている
    case meld
    /// 近くに何も無い浮き牌
    case isolated

    /// ターツ（2枚の組）か
    public var isTartsu: Bool {
        self == .ryanmen || self == .kanchan || self == .penchan
    }
}

/// 外し方の分類。**「なぜ劣るか」ではなく「どんな形で外したか」**を見る。
///
/// 理由（受け入れ・伸びしろ）は打牌のたびに1行で出しているので、
/// ここは本に載っている形の分類に寄せて、練習の指針になるようにする。
public enum WeaknessTag: String, Sendable, Codable, CaseIterable {
    case isolated = "isolated"
    case tartsuChoice = "tartsuChoice"
    case brokeTartsu = "brokeTartsu"
    case pair = "pair"
    case complex = "complex"
    case shantenBack = "shantenBack"

    public var label: String {
        switch self {
        case .isolated: "孤立牌の選び方"
        case .tartsuChoice: "ターツ選択"
        case .brokeTartsu: "ターツを壊した"
        case .pair: "対子の扱い"
        case .complex: "複合形の見切り"
        case .shantenBack: "シャンテン戻し"
        }
    }

    /// 一覧に出す順。よく出るものから
    public static let displayOrder: [WeaknessTag] =
        [.isolated, .tartsuChoice, .brokeTartsu, .pair, .complex, .shantenBack]
}

public enum WeaknessClassifier {

    /// 14枚の中で、その牌が担っていた役割
    public static func role(of tile: Tile, in hand: TileCounts) -> TileRole {
        let n = tile.number
        let count = hand[tile]
        guard count > 0 else { return .isolated }
        if count >= 3 { return .triplet }

        func at(_ number: Int) -> Int {
            guard (1...9).contains(number) else { return 0 }
            return hand[Tile(tile.suit, number)]
        }

        // つながった塊の大きさ。**間の1つ空きまでを同じ塊とみなす**
        // （3556 のような形をひとまとまりで見るため）
        var total = count
        var number = n
        while number > 1, at(number - 1) > 0 || (number > 2 && at(number - 2) > 0) {
            number -= 1
            total += at(number)
        }
        number = n
        while number < 9, at(number + 1) > 0 || (number < 8 && at(number + 2) > 0) {
            number += 1
            total += at(number)
        }
        if total >= 4 { return .complex }

        if count == 2 { return .pair }
        if at(n - 1) > 0 && at(n + 1) > 0 { return .meld }
        if at(n + 1) > 0 { return n == 1 ? .penchan : .ryanmen }
        if at(n - 1) > 0 { return n == 9 ? .penchan : .ryanmen }
        if at(n - 2) > 0 || at(n + 2) > 0 { return .kanchan }
        return .isolated
    }

    /// 切った牌と最善の牌の役割から、外し方を1つに決める
    public static func tag(hand: TileCounts, chosen: Tile, best: Tile,
                           isShantenBack: Bool) -> WeaknessTag {
        if isShantenBack { return .shantenBack }
        let mine = role(of: chosen, in: hand)
        let target = role(of: best, in: hand)

        if mine == .complex || target == .complex { return .complex }
        if mine == .pair || target == .pair || mine == .triplet || target == .triplet {
            return .pair
        }
        if mine.isTartsu && target.isTartsu { return .tartsuChoice }
        if (mine.isTartsu || mine == .meld) && target == .isolated { return .brokeTartsu }
        if mine == .isolated && target == .isolated { return .isolated }
        return .tartsuChoice
    }
}
