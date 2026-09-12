import XCTest

/// App Store に出すスクリーンショットを、実際にアプリを動かして撮る。
/// 画面を組み替えたときに、ビルドが通っただけで満足しないための確認も兼ねる。
///
/// 出力先は /tmp/sokkou-shots。撮ったあと store/MakeScreenshots.swift で
/// 見出しを載せて App Store の寸法にそろえる。
final class StoreScreenshots: XCTestCase {

    private let outDir = "/tmp/sokkou-shots"

    override func setUp() {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(atPath: outDir,
                                                 withIntermediateDirectories: true)
    }

    private func save(_ app: XCUIApplication, _ name: String) {
        // app.screenshot() はアプリの窓だけを、寝かせたまま返してくる。
        // 画面全体を撮る XCUIScreen なら simctl で撮ったのと同じ素直な画になる。
        let shot = XCUIScreen.main.screenshot()
        try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 最善の牌を切る。見栄えのする局にするため、撮影ではノーミスで通す。
    @discardableResult
    private func discardBestTile(_ app: XCUIApplication) -> Bool {
        // 採点が終わるまで最善の目印は出ない。出るまで待ってから叩く。
        // **同じ目印の要素が入れ子で複数出る**ので、押せるものを選ぶ
        _ = app.otherElements["tile-best"].firstMatch.waitForExistence(timeout: 8)
        for candidate in app.otherElements
            .matching(identifier: "tile-best").allElementsBoundByIndex {
            if candidate.exists, candidate.isHittable { candidate.tap(); return true }
        }
        // 最善が掴めなければ、どれでもよいので1枚切って先へ進める
        for candidate in app.otherElements
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "tile-"))
            .allElementsBoundByIndex {
            if candidate.exists, candidate.isHittable { candidate.tap(); return true }
        }
        return false
    }

    func testCaptureStoreScreenshots() {
        let app = XCUIApplication()
        // 撮影は本来の配牌(3〜4向聴)で行う。1向聴だとほとんどの打牌が「戻し」になり、
        // 点数のついた牌がほとんど映らず、画面の説明にならない
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        sleep(2)

        // 1. 打つ前。ヒントの枠が出ている
        save(app, "01-choose")

        // 2. 打った直後。すべての牌に点数が出ている
        discardBestTile(app)
        sleep(1)
        save(app, "02-scored")

        // 3. 採点の内訳。
        //    **最善を切ったままだと「受け入れの違い」が出ない**（比べる相手がいない）。
        //    やり直して、わざと最善でない牌を切ってから開く
        app.buttons["やり直す"].firstMatch.tap()
        sleep(2)
        for candidate in app.otherElements
            .matching(identifier: "tile-miss").allElementsBoundByIndex {
            if candidate.exists, candidate.isHittable { candidate.tap(); break }
        }
        sleep(1)
        let detail = app.buttons["詳細"].firstMatch
        if detail.waitForExistence(timeout: 5), detail.isEnabled {
            detail.tap()
            sleep(2)
            save(app, "03-detail")
            app.buttons["閉じる"].firstMatch.tap()
            sleep(1)
        }

        // 4. 聴牌画面。経験値が入るところ
        // 聴牌の画面は見出しで見分ける。ボタンの文字は状態で変わるので当てにしない
        let result = app.staticTexts["この局の打牌"].firstMatch
        let next = app.buttons["次の局へ"].firstMatch
        // 配牌が遠いと巡目がかさむ。聴牌まで十分に粘る
        for _ in 0..<40 {
            if result.exists { break }
            // 「ツモる」は目印で拾う。文字は「次の局へ」に変わることがある
            let draw = app.descendants(matching: .any)["draw"].firstMatch
            if draw.exists {
                for _ in 0..<6 where !draw.isEnabled { sleep(1) }
                if draw.isEnabled { draw.tap(); sleep(1) }
            }
            discardBestTile(app)
            sleep(1)
        }
        if !result.waitForExistence(timeout: 15) {
            try? app.debugDescription.write(toFile: "/tmp/sokkou-shots/stuck.txt",
                                            atomically: true, encoding: .utf8)
            save(app, "99-stuck")
        }
        XCTAssertTrue(result.exists, "聴牌の画面まで進むこと")
        if result.exists {
            sleep(3)                      // 経験値ゲージが伸びきるのを待つ
            save(app, "04-result")
            if next.exists { next.tap(); sleep(2) }
        }

    }

    /// 段位一覧は別のテストにする。設定シートを開いたあとに続けて局を回すと、
    /// シートが閉じきる前に牌を叩いてしまい後半が撮れなくなるため。
    func testCaptureRankList() {
        let app = XCUIApplication()
        app.launchEnvironment["SOKKOU_QUICK_TENPAI"] = "1"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        sleep(2)
        // 記録が消えている端末では、遊び方が全画面で被る
        let skip = app.buttons["intro-skip"].firstMatch
        if skip.waitForExistence(timeout: 5) { skip.tap(); sleep(1) }

        let settings = app.descendants(matching: .any)["settings"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 8), "設定ボタンが見つからない")
        settings.tap()
        sleep(2)
        // 設定は札を並べる形になった。札の中の文字から押す
        let ranks = app.staticTexts["段位一覧"].firstMatch
        if !ranks.waitForExistence(timeout: 8) {
            try? app.debugDescription.write(toFile: "/tmp/sokkou-shots/settings-dump.txt",
                                            atomically: true, encoding: .utf8)
        }
        XCTAssertTrue(ranks.exists, "段位一覧が見つからない")
        ranks.tap()
        sleep(2)
        save(app, "05-ranks")
    }
}
