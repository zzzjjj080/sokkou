import SwiftUI
import SokkouCore

/// 初回に一度だけ出す遊び方。設定からいつでも読み直せる。
///
/// 「戻し」「90点以上が正解」「ツモが優遇されている」の3つは、
/// 説明が無いと画面を見ただけでは分からない。ここで先に渡しておく。
struct IntroductionView: View {
    var onFinish: () -> Void

    @State private var page = 0
    private static let lastPage = 4

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    purpose.tag(0)
                    scoring.tag(1)
                    shantenBack.tag(2)
                    draws.tag(3)
                    growth.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                HStack {
                    Button("とばす", action: onFinish)
                        .font(.system(size: 15, weight: .bold))
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .opacity(page == Self.lastPage ? 0 : 1)
                    Spacer()
                    Button(page == Self.lastPage ? "はじめる" : "次へ") {
                        if page == Self.lastPage {
                            onFinish()
                        } else {
                            withAnimation { page += 1 }
                        }
                    }
                    .font(.system(size: 17, weight: .heavy))
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("intro-next")
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 14)
            }
        }
    }

    // MARK: - ページ

    private var purpose: some View {
        page(title: "最速で聴牌する1枚を選ぶ") {
            line("配られた手牌からツモを繰り返し、**いちばん早く聴牌できる打牌**を当てていきます。")
            line("打点・役・ドラ・場況は考えません。**速さだけ**の練習です。")
            line("字牌と赤5は使いません。七対子と国士無双も考えません。")
        }
    }

    private var scoring: some View {
        page(title: "最善が100点。90点以上で正解") {
            line("切ったあと、それぞれの牌に点数が付きます。**いちばん速い打牌を100点**として、"
                 + "そこからどれだけ遅くなるかを表した数字です。")
            HStack(spacing: 10) {
                chip("100", Palette.goldFill, Palette.goldInk, "最善")
                chip("94", Palette.greenFill, Palette.onFill, "正解")
                chip("71", Palette.neutralFill, Palette.onFill, "外し")
                chip("戻し", Palette.backFill, Palette.onFill, "対象外")
            }
            line("**最善が2つ以上ある局面もあります。** 差がごくわずかなときは、"
                 + "どちらを選んでも正解にしています。")
        }
    }

    private var shantenBack: some View {
        page(title: "「戻し」は採点しません") {
            line("聴牌から遠ざかる打牌には点数を付けず、**戻し**と表示します。")
            line("遠回りが有利になる場面は確かにありますが、それは打点や安全度を"
                 + "考えたときの話です。**このアプリは速さだけを見るので、判断材料が足りません。**"
                 + "無理に点数を付けると嘘になるため、採点から外しています。")
            line("外しの回数には数えます。最速聴牌を狙うなら選ばない1枚です。")
        }
    }

    private var draws: some View {
        page(title: "ツモは少しだけ優遇されています") {
            line("**約4割の確率で、手が進む牌を引きます。** 残りはふつうの山からの抽選です。")
            line("実戦どおりに引くと聴牌まで長くかかり、1局が終わりません。"
                 + "**練習の回数を増やすための調整**で、実戦より早く聴牌します。")
            line("聴牌したときに出る待ちの枚数と確率は、**調整なしの計算**です。"
                 + "そのまま実戦の目安に使えます。")
        }
    }

    private var growth: some View {
        page(title: "外さず聴牌するほど伸びます") {
            line("1局ごとに経験値が入ります。**外した回数が少ないほど多く**、"
                 + "一度も外さずに聴牌すると最大になります。")
            line("さらに、**最善（金色）をどれだけ選べたか**で最大1.5倍になります。")
            line("経験値がたまると称号とレベルが上がります。**最高位は神速雀士Lv10。**")
            line("外した局面は自動で残ります。設定の**「間違えた局面を復習」**から、"
                 + "まとめて解き直せます。")
        }
    }

    // MARK: - 部品

    private func page(title: String, @ViewBuilder content: () -> some View) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.system(size: 27, weight: .heavy))
                    .foregroundStyle(Palette.gold)
                content()
            }
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 34)
            .padding(.top, 18)
            .padding(.bottom, 30)
        }
    }

    private func line(_ markdown: String) -> some View {
        Text(.init(markdown))
            .font(.system(size: 17))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func chip(_ text: String, _ fill: Color, _ ink: Color, _ caption: String) -> some View {
        VStack(spacing: 4) {
            Text(text)
                .font(.system(size: text == "戻し" ? 13 : 18, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(ink)
                .frame(width: 62, height: 30)
                .background(fill, in: RoundedRectangle(cornerRadius: 7))
            Text(caption).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }
}
