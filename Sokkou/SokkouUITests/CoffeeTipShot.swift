import XCTest

/// 投げ銭（コーヒーを奢る）の見た目と、App Store Connect に出す審査用スクリーンショット。
///
/// **`.storekit` はスキームで指定している**（Coffee.storekit）。
/// `simctl launch` では効かないので、ここから確認・撮影する（引き継ぎ書 11-9）。
final class CoffeeTipShot: XCTestCase {

    private let outDir = "/Users/jin/Claude/Sokkou/store/iap-review"

    override func setUp() {
        continueAfterFailure = false
        try? FileManager.default.createDirectory(atPath: outDir,
                                                 withIntermediateDirectories: true)
    }

    private func save(_ name: String) {
        // 画面全体を撮る。XCUIScreen なら simctl で撮ったのと同じ素直な画になる
        let shot = XCUIScreen.main.screenshot()
        try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        // **ここで出るのは横倒しの画**（端末は縦のまま、アプリだけ横向きに描かれる）。
        // 起こす作業は store/make-iap-shot.sh がやる。撮影はこのテストの担当。
    }

    /// 設定のFormを縦に送る。
    ///
    /// **横向きのアプリをシミュレータで動かすと、端末は縦のままなので
    /// `swipeUp()` の向きが画面と噛み合わない**（引き継ぎ書 4-58）。
    /// 要素の座標系はアプリの向きで返ってくるので、座標を指定して引く。
    private func dragUp(_ app: XCUIApplication) {
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
        from.press(forDuration: 0.1, thenDragTo: to)
    }

    func testCaptureCoffeeTipForReview() {
        let app = XCUIApplication()
        app.launchArguments = ["-SOKKOU_RESET"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))

        // 遊び方を飛ばす
        let skip = app.buttons["intro-skip"].firstMatch
        if skip.waitForExistence(timeout: 15) { skip.tap() }

        let gear = app.buttons["settings"].firstMatch
        XCTAssertTrue(gear.waitForExistence(timeout: 15), "設定の歯車が出ていない")
        gear.tap()

        // **Form は見えている行しか作らない。** いちばん下にあるので、
        // 出てくるまで送りながら探す
        let coffee = app.buttons["buyCoffee"].firstMatch
        var scrolls = 0
        while !(coffee.exists && coffee.isHittable), scrolls < 10 {
            dragUp(app)
            scrolls += 1
        }
        if !coffee.exists { save("debug-settings") }
        XCTAssertTrue(coffee.exists && coffee.isHittable,
                      "コーヒーの行まで届かない（\(scrolls)回引いた）")

        // 出たばかりだと画面のいちばん下で切れる。もうひと送りして真ん中寄りに置く
        dragUp(app)
        XCTAssertTrue(coffee.exists, "送りすぎて行が消えた")

        // 商品の読み込みは行が作られてから走る（`.task`）。
        // 送って出したばかりなので、値が入るまで待つ
        let priceAppeared = expectation(description: "価格が出る")
        var waited = 0.0
        func poll() {
            if coffee.isEnabled, coffee.label.contains("$") || coffee.label.contains("¥") {
                priceAppeared.fulfill(); return
            }
            waited += 0.5
            if waited > 20 { priceAppeared.fulfill(); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: poll)
        }
        poll()
        wait(for: [priceAppeared], timeout: 25)

        if !coffee.isEnabled { save("debug-disabled") }
        XCTAssertTrue(coffee.isEnabled,
                      "ボタンが無効。商品が読めていない（.storekit のパスを疑う）"
                      + " label=[\(coffee.label)]")
        // 価格は StoreKit が返した文字列をそのまま出す。決め打ちしない。
        // シミュレータのストアフロントは米国なので $ 表記になる。
        // 実機・本番では App Store Connect の ¥200 が出る（引き継ぎ書 11-9）
        XCTAssertTrue(coffee.label.contains("$") || coffee.label.contains("¥"),
                      "価格が出ていない。label=[\(coffee.label)]")

        save("coffee-tip")
    }
}
