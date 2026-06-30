import Foundation

protocol WalletSyncMasterDataPipelineRunning {
    func run() async throws -> WalletSyncMasterDataManualPipelineSummary
}

extension WalletSyncMasterDataManualPipeline: WalletSyncMasterDataPipelineRunning {}

protocol WalletSyncMasterDataAvailabilityChecking {
    func checkMasterDataSyncAvailability() async -> WalletSyncCloudKitAccountAvailability
}

// Checks iCloud account availability using an existing database boundary.
// Returns .unknown on error so the coordinator treats unavailability conservatively.
struct WalletSyncBoundaryAvailabilityChecker: WalletSyncMasterDataAvailabilityChecking {
    private let boundary: WalletSyncCloudKitDatabaseBoundary

    init(boundary: WalletSyncCloudKitDatabaseBoundary) {
        self.boundary = boundary
    }

    func checkMasterDataSyncAvailability() async -> WalletSyncCloudKitAccountAvailability {
        do {
            return try await boundary.accountAvailability()
        } catch {
            return .unknown
        }
    }
}

protocol WalletSyncCurrentDateProviding {
    var now: Date { get }
}

struct WalletSyncSystemDateProvider: WalletSyncCurrentDateProviding {
    nonisolated init() {}
    var now: Date { Date() }
}

enum WalletSyncMasterDataCoordinatorSkipReason {
    case rateLimited
    case alreadyRunning
    case iCloudUnavailable
    case disabled
    case error(Error)

    var shortDescription: String {
        switch self {
        case .rateLimited: return "rateLimited"
        case .alreadyRunning: return "alreadyRunning"
        case .iCloudUnavailable: return "iCloudUnavailable"
        case .disabled: return "disabled"
        case .error(let e): return "error: \(e.localizedDescription)"
        }
    }
}

enum WalletSyncMasterDataCoordinatorResult {
    case ran(summary: WalletSyncMasterDataManualPipelineSummary)
    case skipped(reason: WalletSyncMasterDataCoordinatorSkipReason)

    var didRun: Bool {
        if case .ran = self { return true }
        return false
    }

    var skipReason: WalletSyncMasterDataCoordinatorSkipReason? {
        if case .skipped(let reason) = self { return reason }
        return nil
    }

    var pipelineSummary: WalletSyncMasterDataManualPipelineSummary? {
        if case .ran(let summary) = self { return summary }
        return nil
    }
}

// Rate-limited, overlap-guarded coordinator for master-data-only sync.
// Contains no WalletStore, WalletICloudSyncService, or non-master-data reference.
// The only mutation path into WalletStore is through the injected pipeline protocol.
@MainActor
final class WalletSyncMasterDataCoordinator {
    nonisolated static let defaultMinimumInterval: TimeInterval = 5 * 60
    nonisolated static let debugMinimumInterval: TimeInterval = 60

    private let pipeline: WalletSyncMasterDataPipelineRunning
    private let availabilityChecker: WalletSyncMasterDataAvailabilityChecking?
    private let dateProvider: WalletSyncCurrentDateProviding
    private let minimumInterval: TimeInterval
    private let enabled: Bool

    private var isRunning = false
    private(set) var lastRunDate: Date?
    private(set) var lastResult: WalletSyncMasterDataCoordinatorResult?

    init(
        pipeline: WalletSyncMasterDataPipelineRunning,
        availabilityChecker: WalletSyncMasterDataAvailabilityChecking? = nil,
        dateProvider: WalletSyncCurrentDateProviding = WalletSyncSystemDateProvider(),
        minimumInterval: TimeInterval = WalletSyncMasterDataCoordinator.defaultMinimumInterval,
        enabled: Bool = true
    ) {
        self.pipeline = pipeline
        self.availabilityChecker = availabilityChecker
        self.dateProvider = dateProvider
        self.minimumInterval = minimumInterval
        self.enabled = enabled
    }

    func runIfAllowed() async -> WalletSyncMasterDataCoordinatorResult {
        guard enabled else {
            return storeResult(.skipped(reason: .disabled))
        }

        guard !isRunning else {
            return storeResult(.skipped(reason: .alreadyRunning))
        }

        if let lastRunDate, dateProvider.now.timeIntervalSince(lastRunDate) < minimumInterval {
            return storeResult(.skipped(reason: .rateLimited))
        }

        if let checker = availabilityChecker {
            let availability = await checker.checkMasterDataSyncAvailability()
            guard availability == .available else {
                return storeResult(.skipped(reason: .iCloudUnavailable))
            }
        }

        isRunning = true
        defer { isRunning = false }

        lastRunDate = dateProvider.now

        do {
            let summary = try await pipeline.run()
            return storeResult(.ran(summary: summary))
        } catch {
            return storeResult(.skipped(reason: .error(error)))
        }
    }

    @discardableResult
    private func storeResult(_ result: WalletSyncMasterDataCoordinatorResult) -> WalletSyncMasterDataCoordinatorResult {
        lastResult = result
        return result
    }
}
