import SwiftUI
import UIKit
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
    static let cream = Color(red: 1, green: 0.996, blue: 0.973)

    /// 萬子の書体。書道寄りの明朝を優先し、無ければ順に落とす。
    /// 端末に入っている名前は機種とOSで変わるので、実物を見て決めない。
    static let manFontName: String? = [
        "ToppanBunkyuMidashiMincho-ExtraBold",
        "YuKyokasho-Bold",
        "HiraMinProN-W6",
        "HiraginoSans-W7",
    ].first { UIFont(name: $0, size: 12) != nil }

    static func manFont(size: CGFloat) -> Font {
        if let name = manFontName { return .custom(name, size: size) }
        return .system(size: size, weight: .black, design: .serif)
    }
}

/// 牌1枚。絵柄と地色だけを描く。枠や点数は外側で足す。
struct TileView: View {
    let tile: Tile
    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / TileFace.unit.width
            ZStack {
                RoundedRectangle(cornerRadius: 6 * scale)
                    .fill(LinearGradient(colors: [TileFace.cream,
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

/// 萬子は漢数字と「萬」の2段。実物に寄せて太めの明朝で組む。
private struct ManFace: View {
    let number: Int
    let scale: CGFloat
    var body: some View {
        VStack(spacing: -2 * scale) {
            Text(TileFace.kanji[number])
                .font(TileFace.manFont(size: 31 * scale))
                .foregroundStyle(TileFace.dark)
            Text("萬")
                .font(TileFace.manFont(size: 27 * scale))
                .foregroundStyle(TileFace.manRed)
        }
        .minimumScaleFactor(0.5)
    }
}

/// 筒子。実物と同じく中を塗った同心円にする。
/// 外の輪 → 白 → 中心の点、の3層。
private struct PinDot: View {
    let radius: CGFloat
    let color: Color
    var body: some View {
        ZStack {
            Circle().fill(color)
            Circle().fill(TileFace.cream).frame(width: radius * 1.12, height: radius * 1.12)
            Circle().fill(color).frame(width: radius * 0.5, height: radius * 0.5)
        }
        .frame(width: radius * 2, height: radius * 2)
    }
}

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
                PinDot(radius: number == 1 ? radius * 1.15 : radius,
                       color: reds.contains(index) ? TileFace.red : TileFace.dark)
                    .position(x: point.x * scale, y: point.y * scale)
            }
        }
    }
}

/// 索子の竹1本。節を入れて、上下の端を少し膨らませる。
private struct BambooStick: View {
    let height: CGFloat
    let color: Color
    var body: some View {
        let width = max(3, height * 0.38)
        ZStack {
            Capsule().fill(color).frame(width: width, height: height)
            // 節。竹らしさはここで出る
            VStack(spacing: height * 0.26) {
                Capsule().fill(TileFace.cream).frame(width: width * 0.92, height: max(1, height * 0.075))
                Capsule().fill(TileFace.cream).frame(width: width * 0.92, height: max(1, height * 0.075))
            }
            // 端の膨らみ
            VStack {
                Capsule().fill(color).frame(width: width * 1.28, height: height * 0.13)
                Spacer()
                Capsule().fill(color).frame(width: width * 1.28, height: height * 0.13)
            }
            .frame(height: height)
        }
        .frame(width: width * 1.3, height: height)
    }
}

/// 索子は竹。1索だけ鳥。
private struct SouFace: View {
    let number: Int
    let scale: CGFloat
    var body: some View {
        if number == 1 {
            PhoenixFace(scale: scale)
        } else {
            let positions = TileFace.souPositions[number] ?? []
            let height = (TileFace.souHeight[number] ?? 20) * scale
            let reds = TileFace.souRed[number] ?? []
            let angles = TileFace.souAngle[number] ?? []
            ZStack(alignment: .topLeading) {
                Color.clear
                ForEach(Array(positions.enumerated()), id: \.offset) { index, point in
                    BambooStick(height: height,
                                color: reds.contains(index) ? TileFace.red : TileFace.dark)
                        .rotationEffect(.degrees(index < angles.count ? angles[index] : 0))
                        .position(x: point.x * scale, y: point.y * scale)
                }
            }
        }
    }
}

/// 1索の鳳凰。実物の一索は孔雀・鳳凰の意匠なので、
/// 尾羽が扇のように広がり、冠羽と翼がはっきり分かる形にする。
private struct PhoenixFace: View {
    let scale: CGFloat

