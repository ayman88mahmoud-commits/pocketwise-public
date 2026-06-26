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

    // MARK: - Category mapper tests

    func testCategoryMapsToCategoryEntity() {
        let category = makeCategory()

        let dto = WalletSyncRecordMappers.dto(for: category)

        XCTAssertEqual(dto.entity, .category)
    }

    func testCategoryRecordNameIsStable() {
        let category = makeCategory()

        let dto = WalletSyncRecordMappers.dto(for: category)

        XCTAssertEqual(dto.recordName, "Category_55555555-5555-5555-5555-555555555555")
        XCTAssertEqual(dto.recordName, WalletSyncRecordIdentity(entity: .category, id: category.id).recordName)
    }

    func testCategoryIDIsPreserved() {
        let category = makeCategory()

        let dto = WalletSyncRecordMappers.dto(for: category)

        XCTAssertEqual(dto.id, category.id)
    }

    func testCategoryImportantFieldsArePresent() {
        let category = makeCategory()

        let dto = WalletSyncRecordMappers.dto(for: category)

        XCTAssertEqual(dto.fields["name"], .string("Food"))
        XCTAssertEqual(dto.fields["subcategories"], .stringArray(["Supermarket", "Restaurant"]))
        XCTAssertEqual(dto.fields["isActive"], .bool(true))
        XCTAssertEqual(dto.fields["inactiveSubcategoryNames"], .stringArray(["Fast Food"]))
        XCTAssertEqual(dto.fields["createdAt"], .date(category.createdAt))
    }

    func testCategoryTombstoneMetadataIsPreserved() {
        let deletedAt = Date(timeIntervalSince1970: 1_800_020_000)
        let category = makeCategory(isDeleted: true, deletedAt: deletedAt)

        let dto = WalletSyncRecordMappers.dto(for: category)

        XCTAssertTrue(dto.isDeleted)
        XCTAssertEqual(dto.deletedAt, deletedAt)
        XCTAssertEqual(dto.updatedAt, category.updatedAt)
    }

    func testCategoryMapperIsDeterministic() {
        let category = makeCategory()

        let first = WalletSyncRecordMappers.dto(for: category)
        let second = WalletSyncRecordMappers.dto(for: category)

        XCTAssertEqual(first.recordName, second.recordName)
        XCTAssertEqual(first.entity, second.entity)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.updatedAt, second.updatedAt)
        XCTAssertEqual(first.deletedAt, second.deletedAt)
        XCTAssertEqual(first.isDeleted, second.isDeleted)
        XCTAssertEqual(first.fields, second.fields)
    }

    private func makeCategory(
        isDeleted: Bool = false,
        deletedAt: Date? = nil
    ) -> WalletBoard.Category {
        WalletBoard.Category(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            name: "Food",
            subcategories: ["Supermarket", "Restaurant"],
            isActive: true,
            inactiveSubcategoryNames: ["Fast Food"],
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_010_000),
            isDeleted: isDeleted,
            deletedAt: deletedAt
        )
    }

    // MARK: - WalletEvent mapper tests

    func testWalletEventMapsToWalletEventEntity() {
        let walletEvent = makeWalletEvent()

        let dto = WalletSyncRecordMappers.dto(for: walletEvent)

        XCTAssertEqual(dto.entity, .walletEvent)
    }

    func testWalletEventRecordNameIsStable() {
        let walletEvent = makeWalletEvent()

        let dto = WalletSyncRecordMappers.dto(for: walletEvent)

        XCTAssertEqual(dto.recordName, "WalletEvent_66666666-6666-6666-6666-666666666666")
        XCTAssertEqual(dto.recordName, WalletSyncRecordIdentity(entity: .walletEvent, id: walletEvent.id).recordName)
    }

    func testWalletEventIDIsPreserved() {
        let walletEvent = makeWalletEvent()

        let dto = WalletSyncRecordMappers.dto(for: walletEvent)

        XCTAssertEqual(dto.id, walletEvent.id)
    }

    func testWalletEventImportantFieldsArePresent() {
        let walletEvent = makeWalletEvent()

        let dto = WalletSyncRecordMappers.dto(for: walletEvent)

        XCTAssertEqual(dto.fields["name"], .string("Grocery Run"))
        XCTAssertEqual(dto.fields["categoryName"], .string("Food"))
        XCTAssertEqual(dto.fields["subCategoryName"], .string("Supermarket"))
        XCTAssertEqual(dto.fields["isFavorite"], .bool(true))
        XCTAssertEqual(dto.fields["isActive"], .bool(true))
        XCTAssertEqual(dto.fields["createdAt"], .date(walletEvent.createdAt))
    }

    func testWalletEventDefaultAccountLinkageIsPreserved() {
        let walletEvent = makeWalletEvent(defaultAccountName: "Main Wallet")

        let dto = WalletSyncRecordMappers.dto(for: walletEvent)

        XCTAssertEqual(dto.fields["defaultAccountName"], .string("Main Wallet"))
    }

    func testWalletEventNilDefaultAccountMapsToNull() {
        let walletEvent = makeWalletEvent(defaultAccountName: nil)

        let dto = WalletSyncRecordMappers.dto(for: walletEvent)

        XCTAssertEqual(dto.fields["defaultAccountName"], .null)
    }

    func testWalletEventTombstoneMetadataIsPreserved() {
        let deletedAt = Date(timeIntervalSince1970: 1_800_020_000)
        var walletEvent = makeWalletEvent()
        walletEvent.isDeleted = true
        walletEvent.deletedAt = deletedAt

        let dto = WalletSyncRecordMappers.dto(for: walletEvent)

        XCTAssertTrue(dto.isDeleted)
        XCTAssertEqual(dto.deletedAt, deletedAt)
        XCTAssertEqual(dto.updatedAt, walletEvent.updatedAt)
    }

    func testWalletEventMapperIsDeterministic() {
        let walletEvent = makeWalletEvent()

        let first = WalletSyncRecordMappers.dto(for: walletEvent)
        let second = WalletSyncRecordMappers.dto(for: walletEvent)

        XCTAssertEqual(first.recordName, second.recordName)
        XCTAssertEqual(first.entity, second.entity)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.updatedAt, second.updatedAt)
        XCTAssertEqual(first.deletedAt, second.deletedAt)
        XCTAssertEqual(first.isDeleted, second.isDeleted)
        XCTAssertEqual(first.fields, second.fields)
    }

    private func makeWalletEvent(defaultAccountName: String? = nil) -> WalletEvent {
        var walletEvent = WalletEvent(
            name: "Grocery Run",
            categoryName: "Food",
            subCategoryName: "Supermarket",
            defaultAccountName: defaultAccountName,
            isFavorite: true
        )
        walletEvent.id = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        walletEvent.createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        walletEvent.updatedAt = Date(timeIntervalSince1970: 1_800_010_000)
        return walletEvent
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

    // MARK: - MerchantMemory mapper tests

    func testMerchantMemoryMapsToMerchantMemoryEntity() {
        let memory = makeMerchantMemory()

        let dto = WalletSyncRecordMappers.dto(for: memory)

        XCTAssertEqual(dto.entity, .merchantMemory)
    }

    func testMerchantMemoryRecordNameIsStable() {
        let memory = makeMerchantMemory()

        let dto = WalletSyncRecordMappers.dto(for: memory)

        XCTAssertEqual(dto.recordName, "MerchantMemory_77777777-7777-7777-7777-777777777777")
        XCTAssertEqual(dto.recordName, WalletSyncRecordIdentity(entity: .merchantMemory, id: memory.id).recordName)
    }

    func testMerchantMemoryIDIsPreserved() {
        let memory = makeMerchantMemory()

        let dto = WalletSyncRecordMappers.dto(for: memory)

        XCTAssertEqual(dto.id, memory.id)
    }

    func testMerchantMemoryImportantFieldsArePresent() {
        let memory = makeMerchantMemory()

        let dto = WalletSyncRecordMappers.dto(for: memory)

        XCTAssertEqual(dto.fields["merchantName"], .string("Starbucks"))
        XCTAssertEqual(dto.fields["aliases"], .stringArray(["Star Bucks", "SB Coffee"]))
        XCTAssertEqual(dto.fields["defaultCategoryName"], .string("Food"))
        XCTAssertEqual(dto.fields["defaultSubCategoryName"], .string("Coffee"))
        XCTAssertEqual(dto.fields["defaultType"], .string("Expense"))
        XCTAssertEqual(dto.fields["usageCount"], .int(5))
        XCTAssertEqual(dto.fields["isActive"], .bool(true))
        XCTAssertEqual(dto.fields["createdAt"], .date(memory.createdAt))
    }

    func testMerchantMemoryDefaultAccountLinkageIsPreserved() {
        var memory = makeMerchantMemory()
        memory.defaultAccountName = "Main Wallet"

        let dto = WalletSyncRecordMappers.dto(for: memory)

        XCTAssertEqual(dto.fields["defaultAccountName"], .string("Main Wallet"))
    }

    func testMerchantMemoryNilDefaultAccountMapsToNull() {
        let memory = makeMerchantMemory()

        let dto = WalletSyncRecordMappers.dto(for: memory)

        XCTAssertEqual(dto.fields["defaultAccountName"], .null)
    }

    func testMerchantMemoryLastUsedAtIsPreserved() {
        let lastUsed = Date(timeIntervalSince1970: 1_800_005_000)
        var memory = makeMerchantMemory()
        memory.lastUsedAt = lastUsed

        let dto = WalletSyncRecordMappers.dto(for: memory)

        XCTAssertEqual(dto.fields["lastUsedAt"], .date(lastUsed))
    }

    func testMerchantMemoryTombstoneMetadataIsPreserved() {
        let deletedAt = Date(timeIntervalSince1970: 1_800_020_000)
        var memory = makeMerchantMemory()
        memory.isDeleted = true
        memory.deletedAt = deletedAt

        let dto = WalletSyncRecordMappers.dto(for: memory)

        XCTAssertTrue(dto.isDeleted)
        XCTAssertEqual(dto.deletedAt, deletedAt)
        XCTAssertEqual(dto.updatedAt, memory.updatedAt)
    }

    func testMerchantMemoryMapperIsDeterministic() {
        let memory = makeMerchantMemory()

        let first = WalletSyncRecordMappers.dto(for: memory)
        let second = WalletSyncRecordMappers.dto(for: memory)

        XCTAssertEqual(first.recordName, second.recordName)
        XCTAssertEqual(first.entity, second.entity)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.updatedAt, second.updatedAt)
        XCTAssertEqual(first.deletedAt, second.deletedAt)
        XCTAssertEqual(first.isDeleted, second.isDeleted)
        XCTAssertEqual(first.fields, second.fields)
    }

    private func makeMerchantMemory() -> MerchantMemory {
        var memory = MerchantMemory(
            merchantName: "Starbucks",
            defaultCategoryName: "Food",
            defaultSubCategoryName: "Coffee",
            defaultAccountName: nil,
            usageCount: 5
        )
        memory.id = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        memory.aliases = ["Star Bucks", "SB Coffee"]
        memory.createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        memory.updatedAt = Date(timeIntervalSince1970: 1_800_010_000)
        return memory
    }

    // MARK: - InstallmentPlan mapper tests

    func testInstallmentPlanMapsToInstallmentPlanEntity() {
        let plan = makeInstallmentPlan()

        let dto = WalletSyncRecordMappers.dto(for: plan)

        XCTAssertEqual(dto.entity, .installmentPlan)
    }

    func testInstallmentPlanRecordNameIsStable() {
        let plan = makeInstallmentPlan()

        let dto = WalletSyncRecordMappers.dto(for: plan)

        XCTAssertEqual(dto.recordName, "InstallmentPlan_88888888-8888-8888-8888-888888888888")
        XCTAssertEqual(dto.recordName, WalletSyncRecordIdentity(entity: .installmentPlan, id: plan.id).recordName)
    }

    func testInstallmentPlanIDIsPreserved() {
        let plan = makeInstallmentPlan()

        let dto = WalletSyncRecordMappers.dto(for: plan)

        XCTAssertEqual(dto.id, plan.id)
    }

    func testInstallmentPlanImportantFieldsArePresent() {
        let plan = makeInstallmentPlan()

        let dto = WalletSyncRecordMappers.dto(for: plan)

        XCTAssertEqual(dto.fields["purchaseName"], .string("iPhone 16"))
        XCTAssertEqual(dto.fields["totalAmount"], .double(1200.00))
        XCTAssertEqual(dto.fields["installmentCount"], .int(12))
        XCTAssertEqual(dto.fields["firstDueDate"], .date(plan.firstDueDate))
        XCTAssertEqual(dto.fields["categoryName"], .string("Electronics"))
        XCTAssertEqual(dto.fields["subCategoryName"], .string("Phones"))
        XCTAssertEqual(dto.fields["paymentMethodName"], .string("Valu"))
        XCTAssertEqual(dto.fields["createdAt"], .date(plan.createdAt))
    }

    func testInstallmentPlanAccountLinkageIsPreserved() {
        let plan = makeInstallmentPlan(accountName: "Main Wallet")

        let dto = WalletSyncRecordMappers.dto(for: plan)

        XCTAssertEqual(dto.fields["accountName"], .string("Main Wallet"))
    }

    func testInstallmentPlanNilAccountMapsToNull() {
        let plan = makeInstallmentPlan()

        let dto = WalletSyncRecordMappers.dto(for: plan)

        XCTAssertEqual(dto.fields["accountName"], .null)
    }

    func testInstallmentPlanCreditCardLinkageIsPreserved() {
        let cardID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
        let plan = makeInstallmentPlan(linkedCreditCardID: cardID)

        let dto = WalletSyncRecordMappers.dto(for: plan)

        XCTAssertEqual(dto.fields["linkedCreditCardID"], .uuid(cardID))
    }

    func testInstallmentPlanNilCreditCardMapsToNull() {
        let plan = makeInstallmentPlan()

        let dto = WalletSyncRecordMappers.dto(for: plan)

        XCTAssertEqual(dto.fields["linkedCreditCardID"], .null)
    }

    func testInstallmentPlanTombstoneMetadataIsPreserved() {
        let deletedAt = Date(timeIntervalSince1970: 1_800_020_000)
        let plan = makeInstallmentPlan(isDeleted: true, deletedAt: deletedAt)

        let dto = WalletSyncRecordMappers.dto(for: plan)

        XCTAssertTrue(dto.isDeleted)
        XCTAssertEqual(dto.deletedAt, deletedAt)
        XCTAssertEqual(dto.updatedAt, plan.updatedAt)
    }

    func testInstallmentPlanMapperIsDeterministic() {
        let plan = makeInstallmentPlan()

        let first = WalletSyncRecordMappers.dto(for: plan)
        let second = WalletSyncRecordMappers.dto(for: plan)

        XCTAssertEqual(first.recordName, second.recordName)
        XCTAssertEqual(first.entity, second.entity)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.updatedAt, second.updatedAt)
        XCTAssertEqual(first.deletedAt, second.deletedAt)
        XCTAssertEqual(first.isDeleted, second.isDeleted)
        XCTAssertEqual(first.fields, second.fields)
    }

    private func makeInstallmentPlan(
        accountName: String? = nil,
        linkedCreditCardID: UUID? = nil,
        isDeleted: Bool = false,
        deletedAt: Date? = nil
    ) -> InstallmentPlan {
        InstallmentPlan(
            id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
            purchaseName: "iPhone 16",
            totalAmount: 1200.00,
            installmentCount: 12,
            firstDueDate: Date(timeIntervalSince1970: 1_800_000_000),
            accountName: accountName,
            categoryName: "Electronics",
            subCategoryName: "Phones",
            linkedCreditCardID: linkedCreditCardID,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_010_000),
            isDeleted: isDeleted,
            deletedAt: deletedAt
        )
    }

    // MARK: - WalletMonthlyBudget mapper tests

    func testMonthlyBudgetMapsToMonthlyBudgetEntity() {
        let budget = makeMonthlyBudget()

        let dto = WalletSyncRecordMappers.dto(for: budget)

        XCTAssertEqual(dto.entity, .monthlyBudget)
    }

    func testMonthlyBudgetRecordNameIsStable() {
        let budget = makeMonthlyBudget()

        let dto = WalletSyncRecordMappers.dto(for: budget)

        XCTAssertEqual(dto.recordName, "MonthlyBudget_aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
        XCTAssertEqual(dto.recordName, WalletSyncRecordIdentity(entity: .monthlyBudget, id: budget.id).recordName)
    }

    func testMonthlyBudgetIDIsPreserved() {
        let budget = makeMonthlyBudget()

        let dto = WalletSyncRecordMappers.dto(for: budget)

        XCTAssertEqual(dto.id, budget.id)
    }

    func testMonthlyBudgetScalarFieldsArePresent() {
        let budget = makeMonthlyBudget()

        let dto = WalletSyncRecordMappers.dto(for: budget)

        XCTAssertEqual(dto.fields["year"], .int(2025))
        XCTAssertEqual(dto.fields["month"], .int(6))
        XCTAssertEqual(dto.fields["createdAt"], .date(budget.createdAt))
    }

    func testMonthlyBudgetItemsFieldIsAbsent() {
        // items ([WalletMonthlyBudgetItem]) is intentionally not mapped — nested object arrays have no matching WalletSyncFieldValue type yet.
        let budget = makeMonthlyBudget()

        let dto = WalletSyncRecordMappers.dto(for: budget)

        XCTAssertNil(dto.fields["items"])
    }

    func testMonthlyBudgetTombstoneMetadataIsPreserved() {
        let deletedAt = Date(timeIntervalSince1970: 1_800_020_000)
        let budget = makeMonthlyBudget(isDeleted: true, deletedAt: deletedAt)

        let dto = WalletSyncRecordMappers.dto(for: budget)

        XCTAssertTrue(dto.isDeleted)
        XCTAssertEqual(dto.deletedAt, deletedAt)
        XCTAssertEqual(dto.updatedAt, budget.updatedAt)
    }

    func testMonthlyBudgetMapperIsDeterministic() {
        let budget = makeMonthlyBudget()

        let first = WalletSyncRecordMappers.dto(for: budget)
        let second = WalletSyncRecordMappers.dto(for: budget)

        XCTAssertEqual(first.recordName, second.recordName)
        XCTAssertEqual(first.entity, second.entity)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.updatedAt, second.updatedAt)
        XCTAssertEqual(first.deletedAt, second.deletedAt)
        XCTAssertEqual(first.isDeleted, second.isDeleted)
        XCTAssertEqual(first.fields, second.fields)
    }

    private func makeMonthlyBudget(
        isDeleted: Bool = false,
        deletedAt: Date? = nil
    ) -> WalletMonthlyBudget {
        WalletMonthlyBudget(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            year: 2025,
            month: 6,
            items: [],
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_010_000),
            isDeleted: isDeleted,
            deletedAt: deletedAt
        )
    }

    // MARK: - PersonDebt mapper tests

    func testPersonDebtMapsToPersonDebtEntity() {
        let debt = makePersonDebt()

        let dto = WalletSyncRecordMappers.dto(for: debt)

        XCTAssertEqual(dto.entity, .personDebt)
    }

    func testPersonDebtRecordNameIsStable() {
        let debt = makePersonDebt()

        let dto = WalletSyncRecordMappers.dto(for: debt)

        XCTAssertEqual(dto.recordName, "PersonDebt_bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")
        XCTAssertEqual(dto.recordName, WalletSyncRecordIdentity(entity: .personDebt, id: debt.id).recordName)
    }

    func testPersonDebtIDIsPreserved() {
        let debt = makePersonDebt()

        let dto = WalletSyncRecordMappers.dto(for: debt)

        XCTAssertEqual(dto.id, debt.id)
    }

    func testPersonDebtImportantFieldsArePresent() {
        let debt = makePersonDebt()

        let dto = WalletSyncRecordMappers.dto(for: debt)

        XCTAssertEqual(dto.fields["personName"], .string("Ahmed"))
        XCTAssertEqual(dto.fields["kind"], .string("Owed to Me"))
        XCTAssertEqual(dto.fields["originalAmount"], .double(500.00))
        XCTAssertEqual(dto.fields["isArchived"], .bool(false))
        XCTAssertEqual(dto.fields["createdAt"], .date(debt.createdAt))
    }

    func testPersonDebtNoteIsPreserved() {
        let debt = makePersonDebt(note: "Borrowed for trip")

        let dto = WalletSyncRecordMappers.dto(for: debt)

        XCTAssertEqual(dto.fields["note"], .string("Borrowed for trip"))
    }

    func testPersonDebtNilNoteMapsToNull() {
        let debt = makePersonDebt()

        let dto = WalletSyncRecordMappers.dto(for: debt)

        XCTAssertEqual(dto.fields["note"], .null)
    }

    func testPersonDebtDueDateIsPreserved() {
        let dueDate = Date(timeIntervalSince1970: 1_800_050_000)
        let debt = makePersonDebt(dueDate: dueDate)

        let dto = WalletSyncRecordMappers.dto(for: debt)

        XCTAssertEqual(dto.fields["dueDate"], .date(dueDate))
    }

    func testPersonDebtNilDueDateMapsToNull() {
        let debt = makePersonDebt()

        let dto = WalletSyncRecordMappers.dto(for: debt)

        XCTAssertEqual(dto.fields["dueDate"], .null)
    }

    func testPersonDebtTombstoneMetadataIsPreserved() {
        let deletedAt = Date(timeIntervalSince1970: 1_800_020_000)
        var debt = makePersonDebt()
        debt.isDeleted = true
        debt.deletedAt = deletedAt

        let dto = WalletSyncRecordMappers.dto(for: debt)

        XCTAssertTrue(dto.isDeleted)
        XCTAssertEqual(dto.deletedAt, deletedAt)
        XCTAssertEqual(dto.updatedAt, debt.updatedAt)
    }

    func testPersonDebtMapperIsDeterministic() {
        let debt = makePersonDebt()

        let first = WalletSyncRecordMappers.dto(for: debt)
        let second = WalletSyncRecordMappers.dto(for: debt)

        XCTAssertEqual(first.recordName, second.recordName)
        XCTAssertEqual(first.entity, second.entity)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.updatedAt, second.updatedAt)
        XCTAssertEqual(first.deletedAt, second.deletedAt)
        XCTAssertEqual(first.isDeleted, second.isDeleted)
        XCTAssertEqual(first.fields, second.fields)
    }

    private func makePersonDebt(
        note: String? = nil,
        dueDate: Date? = nil
    ) -> PersonDebt {
        var debt = PersonDebt(
            personName: "Ahmed",
            kind: .owedToMe,
            originalAmount: 500.00
        )
        debt.id = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        debt.createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        debt.updatedAt = Date(timeIntervalSince1970: 1_800_010_000)
        debt.note = note
        debt.dueDate = dueDate
        return debt
    }

    // MARK: - WalletMonthlyBudgetItem mapper tests

    func testMonthlyBudgetItemMapsToMonthlyBudgetItemEntity() {
        let item = makeMonthlyBudgetItem()

        let dto = WalletSyncRecordMappers.dto(for: item)

        XCTAssertEqual(dto.entity, .monthlyBudgetItem)
    }

    func testMonthlyBudgetItemRecordNameIsStable() {
        let item = makeMonthlyBudgetItem()

        let dto = WalletSyncRecordMappers.dto(for: item)

        XCTAssertEqual(dto.recordName, "MonthlyBudgetItem_cccccccc-cccc-cccc-cccc-cccccccccccc")
        XCTAssertEqual(dto.recordName, WalletSyncRecordIdentity(entity: .monthlyBudgetItem, id: item.id).recordName)
    }

    func testMonthlyBudgetItemIDIsPreserved() {
        let item = makeMonthlyBudgetItem()

        let dto = WalletSyncRecordMappers.dto(for: item)

        XCTAssertEqual(dto.id, item.id)
    }

    func testMonthlyBudgetItemImportantFieldsArePresent() {
        let item = makeMonthlyBudgetItem()

        let dto = WalletSyncRecordMappers.dto(for: item)

        XCTAssertEqual(dto.fields["categoryName"], .string("Food"))
        XCTAssertEqual(dto.fields["plannedAmount"], .double(800.00))
        XCTAssertEqual(dto.fields["createdAt"], .date(item.createdAt))
    }

    func testMonthlyBudgetItemTombstoneMetadataIsPreserved() {
        let deletedAt = Date(timeIntervalSince1970: 1_800_020_000)
        let item = makeMonthlyBudgetItem(isDeleted: true, deletedAt: deletedAt)

        let dto = WalletSyncRecordMappers.dto(for: item)

        XCTAssertTrue(dto.isDeleted)
        XCTAssertEqual(dto.deletedAt, deletedAt)
        XCTAssertEqual(dto.updatedAt, item.updatedAt)
    }

    func testMonthlyBudgetItemMapperIsDeterministic() {
        let item = makeMonthlyBudgetItem()

        let first = WalletSyncRecordMappers.dto(for: item)
        let second = WalletSyncRecordMappers.dto(for: item)

        XCTAssertEqual(first.recordName, second.recordName)
        XCTAssertEqual(first.entity, second.entity)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.updatedAt, second.updatedAt)
        XCTAssertEqual(first.deletedAt, second.deletedAt)
        XCTAssertEqual(first.isDeleted, second.isDeleted)
        XCTAssertEqual(first.fields, second.fields)
    }

    private func makeMonthlyBudgetItem(
        isDeleted: Bool = false,
        deletedAt: Date? = nil
    ) -> WalletMonthlyBudgetItem {
        var item = WalletMonthlyBudgetItem(
            categoryName: "Food",
            plannedAmount: 800.00
        )
        item.id = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
        item.createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        item.updatedAt = Date(timeIntervalSince1970: 1_800_010_000)
        item.isDeleted = isDeleted
        item.deletedAt = deletedAt
        return item
    }

    // MARK: - PersonDebtEntry mapper tests

    func testPersonDebtEntryMapsToPersonDebtEntryEntity() {
        let entry = makePersonDebtEntry()

        let dto = WalletSyncRecordMappers.dto(for: entry)

        XCTAssertEqual(dto.entity, .personDebtEntry)
    }

    func testPersonDebtEntryRecordNameIsStable() {
        let entry = makePersonDebtEntry()

        let dto = WalletSyncRecordMappers.dto(for: entry)

        XCTAssertEqual(dto.recordName, "PersonDebtEntry_dddddddd-dddd-dddd-dddd-dddddddddddd")
        XCTAssertEqual(dto.recordName, WalletSyncRecordIdentity(entity: .personDebtEntry, id: entry.id).recordName)
    }

    func testPersonDebtEntryIDIsPreserved() {
        let entry = makePersonDebtEntry()

        let dto = WalletSyncRecordMappers.dto(for: entry)

        XCTAssertEqual(dto.id, entry.id)
    }

    func testPersonDebtEntryImportantFieldsArePresent() {
        let entry = makePersonDebtEntry()

        let dto = WalletSyncRecordMappers.dto(for: entry)

        XCTAssertEqual(dto.fields["entryType"], .string("Repayment Received"))
        XCTAssertEqual(dto.fields["amount"], .double(200.00))
        XCTAssertEqual(dto.fields["accountName"], .string("Main Wallet"))
        XCTAssertEqual(dto.fields["date"], .date(entry.date))
        XCTAssertEqual(dto.fields["createdAt"], .date(entry.createdAt))
    }

    func testPersonDebtEntryParentDebtLinkageIsPreserved() {
        let debtID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        let entry = makePersonDebtEntry(debtID: debtID)

        let dto = WalletSyncRecordMappers.dto(for: entry)

        XCTAssertEqual(dto.fields["debtID"], .uuid(debtID))
    }

    func testPersonDebtEntryNoteIsPreserved() {
        let entry = makePersonDebtEntry(note: "Partial payment")

        let dto = WalletSyncRecordMappers.dto(for: entry)

        XCTAssertEqual(dto.fields["note"], .string("Partial payment"))
    }

    func testPersonDebtEntryNilNoteMapsToNull() {
        let entry = makePersonDebtEntry()

        let dto = WalletSyncRecordMappers.dto(for: entry)

        XCTAssertEqual(dto.fields["note"], .null)
    }

    func testPersonDebtEntryTombstoneMetadataIsPreserved() {
        let deletedAt = Date(timeIntervalSince1970: 1_800_020_000)
        let entry = makePersonDebtEntry(isDeleted: true, deletedAt: deletedAt)

        let dto = WalletSyncRecordMappers.dto(for: entry)

        XCTAssertTrue(dto.isDeleted)
        XCTAssertEqual(dto.deletedAt, deletedAt)
        XCTAssertEqual(dto.updatedAt, entry.updatedAt)
    }

    func testPersonDebtEntryMapperIsDeterministic() {
        let entry = makePersonDebtEntry()

        let first = WalletSyncRecordMappers.dto(for: entry)
        let second = WalletSyncRecordMappers.dto(for: entry)

        XCTAssertEqual(first.recordName, second.recordName)
        XCTAssertEqual(first.entity, second.entity)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.updatedAt, second.updatedAt)
        XCTAssertEqual(first.deletedAt, second.deletedAt)
        XCTAssertEqual(first.isDeleted, second.isDeleted)
        XCTAssertEqual(first.fields, second.fields)
    }

    private func makePersonDebtEntry(
        debtID: UUID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
        note: String? = nil,
        isDeleted: Bool = false,
        deletedAt: Date? = nil
    ) -> PersonDebtEntry {
        var entry = PersonDebtEntry(
            debtID: debtID,
            entryType: .repaymentReceived,
            amount: 200.00,
            accountName: "Main Wallet",
            date: Date(timeIntervalSince1970: 1_800_000_000)
        )
        entry.id = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
        entry.createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        entry.updatedAt = Date(timeIntervalSince1970: 1_800_010_000)
        entry.note = note
        entry.isDeleted = isDeleted
        entry.deletedAt = deletedAt
        return entry
    }
}
