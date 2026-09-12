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

    /// 画面の要素一覧を書き出す。目印が本当に出ているかを確かめるため
    private func dump(_ app: XCUIApplication, _ name: String) {
        try? app.debugDescription.write(toFile: "\(outDir)/\(name).txt",
                                        atomically: true, encoding: .utf8)
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
        XCTAssertTrue(app.otherElements["tile-miss"].firstMatch.waitForExistence(timeout: 10),
                      "不正解になる牌が1枚はあること")
        // 同じ目印の要素が入れ子で2つ出るので、押せるほうを選ぶ
        for candidate in app.otherElements
            .matching(identifier: "tile-miss").allElementsBoundByIndex {
            if candidate.exists, candidate.isHittable { candidate.tap(); return true }
        }
        return false
    }

    /// 遊び方を飛ばして本編へ入る
    private func skipIntroduction(_ app: XCUIApplication) {
        let skip = app.buttons["intro-skip"].firstMatch
        XCTAssertTrue(skip.waitForExistence(timeout: 15), "遊び方の「とばす」が出ていること")
        skip.tap()
        XCTAssertTrue(app.buttons["settings"].firstMatch.waitForExistence(timeout: 15),
                      "とばしたら本編に入ること")
    }

    private func openSettings(_ app: XCUIApplication) {
        let gear = app.buttons["settings"].firstMatch
        XCTAssertTrue(gear.waitForExistence(timeout: 10), "設定の歯車が出ていること")
        gear.tap()
    }

    /// 種類を問わず目印で引く。
    /// SwiftUI は同じ目印を、行にも中の部品にも付けることがあるので種類で決め打ちしない
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Form は画面に入っている行しか作らないので、出てくるまでスクロールする。
    ///
    /// **シミュレータでは、どちらへ振れば中身が上へ送られるか当てにならない。**
    /// 端末は縦のまま、アプリだけ横向きに描かれているので、
    /// XCUITest の上下左右と画面上の上下左右が一致しない。
    /// 実機では素直に一致するが、ここでは四方向を順に試して、
    /// 目当ての行が出たところで止める。
    @discardableResult
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        if element.exists, element.isHittable { return true }
        let swipes: [(XCUIApplication) -> () -> Void] = [
            { app in { app.swipeDown() } },
            { app in { app.swipeUp() } },
            { app in { app.swipeLeft() } },
            { app in { app.swipeRight() } },
        ]
        for _ in 0..<3 {
            for makeSwipe in swipes {
                makeSwipe(app)()
                if element.exists, element.isHittable { return true }
            }
        }
        return element.exists && element.isHittable
    }

    /// 名前で引く。**Form の中の Toggle は accessibilityIdentifier が落ちる**ので、
    /// 表示している文字で探すしかない
    private func labelled(_ text: String, type: XCUIElement.ElementType,
                          in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: type)
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }

    // MARK: - 初回の説明

    func testIntroductionAppearsOnFirstLaunchOnly() {
        let app = launchFresh()

        let next = app.buttons["intro-next"].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 10), "初回は遊び方が出ること")
        save("01-intro-1")

        // ページ数を決め打ちしない。ボタンが消えるまで進める
        var pages = 0
        while next.exists, pages < 8 {
            sleep(1)    // めくりの途中で撮ると中身が切れる
            save(String(format: "intro-%02d", pages + 1))
            next.tap()
            pages += 1
        }
        XCTAssertGreaterThanOrEqual(pages, 2, "何ページかあること")

        // 説明が閉じて本編に戻ったこと。
        // 牌の目印は局面によって変わるので、必ず出ている歯車で見る
        XCTAssertTrue(app.buttons["settings"].firstMatch.waitForExistence(timeout: 10),
                      "説明を読み終えたら本編に戻ること")
        save("03-game-light")

        // 2回目の起動では出ない。
        // **終わらせる前に少し置く。** 見終わった印を書いた直後に落とすと、
        // 保存が間に合わずに次の起動でまた出てしまうことがある
        sleep(2)
        app.terminate()

        // 同じ実体を使い回すと前回の起動引数が残ることがあるので、作り直す
        let second = XCUIApplication()
        second.launchArguments = []
        second.launch()
        XCTAssertTrue(second.wait(for: .runningForeground, timeout: 20))
        XCTAssertTrue(second.buttons["settings"].firstMatch.waitForExistence(timeout: 15),
                      "2回目はすぐ本編に入ること")
        XCTAssertFalse(second.buttons["intro-next"].firstMatch.exists,
                       "2回目からは遊び方を出さないこと")
    }

    // MARK: - 復習

    /// 外した局面が復習にたまること。
    /// どの牌が外しになるかは配牌しだいなので、**たまったかどうかだけ**を見る
    func testMissedHandIsRemembered() {
        let app = launchFresh()
        skipIntroduction(app)

        XCTAssertTrue(discardMissTile(app), "わざと外せること")
        // 外したら、詳細を開かなくても理由が1行出ること
        XCTAssertTrue(app.staticTexts["explanation"].firstMatch.waitForExistence(timeout: 5),
                      "外した理由の一言が出ていない")
        save("04-scored")

        // 外した打牌で聴牌して局が終わると、歯車のある画面から離れる。
        // その場合は次の局へ進めてから設定を開く
        if !app.buttons["settings"].firstMatch.exists {
            let next = app.buttons["draw"].firstMatch
            if next.waitForExistence(timeout: 5), next.isEnabled { next.tap() }
        }

        openSettings(app)
        save("05-settings")
        XCTAssertTrue(element("review-link", in: app).waitForExistence(timeout: 10),
                      "外した局面が復習に入ること")

        // 上段からも復習へ入れること。設定の奥だけだと開かない
        app.buttons["閉じる"].firstMatch.tap()
        let top = element("review-top", in: app)
        if top.waitForExistence(timeout: 5) {
            top.tap()
            XCTAssertTrue(element("review-all", in: app).waitForExistence(timeout: 10),
                          "上段のボタンから復習の入口が開くこと")
            save("05c-review-from-top")
            app.buttons["閉じる"].firstMatch.tap()
        } else {
            XCTFail("上段に復習のボタンが出ること")
        }
        openSettings(app)

        // 形で絞れること。外した局面には必ず分類が付く
        element("review-link", in: app).tap()
        let all = element("review-all", in: app)
        XCTAssertTrue(all.waitForExistence(timeout: 10), "復習の入口が出ること")
        let tagged = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "review-"))
            .allElementsBoundByIndex
            .filter { $0.identifier != "review-all" && $0.identifier != "review-link" }
        XCTAssertFalse(tagged.isEmpty, "形ごとの行が1つは出ること")
        save("05b-review-tags")
    }

    /// 復習の出題から結果までを通す。
    /// **決まった1局面を仕込んで**確かめるので、配牌に左右されない
    func testReviewSessionRunsToTheEnd() {
        let app = XCUIApplication()
        app.launchArguments = ["-SOKKOU_RESET", "-SOKKOU_SEED_REVIEW"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        skipIntroduction(app)

        openSettings(app)
        let review = element("review-link", in: app)
        XCTAssertTrue(review.waitForExistence(timeout: 10), "仕込んだ局面が入っていること")
        review.tap()
        // 入口で形を選べるようになった。ここでは「すべて」から入る
        let all = element("review-all", in: app)
        XCTAssertTrue(all.waitForExistence(timeout: 10), "復習の入口が出ること")
        save("06-review-start")
        all.tap()
        save("06-review-opened")

        let next = app.buttons["review-next"].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 10), "復習の画面が出ること")
        XCTAssertFalse(next.isEnabled, "答える前は進めないこと")

        var tapped = false
        for index in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 100] where !tapped {
            for candidate in app.otherElements
                .matching(identifier: "tile-\(index)").allElementsBoundByIndex {
                if candidate.exists, candidate.isHittable {
                    candidate.tap(); tapped = true; break
                }
            }
        }
        XCTAssertTrue(tapped, "復習の画面で牌を選べること")
        // 仕込んだ局面で1萬(tile-0)を切ると最善ではないので、理由の一言が出る
        XCTAssertTrue(app.staticTexts["explanation"].firstMatch.waitForExistence(timeout: 5),
                      "復習でも理由の一言が出ること")
        save("07-review-answered")

        // 間違いを見直す場所なので、本編と同じく詳細まで開けること
        let detail = element("review-detail", in: app)
        XCTAssertTrue(detail.waitForExistence(timeout: 5), "復習にも詳細のボタンが出ること")
        detail.tap()
        // 盤面と、受け入れの違いが出ていること
        XCTAssertTrue(app.staticTexts["この14枚から"].firstMatch.waitForExistence(timeout: 10),
                      "詳細に盤面が出ること")
        XCTAssertTrue(app.staticTexts["何を引けば進むか"].firstMatch.exists,
                      "受け入れの比較が出ること")
        save("07b-review-detail")
        // 閉じて元の画面へ戻る
        app.swipeDown(velocity: .fast)

        XCTAssertTrue(next.waitForExistence(timeout: 10), "詳細を閉じたら復習へ戻ること")
        XCTAssertTrue(next.isEnabled, "答えたら進めること")
        next.tap()

        XCTAssertTrue(app.staticTexts["復習おわり"].firstMatch.waitForExistence(timeout: 10),
                      "最後まで行くと結果が出ること")
        save("08-review-summary")
        app.buttons["review-close"].firstMatch.tap()
    }

    // MARK: - 利き手

    /// **設定の画面を経由せずに確かめる。**
    /// シミュレータは端末が縦のままアプリだけ横向きに描くので、
    /// XCUITest のスワイプが画面上の上下と噛み合わず、
    /// 画面に入りきらない設定の行までスクロールできない
    /// （実機では噛み合う。設定が最後まで送れることは指で確認済み）。
    /// ここで見たいのは並びが入れ替わることなので、起動時に設定を入れて比べる。
    func testDrawButtonCanMoveToTheLeft() {
        let app = launchFresh()
        skipIntroduction(app)

        let draw = app.buttons["draw"].firstMatch
        XCTAssertTrue(draw.waitForExistence(timeout: 10))
        let rightHandedX = draw.frame.midX
        save("09-right-handed")

        app.terminate()
        app.launchArguments = ["-SOKKOU_LEFT_HANDED"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))

        XCTAssertTrue(draw.waitForExistence(timeout: 10))
        XCTAssertLessThan(draw.frame.midX, rightHandedX,
                          "設定を入れたら「ツモる」が左へ動くこと")
        save("10-left-handed")
    }

    /// 局が終わった画面から、設定を通らずに苦手な形の練習へ入れること。
    ///
    /// 苦手な形が分かっても、設定の奥にあると開かない。
    /// **思い立った場所から1タップで始められる**ことがこの機能の要点なので、
    /// 入口が消えたらテストで気づけるようにしておく。
    func testWeakShapePracticeStartsFromTheRoundResult() {
        let app = XCUIApplication()
        app.launchArguments = ["-SOKKOU_RESET", "-SOKKOU_SEED_WEAK"]
        app.launchEnvironment["SOKKOU_QUICK_TENPAI"] = "1"   // 1打で聴牌まで行く
        app.launch()

        skipIntroduction(app)

        // 聴牌するまで打っては引くを繰り返す。1シャンテン配牌なので普通は1巡だが、
        // 引いた牌や描き直しの間合いで伸びることがあるので長めに粘る。
        // 途中で牌が掴めない瞬間があっても、抜けずに次の周回で取り直す
        let practice = element("practice-weak", in: app)
        for _ in 0..<20 {
            if practice.exists { break }
            func hittable(_ query: XCUIElementQuery) -> XCUIElement? {
                query.allElementsBoundByIndex.first { $0.exists && $0.isHittable }
            }
            let tile = hittable(app.otherElements.matching(identifier: "tile-best"))
                ?? hittable(app.otherElements
                    .matching(NSPredicate(format: "identifier BEGINSWITH %@", "tile-")))
            guard let tile else { _ = practice.waitForExistence(timeout: 2); continue }
            tile.tap()
            let draw = element("draw", in: app)
            guard draw.waitForExistence(timeout: 10) else { continue }
            // 押せるようになるまで少し待つ（打牌の判定が出るまで無効）
            for _ in 0..<10 where !draw.isEnabled { _ = practice.waitForExistence(timeout: 1) }
            if draw.isEnabled { draw.tap() }
        }

        XCTAssertTrue(practice.waitForExistence(timeout: 20),
                      "局終わりの画面に苦手な形の入口が出ること")
        save("07-practice-entry")

        practice.tap()
        // 絞られた形の名前が見出しに出る
        XCTAssertTrue(app.staticTexts["ターツ選択"].waitForExistence(timeout: 15),
                      "その形だけの復習が始まること")
        save("07-practice-opened")
    }
}
