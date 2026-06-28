import Foundation
import CloudKit

protocol WalletSyncDryRunChangedRecordFetching {
    func fetchChangedRecords(since changeToken: Data?) async throws -> WalletSyncCloudKitFetchResult
}

extension WalletSyncRealCloudKitPrivateDatabaseBoundary: WalletSyncDryRunChangedRecordFetching {}

struct WalletSyncDryRunLoopSummary: Equatable {
    var usedSavedToken: Bool
    var changedRecordCount: Int
    var deletedRecordCount: Int
    var tokenReturned: Bool
    var tokenSaved: Bool
    var moreComing: Bool
    var sampleChangedRecordNames: [String]
    var sampleDeletedRecordNames: [String]
}

struct WalletSyncDryRunLoopController {
    private let changedRecordFetcher: WalletSyncDryRunChangedRecordFetching
    private let tokenStore: WalletSyncChangeTokenStoring
    private let sampleLimit: Int

    init(
        changedRecordFetcher: WalletSyncDryRunChangedRecordFetching,
        tokenStore: WalletSyncChangeTokenStoring,
        sampleLimit: Int = 10
    ) {
        self.changedRecordFetcher = changedRecordFetcher
        self.tokenStore = tokenStore
        self.sampleLimit = sampleLimit
    }

    func runDryRunLoop() async throws -> WalletSyncDryRunLoopSummary {
        let savedTokenData = tokenStore.loadWalletSyncZoneChangeTokenData()
        let result = try await changedRecordFetcher.fetchChangedRecords(since: savedTokenData)
        let tokenSaved: Bool

        if let returnedTokenData = result.changeTokenData {
            tokenStore.saveWalletSyncZoneChangeTokenData(returnedTokenData)
            tokenSaved = true
        } else {
            tokenSaved = false
        }

        return WalletSyncDryRunLoopSummary(
            usedSavedToken: savedTokenData != nil,
            changedRecordCount: result.records.count,
            deletedRecordCount: result.deletedRecordNames.count,
            tokenReturned: result.changeTokenData != nil,
            tokenSaved: tokenSaved,
            moreComing: result.moreComing,
            sampleChangedRecordNames: Array(result.records.map(\.recordID.recordName).prefix(sampleLimit)),
            sampleDeletedRecordNames: Array(result.deletedRecordNames.prefix(sampleLimit))
        )
    }
}
