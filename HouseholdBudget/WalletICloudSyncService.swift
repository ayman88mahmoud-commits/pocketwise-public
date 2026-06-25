import Foundation
import CloudKit
#if canImport(UIKit)
import UIKit
#endif

final class WalletICloudSyncService {

    static let shared = WalletICloudSyncService()

    private let recordType = "WalletSnapshot"
    private let iCloudContainersEntitlement = "com.apple.developer.icloud-container-identifiers"

    private enum FieldKey {
        static let schemaVersion = "schemaVersion"
        static let updatedAt = "updatedAt"
        static let deviceName = "deviceName"
        static let snapshotData = "snapshotData"
        static let appBuildInfo = "appBuildInfo"
    }

    func checkAvailability() async -> WalletICloudAvailability {
        guard hasICloudContainerEntitlement else {
            return .capabilityNotEnabled
        }

        do {
            let status = try await accountStatus(in: CKContainer.default())

            switch status {
            case .available:
                return .available
            case .noAccount:
                return .noAccount
            case .restricted:
                return .restricted
            case .couldNotDetermine:
                return .couldNotDetermine
            case .temporarilyUnavailable:
                return .couldNotDetermine
            @unknown default:
                return .unknown
            }
        } catch {
            if isMissingEntitlementError(error) {
                return .capabilityNotEnabled
            }

            return .error
        }
    }

    func fetchRemoteMetadata() async throws -> WalletICloudRemoteMetadata? {
        do {
            let database = try await availablePrivateDatabase()
            let record = try await fetchRecord(in: database)
            return metadata(from: record)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        } catch {
            if isMissingEntitlementError(error) {
                throw WalletICloudSyncError.notAvailable("iCloud capability is not enabled for this app target.")
            }

            throw error
        }
    }

    func upload(snapshot: WalletDataSnapshot) async throws -> WalletICloudRemoteMetadata {
        do {
            let database = try await availablePrivateDatabase()
            let record: CKRecord

            do {
                record = try await fetchRecord(in: database)
            } catch let error as CKError where error.code == .unknownItem {
                record = CKRecord(recordType: recordType, recordID: recordID)
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)

            record[FieldKey.schemaVersion] = snapshot.schemaVersion as NSNumber
            record[FieldKey.updatedAt] = snapshot.exportedAt as NSDate
            record[FieldKey.deviceName] = currentDeviceName as NSString
            record[FieldKey.snapshotData] = data as NSData
            if let appBuildInfo = snapshot.appBuildInfo {
                record[FieldKey.appBuildInfo] = appBuildInfo as NSString
            }

            let savedRecord = try await saveRecord(record, in: database)
            return metadata(from: savedRecord)
        } catch {
            if isMissingEntitlementError(error) {
                throw WalletICloudSyncError.notAvailable("iCloud capability is not enabled for this app target.")
            }

            throw error
        }
    }

    func downloadSnapshot() async throws -> WalletDataSnapshot {
        do {
            let database = try await availablePrivateDatabase()
            let record = try await fetchRecord(in: database)
            guard let data = record[FieldKey.snapshotData] as? Data else {
                throw WalletICloudSyncError.missingSnapshotData
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(WalletDataSnapshot.self, from: data)
        } catch let error as CKError where error.code == .unknownItem {
            throw WalletICloudSyncError.remoteSnapshotMissing
        } catch let error as WalletICloudSyncError {
            throw error
        } catch {
            if isMissingEntitlementError(error) {
                throw WalletICloudSyncError.notAvailable("iCloud capability is not enabled for this app target.")
            }

            throw error
        }
    }

    private var recordID: CKRecord.ID {
        CKRecord.ID(recordName: "primaryWalletSnapshot")
    }

    private func availablePrivateDatabase() async throws -> CKDatabase {
        guard hasICloudContainerEntitlement else {
            throw WalletICloudSyncError.notAvailable("iCloud capability is not enabled for this app target.")
        }

        let container = CKContainer.default()
        let status = try await accountStatus(in: container)

        guard status == .available else {
            throw WalletICloudSyncError.notAvailable("iCloud is not available for this device or app target.")
        }

        return container.privateCloudDatabase
    }

    private var hasICloudContainerEntitlement: Bool {
        guard let profileURL = Bundle.main.url(
            forResource: "embedded",
            withExtension: "mobileprovision"
        ),
              let profileData = try? Data(contentsOf: profileURL),
              let profileText = String(data: profileData, encoding: .isoLatin1) else {
            // embedded.mobileprovision is absent in TestFlight and App Store signed builds.
            // Entitlements are enforced by the code signature — assume the iCloud
            // container entitlement is present and let CloudKit surface any real errors.
            return true
        }

        return profileText.contains(iCloudContainersEntitlement)
    }

    private func accountStatus(in container: CKContainer) async throws -> CKAccountStatus {
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

    private func fetchRecord(in database: CKDatabase) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            database.fetch(withRecordID: recordID) { record, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let record {
                    continuation.resume(returning: record)
                } else {
                    continuation.resume(throwing: WalletICloudSyncError.remoteSnapshotMissing)
                }
            }
        }
    }

    private func saveRecord(_ record: CKRecord, in database: CKDatabase) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            database.save(record) { savedRecord, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let savedRecord {
                    continuation.resume(returning: savedRecord)
                } else {
                    continuation.resume(throwing: WalletICloudSyncError.notAvailable("iCloud save did not return a record."))
                }
            }
        }
    }

    private func metadata(from record: CKRecord) -> WalletICloudRemoteMetadata {
        WalletICloudRemoteMetadata(
            remoteUpdatedAt: (record[FieldKey.updatedAt] as? Date) ?? (record[FieldKey.updatedAt] as? NSDate).map { Date(timeIntervalSince1970: $0.timeIntervalSince1970) },
            schemaVersion: (record[FieldKey.schemaVersion] as? NSNumber)?.intValue,
            deviceName: record[FieldKey.deviceName] as? String,
            appBuildInfo: record[FieldKey.appBuildInfo] as? String
        )
    }

    private var currentDeviceName: String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return Host.current().localizedName ?? "Unknown Device"
        #endif
    }

    private func isMissingEntitlementError(_ error: Error) -> Bool {
        let nsError = error as NSError
        let message = nsError.localizedDescription.lowercased()
        return message.contains("entitlement") || message.contains("not entitled")
    }
}
