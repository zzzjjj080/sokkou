import UIKit

/// 触覚フィードバック。
///
/// 「押した」と「変わった」で強さを分ける。
/// 生成器は使い回して `prepare()` しておく。毎回作ると1打目が鳴らない。
/// **シミュレータでは鳴らないので、確認は実機で行う。**
@MainActor
enum Haptics {
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notice = UINotificationFeedbackGenerator()

    /// 設定で切れるようにしておく。連続で打つアプリなので、うるさく感じる人がいる。
    static var isEnabled = true

    static func warmUp() {
        guard isEnabled else { return }
        rigid.prepare(); light.prepare(); medium.prepare(); heavy.prepare(); notice.prepare()
    }

    /// 牌を押した瞬間。判定より先に鳴らす
    static func tap() { fire { rigid.impactOccurred() } }
    /// 正解。軽く。テンポを止めない
    static func correct() { fire { light.impactOccurred() } }
    /// 不正解
    static func incorrect() { fire { notice.notificationOccurred(.error) } }
    /// シャンテン戻し。不正解とも区別する
    static func shantenBack() { fire { notice.notificationOccurred(.warning) } }
    /// ツモって手牌が変わった
    static func draw() { fire { medium.impactOccurred() } }
    /// テンパイして局が終わった
    static func roundFinished() { fire { notice.notificationOccurred(.success) } }
    /// 最速聴牌。区切りのあとに一発足す
    static func fastest() {
        fire {
            notice.notificationOccurred(.success)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(220))
                if isEnabled { heavy.impactOccurred() }
            }
        }
    }
    /// 昇格。めったに起きないので一番強くしてよい
    static func promoted() {
        fire {
            heavy.impactOccurred()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(160))
                if isEnabled { heavy.impactOccurred() }
            }
        }
    }

    private static func fire(_ action: () -> Void) {
        guard isEnabled else { return }
        action()
        warmUp()
    }
}
