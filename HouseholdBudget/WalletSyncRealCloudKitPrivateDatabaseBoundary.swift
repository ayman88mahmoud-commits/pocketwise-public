import Foundation
import CloudKit

protocol WalletSyncPrivateDatabaseRecordSaving {
    func saveRecords(_ records: [CKRecord]) async throws -> [CKRecord]
}

// Resolves the private CloudKit database from the container at call time and
// batches records through a CKModifyRecordsOperation. Returns empty immediately
// for an empty input to avoid creating any CloudKit operation.
struct WalletSyncCKPrivateDatabaseRecordSaver: WalletSyncPrivateDatabaseRecordSaving {
    private let containerIdentifier: String?

    init(containerIdentifier: String? = nil) {
        self.containerIdentifier = containerIdentifier
    }

    func saveRecords(_ records: [CKRecord]) async throws -> [CKRecord] {
        if records.isEmpty { return [] }
        let container = containerIdentifier.map(CKContainer.init(identifier:)) ?? CKContainer.default()
        let database = container.privateCloudDatabase
        return try await withCheckedThrowingContinuation { continuation in
            var savedRecords: [CKRecord] = []
            let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
            operation.perRecordSaveBlock = { _, result in
                if case .success(let record) = result {
                    savedRecords.append(record)
                }
            }
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: savedRecords)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(operation)
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

    init(
        configuration: WalletSyncCloudKitConfiguration,
        accountStatusProvider: WalletSyncCloudKitAccountStatusProviding,
        recordSaver: WalletSyncPrivateDatabaseRecordSaving
    ) {
        self.configuration = configuration
        self.accountStatusProvider = accountStatusProvider
        self.recordSaver = recordSaver
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

    func fetchChangedRecords(since changeToken: Data?) async throws -> WalletSyncCloudKitFetchResult {
        throw WalletSyncCloudKitError.recordOperationsNotEnabled
    }
}
