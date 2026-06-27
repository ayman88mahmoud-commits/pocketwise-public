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

struct WalletSyncCloudKitUploadResult {
    var savedRecords: [CKRecord]
    var failedRecordNames: [String]
    var underlyingErrorsByRecordName: [String: Error]

    nonisolated init(
        savedRecords: [CKRecord],
        failedRecordNames: [String] = [],
        underlyingErrorsByRecordName: [String: Error] = [:]
    ) {
        self.savedRecords = savedRecords
        self.failedRecordNames = failedRecordNames
        self.underlyingErrorsByRecordName = underlyingErrorsByRecordName
    }
}

enum WalletSyncCloudKitAccountAvailability: String, Codable, CaseIterable, Hashable {
    case available
    case noAccount
    case restricted
    case couldNotDetermine
    case temporarilyUnavailable
    case unknown
}

protocol WalletSyncCloudKitDatabaseBoundary: AnyObject {
    func accountAvailability() async throws -> WalletSyncCloudKitAccountAvailability
    func saveRecords(_ records: [CKRecord]) async throws -> [CKRecord]
    func fetchChangedRecords(since changeToken: Data?) async throws -> WalletSyncCloudKitFetchResult
}

enum WalletSyncCloudKitError: LocalizedError {
    case missingDatabaseBoundary
    case invalidRecord(String)
    case wrongRecordType(String)
    case cloudKitUnavailable
    case accountNotAvailable
    case networkUnavailable
    case partialFailure(recordNames: [String], underlying: Error)
    case permissionFailure
    case unknown(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .missingDatabaseBoundary:
            return "Cloud sync database boundary is not configured."
        case .invalidRecord(let message):
            return message
        case .wrongRecordType(let recordType):
            return "Unexpected CloudKit record type: \(recordType)."
        case .cloudKitUnavailable:
            return "CloudKit is unavailable."
        case .accountNotAvailable:
            return "iCloud account is not available."
        case .networkUnavailable:
            return "Network is unavailable."
        case .partialFailure(let recordNames, _):
            return "Cloud sync failed for \(recordNames.count) record(s)."
        case .permissionFailure:
            return "CloudKit permission was denied."
        case .unknown(let underlying):
            return underlying.localizedDescription
        }
    }
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
            throw WalletSyncCloudKitError.missingDatabaseBoundary
        }

        return try await databaseBoundary.saveRecords(records)
    }

    func uploadPreparedRecordsWithResult(_ records: [CKRecord]) async throws -> WalletSyncCloudKitUploadResult {
        let savedRecords = try await uploadPreparedRecords(records)
        return WalletSyncCloudKitUploadResult(savedRecords: savedRecords)
    }

    func checkAccountAvailability() async throws -> WalletSyncCloudKitAccountAvailability {
        guard let databaseBoundary else {
            throw WalletSyncCloudKitError.missingDatabaseBoundary
        }

        return try await databaseBoundary.accountAvailability()
    }

    func fetchRecordChanges(since changeToken: Data?) async throws -> WalletSyncCloudKitFetchResult {
        guard let databaseBoundary else {
            throw WalletSyncCloudKitError.missingDatabaseBoundary
        }

        return try await databaseBoundary.fetchChangedRecords(since: changeToken)
    }
}
