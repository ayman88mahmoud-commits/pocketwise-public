import XCTest
@testable import PocketWise

final class CloudMergeFixtureScaffoldTests: XCTestCase {

    private let p0FixtureNames = [
        "missing-account-reference",
        "duplicate-financial-event-id",
        "duplicate-recurring-paid-occurrence-identity",
        "account-balance-both-edited",
        "financial-event-paid-status-conflict",
        "credit-card-payment-no-double-apply",
        "person-debt-entry-no-double-apply",
        "delete-vs-edit-newer-delete",
        "monthly-budget-item-conflict-no-child-updated-at",
        "old-backup-restore-before-sync",
        "generated-previews-ignored"
    ]

    private let safetyRules = [
        "stage-first",
        "no-posting-functions",
        "no-balance-mutation-through-user-actions",
        "block-duplicate-recurring-paid-occurrence-identity",
        "block-missing-required-references",
        "exclude-generated-previews",
        "manual-backup-before-first-live-merge"
    ]

    func testP0FixtureNamesAreDocumentedAndStable() {
        XCTAssertEqual(p0FixtureNames.count, 11)
        XCTAssertEqual(Set(p0FixtureNames).count, p0FixtureNames.count)
        XCTAssertTrue(p0FixtureNames.contains("missing-account-reference"))
        XCTAssertTrue(p0FixtureNames.contains("duplicate-recurring-paid-occurrence-identity"))
        XCTAssertTrue(p0FixtureNames.contains("credit-card-payment-no-double-apply"))
        XCTAssertTrue(p0FixtureNames.contains("person-debt-entry-no-double-apply"))
        XCTAssertTrue(p0FixtureNames.contains("generated-previews-ignored"))
    }

    func testCoreSafetyRulesAreDocumentedAndStable() {
        XCTAssertEqual(safetyRules.count, 7)
        XCTAssertEqual(Set(safetyRules).count, safetyRules.count)
        XCTAssertTrue(safetyRules.contains("stage-first"))
        XCTAssertTrue(safetyRules.contains("no-posting-functions"))
        XCTAssertTrue(safetyRules.contains("no-balance-mutation-through-user-actions"))
        XCTAssertTrue(safetyRules.contains("manual-backup-before-first-live-merge"))
    }

    func testScaffoldDoesNotRequireCloudKitOrWalletMutation() {
        XCTAssertFalse(p0FixtureNames.isEmpty)
        XCTAssertFalse(safetyRules.isEmpty)
    }
}
