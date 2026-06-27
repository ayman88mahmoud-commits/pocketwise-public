import Foundation
import CloudKit

protocol WalletSyncPrivateDatabaseRecordSaving {
    func saveRecords(_ records: [CKRecord]) async throws -> [CKRecord]
}

protocol WalletSyncPrivateDatabaseRecordFetching {
    func fetchRecord(named recordName: String) async throws -> CKRecord
}

// Resolves the private CloudKit database from the container at call time and
// returns CloudKit's per-record save results in the same order as the input.
// Empty input returns immediately to avoid touching CloudKit.
struct WalletSyncCKPrivateDatabaseRecordSaver: WalletSyncPrivateDatabaseRecordSaving {
    private let containerIdentifier: String?

    init(containerIdentifier: String? = nil) {
        self.containerIdentifier = containerIdentifier
    }

    func saveRecords(_ records: [CKRecord]) async throws -> [CKRecord] {
        if records.isEmpty { return [] }
        let container = containerIdentifier.map(CKContainer.init(identifier:)) ?? CKContainer.default()
        let database = container.privateCloudDatabase

        let result = try await database.modifyRecords(
            saving: records,
            deleting: [],
            savePolicy: .changedKeys,
            atomically: true
        )

        return try records.map { record in
            guard let saveResult = result.saveResults[record.recordID] else {
                throw WalletSyncCloudKitError.invalidRecord(record.recordID.recordName)
            }

            return try saveResult.get()
        }
    }
}

// Resolves the private CloudKit database at call time and fetches one specific
// record ID. It does not query, fetch changes, or persist any token state.
struct WalletSyncCKPrivateDatabaseRecordFetcher: WalletSyncPrivateDatabaseRecordFetching {
    private let containerIdentifier: String?

    init(containerIdentifier: String? = nil) {
        self.containerIdentifier = containerIdentifier
    }

    func fetchRecord(named recordName: String) async throws -> CKRecord {
        let container = containerIdentifier.map(CKContainer.init(identifier:)) ?? CKContainer.default()
        let database = container.privateCloudDatabase
        let recordID = CKRecord.ID(recordName: recordName)

        return try await withCheckedThrowingContinuation { continuation in
            database.fetch(withRecordID: recordID) { record, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let record {
                    continuation.resume(returning: record)
                } else {
                    continuation.resume(throwing: WalletSyncCloudKitError.invalidRecord(recordName))
                }
            }
        }
    }
}

// Holds configuration for the private CloudKit database and delegates account status
// to an injected provider. Record save operations are delegated to an injected
// record-saving provider. fetchChangedRecords remains disabled until a future phase
// explicitly enables it.
final class WalletSyncRealCloudKitPrivateDatabaseBoundary: WalletSyncCloudKitDatabaseBoundary {

    private let configuration: WalletSyncCloudKitConfiguration
    private let accountStatusProvider: WalletSyncCloudKitAccountStatusProviding
    private let recordSaver: WalletSyncPrivateDatabaseRecordSaving
    private let recordFetcher: WalletSyncPrivateDatabaseRecordFetching

    init(
        configuration: WalletSyncCloudKitConfiguration,
        accountStatusProvider: WalletSyncCloudKitAccountStatusProviding,
        recordSaver: WalletSyncPrivateDatabaseRecordSaving,
        recordFetcher: WalletSyncPrivateDatabaseRecordFetching
    ) {
        self.configuration = configuration
        self.accountStatusProvider = accountStatusProvider
        self.recordSaver = recordSaver
        self.recordFetcher = recordFetcher
    }

    convenience init(
        configuration: WalletSyncCloudKitConfiguration = WalletSyncCloudKitConfiguration()
    ) {
        self.init(
            configuration: configuration,
            accountStatusProvider: WalletSyncCKContainerAccountStatusProvider(
                containerIdentifier: configuration.containerIdentifier
            ),
            recordSaver: WalletSyncCKPrivateDatabaseRecordSaver(
                containerIdentifier: configuration.containerIdentifier
            ),
            recordFetcher: WalletSyncCKPrivateDatabaseRecordFetcher(
                containerIdentifier: configuration.containerIdentifier
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
        if records.isEmpty { return [] }

        do {
            return try await recordSaver.saveRecords(records)
        } catch {
            throw WalletSyncCloudKitError.unknown(underlying: error)
        }
    }

    func fetchRecord(named recordName: String) async throws -> CKRecord {
        do {
            return try await recordFetcher.fetchRecord(named: recordName)
        } catch let error as WalletSyncCloudKitError {
            throw error
        } catch {
            throw WalletSyncCloudKitError.unknown(underlying: error)
        }
    }

    func fetchChangedRecords(since changeToken: Data?) async throws -> WalletSyncCloudKitFetchResult {
        throw WalletSyncCloudKitError.recordOperationsNotEnabled
    }
}
