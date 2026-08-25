import SwiftUI
import SokkouCore

/// 牌の絵柄。Web版で作ったSVGの座標をそのまま移してある。
/// 基準は 60×80 の座標系で、表示サイズに合わせて拡大する。
enum TileFace {
    static let unit = CGSize(width: 60, height: 80)

    static let kanji = ["", "一", "二", "三", "四", "伍", "六", "七", "八", "九"]

    /// 筒子の丸の位置
    static let pinPositions: [Int: [CGPoint]] = [
        1: [.init(x: 30, y: 40)],
        2: [.init(x: 30, y: 26), .init(x: 30, y: 54)],
        3: [.init(x: 44, y: 22), .init(x: 30, y: 40), .init(x: 16, y: 58)],
        4: [.init(x: 20, y: 26), .init(x: 40, y: 26), .init(x: 20, y: 54), .init(x: 40, y: 54)],
        5: [.init(x: 19, y: 25), .init(x: 41, y: 25), .init(x: 30, y: 40),
            .init(x: 19, y: 55), .init(x: 41, y: 55)],
        6: [.init(x: 19, y: 19), .init(x: 41, y: 19), .init(x: 19, y: 45),
            .init(x: 41, y: 45), .init(x: 19, y: 64), .init(x: 41, y: 64)],
        7: [.init(x: 44, y: 14), .init(x: 30, y: 22), .init(x: 16, y: 30), .init(x: 20, y: 52),
            .init(x: 40, y: 52), .init(x: 20, y: 67), .init(x: 40, y: 67)],
        8: [.init(x: 21, y: 17), .init(x: 39, y: 17), .init(x: 21, y: 32), .init(x: 39, y: 32),
            .init(x: 21, y: 48), .init(x: 39, y: 48), .init(x: 21, y: 63), .init(x: 39, y: 63)],
        9: [.init(x: 16, y: 22), .init(x: 30, y: 22), .init(x: 44, y: 22),
            .init(x: 16, y: 40), .init(x: 30, y: 40), .init(x: 44, y: 40),
            .init(x: 16, y: 58), .init(x: 30, y: 58), .init(x: 44, y: 58)],
    ]
    /// 赤くする丸の位置（実物の意匠に合わせてある）
    static let pinRed: [Int: Set<Int>] = [
        3: [1], 5: [2], 6: [2, 3, 4, 5], 7: [3, 4, 5, 6], 9: [3, 4, 5],
    ]
    static let pinRadius: [Int: CGFloat] = [
        1: 13, 2: 10.5, 3: 10, 4: 9.4, 5: 8.8, 6: 8.4, 7: 7.2, 8: 7.1, 9: 7.5,
    ]

    /// 索子の竹の位置
    static let souPositions: [Int: [CGPoint]] = [
        2: [.init(x: 30, y: 26), .init(x: 30, y: 54)],
        3: [.init(x: 30, y: 21), .init(x: 21, y: 55), .init(x: 39, y: 55)],
        4: [.init(x: 20, y: 25), .init(x: 40, y: 25), .init(x: 20, y: 55), .init(x: 40, y: 55)],
        5: [.init(x: 19, y: 24), .init(x: 41, y: 24), .init(x: 30, y: 40),
            .init(x: 19, y: 56), .init(x: 41, y: 56)],
        6: [.init(x: 16, y: 26), .init(x: 30, y: 26), .init(x: 44, y: 26),
            .init(x: 16, y: 55), .init(x: 30, y: 55), .init(x: 44, y: 55)],
        7: [.init(x: 30, y: 17), .init(x: 16, y: 41), .init(x: 30, y: 41), .init(x: 44, y: 41),
            .init(x: 16, y: 62), .init(x: 30, y: 62), .init(x: 44, y: 62)],
        8: [.init(x: 14, y: 25), .init(x: 24, y: 25), .init(x: 36, y: 25), .init(x: 46, y: 25),
            .init(x: 14, y: 56), .init(x: 24, y: 56), .init(x: 36, y: 56), .init(x: 46, y: 56)],
        9: [.init(x: 16, y: 20), .init(x: 30, y: 20), .init(x: 44, y: 20),
            .init(x: 16, y: 40), .init(x: 30, y: 40), .init(x: 44, y: 40),
            .init(x: 16, y: 60), .init(x: 30, y: 60), .init(x: 44, y: 60)],
    ]
    static let souHeight: [Int: CGFloat] = [2: 26, 3: 22, 4: 24, 5: 21, 6: 21, 7: 18, 8: 20, 9: 17]
    /// 赤が入るのは5索(中央)・7索(上)・9索(真ん中の列)
    static let souRed: [Int: Set<Int>] = [5: [2], 7: [0], 9: [3, 4, 5]]
    /// 8索は上段が「M」、下段が「W」に見える配置（実物の意匠）
    static let souAngle: [Int: [Double]] = [8: [22, -22, 22, -22, -22, 22, -22, 22]]

