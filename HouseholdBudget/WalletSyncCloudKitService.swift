import Foundation
import CloudKit

struct WalletSyncCloudKitConfiguration: Equatable {
    var containerIdentifier: String?
    var databaseScope: CKDatabase.Scope

    init(
        containerIdentifier: String? = nil,
        databaseScope: CKDatabase.Scope = .private
    ) {
        self.containerIdentifier = containerIdentifier
        self.databaseScope = databaseScope
    }
}

protocol WalletSyncCloudKitDatabaseBoundary: AnyObject {}

@MainActor
final class WalletSyncCloudKitService {
    let configuration: WalletSyncCloudKitConfiguration
    private let databaseBoundary: WalletSyncCloudKitDatabaseBoundary?

    init(
        configuration: WalletSyncCloudKitConfiguration? = nil,
        databaseBoundary: WalletSyncCloudKitDatabaseBoundary? = nil
    ) {
        self.configuration = configuration ?? WalletSyncCloudKitConfiguration()
        self.databaseBoundary = databaseBoundary
    }

    func prepareRecordsForUpload(_ dtos: [WalletSyncRecordDTO]) -> [CKRecord] {
        dtos.map(WalletSyncCKRecordAdapter.ckRecord(from:))
    }

    func decodeDownloadedRecords(_ records: [CKRecord]) throws -> [WalletSyncRecordDTO] {
        try records.map(WalletSyncCKRecordAdapter.dto(from:))
    }
}