    private let ink = TileFace.dark
    private let accent = TileFace.red

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            // 尾羽。下へ扇状に5枚広げる。これがあると鳳凰に見える
            ForEach(0..<5, id: \.self) { i in
                let t = Double(i) - 2                       // -2...2
                TailFeather()
                    .fill(i % 2 == 1 ? accent : ink)
                    .frame(width: 5.5 * scale, height: (30 - abs(t) * 5) * scale)
                    .rotationEffect(.degrees(t * 21), anchor: .top)
                    .position(x: 31 * scale, y: 46 * scale)
            }

            // 胴。頭から胸、腹へ流れる
            BodyShape()
                .fill(ink)
                .frame(width: 27 * scale, height: 32 * scale)
                .position(x: 28 * scale, y: 30 * scale)

            // 翼。地色で抜いて羽の重なりを出す
            WingShape()
                .fill(TileFace.cream)
                .frame(width: 19 * scale, height: 15 * scale)
                .position(x: 32 * scale, y: 33 * scale)
            WingShape()
                .stroke(ink, lineWidth: 1.1 * scale)
                .frame(width: 19 * scale, height: 15 * scale)
                .position(x: 32 * scale, y: 33 * scale)

            // 冠羽。頭の上に3本
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(accent)
                    .frame(width: 2.2 * scale, height: (10 - Double(i) * 1.6) * scale)
                    .rotationEffect(.degrees(-46 + Double(i) * 17), anchor: .bottom)
                    .position(x: (21 + Double(i) * 2.6) * scale, y: 11.5 * scale)
            }

            // くちばしと目
            BeakShape().fill(accent)
                .frame(width: 8 * scale, height: 6 * scale)
                .position(x: 14.5 * scale, y: 21 * scale)
            Circle().fill(TileFace.cream)
                .frame(width: 3.2 * scale, height: 3.2 * scale)
                .position(x: 22 * scale, y: 19.5 * scale)
            Circle().fill(ink)
                .frame(width: 1.4 * scale, height: 1.4 * scale)
                .position(x: 22 * scale, y: 19.5 * scale)

            // 脚
            Capsule().fill(accent)
                .frame(width: 1.8 * scale, height: 7 * scale)
                .rotationEffect(.degrees(-12))
                .position(x: 26 * scale, y: 46 * scale)
        }
    }

    /// 頭・胸・腹がひと続きになった胴
    private struct BodyShape: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            let w = r.width, h = r.height
            p.move(to: CGPoint(x: w * 0.26, y: h * 0.10))            // 頭の上
            p.addQuadCurve(to: CGPoint(x: w * 0.62, y: h * 0.30),     // 首の後ろ
                           control: CGPoint(x: w * 0.58, y: h * 0.06))
            p.addQuadCurve(to: CGPoint(x: w * 0.86, y: h * 0.72),     // 背
                           control: CGPoint(x: w * 0.92, y: h * 0.44))
            p.addQuadCurve(to: CGPoint(x: w * 0.40, y: h * 0.98),     // 尾のつけ根
                           control: CGPoint(x: w * 0.72, y: h * 0.96))
            p.addQuadCurve(to: CGPoint(x: w * 0.14, y: h * 0.44),     // 腹
                           control: CGPoint(x: w * 0.10, y: h * 0.78))
            p.addQuadCurve(to: CGPoint(x: w * 0.26, y: h * 0.10),     // 喉
                           control: CGPoint(x: w * 0.06, y: h * 0.16))
            p.closeSubpath()
            return p
        }
    }

    /// 胴に重ねる翼
    private struct WingShape: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            let w = r.width, h = r.height
            p.move(to: CGPoint(x: w * 0.06, y: h * 0.22))
            p.addQuadCurve(to: CGPoint(x: w * 0.98, y: h * 0.66),
                           control: CGPoint(x: w * 0.66, y: h * 0.02))
            p.addQuadCurve(to: CGPoint(x: w * 0.06, y: h * 0.22),
                           control: CGPoint(x: w * 0.42, y: h * 0.92))
            p.closeSubpath()
            return p
        }
    }

    /// 1枚の尾羽。先を細くする
    private struct TailFeather: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            let w = r.width, h = r.height
            p.move(to: CGPoint(x: w * 0.5, y: 0))
            p.addQuadCurve(to: CGPoint(x: w * 0.5, y: h),
                           control: CGPoint(x: w * 1.35, y: h * 0.62))
            p.addQuadCurve(to: CGPoint(x: w * 0.5, y: 0),
                           control: CGPoint(x: w * -0.35, y: h * 0.62))
            p.closeSubpath()
            return p
        }
    }

    private struct BeakShape: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.width, y: r.height * 0.10))
            p.addLine(to: CGPoint(x: 0, y: r.height * 0.5))
            p.addLine(to: CGPoint(x: r.width, y: r.height * 0.92))
            p.closeSubpath()
            return p
        }
    }
}
