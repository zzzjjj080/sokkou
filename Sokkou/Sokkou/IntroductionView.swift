import SwiftUI
import SokkouCore

/// 初回に一度だけ出す遊び方。設定からいつでも読み直せる。
///
/// **文字は最小限にして、牌そのもので見せる。** 「戻し」「90点以上が正解」
/// 「ツモが優遇されている」の3つは、説明が無いと画面を見ただけでは分からない。
struct IntroductionView: View {
    var onFinish: () -> Void

    @State private var page = 0
    private static let lastPage = 3

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    purpose.tag(0)
                    scoring.tag(1)
                    draws.tag(2)
                    growth.tag(3)
                }
                // 標準の点は本文の上に重なって出るので使わない。下の行に自分で置く
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack {
                    Button("とばす", action: onFinish)
                        .font(.system(size: 17, weight: .bold))
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .opacity(page == Self.lastPage ? 0 : 1)
                        .accessibilityIdentifier("intro-skip")
                    Spacer()
                    HStack(spacing: 9) {
                        ForEach(0...Self.lastPage, id: \.self) { index in
                            Circle()
                                .fill(index == page ? Palette.gold : Palette.track)
                                .frame(width: 9, height: 9)
                        }
                    }
                    Spacer()
                    Button(page == Self.lastPage ? "はじめる" : "次へ") {
                        if page == Self.lastPage {
                            onFinish()
                        } else {
                            withAnimation { page += 1 }
                        }
                    }
                    .font(.system(size: 20, weight: .heavy))
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("intro-next")
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - ページ

    /// 何をするアプリか。手牌を並べて、選ぶ1枚を指す
    private var purpose: some View {
        page(title: "最速で聴牌する1枚を選ぶ") {
            HStack(spacing: 5) {
                ForEach(Self.sampleHand, id: \.index) { tile in
                    TileView(tile: tile).frame(width: 46)
                }
                Spacer().frame(width: 10)
                VStack(spacing: 3) {
                    TileView(tile: Tile(.sou, 9)).frame(width: 46)
                    Text("ツモ").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.gold)
                }
            }
            line("この14枚から、**いちばん早く聴牌できる1枚**を切ります。")
            small("打点・役・ドラ・場況は考えません。速さだけの練習です。"
                  + "字牌と赤5は使わず、七対子も考えません。")
        }
    }

    /// 点数の見方。実際のバッジの色そのままで見せる
    private var scoring: some View {
        page(title: "最善が100点・90点以上で正解") {
            HStack(spacing: 18) {
                sample(Tile(.man, 1), "100", Palette.goldFill, Palette.goldInk, "最善")
                sample(Tile(.pin, 5), "94", Palette.greenFill, Palette.onFill, "正解")
                sample(Tile(.sou, 3), "71", Palette.neutralFill, Palette.onFill, "遅い")
                sample(Tile(.man, 9), "戻し", Palette.backFill, Palette.onFill, "対象外")
            }
            line("切ったあと、**すべての牌に点数**が付きます。最善が2つ以上のこともあります。")
            small("「戻し」は聴牌から遠ざかる打牌。速さだけでは良し悪しを決められないので、"
                  + "点数を付けずに採点から外しています。")
        }
    }

    /// ツモの偏り。4割と6割を帯で見せる
    private var draws: some View {
        page(title: "ツモは少し優遇しています") {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Text("手が進む牌 4割")
                        .frame(width: geo.size.width * 0.4)
                        .background(Palette.goldFill)
                        .foregroundStyle(Palette.goldInk)
                    Text("ふつうの山 6割")
                        .frame(width: geo.size.width * 0.6)
                        .background(Palette.neutralFill)
                        .foregroundStyle(Palette.onFill)
                }
                .font(.system(size: 16, weight: .heavy))
                .frame(height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(height: 44)
            line("1局を短くするための調整です。**実戦より早く聴牌します。**")
            small("聴牌したときに出る待ちの枚数と確率は調整なしの計算なので、"
                  + "そのまま実戦の目安に使えます。")
        }
    }

    /// 経験値と復習
    private var growth: some View {
        page(title: "外さず聴牌するほど伸びる") {
            VStack(alignment: .leading, spacing: 6) {
                Text("見習い雀士 Lv3").font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Palette.gold)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.track)
                        Capsule().fill(Palette.goldFill)
                            .frame(width: geo.size.width * 0.62)
                    }
                }
                .frame(height: 14)
            }
            line("外しが少ないほど経験値が多く、**最善（金）を選ぶほど最大1.5倍**になります。")
            small("外した局面は自動で残ります。設定の「間違えた局面を復習」から解き直せます。")
        }
    }

    // MARK: - 部品

    /// 1ページぶんの枠。横画面なので幅を絞って中央に置く
    private func page(title: String, @ViewBuilder content: () -> some View) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(Palette.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                content()
            }
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 34)
            .padding(.top, 14)
            .padding(.bottom, 20)
        }
    }

    private func line(_ markdown: String) -> some View {
        Text(.init(markdown))
            .font(.system(size: 21))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func small(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// 牌と、その上に乗る点数のバッジ。本編と同じ色を使う
    private func sample(_ tile: Tile, _ score: String,
                        _ fill: Color, _ ink: Color, _ caption: String) -> some View {
        VStack(spacing: 5) {
            Text(score)
                .font(.system(size: score == "戻し" ? 13 : 19, weight: .heavy))
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(ink)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(fill, in: RoundedRectangle(cornerRadius: 7))
            TileView(tile: tile).frame(width: 52)
            Text(caption).font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }

    /// 1萬2萬3萬 5萬6萬 3筒4筒5筒 7筒8筒 2索3索4索
    private static let sampleHand: [Tile] = [
        Tile(.man, 1), Tile(.man, 2), Tile(.man, 3), Tile(.man, 5), Tile(.man, 6),
        Tile(.pin, 3), Tile(.pin, 4), Tile(.pin, 5), Tile(.pin, 7), Tile(.pin, 8),
        Tile(.sou, 2), Tile(.sou, 3), Tile(.sou, 4),
    ]
}