    static let dark = Color(red: 0.149, green: 0.204, blue: 0.302)   // #26344d
    static let red = Color(red: 0.659, green: 0.196, blue: 0.165)    // #a8322a
    static let manRed = Color(red: 0.557, green: 0.165, blue: 0.145) // #8e2a25
}

/// 牌1枚。絵柄と地色だけを描く。枠や点数は外側で足す。
struct TileView: View {
    let tile: Tile
    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / TileFace.unit.width
            ZStack {
                RoundedRectangle(cornerRadius: 6 * scale)
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.996, blue: 0.973),
                                                  Color(red: 0.957, green: 0.933, blue: 0.855)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 6 * scale)
                        .stroke(Color(red: 0.788, green: 0.741, blue: 0.573), lineWidth: 1))
                face(scale: scale)
            }
        }
        .aspectRatio(TileFace.unit.width / TileFace.unit.height, contentMode: .fit)
    }

    @ViewBuilder
    private func face(scale: CGFloat) -> some View {
        switch tile.suit {
        case .man: ManFace(number: tile.number, scale: scale)
        case .pin: PinFace(number: tile.number, scale: scale)
        case .sou: SouFace(number: tile.number, scale: scale)
        }
    }
}

/// 萬子は漢数字と「萬」の2段
private struct ManFace: View {
    let number: Int
    let scale: CGFloat
    var body: some View {
        VStack(spacing: 0) {
            Text(TileFace.kanji[number])
                .font(.system(size: 30 * scale, weight: .bold, design: .serif))
                .foregroundStyle(TileFace.dark)
            Text("萬")
                .font(.system(size: 24 * scale, weight: .bold, design: .serif))
                .foregroundStyle(TileFace.manRed)
        }
        .minimumScaleFactor(0.5)
    }
}

/// 筒子は輪の集まり
private struct PinFace: View {
    let number: Int
    let scale: CGFloat
    var body: some View {
        let positions = TileFace.pinPositions[number] ?? []
        let radius = (TileFace.pinRadius[number] ?? 9) * scale
        let reds = TileFace.pinRed[number] ?? []
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(Array(positions.enumerated()), id: \.offset) { index, point in
                let color = reds.contains(index) ? TileFace.red : TileFace.dark
                Circle()
                    .stroke(color, lineWidth: max(1, radius * 0.34))
                    .frame(width: radius * 1.6, height: radius * 1.6)
                    .position(x: point.x * scale, y: point.y * scale)
            }
            if number == 1 {
                // 1筒だけ中心に点を置く
                Circle().fill(TileFace.red)
                    .frame(width: radius * 0.55, height: radius * 0.55)
                    .position(x: 30 * scale, y: 40 * scale)
            }
        }
    }
}

/// 索子は竹。1索だけ鳥。
private struct SouFace: View {
    let number: Int
    let scale: CGFloat
    var body: some View {
        if number == 1 {
            BirdFace(scale: scale)
        } else {
            let positions = TileFace.souPositions[number] ?? []
            let height = (TileFace.souHeight[number] ?? 20) * scale
            let reds = TileFace.souRed[number] ?? []
            let angles = TileFace.souAngle[number] ?? []
            ZStack(alignment: .topLeading) {
                Color.clear
                ForEach(Array(positions.enumerated()), id: \.offset) { index, point in
                    let color = reds.contains(index) ? TileFace.red : TileFace.dark
                    Capsule()
                        .fill(color)
                        .frame(width: max(2, height * 0.34), height: height)
                        .rotationEffect(.degrees(index < angles.count ? angles[index] : 0))
                        .position(x: point.x * scale, y: point.y * scale)
                }
            }
        }
    }
}

/// 1索の鳥。細部まで似せず、輪郭が鳥に見えれば足りる。
private struct BirdFace: View {
    let scale: CGFloat
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            Ellipse().fill(TileFace.dark)
                .frame(width: 26 * scale, height: 30 * scale)
                .position(x: 30 * scale, y: 34 * scale)
            Circle().fill(Color(red: 1, green: 0.996, blue: 0.973))
                .frame(width: 5 * scale, height: 5 * scale)
                .position(x: 30 * scale, y: 26 * scale)
            Capsule().fill(TileFace.red)
                .frame(width: 4 * scale, height: 14 * scale)
                .position(x: 25 * scale, y: 58 * scale)
            Capsule().fill(TileFace.red)
                .frame(width: 4 * scale, height: 14 * scale)
                .position(x: 35 * scale, y: 58 * scale)
        }
    }
}
