import Foundation
import CloudKit

protocol WalletSyncPrivateDatabaseRecordSaving {
    func saveRecords(_ records: [CKRecord]) async throws -> [CKRecord]
}

protocol WalletSyncPrivateDatabaseRecordFetching {
    func fetchRecord(named recordName: String, in zoneID: CKRecordZone.ID) async throws -> CKRecord
}

protocol WalletSyncPrivateDatabaseChangedRecordFetching {
    func fetchChangedRecords(
        in zoneID: CKRecordZone.ID,
        since changeToken: Data?
    ) async throws -> WalletSyncCloudKitFetchResult
}

protocol WalletSyncPrivateDatabaseZoneEnsuring {
    func ensureZone(_ zoneID: CKRecordZone.ID) async throws
}

protocol WalletSyncPrivateDatabaseZoneOperating {
    func fetchZone(_ zoneID: CKRecordZone.ID) async throws -> CKRecordZone
    func saveZone(_ zoneID: CKRecordZone.ID) async throws
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

    func fetchRecord(named recordName: String, in zoneID: CKRecordZone.ID) async throws -> CKRecord {
        let container = containerIdentifier.map(CKContainer.init(identifier:)) ?? CKContainer.default()
        let database = container.privateCloudDatabase
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)

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

// Resolves the private CloudKit database at call time and fetches record-zone
// changes from the supplied sync zone. The returned server change token is
// serialized for callers to inspect or persist in a later phase; this provider
// does not persist any token itself.
struct WalletSyncCKPrivateDatabaseChangedRecordFetcher: WalletSyncPrivateDatabaseChangedRecordFetching {
    private let containerIdentifier: String?

    init(containerIdentifier: String? = nil) {
        self.containerIdentifier = containerIdentifier
    }

    func fetchChangedRecords(
        in zoneID: CKRecordZone.ID,
        since changeToken: Data?
    ) async throws -> WalletSyncCloudKitFetchResult {
        let container = containerIdentifier.map(CKContainer.init(identifier:)) ?? CKContainer.default()
        let database = container.privateCloudDatabase
        let previousToken = try changeToken.flatMap(decodeServerChangeToken(from:))
        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration(
            previousServerChangeToken: previousToken
        )
        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID],
            configurationsByRecordZoneID: [zoneID: configuration]
        )

        return try await withCheckedThrowingContinuation { continuation in
            var changedRecords: [CKRecord] = []
            var deletedRecordNames: [String] = []
            var newTokenData: Data?
            var moreComing = false
            var didResume = false

            operation.recordWasChangedBlock = { _, recordResult in
                if case .success(let record) = recordResult {
                    changedRecords.append(record)
                }
            }

            operation.recordWithIDWasDeletedBlock = { recordID, _ in
                deletedRecordNames.append(recordID.recordName)
            }

            operation.recordZoneFetchResultBlock = { _, fetchChangesResult in
                switch fetchChangesResult {
                case .success(let result):
                    newTokenData = try? encodeServerChangeToken(result.serverChangeToken)
                    moreComing = result.moreComing
                case .failure(let error):
                    if !didResume {
                        didResume = true
                        continuation.resume(throwing: error)
                    }
                }
            }

            operation.fetchRecordZoneChangesResultBlock = { operationResult in
                guard !didResume else { return }
                didResume = true

                switch operationResult {
                case .success:
                    continuation.resume(
                        returning: WalletSyncCloudKitFetchResult(
                            records: changedRecords,
                            deletedRecordNames: deletedRecordNames,
                            changeTokenData: newTokenData,
                            moreComing: moreComing
                        )
                    )
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }
    }

    private func encodeServerChangeToken(_ token: CKServerChangeToken) throws -> Data {
        try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }

    private func decodeServerChangeToken(from data: Data) throws -> CKServerChangeToken {
        guard let token = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: CKServerChangeToken.self,
            from: data
        ) else {
            throw WalletSyncCloudKitError.invalidRecord("Invalid CloudKit change token data.")
        }

        return token
    }
}

