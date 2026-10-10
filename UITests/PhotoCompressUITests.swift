import XCTest

/// Drives the real app end to end on fixture photos from Tests/Fixtures (git-ignored; skipped if absent).
@MainActor
final class PhotoCompressUITests: XCTestCase {

    private func fixtures() throws -> String {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Tests/Fixtures")
        let files = ["iphone13pro-nogps.heic", "iphone11-gps.heic"].map { directory.appendingPathComponent($0).path }
        try XCTSkipUnless(files.allSatisfy(FileManager.default.fileExists), "no fixtures in Tests/Fixtures")
        return files.joined(separator: ",")
    }

    private func allowPhotoAccessIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow Full Access"]
        if allow.waitForExistence(timeout: 8) { allow.tap() }
    }

    func testCompressSaveNavigateAndSwitchLanguage() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "e2e", "-demoFiles", try fixtures(), "-AppleLanguages", "(en)"]
        app.launch()
        allowPhotoAccessIfAsked()

        // Results: both photos saved.
        XCTAssertTrue(app.staticTexts["2 photos saved"].waitForExistence(timeout: 60))

        // Tap a row: the compressed copy opens, then closes.
        app.buttons.containing(.staticText, identifier: "iphone11-gps").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Compressed copy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["iphone11-gps-compressed.jpg"].exists)
        app.buttons["Done"].tap()

        // Tabs: Settings and back; results are still there.
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["Same as iPhone"].firstMatch.waitForExistence(timeout: 5))

        // Language switch takes effect immediately, including the tab bar.
        app.descendants(matching: .any)["Español"].firstMatch.tap()
        XCTAssertTrue(app.tabBars.buttons["Configuración"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Comprimir"].tap()
        XCTAssertTrue(app.staticTexts["2 fotos guardadas"].waitForExistence(timeout: 5))

        // Back arrow returns home.
        app.navigationBars.buttons["Inicio"].tap()
        XCTAssertTrue(app.buttons["Elegir fotos"].waitForExistence(timeout: 5))

        // Restore the language setting.
        app.tabBars.buttons["Configuración"].tap()
        app.descendants(matching: .any)["Igual que el iPhone"].firstMatch.tap()
    }
}
