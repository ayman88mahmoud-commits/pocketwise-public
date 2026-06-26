import Foundation

enum WalletSyncRecordMappers {
    static func dto(for account: Account) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            identity: WalletSyncRecordIdentity(entity: .account, id: account.id),
            updatedAt: account.updatedAt,
            deletedAt: account.deletedAt,
            isDeleted: account.isDeleted,
            fields: [
                "name": .string(account.name),
                "balance": .double(account.balance),
                "type": .string(account.type.rawValue),
                "isActive": .bool(account.isActive),
                "recognitionAliases": .stringArray(account.recognitionAliases),
                "recognitionCardEndings": .stringArray(account.recognitionCardEndings),
                "appearanceColor": account.appearanceColor.map { .string($0.rawValue) } ?? .null,
                "createdAt": .date(account.createdAt)
            ]
        )
    }

    static func dto(for category: Category) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            identity: WalletSyncRecordIdentity(entity: .category, id: category.id),
            updatedAt: category.updatedAt,
            deletedAt: category.deletedAt,
            isDeleted: category.isDeleted,
            fields: [
                "name": .string(category.name),
                "subcategories": .stringArray(category.subcategories),
                "isActive": .bool(category.isActive),
                "inactiveSubcategoryNames": .stringArray(category.inactiveSubcategoryNames),
                "createdAt": .date(category.createdAt)
            ]
        )
    }

    static func dto(for walletEvent: WalletEvent) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            identity: WalletSyncRecordIdentity(entity: .walletEvent, id: walletEvent.id),
            updatedAt: walletEvent.updatedAt,
            deletedAt: walletEvent.deletedAt,
            isDeleted: walletEvent.isDeleted,
            fields: [
                "name": .string(walletEvent.name),
                "categoryName": .string(walletEvent.categoryName),
                "subCategoryName": .string(walletEvent.subCategoryName),
                "defaultAccountName": walletEvent.defaultAccountName.map { .string($0) } ?? .null,
                "isFavorite": .bool(walletEvent.isFavorite),
                "isActive": .bool(walletEvent.isActive),
                "createdAt": .date(walletEvent.createdAt)
            ]
        )
    }

    static func dto(for memory: MerchantMemory) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            identity: WalletSyncRecordIdentity(entity: .merchantMemory, id: memory.id),
            updatedAt: memory.updatedAt,
            deletedAt: memory.deletedAt,
            isDeleted: memory.isDeleted,
            fields: [
                "merchantName": .string(memory.merchantName),
                "aliases": .stringArray(memory.aliases),
                "defaultCategoryName": .string(memory.defaultCategoryName),
                "defaultSubCategoryName": .string(memory.defaultSubCategoryName),
                "defaultAccountName": memory.defaultAccountName.map { .string($0) } ?? .null,
                "defaultType": .string(memory.defaultType.rawValue),
                "lastUsedAt": memory.lastUsedAt.map { .date($0) } ?? .null,
                "usageCount": .int(memory.usageCount),
                "isActive": .bool(memory.isActive),
                "createdAt": .date(memory.createdAt)
            ]
        )
    }

    static func dto(for plan: InstallmentPlan) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            identity: WalletSyncRecordIdentity(entity: .installmentPlan, id: plan.id),
            updatedAt: plan.updatedAt,
            deletedAt: plan.deletedAt,
            isDeleted: plan.isDeleted,
            fields: [
                "purchaseName": .string(plan.purchaseName),
                "totalAmount": .double(plan.totalAmount),
                "installmentCount": .int(plan.installmentCount),
                "firstDueDate": .date(plan.firstDueDate),
                "accountName": plan.accountName.map { .string($0) } ?? .null,
                "categoryName": .string(plan.categoryName),
                "subCategoryName": .string(plan.subCategoryName),
                "paymentMethodName": .string(plan.paymentMethodName),
                "linkedCreditCardID": plan.linkedCreditCardID.map { .uuid($0) } ?? .null,
                "note": plan.note.map { .string($0) } ?? .null,
                "createdAt": .date(plan.createdAt)
            ]
        )
    }

    // items ([WalletMonthlyBudgetItem]) is intentionally omitted — it is a nested object array with no matching WalletSyncFieldValue type yet. Each item syncs independently via the .monthlyBudget entity's child records.
    static func dto(for budget: WalletMonthlyBudget) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            identity: WalletSyncRecordIdentity(entity: .monthlyBudget, id: budget.id),
            updatedAt: budget.updatedAt,
            deletedAt: budget.deletedAt,
            isDeleted: budget.isDeleted,
            fields: [
                "year": .int(budget.year),
                "month": .int(budget.month),
                "createdAt": .date(budget.createdAt)
            ]
        )
    }

    static func dto(for debt: PersonDebt) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            identity: WalletSyncRecordIdentity(entity: .personDebt, id: debt.id),
            updatedAt: debt.updatedAt,
            deletedAt: debt.deletedAt,
            isDeleted: debt.isDeleted,
            fields: [
                "personName": .string(debt.personName),
                "kind": .string(debt.kind.rawValue),
                "originalAmount": .double(debt.originalAmount),
                "note": debt.note.map { .string($0) } ?? .null,
                "dueDate": debt.dueDate.map { .date($0) } ?? .null,
                "isArchived": .bool(debt.isArchived),
                "createdAt": .date(debt.createdAt)
            ]
        )
    }

    static func dto(for item: WalletMonthlyBudgetItem) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            identity: WalletSyncRecordIdentity(entity: .monthlyBudgetItem, id: item.id),
            updatedAt: item.updatedAt,
            deletedAt: item.deletedAt,
            isDeleted: item.isDeleted,
            fields: [
                "categoryName": .string(item.categoryName),
                "plannedAmount": .double(item.plannedAmount),
                "createdAt": .date(item.createdAt)
            ]
        )
    }

    static func dto(for entry: PersonDebtEntry) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            identity: WalletSyncRecordIdentity(entity: .personDebtEntry, id: entry.id),
            updatedAt: entry.updatedAt,
            deletedAt: entry.deletedAt,
            isDeleted: entry.isDeleted,
            fields: [
                "debtID": .uuid(entry.debtID),
                "entryType": .string(entry.entryType.rawValue),
                "amount": .double(entry.amount),
                "accountName": .string(entry.accountName),
                "date": .date(entry.date),
                "note": entry.note.map { .string($0) } ?? .null,
                "createdAt": .date(entry.createdAt)
            ]
        )
    }

    static func dto(for card: CreditCard) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            identity: WalletSyncRecordIdentity(entity: .creditCard, id: card.id),
            updatedAt: card.updatedAt,
            deletedAt: card.deletedAt,
            isDeleted: card.isDeleted,
            fields: [
                "name": .string(card.name),
                "bankName": .string(card.bankName),
                "lastFourDigits": card.lastFourDigits.map { .string($0) } ?? .null,
                "cardNetwork": .string(card.cardNetwork.rawValue),
                "appearanceColor": card.appearanceColor.map { .string($0.rawValue) } ?? .null,
                "creditLimit": .double(card.creditLimit),
                "openingOutstandingBalance": .double(card.openingOutstandingBalance),
                "openingOutstandingDate": card.openingOutstandingDate.map { .date($0) } ?? .null,
                "statementClosingDay": .int(card.statementClosingDay),
                "paymentDueDay": .int(card.paymentDueDay),
                "defaultPaymentAccountName": card.defaultPaymentAccountName.map { .string($0) } ?? .null,
                "isActive": .bool(card.isActive),
                "note": card.note.map { .string($0) } ?? .null,
                "createdAt": .date(card.createdAt)
            ]
        )
    }

    static func dto(for purchase: CreditCardPurchase) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            identity: WalletSyncRecordIdentity(entity: .creditCardPurchase, id: purchase.id),
            updatedAt: purchase.updatedAt,
            deletedAt: purchase.deletedAt,
            isDeleted: purchase.isDeleted,
            fields: [
                "cardID": .uuid(purchase.cardID),
                "title": .string(purchase.title),
                "amount": .double(purchase.amount),
                "purchaseDate": .date(purchase.purchaseDate),
                "categoryName": .string(purchase.categoryName),
                "subCategoryName": .string(purchase.subCategoryName),
                "note": purchase.note.map { .string($0) } ?? .null,
                "createdAt": .date(purchase.createdAt)
            ]
        )
    }

    static func dto(for payment: CreditCardPayment) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            identity: WalletSyncRecordIdentity(entity: .creditCardPayment, id: payment.id),
            updatedAt: payment.updatedAt,
            deletedAt: payment.deletedAt,
            isDeleted: payment.isDeleted,
            fields: [
                "cardID": .uuid(payment.cardID),
                "fromAccountName": .string(payment.fromAccountName),
                "amount": .double(payment.amount),
                "paymentDate": .date(payment.paymentDate),
                "note": payment.note.map { .string($0) } ?? .null,
                "createdAt": .date(payment.createdAt)
            ]
        )
    }

    // recurringScheduleOverrides is intentionally omitted — it is a nested object array with no matching WalletSyncFieldValue type yet.
    static func dto(for event: FinancialEvent) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            identity: WalletSyncRecordIdentity(entity: .financialEvent, id: event.id),
            updatedAt: event.updatedAt,
            deletedAt: event.deletedAt,
            isDeleted: event.isDeleted,
            fields: [
                "type": .string(event.type.rawValue),
                "status": .string(event.status.rawValue),
                "title": .string(event.title),
                "amount": .double(event.amount),
                "date": .date(event.date),
                "accountName": event.accountName.map { .string($0) } ?? .null,
                "destinationAccountName": event.destinationAccountName.map { .string($0) } ?? .null,
                "paymentMethodName": event.paymentMethodName.map { .string($0) } ?? .null,
                "walletEventName": event.walletEventName.map { .string($0) } ?? .null,
                "categoryName": event.categoryName.map { .string($0) } ?? .null,
                "subCategoryName": event.subCategoryName.map { .string($0) } ?? .null,
                "incomeType": event.incomeType.map { .string($0.rawValue) } ?? .null,
                "reimbursementCategoryName": event.reimbursementCategoryName.map { .string($0) } ?? .null,
                "repeatRule": .string(event.repeatRule.rawValue),
                "recurringEndKind": event.recurringEndKind.map { .string($0.rawValue) } ?? .null,
                "recurringEndDate": event.recurringEndDate.map { .date($0) } ?? .null,
                "recurringEndPaymentCount": event.recurringEndPaymentCount.map { .int($0) } ?? .null,
                "recurringAmountMode": event.recurringAmountMode.map { .string($0.rawValue) } ?? .null,
                "recurringEstimatedAmount": event.recurringEstimatedAmount.map { .double($0) } ?? .null,
                "confidence": event.confidence.map { .string($0.rawValue) } ?? .null,
                "sourceInstallmentPlanID": event.sourceInstallmentPlanID.map { .uuid($0) } ?? .null,
                "sourceRecurringEventID": event.sourceRecurringEventID.map { .uuid($0) } ?? .null,
                "recurringOccurrenceYear": event.recurringOccurrenceYear.map { .int($0) } ?? .null,
                "recurringOccurrenceMonth": event.recurringOccurrenceMonth.map { .int($0) } ?? .null,
                "note": event.note.map { .string($0) } ?? .null,
                "createdAt": .date(event.createdAt)
            ]
        )
    }
}
