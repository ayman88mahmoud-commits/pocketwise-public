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
    var deletedRecordNames: [String]
    var changeTokenData: Data?
    var moreComing: Bool

    nonisolated init(
        records: [CKRecord],
        deletedRecordNames: [String] = [],
        changeTokenData: Data? = nil,
        moreComing: Bool = false
    ) {
        self.records = records
        self.deletedRecordNames = deletedRecordNames
        self.changeTokenData = changeTokenData
        self.moreComing = moreComing
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

    init(cloudKitAccountStatus status: CKAccountStatus) {
        switch status {
        case .available:
            self = .available
        case .noAccount:
            self = .noAccount
        case .restricted:
            self = .restricted
        case .couldNotDetermine:
            self = .couldNotDetermine
        case .temporarilyUnavailable:
            self = .temporarilyUnavailable
        @unknown default:
            self = .unknown
        }
    }
}

protocol WalletSyncCloudKitDatabaseBoundary: AnyObject {
    func accountAvailability() async throws -> WalletSyncCloudKitAccountAvailability
    func saveRecords(_ records: [CKRecord]) async throws -> [CKRecord]
    func fetchChangedRecords(since changeToken: Data?) async throws -> WalletSyncCloudKitFetchResult
}

protocol WalletSyncCloudKitAccountStatusProviding {
    func accountStatus() async throws -> CKAccountStatus
}

struct WalletSyncCKContainerAccountStatusProvider: WalletSyncCloudKitAccountStatusProviding {
    private let container: CKContainer

    init(containerIdentifier: String? = nil) {
        if let containerIdentifier {
            self.container = CKContainer(identifier: containerIdentifier)
        } else {
            self.container = CKContainer.default()
        }
    }

    init(container: CKContainer) {
        self.container = container
    }

    func accountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            container.accountStatus { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }
}

final class WalletSyncRealCloudKitAccountBoundary: WalletSyncCloudKitDatabaseBoundary {
    private let accountStatusProvider: WalletSyncCloudKitAccountStatusProviding

    init(accountStatusProvider: WalletSyncCloudKitAccountStatusProviding) {
        self.accountStatusProvider = accountStatusProvider
    }

    convenience init(containerIdentifier: String? = nil) {
        self.init(
            accountStatusProvider: WalletSyncCKContainerAccountStatusProvider(
                containerIdentifier: containerIdentifier
            )
        )
    }

    func accountAvailability() async throws -> WalletSyncCloudKitAccountAvailability {
        do {
            let status = try await accountStatusProvider.accountStatus()
            return WalletSyncCloudKitAccountAvailability(cloudKitAccountStatus: status)
        } catch {
            throw WalletSyncCloudKitError.unknown(underlying: error)
        }
    }

    func saveRecords(_ records: [CKRecord]) async throws -> [CKRecord] {
        throw WalletSyncCloudKitError.recordOperationsNotEnabled
    }

    func fetchChangedRecords(since changeToken: Data?) async throws -> WalletSyncCloudKitFetchResult {
        throw WalletSyncCloudKitError.recordOperationsNotEnabled
    }
}

enum WalletSyncCloudKitError: LocalizedError {
    case missingDatabaseBoundary
    case invalidRecord(String)
    case wrongRecordType(String)
    case cloudKitUnavailable
    case recordOperationsNotEnabled
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
        case .recordOperationsNotEnabled:
            return "Record operations are not enabled in this sync phase."
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