struct WalletSyncCKPrivateDatabaseZoneOperator: WalletSyncPrivateDatabaseZoneOperating {
    private let containerIdentifier: String?

    init(containerIdentifier: String? = nil) {
        self.containerIdentifier = containerIdentifier
    }

    func fetchZone(_ zoneID: CKRecordZone.ID) async throws -> CKRecordZone {
        let container = containerIdentifier.map(CKContainer.init(identifier:)) ?? CKContainer.default()
        let database = container.privateCloudDatabase
        return try await withCheckedThrowingContinuation { continuation in
            database.fetch(withRecordZoneID: zoneID) { zone, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let zone {
                    continuation.resume(returning: zone)
                } else {
                    continuation.resume(throwing: WalletSyncCloudKitError.invalidRecord(zoneID.zoneName))
                }
            }
        }
    }

    func saveZone(_ zoneID: CKRecordZone.ID) async throws {
        let container = containerIdentifier.map(CKContainer.init(identifier:)) ?? CKContainer.default()
        let database = container.privateCloudDatabase
        let zone = CKRecordZone(zoneID: zoneID)
        let result = try await database.modifyRecordZones(saving: [zone], deleting: [])

        guard let saveResult = result.saveResults[zoneID] else {
            throw WalletSyncCloudKitError.invalidRecord(zoneID.zoneName)
        }

        _ = try saveResult.get()
    }
}

// Creates the supplied custom record zone when it does not already exist. This
// provider does not run automatically; callers must explicitly request zone setup.
struct WalletSyncCKPrivateDatabaseZoneEnsurer: WalletSyncPrivateDatabaseZoneEnsuring {
    private let zoneOperator: WalletSyncPrivateDatabaseZoneOperating

    init(containerIdentifier: String? = nil) {
        self.zoneOperator = WalletSyncCKPrivateDatabaseZoneOperator(containerIdentifier: containerIdentifier)
    }

    init(zoneOperator: WalletSyncPrivateDatabaseZoneOperating) {
        self.zoneOperator = zoneOperator
    }

    func ensureZone(_ zoneID: CKRecordZone.ID) async throws {
        do {
            _ = try await zoneOperator.fetchZone(zoneID)
            return
        } catch {
            guard Self.isZoneMissingError(error) else {
                throw error
            }
        }

        do {
            try await zoneOperator.saveZone(zoneID)
        } catch {
            guard Self.isZoneAlreadyExistsError(error) else {
                throw error
            }
        }
    }

    static func isZoneMissingError(_ error: Error) -> Bool {
        if let ckError = error as? CKError {
            return ckError.code == .zoneNotFound || ckError.code == .unknownItem
        }

        if let walletError = error as? WalletSyncCloudKitError {
            switch walletError {
            case .unknown(let underlying):
                return isZoneMissingError(underlying)
            case .invalidRecord(let message):
                return isZoneMissingMessage(message)
            default:
                return false
            }
        }

        let nsError = error as NSError
        if nsError.domain == CKError.errorDomain &&
            (nsError.code == CKError.Code.zoneNotFound.rawValue ||
             nsError.code == CKError.Code.unknownItem.rawValue) {
            return true
        }

        return isZoneMissingMessage(nsError.localizedDescription)
    }

    private static func isZoneMissingMessage(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains(WalletSyncRealCloudKitPrivateDatabaseBoundary.syncZoneName.lowercased()) &&
            (normalized.contains("zone was purged") ||
             normalized.contains("zone not found") ||
             normalized.contains("unknown item"))
    }

    static func isZoneAlreadyExistsError(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else {
            return false
        }

        return ckError.code == .serverRecordChanged
    }
}

// Holds configuration for the private CloudKit database and delegates account status
// to an injected provider. Record save operations are delegated to an injected
// record-saving provider. Changed-record fetches are delegated to an injected
// provider and do not persist returned change tokens.
final class WalletSyncRealCloudKitPrivateDatabaseBoundary: WalletSyncCloudKitDatabaseBoundary {

