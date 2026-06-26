import XCTest
@testable import PocketWise

final class CloudMergeModelMetadataTests: XCTestCase {

    func testWalletMonthlyBudgetItemDecodesOldJSONWithDefaultMetadata() throws {
        let oldJSON = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "categoryName": "Groceries",
          "plannedAmount": 2500
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(WalletMonthlyBudgetItem.self, from: oldJSON)

        XCTAssertEqual(item.id.uuidString, "11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(item.categoryName, "Groceries")
        XCTAssertEqual(item.plannedAmount, 2500)
        XCTAssertEqual(item.updatedAt, item.createdAt)
        XCTAssertFalse(item.isDeleted)
        XCTAssertNil(item.deletedAt)
    }

    func testWalletMonthlyBudgetItemMetadataRoundTrips() throws {
        let id = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_700_010_000)
        let deletedAt = Date(timeIntervalSince1970: 1_700_020_000)
        let item = WalletMonthlyBudgetItem(
            id: id,
            categoryName: "School",
            plannedAmount: 7900,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isDeleted: true,
            deletedAt: deletedAt
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(item)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WalletMonthlyBudgetItem.self, from: data)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.categoryName, "School")
        XCTAssertEqual(decoded.plannedAmount, 7900)
        XCTAssertEqual(decoded.createdAt, createdAt)
        XCTAssertEqual(decoded.updatedAt, updatedAt)
        XCTAssertTrue(decoded.isDeleted)
        XCTAssertEqual(decoded.deletedAt, deletedAt)
    }

    func testRecurringPaidOccurrenceIdentityReturnsNilForNonOccurrenceRecords() {
        let event = FinancialEvent(
            type: .expense,
            status: .paid,
            title: "One-off groceries",
            amount: 500,
            date: Date()
        )

        XCTAssertNil(event.recurringPaidOccurrenceIdentity)
    }

    func testRecurringPaidOccurrenceIdentityReturnsNilForUnpaidOccurrenceRecords() {
        let sourceID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        var event = FinancialEvent(
            type: .expense,
            status: .unpaid,
            title: "Rent",
            amount: 25300,
            date: Date()
        )
        event.sourceRecurringEventID = sourceID
        event.recurringOccurrenceYear = 2026
        event.recurringOccurrenceMonth = 7

        XCTAssertNil(event.recurringPaidOccurrenceIdentity)
    }

    func testRecurringPaidOccurrenceIdentityReturnsExpectedIdentityForPaidOccurrence() {
        let sourceID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        var event = FinancialEvent(
            type: .expense,
            status: .paid,
            title: "Rent",
            amount: 25300,
            date: Date()
        )
        event.sourceRecurringEventID = sourceID
        event.recurringOccurrenceYear = 2026
        event.recurringOccurrenceMonth = 7

        XCTAssertEqual(
            event.recurringPaidOccurrenceIdentity,
            RecurringPaidOccurrenceIdentity(
                sourceRecurringEventID: sourceID,
                year: 2026,
                month: 7
            )
        )
    }
}
