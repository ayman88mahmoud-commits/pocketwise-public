import Foundation
import CloudKit

// Holds configuration for the private CloudKit database and delegates account status
// to an injected provider. All record operations throw cloudKitUnavailable until
// a future phase explicitly enables them.
final class WalletSyncRealCloudKitPrivateDatabaseBoundary: WalletSyncCloudKitDatabaseBoundary {

    private let configuration: WalletSyncCloudKitConfiguration
    private let accountStatusProvider: WalletSyncCloudKitAccountStatusProviding

    init(
        configuration: WalletSyncCloudKitConfiguration,
        accountStatusProvider: WalletSyncCloudKitAccountStatusProviding
    ) {
        self.configuration = configuration
        self.accountStatusProvider = accountStatusProvider
    }

    convenience init(
        configuration: WalletSyncCloudKitConfiguration = WalletSyncCloudKitConfiguration()
    ) {
        self.init(
            configuration: configuration,
            accountStatusProvider: WalletSyncCKContainerAccountStatusProvider(
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
        throw WalletSyncCloudKitError.cloudKitUnavailable
    }

    func fetchChangedRecords(since changeToken: Data?) async throws -> WalletSyncCloudKitFetchResult {
        throw WalletSyncCloudKitError.cloudKitUnavailable
    }
}
