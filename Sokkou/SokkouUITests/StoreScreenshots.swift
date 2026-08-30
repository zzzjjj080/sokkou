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
        // 採点が終わるまで最善の目印は出ない。出るまで待ってから叩く
        let best = app.otherElements["tile-best"].firstMatch
        if best.waitForExistence(timeout: 8), best.isHittable { best.tap(); return true }
        for index in 0..<14 {
            let tile = app.otherElements["tile-\(index)"].firstMatch
            if tile.exists, tile.isHittable { tile.tap(); return true }
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

        // 3. 採点の内訳
        let detail = app.buttons["詳細"].firstMatch
        if detail.waitForExistence(timeout: 5), detail.isEnabled {
            detail.tap()
            sleep(2)
            save(app, "03-detail")
            app.buttons["閉じる"].firstMatch.tap()
            sleep(1)
        }

        // 4. 聴牌画面。経験値が入るところ
        let next = app.buttons["次の局へ"].firstMatch
        for _ in 0..<24 {
            if next.exists { break }
            let draw = app.buttons["ツモる"].firstMatch
            if draw.exists, draw.isEnabled { draw.tap(); sleep(1) }
            discardBestTile(app)
            sleep(1)
        }
        if next.waitForExistence(timeout: 10) {
            sleep(3)                      // 経験値ゲージが伸びきるのを待つ
            save(app, "04-result")
            next.tap()
            sleep(2)
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

        let settings = app.descendants(matching: .any)["settings"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 8), "設定ボタンが見つからない")
        settings.tap()
        sleep(2)
        let ranks = app.buttons["段位一覧"].exists
            ? app.buttons["段位一覧"].firstMatch
            : app.cells.containing(.staticText, identifier: "段位一覧").firstMatch
        XCTAssertTrue(ranks.waitForExistence(timeout: 8), "段位一覧が見つからない")
        ranks.tap()
        sleep(2)
        save(app, "05-ranks")
    }
}
