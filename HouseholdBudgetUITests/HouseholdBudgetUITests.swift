import XCTest

final class HouseholdBudgetUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDemoDataSmokeFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-demo-data",
            "--uitest-skip-loading-delay"
        ]
        app.launchEnvironment = [
            "POCKETWISE_UITEST_SUITE": "PocketWiseUITest-\(UUID().uuidString)",
            "POCKETWISE_UITEST_DEMO_JSON": try loadDemoFixtureJSON()
        ]
        app.launch()

        XCTAssertTrue(waitForIdentifier("screen.today", in: app), "Today screen did not appear.")

        tapTab(identifier: "tab.transactions", fallbackLabel: "Transactions", in: app)
        XCTAssertTrue(waitForIdentifier("screen.transactions", in: app), "Transactions screen did not appear.")

        tapTab(identifier: "tab.budget", fallbackLabel: "Plan", in: app)
        XCTAssertTrue(waitForIdentifier("screen.budget", in: app), "Budget screen did not appear.")

        tapTab(identifier: "tab.today", fallbackLabel: "Today", in: app)
        XCTAssertTrue(waitForIdentifier("screen.today", in: app), "Today screen did not reappear.")
        openManageIncome(in: app)
        XCTAssertTrue(waitForIdentifier("sheet.manageIncome", in: app), "Manage Income sheet did not appear.")
        XCTAssertTrue(waitForIdentifier("section.expectedIncome", in: app), "Expected income section did not appear.")
        XCTAssertTrue(waitForIdentifier("section.recurringIncome", in: app), "Recurring income section did not appear.")
        XCTAssertTrue(waitForIdentifier("section.receivedIncome", in: app), "Received income section did not appear.")
        tapIfExists(app.buttons["Close"])

        tapTab(identifier: "tab.settings", fallbackLabel: "Settings", in: app)
        XCTAssertTrue(waitForIdentifier("screen.settings", in: app), "Settings screen did not appear.")

        tapButton(identifier: "button.settingsCreditCards", fallbackLabel: "Credit Cards", in: app)
        XCTAssertTrue(waitForIdentifier("screen.creditCards", in: app), "Credit Cards screen did not appear.")
        XCTAssertTrue(app.staticTexts["PocketWise Demo Card"].waitForExistence(timeout: 5), "Demo credit card label did not appear.")
        navigateBack(in: app)

        tapButton(identifier: "button.settingsDataBackup", fallbackLabel: "Data Backup", in: app)
        XCTAssertTrue(waitForIdentifier("screen.dataBackup", in: app), "Data Backup screen did not appear.")
        navigateBack(in: app)
    }

    private func loadDemoFixtureJSON() throws -> String {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("HouseholdBudgetTests/Fixtures/PocketWise-Demo-Household-TestData.json")
        return try String(contentsOf: fixtureURL, encoding: .utf8)
    }

    private func waitForIdentifier(_ identifier: String, in app: XCUIApplication, timeout: TimeInterval = 8) -> Bool {
        app.descendants(matching: .any)[identifier].waitForExistence(timeout: timeout)
    }

    private func tapTab(identifier: String, fallbackLabel: String, in app: XCUIApplication) {
        let tabByIdentifier = app.tabBars.buttons[identifier]
        if tabByIdentifier.waitForExistence(timeout: 2) {
            tabByIdentifier.tap()
            return
        }

        let tabByLabel = app.tabBars.buttons[fallbackLabel]
        XCTAssertTrue(tabByLabel.waitForExistence(timeout: 5), "Missing tab: \(identifier) / \(fallbackLabel)")
        tabByLabel.tap()
    }

    private func tapButton(identifier: String, fallbackLabel: String, in app: XCUIApplication) {
        let buttonByIdentifier = app.buttons[identifier]
        if buttonByIdentifier.waitForExistence(timeout: 2) {
            buttonByIdentifier.tap()
            return
        }

        let buttonByLabel = app.buttons[fallbackLabel]
        XCTAssertTrue(buttonByLabel.waitForExistence(timeout: 5), "Missing button: \(identifier) / \(fallbackLabel)")
        buttonByLabel.tap()
    }

    private func openManageIncome(in app: XCUIApplication) {
        let addIncomeButton = app.buttons["Add Income"]
        XCTAssertTrue(addIncomeButton.waitForExistence(timeout: 5), "Add Income menu did not appear.")
        addIncomeButton.tap()
        tapButton(identifier: "button.manageIncome", fallbackLabel: "Manage income", in: app)
    }

    private func navigateBack(in app: XCUIApplication) {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Back button did not appear.")
        backButton.tap()
    }

    private func tapIfExists(_ element: XCUIElement) {
        if element.waitForExistence(timeout: 3) {
            element.tap()
        }
    }
}
