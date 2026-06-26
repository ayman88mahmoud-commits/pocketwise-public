import XCTest
@testable import WalletBoard

final class WalletSyncRecordMapperTests: XCTestCase {

    func testAccountMapsToAccountEntity() {
        let account = makeAccount()

        let dto = WalletSyncRecordMappers.dto(for: account)

        XCTAssertEqual(dto.entity, .account)
    }

    func testAccountRecordNameIsStable() {
        let account = makeAccount()

        let dto = WalletSyncRecordMappers.dto(for: account)

        XCTAssertEqual(dto.recordName, "Account_11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(dto.recordName, WalletSyncRecordIdentity(entity: .account, id: account.id).recordName)
    }

    func testAccountIDIsPreserved() {
        let account = makeAccount()

        let dto = WalletSyncRecordMappers.dto(for: account)

        XCTAssertEqual(dto.id, account.id)
    }

    func testAccountNormalFieldsArePresent() {
        let account = makeAccount()

        let dto = WalletSyncRecordMappers.dto(for: account)

        XCTAssertEqual(dto.fields["name"], .string("Test Cash"))
        XCTAssertEqual(dto.fields["balance"], .double(1250.75))
        XCTAssertEqual(dto.fields["type"], .string("Cash"))
        XCTAssertEqual(dto.fields["isActive"], .bool(true))
        XCTAssertEqual(dto.fields["recognitionAliases"], .stringArray(["Main cash", "Cash wallet"]))
        XCTAssertEqual(dto.fields["recognitionCardEndings"], .stringArray(["1234", "9876"]))
        XCTAssertEqual(dto.fields["appearanceColor"], .string("Green"))
        XCTAssertEqual(dto.fields["createdAt"], .date(account.createdAt))
    }

    func testAccountNilAppearanceColorMapsToNullField() {
        let account = makeAccount(appearanceColor: nil)

        let dto = WalletSyncRecordMappers.dto(for: account)

        XCTAssertEqual(dto.fields["appearanceColor"], .null)
    }

    func testAccountTombstoneMetadataIsPreserved() {
        let deletedAt = Date(timeIntervalSince1970: 1_800_020_000)
        let account = makeAccount(isDeleted: true, deletedAt: deletedAt)

        let dto = WalletSyncRecordMappers.dto(for: account)

        XCTAssertTrue(dto.isDeleted)
        XCTAssertEqual(dto.deletedAt, deletedAt)
        XCTAssertEqual(dto.updatedAt, account.updatedAt)
    }

    func testAccountMapperIsDeterministic() {
        let account = makeAccount()

        let first = WalletSyncRecordMappers.dto(for: account)
        let second = WalletSyncRecordMappers.dto(for: account)

        XCTAssertEqual(first.recordName, second.recordName)
        XCTAssertEqual(first.entity, second.entity)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.updatedAt, second.updatedAt)
        XCTAssertEqual(first.deletedAt, second.deletedAt)
        XCTAssertEqual(first.isDeleted, second.isDeleted)
        XCTAssertEqual(first.fields, second.fields)
    }

