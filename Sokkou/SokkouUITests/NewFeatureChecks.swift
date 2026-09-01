import XCTest

/// 今回足した4つを、実際に動かして確かめる。
/// ・初回の説明が出るか
/// ・外した局面が復習にたまるか、復習で解き直せるか
/// ・「ツモる」を左に移せるか
/// ・明るい画面でも読めるか（画は目視用に残す）
final class NewFeatureChecks: XCTestCase {

    private let outDir = "/tmp/sokkou-checks"

    override func setUp() {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(atPath: outDir,
                                                 withIntermediateDirectories: true)
    }

    private func save(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 記録を消した状態で起動する
    private func launchFresh() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-SOKKOU_RESET"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        return app
    }

    /// **わざと外す。**
    /// 90点以上は正解なので「最善でない牌」では足りない。
    /// 不正解の牌にだけ付く tile-miss を叩く
    @discardableResult
    private func discardMissTile(_ app: XCUIApplication) -> Bool {
        let miss = app.otherElements["tile-miss"].firstMatch
        XCTAssertTrue(miss.waitForExistence(timeout: 10), "不正解になる牌が1枚はあること")
        guard miss.isHittable else { return false }
        miss.tap()
        return true
    }

    private func openSettings(_ app: XCUIApplication) {
        let gear = app.buttons["settings"].firstMatch
        XCTAssertTrue(gear.waitForExistence(timeout: 10), "設定の歯車が出ていること")
        gear.tap()
    }

    // MARK: - 初回の説明

    func testIntroductionAppearsOnFirstLaunchOnly() {
        let app = launchFresh()

        let next = app.buttons["intro-next"].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 10), "初回は遊び方が出ること")
        save("01-intro-1")

        // 5ページある。最後は「はじめる」
        for page in 1...5 {
            XCTAssertTrue(next.waitForExistence(timeout: 5), "\(page)ページ目でボタンが出ていること")
            if page == 3 { save("02-intro-3") }
            next.tap()
        }

        // 説明が閉じて、手牌が出ていること
        XCTAssertTrue(app.otherElements["tile-0"].firstMatch.waitForExistence(timeout: 10)
                      || app.otherElements["tile-best"].firstMatch.waitForExistence(timeout: 10),
                      "説明を読み終えたら手牌が出ること")
        save("03-game-light")

        // 2回目の起動では出ない
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        XCTAssertFalse(app.buttons["intro-next"].firstMatch.waitForExistence(timeout: 4),
                       "2回目からは遊び方を出さないこと")
    }

    // MARK: - 復習

    func testMissedHandGoesToReviewAndCanBeSolved() {
        let app = launchFresh()

        // 説明を飛ばす
        let skip = app.buttons["とばす"].firstMatch
        if skip.waitForExistence(timeout: 10) { skip.tap() }

        XCTAssertTrue(discardMissTile(app), "わざと外せること")
        save("04-scored")

        openSettings(app)
        let review = app.buttons["review-link"].firstMatch
        XCTAssertTrue(review.waitForExistence(timeout: 10), "外した局面が復習に入ること")
        save("05-settings")
        review.tap()

        // 復習画面。1枚選ぶと採点が出て、次へ進めるようになる
        let nextButton = app.buttons["結果を見る"].firstMatch
        XCTAssertTrue(nextButton.waitForExistence(timeout: 10), "1件だけなので「結果を見る」が出る")
        XCTAssertFalse(nextButton.isEnabled, "答える前は進めないこと")

        let best = app.otherElements["tile-best"].firstMatch
        if best.waitForExistence(timeout: 5) {
            best.tap()      // 今度は最善を選ぶ
        } else {
            app.otherElements["tile-0"].firstMatch.tap()
        }
        save("06-review-answered")
        XCTAssertTrue(nextButton.isEnabled, "答えたら進めること")
        nextButton.tap()

        XCTAssertTrue(app.staticTexts["復習おわり"].firstMatch.waitForExistence(timeout: 10),
                      "最後まで行くと結果が出ること")
        save("07-review-summary")
        app.buttons["閉じる"].firstMatch.tap()
    }

    // MARK: - 利き手

    func testDrawButtonCanMoveToTheLeft() {
        let app = launchFresh()
        let skip = app.buttons["とばす"].firstMatch
        if skip.waitForExistence(timeout: 10) { skip.tap() }

        let draw = app.buttons["draw"].firstMatch
        XCTAssertTrue(draw.waitForExistence(timeout: 10))
        let rightHandedX = draw.frame.midX

        openSettings(app)
        let toggle = app.switches["left-handed"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "持ち方の設定があること")
        toggle.tap()
        app.buttons["閉じる"].firstMatch.tap()

        XCTAssertTrue(draw.waitForExistence(timeout: 10))
        XCTAssertLessThan(draw.frame.midX, rightHandedX,
                          "設定を入れたら「ツモる」が左へ動くこと")
        save("08-left-handed")
    }
}
