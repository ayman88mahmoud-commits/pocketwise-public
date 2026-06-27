import Foundation

struct WalletSyncAccountAvailabilityChecker {
    private let boundary: WalletSyncCloudKitDatabaseBoundary

    init(boundary: WalletSyncCloudKitDatabaseBoundary) {
        self.boundary = boundary
    }

    static func liveDefault() -> WalletSyncAccountAvailabilityChecker {
        WalletSyncAccountAvailabilityChecker(
            boundary: WalletSyncRealCloudKitAccountBoundary()
        )
    }

    func checkAvailability() async throws -> WalletSyncCloudKitAccountAvailability {
        try await boundary.accountAvailability()
    }
}
