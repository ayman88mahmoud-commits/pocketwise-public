import Foundation
import CloudKit

enum WalletSyncInboxItemStatus: Equatable {
    case validChangedRecord
    case validDeletedTombstone
    case deletedRecordNameOnly
    case unsupportedEntity
    case decodeFailed
    case blockedMonthlyBudgetItemNoParent
    case blockedHouseholdSettingsNoModel
}

struct WalletSyncInboxItem: Equatable {
    var recordName: String
    var entity: WalletSyncRecordEntity?
    var id: UUID?
    var isDeleted: Bool
    var updatedAt: Date?
    var deletedAt: Date?
    var fieldCount: Int
    var status: WalletSyncInboxItemStatus
}

struct WalletSyncInboxParseResult: Equatable {
    var items: [WalletSyncInboxItem]

    var validCount: Int {
        items.filter {
            $0.status == .validChangedRecord ||
            $0.status == .validDeletedTombstone ||
            $0.status == .deletedRecordNameOnly
        }.count
    }

    var blockedCount: Int {
        items.filter {
            $0.status == .blockedMonthlyBudgetItemNoParent ||
            $0.status == .blockedHouseholdSettingsNoModel ||
            $0.status == .unsupportedEntity
        }.count
    }

    var failedCount: Int {
        items.filter { $0.status == .decodeFailed }.count
    }
}

struct WalletSyncInboxParser {
    func parse(
        changedRecords: [CKRecord],
        deletedRecordNames: [String]
    ) -> WalletSyncInboxParseResult {
        let changedItems = changedRecords.map(parseChangedRecord)
        let deletedItems = deletedRecordNames.map(parseDeletedRecordName)
        return WalletSyncInboxParseResult(items: changedItems + deletedItems)
    }

    private func parseChangedRecord(_ record: CKRecord) -> WalletSyncInboxItem {
        let recordName = record.recordID.recordName

        do {
            let dto = try WalletSyncCKRecordAdapter.dto(from: record)
            return WalletSyncInboxItem(
                recordName: dto.recordName,
                entity: dto.entity,
                id: dto.id,
                isDeleted: dto.isDeleted,
                updatedAt: dto.updatedAt,
                deletedAt: dto.deletedAt,
                fieldCount: dto.fields.count,
                status: status(for: dto)
            )
        } catch WalletSyncCKRecordAdapter.AdapterError.invalidEntity(_) {
            return failedItem(recordName: recordName, status: .unsupportedEntity)
        } catch {
            return failedItem(recordName: recordName, status: .decodeFailed)
        }
    }

    private func parseDeletedRecordName(_ recordName: String) -> WalletSyncInboxItem {
        let identity = identityFromRecordName(recordName)
        return WalletSyncInboxItem(
            recordName: recordName,
            entity: identity?.entity,
            id: identity?.id,
            isDeleted: true,
            updatedAt: nil,
            deletedAt: nil,
            fieldCount: 0,
            status: .deletedRecordNameOnly
        )
    }

    private func status(for dto: WalletSyncRecordDTO) -> WalletSyncInboxItemStatus {
        switch dto.entity {
        case .monthlyBudgetItem:
            return .blockedMonthlyBudgetItemNoParent
        case .householdSettings:
            return .blockedHouseholdSettingsNoModel
        default:
            return dto.isDeleted ? .validDeletedTombstone : .validChangedRecord
        }
    }

    private func failedItem(
        recordName: String,
        status: WalletSyncInboxItemStatus
    ) -> WalletSyncInboxItem {
        WalletSyncInboxItem(
            recordName: recordName,
            entity: nil,
            id: nil,
            isDeleted: false,
            updatedAt: nil,
            deletedAt: nil,
            fieldCount: 0,
            status: status
        )
    }

    private func identityFromRecordName(_ recordName: String) -> WalletSyncRecordIdentity? {
        for entity in WalletSyncRecordEntity.allCases {
            let prefix = "\(entity.recordNamePrefix)_"
            guard recordName.hasPrefix(prefix) else { continue }
            let idText = String(recordName.dropFirst(prefix.count))
            guard let id = UUID(uuidString: idText) else { return nil }
            return WalletSyncRecordIdentity(entity: entity, id: id)
        }

        return nil
    }
}
