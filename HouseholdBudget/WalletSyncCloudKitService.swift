import Foundation
import CloudKit

struct WalletSyncCloudKitConfiguration: Equatable {
    var containerIdentifier: String?
    var databaseScope: CKDatabase.Scope

    nonisolated init(
        containerIdentifier: String? = nil,
        databaseScope: CKDatabase.Scope = .private
    ) {
        self.containerIdentifier = containerIdentifier
        self.databaseScope = databaseScope
    }
}

struct WalletSyncCloudKitFetchResult {
    var records: [CKRecord]
    var changeTokenData: Data?

    nonisolated init(records: [CKRecord], changeTokenData: Data? = nil) {
        self.records = records
        self.changeTokenData = changeTokenData
    }
}

protocol WalletSyncCloudKitDatabaseBoundary: AnyObject {
    func saveRecords(_ records: [CKRecord]) async throws -> [CKRecord]
    func fetchChangedRecords(since changeToken: Data?) async throws -> WalletSyncCloudKitFetchResult
}

enum WalletSyncCloudKitServiceError: Error, Equatable {
    case missingDatabaseBoundary
}

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

    func uploadPreparedRecords(_ records: [CKRecord]) async throws -> [CKRecord] {
        guard let databaseBoundary else {
            throw WalletSyncCloudKitServiceError.missingDatabaseBoundary
        }

        return try await databaseBoundary.saveRecords(records)
    }

    func fetchRecordChanges(since changeToken: Data?) async throws -> WalletSyncCloudKitFetchResult {
        guard let databaseBoundary else {
            throw WalletSyncCloudKitServiceError.missingDatabaseBoundary
        }

        return try await databaseBoundary.fetchChangedRecords(since: changeToken)
    }
}