    nonisolated static let syncZoneName = "WalletSyncZoneV2"

    private let configuration: WalletSyncCloudKitConfiguration
    private let accountStatusProvider: WalletSyncCloudKitAccountStatusProviding
    private let recordSaver: WalletSyncPrivateDatabaseRecordSaving
    private let recordFetcher: WalletSyncPrivateDatabaseRecordFetching
    private let changedRecordFetcher: WalletSyncPrivateDatabaseChangedRecordFetching
    private let zoneEnsurer: WalletSyncPrivateDatabaseZoneEnsuring
    private let syncZoneID: CKRecordZone.ID

    init(
        configuration: WalletSyncCloudKitConfiguration,
        accountStatusProvider: WalletSyncCloudKitAccountStatusProviding,
        recordSaver: WalletSyncPrivateDatabaseRecordSaving,
        recordFetcher: WalletSyncPrivateDatabaseRecordFetching,
        changedRecordFetcher: WalletSyncPrivateDatabaseChangedRecordFetching,
        zoneEnsurer: WalletSyncPrivateDatabaseZoneEnsuring,
        syncZoneID: CKRecordZone.ID = WalletSyncRealCloudKitPrivateDatabaseBoundary.defaultSyncZoneID()
    ) {
        self.configuration = configuration
        self.accountStatusProvider = accountStatusProvider
        self.recordSaver = recordSaver
        self.recordFetcher = recordFetcher
        self.changedRecordFetcher = changedRecordFetcher
        self.zoneEnsurer = zoneEnsurer
        self.syncZoneID = syncZoneID
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
            ),
            changedRecordFetcher: WalletSyncCKPrivateDatabaseChangedRecordFetcher(
                containerIdentifier: configuration.containerIdentifier
            ),
            zoneEnsurer: WalletSyncCKPrivateDatabaseZoneEnsurer(
                containerIdentifier: configuration.containerIdentifier
            ),
            syncZoneID: Self.defaultSyncZoneID()
        )
    }

    static func defaultSyncZoneID() -> CKRecordZone.ID {
        CKRecordZone.ID(zoneName: syncZoneName, ownerName: CKCurrentUserDefaultName)
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
            return try await recordSaver.saveRecords(records.map(recordInSyncZone))
        } catch {
            throw WalletSyncCloudKitError.unknown(underlying: error)
        }
    }

    func fetchRecord(named recordName: String) async throws -> CKRecord {
        do {
            return try await recordFetcher.fetchRecord(named: recordName, in: syncZoneID)
        } catch let error as WalletSyncCloudKitError {
            throw error
        } catch {
            throw WalletSyncCloudKitError.unknown(underlying: error)
        }
    }

    func fetchChangedRecords(since changeToken: Data?) async throws -> WalletSyncCloudKitFetchResult {
        do {
            return try await changedRecordFetcher.fetchChangedRecords(in: syncZoneID, since: changeToken)
        } catch let error as WalletSyncCloudKitError {
            throw error
        } catch {
            throw WalletSyncCloudKitError.unknown(underlying: error)
        }
    }

    func ensureSyncZone() async throws {
        do {
            try await zoneEnsurer.ensureZone(syncZoneID)
        } catch let error as WalletSyncCloudKitError {
            throw error
        } catch {
            throw WalletSyncCloudKitError.unknown(underlying: error)
        }
    }

    private func recordInSyncZone(_ record: CKRecord) -> CKRecord {
        guard record.recordID.zoneID != syncZoneID else {
            return record
        }

        let zonedRecordID = CKRecord.ID(recordName: record.recordID.recordName, zoneID: syncZoneID)
        let zonedRecord = CKRecord(recordType: record.recordType, recordID: zonedRecordID)

        for key in record.allKeys() {
            zonedRecord[key] = record[key]
        }

        return zonedRecord
    }
}
