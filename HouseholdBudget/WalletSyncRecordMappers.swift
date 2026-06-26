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
}