    private func makeAccount(
        appearanceColor: ProviderAppearanceColor? = .green,
        isDeleted: Bool = false,
        deletedAt: Date? = nil
    ) -> Account {
        Account(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Test Cash",
            balance: 1250.75,
            type: .cash,
            isActive: true,
            recognitionAliases: ["Main cash", "Cash wallet"],
            recognitionCardEndings: ["1234", "9876"],
            appearanceColor: appearanceColor,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_010_000),
            isDeleted: isDeleted,
            deletedAt: deletedAt
        )
    }

    // MARK: - FinancialEvent mapper tests

    func testFinancialEventMapsToFinancialEventEntity() {
        let event = makeEvent()

        let dto = WalletSyncRecordMappers.dto(for: event)

        XCTAssertEqual(dto.entity, .financialEvent)
    }

    func testFinancialEventRecordNameIsStable() {
        let event = makeEvent()

        let dto = WalletSyncRecordMappers.dto(for: event)

        XCTAssertEqual(dto.recordName, "FinancialEvent_22222222-2222-2222-2222-222222222222")
        XCTAssertEqual(dto.recordName, WalletSyncRecordIdentity(entity: .financialEvent, id: event.id).recordName)
    }

    func testFinancialEventIDIsPreserved() {
        let event = makeEvent()

        let dto = WalletSyncRecordMappers.dto(for: event)

        XCTAssertEqual(dto.id, event.id)
    }

    func testFinancialEventCoreFieldsArePresent() {
        let event = makeEvent()

        let dto = WalletSyncRecordMappers.dto(for: event)

        XCTAssertEqual(dto.fields["type"], .string("Expense"))
        XCTAssertEqual(dto.fields["title"], .string("Groceries"))
        XCTAssertEqual(dto.fields["amount"], .double(150.00))
        XCTAssertEqual(dto.fields["date"], .date(event.date))
        XCTAssertEqual(dto.fields["createdAt"], .date(event.createdAt))
    }

    func testFinancialEventPaidStatusIsPreserved() {
        let event = makeEvent(status: .paid)

        let dto = WalletSyncRecordMappers.dto(for: event)

        XCTAssertEqual(dto.fields["status"], .string("Paid"))
    }

    func testFinancialEventUnpaidStatusIsPreserved() {
        let event = makeEvent(status: .unpaid)

        let dto = WalletSyncRecordMappers.dto(for: event)

        XCTAssertEqual(dto.fields["status"], .string("Unpaid"))
    }

    func testFinancialEventAccountLinkageIsPreserved() {
        let event = makeEvent(
            accountName: "Main Wallet",
            paymentMethodName: "Visa 1234"
        )

        let dto = WalletSyncRecordMappers.dto(for: event)

        XCTAssertEqual(dto.fields["accountName"], .string("Main Wallet"))
        XCTAssertEqual(dto.fields["paymentMethodName"], .string("Visa 1234"))
    }

    func testFinancialEventNilAccountFieldsMapsToNull() {
        let event = makeEvent()

        let dto = WalletSyncRecordMappers.dto(for: event)

        XCTAssertEqual(dto.fields["accountName"], .null)
        XCTAssertEqual(dto.fields["destinationAccountName"], .null)
        XCTAssertEqual(dto.fields["paymentMethodName"], .null)
    }

    func testFinancialEventRecurringLinkageIsPreserved() {
        let recurringID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        var event = makeEvent()
        event.sourceRecurringEventID = recurringID
        event.recurringOccurrenceYear = 2025
        event.recurringOccurrenceMonth = 6

        let dto = WalletSyncRecordMappers.dto(for: event)

        XCTAssertEqual(dto.fields["sourceRecurringEventID"], .uuid(recurringID))
        XCTAssertEqual(dto.fields["recurringOccurrenceYear"], .int(2025))
        XCTAssertEqual(dto.fields["recurringOccurrenceMonth"], .int(6))
    }

    func testFinancialEventInstallmentLinkageIsPreserved() {
        let planID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        var event = makeEvent()
        event.sourceInstallmentPlanID = planID

        let dto = WalletSyncRecordMappers.dto(for: event)

        XCTAssertEqual(dto.fields["sourceInstallmentPlanID"], .uuid(planID))
    }

    func testFinancialEventTombstoneMetadataIsPreserved() {
        let deletedAt = Date(timeIntervalSince1970: 1_800_020_000)
        var event = makeEvent()
        event.isDeleted = true
        event.deletedAt = deletedAt

        let dto = WalletSyncRecordMappers.dto(for: event)

        XCTAssertTrue(dto.isDeleted)
        XCTAssertEqual(dto.deletedAt, deletedAt)
        XCTAssertEqual(dto.updatedAt, event.updatedAt)
    }

    func testFinancialEventMapperIsDeterministic() {
        let event = makeEvent()

        let first = WalletSyncRecordMappers.dto(for: event)
        let second = WalletSyncRecordMappers.dto(for: event)

        XCTAssertEqual(first.recordName, second.recordName)
        XCTAssertEqual(first.entity, second.entity)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.updatedAt, second.updatedAt)
        XCTAssertEqual(first.deletedAt, second.deletedAt)
        XCTAssertEqual(first.isDeleted, second.isDeleted)
        XCTAssertEqual(first.fields, second.fields)
    }

    private func makeEvent(
        status: FinancialEventStatus = .paid,
        accountName: String? = nil,
        destinationAccountName: String? = nil,
        paymentMethodName: String? = nil
    ) -> FinancialEvent {
        var event = FinancialEvent(
            type: .expense,
            status: status,
            title: "Groceries",
            amount: 150.00,
            date: Date(timeIntervalSince1970: 1_800_000_000),
            accountName: accountName,
            destinationAccountName: destinationAccountName,
            paymentMethodName: paymentMethodName,
            walletEventName: nil,
            categoryName: "Food",
            subCategoryName: nil
        )
        event.id = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        event.createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        event.updatedAt = Date(timeIntervalSince1970: 1_800_010_000)
        return event
    }
}
