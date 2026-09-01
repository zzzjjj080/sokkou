import SwiftUI
import UIKit

/// 明るい画面と暗い画面で色を切り替える。
///
/// 金色や黄緑は暗い背景でしか読めない。明るい背景では白飛びするので、
/// **文字に使う色は明るい側だけ濃くする。** 牌はどちらでも生成色のままでよい
/// （クリーム色なので、背景に少し灰色を混ぜて牌との境目を作る）。
enum Palette {
    private static func adaptive(dark: (Double, Double, Double),
                                 light: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }

    /// 画面の地
    static let background = adaptive(dark: (0.106, 0.122, 0.141),
                                     light: (0.867, 0.882, 0.898))
    /// シートやカードの地
    static let panel = adaptive(dark: (0.149, 0.169, 0.200),
                                light: (0.973, 0.976, 0.980))

    /// 称号・巡目・最速。**明るい側は白飛びするので山吹色まで落とす**
    static let gold = adaptive(dark: (1, 0.835, 0.290),
                               light: (0.667, 0.478, 0.020))
    /// 金色の面の上に置く文字
    static let goldInk = adaptive(dark: (0.14, 0.11, 0.01),
                                  light: (0.16, 0.12, 0.01))
    /// 金色の面（バッジ・メーター）。ここは両方で明るいままでよい
    static let goldFill = adaptive(dark: (0.910, 0.725, 0.227),
                                   light: (0.949, 0.769, 0.243))

    /// 正解の文字
    static let green = adaptive(dark: (0.42, 0.85, 0.55),
                                light: (0.106, 0.478, 0.243))
    /// 正解の枠・面
    static let greenRing = adaptive(dark: (0.247, 0.627, 0.373),
                                    light: (0.133, 0.510, 0.271))
    static let greenFill = adaptive(dark: (0.180, 0.490, 0.275),
                                    light: (0.145, 0.475, 0.278))

    /// 外したときの文字
    static let miss = adaptive(dark: (1, 0.60, 0.55),
                               light: (0.769, 0.184, 0.137))
    /// 自分が選んだ牌の枠
    static let chosen = adaptive(dark: (0.290, 0.490, 1),
                                 light: (0.114, 0.353, 0.878))
    /// ヒントの枠
    static let hintRing = adaptive(dark: (1, 0.231, 0.188),
                                   light: (0.831, 0.145, 0.106))

    /// 点数バッジの地（最善でも正解でもない牌）
    static let neutralFill = adaptive(dark: (0.227, 0.251, 0.282),
                                      light: (0.396, 0.427, 0.467))
    /// シャンテン戻しのバッジの地
    static let backFill = adaptive(dark: (0.35, 0.24, 0.24),
                                   light: (0.510, 0.322, 0.310))
    /// 色の付いた面の上に置く文字。地を濃く保っているのでどちらでも白
    static let onFill = Color.white

    /// 伸びたばかりの経験値
    static let freshExp = adaptive(dark: (0.55, 1, 0.65),
                                   light: (0.180, 0.702, 0.353))
    /// 経験値メーターの溝
    static let track = Color.primary.opacity(0.12)
    /// うっすら地を作りたいとき
    static let faintFill = Color.primary.opacity(0.05)
    /// 区切り線
    static let hairline = Color.primary.opacity(0.15)

    /// 表の見出し
    static let heading = adaptive(dark: (0.62, 0.75, 1),
                                  light: (0.157, 0.322, 0.694))
    /// 外した回を表す点
    static let missDot = adaptive(dark: (0.85, 0.35, 0.30),
                                  light: (0.741, 0.204, 0.157))
}
