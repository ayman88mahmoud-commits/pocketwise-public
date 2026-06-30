# Sync Preflight Validation Plan

Date: 2026-06-30  
Scope: documentation-only plan for future sync, import, and restore preflight validation. No CloudKit sync was enabled, no Swift code was changed, and no app behavior was modified.

---

## Schema Version Gate — Implementation Status

Implemented in commit: Add blocking backup validation severity  
Date: 2026-06-30

### What was implemented

- Added `case error` to `BackupValidationSeverity` in `WalletModels.swift`. The three severities are now: `.error`, `.warning`, `.info`.
- Added `errorCount: Int` and `hasErrors: Bool` computed properties to `BackupValidationReport`.
- Updated `summaryText` in `BackupValidationReport` to surface blocking error count when `hasErrors` is true.
- Added schema version gate at the start of `makeBackupValidationReport(for:)` in `WalletStore.swift`: if `snapshot.schemaVersion > WalletDataSnapshot.currentSchemaVersion`, an `.error` issue titled "Unsupported schema version" is appended.

### Severities now in effect

| Severity | Meaning | Examples |
|---|---|---|
| `.error` | Blocking — restore is unsafe until resolved | Schema version from a newer app than is installed |
| `.warning` | Non-blocking — restore proceeds with caution | Duplicate event IDs, paid events missing account, duplicate budget item IDs |
| `.info` | Diagnostic only | (none currently emitted) |

### What currently blocks validation

A `BackupValidationReport` with `hasErrors == true` (i.e., `errorCount > 0`) indicates that restore is unsafe. The only condition currently emitting `.error` is:

> `snapshot.schemaVersion > WalletDataSnapshot.currentSchemaVersion`

The restore UI (`DataBackupView`) does not yet gate on `hasErrors` — wiring `canRestore` into the restore flow is the next step (Phase 1 of Section 9 is partially complete).

### What remains future work

- Wire `hasErrors` into `DataBackupView` to block the restore action when `canRestore == false`.
- Add orphaned account/category name reference checks as `.error` severity (Phase 1 remainder).
- Add tombstone coherence checks (Phase 2).
- Build `SyncPreflightReport` model (Phase 3).
- Extend validator to master data, planning data, and financial data (Phases 4–6).
- Wire validator into sync applier gate (Phase 7).

### Confirmation

CloudKit automatic sync remains disabled. `WalletSyncFeatureFlags.isAutomaticCloudKitSyncEnabled` is `false`. No financial behavior was changed. Manual backup, export, and import workflows were not redesigned.

---

## 1. Executive Summary

The app has an existing `makeBackupValidationReport(for:)` function that performs structural backup validation — checking referential integrity, value ranges, and required fields across the current snapshot. That validator uses `.warning` and `.info` severities only; there is no blocking `.error` severity in the current model.

Before CloudKit record sync can be safely enabled, a stronger preflight validation layer is needed. That layer must:

- Run **before** any sync record is applied to local state (not after).
- Be capable of **blocking** a sync apply when financial integrity would be violated.
- Distinguish between **errors** (block apply, surface to user), **warnings** (log and continue), and **info** (diagnostic only).
- Cover risks that the current backup validator does not: orphaned name references, tombstone conflicts, schema version mismatches, duplicate IDs from a remote source, balance-affecting records arriving out of order, and missing cascade data.

This plan documents the target validation scope, risk inventory, model-specific checklists, phased implementation order, and required tests. No implementation is authorized by this plan. CloudKit sync remains disabled.

---

## 2. Current Validation Coverage

### What `makeBackupValidationReport(for:)` Already Checks

The existing validator in `WalletStore.swift` (lines 2915–3164) currently checks:

| Check | Severity |
|---|---|
| Duplicate financial event IDs within snapshot | `.warning` |
| Duplicate monthly budget item IDs within snapshot | `.warning` |
| Paid financial events missing an account name | `.warning` |
| Transfer events missing source or destination account | `.warning` |
| Future-dated paid financial events | `.warning` |
| Installment-tagged events missing a linked installment plan ID | `.warning` |
| Credit card purchases with invalid amount or missing card | `.warning` |
| Credit card payments with invalid amount, missing card, or missing source account | `.warning` |
| Installment plans with invalid durations, amounts, or paid counts | `.warning` |
| Installment plans missing account name or linked credit card (when card-linked) | `.warning` |
| Installment plans where paid event count exceeds declared total events | `.warning` |
| Credit card default payment account name missing from accounts list | `.warning` |
| Person debt entries with invalid amounts or missing account name | `.warning` |

### What the Current Validator Does NOT Check

- Whether account/category **names referenced** by events actually exist in the accounts/categories arrays.
- Whether a record arriving from a remote source has an ID that **conflicts with a local tombstone**.
- Whether a record's **schema version** is compatible with the installed app version.
- Whether applying a financial event would **duplicate a balance effect** already applied locally.
- Whether an installment plan arriving without its child events would leave orphaned future references.
- Whether a soft-deleted record (with `isDeleted = true`) is arriving alongside a live local copy.
- Whether `WalletMonthlyBudgetItem` IDs are stable or were regenerated since last sync.
- Whether a `PersonDebt` arrives without its child `PersonDebtEntry` records.
- Whether `resetToSampleData` tombstone gap creates a conflict (sample IDs written without tombstones for prior live records).

---

## 3. Data Integrity Risks to Detect

| Risk | Example | Current Cause | Affected Models | Detection Strategy | Severity | Blocking? |
|---|---|---|---|---|---|---|
| Orphaned account name reference | Financial event references "Savings" but no account named "Savings" exists | Rename arrived via direct struct mutation, bypassing `renameAccountReferences` | `FinancialEvent`, `WalletEvent`, `InstallmentPlan`, `PersonDebtEntry` | For each referencing record, check that the string name exists in the accounts array | Error | Yes |
| Orphaned category name reference | Financial event has category "Food" but no category with that name exists | Category deleted on another device, sync applied deletion before cascading the reference update | `FinancialEvent`, `WalletEvent`, `InstallmentPlan`, `WalletMonthlyBudget` items | For each referencing record, check category name exists in categories array | Error | Yes |
| Incoming ID conflicts with local tombstone | Remote record arrives for a financial event the local device already deleted | Deletion not yet delivered to remote; remote device created a new record reusing the same ID | `FinancialEvent`, `InstallmentPlan`, `PersonDebt`, `PersonDebtEntry`, `CreditCardPurchase`, `CreditCardPayment` | Before applying, check `isFinancialEventDeletedLocally(id:)` / `isInstallmentPlanDeletedLocally(id:)` / `isHighRiskRecordDeletedLocally(entity:id:)` | Error | Yes |
| Incoming record missing from generic tombstone store | Account/category/wallet event arrives that was locally deleted via `markSyncRecordDeletedLocally` | Generic tombstone store has no `deletedAt` timestamp; conflict resolution is ambiguous | `Account`, `Category`, `WalletEvent`, `MerchantMemory`, `HistoricalMonthlySummaryEntry` | Check `isRecordDeletedLocally(entity:id:)` before applying; flag when no timestamp available for LWW resolution | Warning | No (flag only) |
| Schema version mismatch | Remote snapshot encoded at schema version 3, local app only knows version 2 | Different app versions installed on different devices | `WalletDataSnapshot` (restore), any future per-record schema versioning | Compare incoming `schemaVersion` against `WalletDataSnapshot.currentSchemaVersion`; block if incoming > local | Error | Yes |
| Duplicate ID from remote source | Remote device sends a financial event ID already present locally as an active record | ID collision, clock skew, or backup-restore on remote device that reset UUIDs | All record types with `id: UUID` | Before applying, scan local arrays for matching ID on a non-deleted record | Error | Yes |
| Balance-affecting record without posted state flag | Financial event arrives with `status == .paid` but the balance effect has already been applied locally | Sync applier re-applies events that were already posted | `FinancialEvent`, `PersonDebtEntry`, `CreditCardPayment` | Validate that a paid event arriving remotely was not already known locally before allowing the applier to reverse/re-apply it | Error | Yes |
| Installment plan arriving without child events | InstallmentPlan record arrives but no linked `FinancialEvent` records with matching `installmentPlanId` are in the payload | Partial sync delivery, events queued separately from plan | `InstallmentPlan`, `FinancialEvent` | Warn if a plan is in payload with zero child events; block if plan's `totalEvents > 0` and zero children present | Warning | No |
| PersonDebt arriving without child entries | Parent debt record arrives without any linked `PersonDebtEntry` records | Partial delivery | `PersonDebt`, `PersonDebtEntry` | Warn if debt record arrives without at least one child entry; block if kind requires at least one entry for balance resolution | Warning | No |
| WalletMonthlyBudgetItem ID regeneration | Budget item IDs were regenerated on device A via `saveMonthlyBudget`, creating duplicate IDs when device B merges | `saveMonthlyBudget` recreates item IDs from category amounts rather than preserving them | `WalletMonthlyBudgetItem` | Validate that all incoming budget item IDs are stable and distinct from existing local items | Warning | No (block in future phase) |
| resetToSampleData tombstone gap | Sample data IDs overlap with prior live record IDs that were never tombstoned | `resetToSampleData` replaces arrays without writing tombstones | All record types | Warn if a record arriving from remote matches an ID from the post-reset sample data set | Warning | No |
| Subcategory name not in parent category | Financial event has subcategory "Groceries" but parent category has no such subcategory | Subcategory renamed or deleted on another device | `FinancialEvent` (`subcategoryName`), `WalletEvent` | For events with subcategory fields, validate subcategory name exists in parent category's subcategory lists | Warning | No |

---

## 4. Proposed Preflight Validator Scope

The preflight validator is a **read-only gate** that runs before any sync record is applied to `WalletStore`. It does not modify any store arrays, UserDefaults values, or tombstone stores. It returns a result struct analogous to `BackupValidationReport` but with a blocking `.error` severity tier.

### Inputs

- The incoming sync payload (set of records to apply, keyed by entity type and record ID).
- The current local `WalletDataSnapshot` (read-only).
- The current `WalletSyncStateStore` state (read-only tombstone lookups).
- The target app schema version.

### Outputs

- A `SyncPreflightReport` containing:
  - A list of `SyncPreflightIssue` values, each with: `severity` (`.error` / `.warning` / `.info`), `entity`, `recordID?`, `title`, `detail`.
  - A computed `canApply: Bool` — `false` if any issue has `.error` severity.
  - A `blockingCount`, `warningCount`, `infoCount`.

### What It Does NOT Do

- It does not apply any records.
- It does not write tombstones.
- It does not upload or fetch from CloudKit.
- It does not mutate any financial data.
- It does not trigger recurring schedule generation or balance recalculation.

---

## 5. Blocking Errors vs Warnings

### Blocking Errors — Apply Must Not Proceed

| Condition | Reason |
|---|---|
| Orphaned account name reference in incoming financial event | Balance may post to a non-existent account |
| Orphaned category name reference in incoming event | Categorization becomes invalid; reporting will be corrupted |
| Incoming record ID matches a local tombstone | Would resurrect a record the local user intentionally deleted |
| Incoming schema version exceeds local app version | Local decoder does not know how to handle unknown fields safely |
| Incoming record ID already exists as an active (non-deleted) local record and payload does not include a merge resolution | Unresolved identity collision; applying would create a duplicate |
| Paid financial event arriving whose balance effect cannot be determined (no prior local record to diff against) | Risk of double-posting or missed reversal |

### Warnings — Log, Surface, Allow Apply

| Condition | Reason |
|---|---|
| Incoming ID matches generic tombstone (no timestamp) | Cannot perform LWW resolution; proceed with caution |
| InstallmentPlan arriving without child events | Plan will exist but future events will be missing until next sync |
| PersonDebt arriving without child entries | Debt entry history will be incomplete |
| WalletMonthlyBudgetItem with potentially regenerated ID | May create duplicate budget rows |
| resetToSampleData post-reset ID overlap | Sample data IDs should be excluded from conflict resolution |
| Subcategory name not found in parent category | Subcategory field will be orphaned; not financially dangerous |

### Info — Diagnostic Only

| Condition |
|---|
| Record arriving with `updatedAt` older than local copy (LWW would skip it) |
| Record arriving with `isDeleted = true` that was already absent locally (no-op delete) |
| Record arriving with no changes relative to local copy |

---

## 6. Model-Specific Validation Checklist

### Accounts (`Account`)

- [ ] Incoming ID not in generic tombstone store for entity `account`.
- [ ] Incoming ID not already active locally unless payload provides a merge resolution.
- [ ] Account name does not duplicate an existing active account name (case-sensitive match).
- [ ] Balance field not present in sync payload (calculated balance must never sync directly).

### Categories (`Category`) and Subcategories

- [ ] Incoming ID not in generic tombstone store for entity `category`.
- [ ] Category name does not duplicate an existing active category name.
- [ ] Subcategory strings contain no empty values.
- [ ] `inactiveSubcategoryNames` does not reference subcategory names that still appear in active `subcategories` list.

### WalletEvents (`WalletEvent`)

- [ ] Incoming ID not in generic tombstone store for entity `walletEvent`.
- [ ] If event has an `accountName`, that name exists in local accounts array.
- [ ] If event has a `categoryName`, that name exists in local categories array.

### FinancialEvents (`FinancialEvent`)

- [ ] Incoming ID not in financial event tombstone store (`isFinancialEventDeletedLocally`).
- [ ] Incoming ID not already active locally (duplicate collision).
- [ ] `accountName` exists in local accounts array.
- [ ] `destinationAccountName` (if present) exists in local accounts array.
- [ ] `categoryName` (if present) exists in local categories array.
- [ ] If `installmentPlanId` is set, that plan ID exists in local or incoming installment plans.
- [ ] `status == .paid` events: validate that balance impact has not already been applied locally.
- [ ] Future-dated events with `status == .paid`: flag as warning (same as current backup check).

### InstallmentPlans (`InstallmentPlan`)

- [ ] Incoming ID not in installment plan tombstone store (`isInstallmentPlanDeletedLocally`).
- [ ] `accountName` exists in local accounts array.
- [ ] If card-linked, `creditCardId` exists in local credit cards array.
- [ ] At least one child event exists in local data or incoming payload if `totalEvents > 0`.
- [ ] `paidEventsCount` does not exceed `totalEvents`.

### WalletMonthlyBudgets and Items (`WalletMonthlyBudget`, `WalletMonthlyBudgetItem`)

- [ ] Budget ID not in generic tombstone store.
- [ ] All budget item IDs are distinct within payload.
- [ ] All budget item IDs are stable (not regenerated from category amounts in this payload).
- [ ] Each item's category name exists in local categories array.

### PersonDebts and Entries (`PersonDebt`, `PersonDebtEntry`)

- [ ] Debt ID not in high-risk tombstone store for entity `personDebt`.
- [ ] Entry IDs not in high-risk tombstone store for entity `personDebtEntry`.
- [ ] Debt's `accountName` exists in local accounts array.
- [ ] Each entry's `accountName` exists in local accounts array.
- [ ] At least one entry exists in payload or local data for each incoming debt.

### CreditCards, Purchases, Payments (`CreditCard`, `CreditCardPurchase`, `CreditCardPayment`)

- [ ] Purchase IDs not in high-risk tombstone store for entity `creditCardPurchase`.
- [ ] Payment IDs not in high-risk tombstone store for entity `creditCardPayment`.
- [ ] Each purchase and payment references a `creditCardId` that exists locally or in payload.
- [ ] Payment `sourceAccountName` exists in local accounts array.
- [ ] Card `defaultPaymentAccountName` (if set) exists in local accounts array.
- [ ] Card balance field not present in sync payload (calculated balance must never sync directly).

### MerchantMemories (`MerchantMemory`)

- [ ] Incoming ID not in generic tombstone store for entity `merchantMemory`.
- [ ] Category name (if set) exists in local categories array.

### HistoricalMonthlySummaryEntries (`HistoricalMonthlySummaryEntry`)

- [ ] Incoming ID not in generic tombstone store for entity `historicalMonthlySummary`.
- [ ] Do not apply if entry's month/year is still the current active month (derived data, not historical yet).

---

## 7. Restore and Import Preflight Flow

Manual iCloud backup restore and local file import both use `importBackupSnapshotFromJSON(_:)` / `restoreFromBackupSnapshot(_:)`. The current flow validates via `makeBackupValidationReport(for:)` before replacing local arrays.

### Proposed Additions to Restore/Import Preflight

1. **Schema version gate**: reject snapshot if `schemaVersion > WalletDataSnapshot.currentSchemaVersion`. Surface a clear error to the user (not a silent no-op).
2. **ID collision check**: warn if the incoming snapshot contains financial event IDs that match active local IDs but have different content — this suggests a partial overwrite risk.
3. **Tombstone coherence check**: warn if the incoming snapshot contains records whose IDs appear in the local tombstone store. Restoring would resurrect tombstoned records.
4. **Name reference integrity**: run orphaned-name checks (Section 3) before applying the full restore.
5. **Blocking severity**: add a `.error` severity to `BackupValidationSeverity` and update `makeBackupValidationReport` to use it for the most dangerous conditions — missing source accounts on paid transactions, schema version mismatches, and duplicate active IDs.

### What Must Not Change in the Restore Flow

- The local safety backup created before iCloud restore must continue to be written first.
- The user confirmation step before overwriting local data must remain.
- `restoreFromBackupSnapshot` must continue to call `objectWillChange.send()` after apply.
- No tombstones should be written during restore (restoring a deleted record is intentional).

---

## 8. Future CloudKit Sync Preflight Flow

When CloudKit record sync is eventually enabled, the preflight flow will run once per sync cycle, before the applier processes any incoming records. Proposed execution order:

```
1. Fetch incoming record payload from CloudKit (records changed since last change token).
2. Parse payload into typed DTO structs.
3. Run SyncPreflightValidator(incoming: payload, local: snapshot, tombstones: syncStateStore).
4. If report.canApply == false:
   a. Log all blocking issues with record IDs.
   b. Surface a user-readable summary if blocking issues affect visible data.
   c. DO NOT call the applier.
   d. Retain the current change token (do not advance it past the blocked batch).
5. If report.canApply == true:
   a. Log all warnings.
   b. Pass payload to the applier (WalletSyncMasterDataApplier or full-data applier).
   c. Advance change token after successful apply.
```

### Key Design Decisions for Future Implementation

- The preflight validator must be stateless and side-effect-free.
- It must be testable in isolation without requiring a real CloudKit connection.
- It must not call any `WalletStore` mutating methods.
- Blocking conditions must be conservatively chosen: when in doubt, block rather than apply.
- The validator result must be logged to a persistent sync error log for debugging.

---

## 9. Suggested Implementation Order

### Phase 1 — Add Blocking Severity to Existing Validator

- Add `.error` case to `BackupValidationSeverity`.
- Update `BackupValidationReport` to compute `canRestore: Bool` from error count.
- Add schema version gate check to `makeBackupValidationReport(for:)`.
- Add orphaned account/category name reference check to `makeBackupValidationReport(for:)`.
- Update restore flow to block if `canRestore == false`.

### Phase 2 — Add Tombstone Conflict Checks to Restore Flow

- Add tombstone coherence check to `makeBackupValidationReport(for:)`: warn if restoring a record whose ID is in the local tombstone store.
- Document expected behavior: restoring from a backup after deletion is intentional; the tombstone check is a warning, not a block.

### Phase 3 — Create SyncPreflightReport Model

- Define `SyncPreflightIssueSeverity` enum with `.error`, `.warning`, `.info`.
- Define `SyncPreflightIssue` struct with `severity`, `entity`, `recordID?`, `title`, `detail`.
- Define `SyncPreflightReport` struct with `issues`, `canApply`, `blockingCount`, `warningCount`, `infoCount`.
- No validator logic yet — models only.

### Phase 4 — Build SyncPreflightValidator for Master Data

- Implement read-only validator for accounts and categories only.
- Input: incoming account/category records, local snapshot, tombstone store.
- Checks: tombstone conflicts, ID collisions, name duplicates.
- Output: `SyncPreflightReport`.
- No integration with the applier yet.

### Phase 5 — Extend Validator to Planning Data

- Add installment plan and wallet event checks.
- Add monthly budget and budget item checks.
- Add merchant memory checks.

### Phase 6 — Extend Validator to Financial Data

- Add financial event checks (orphaned names, tombstone conflicts, paid event balance state).
- Add person debt and debt entry checks.
- Add credit card purchase and payment checks.

### Phase 7 — Wire Validator into Sync Applier Gate

- Call `SyncPreflightValidator` before the applier in the sync pipeline.
- Block applier if `canApply == false`.
- Log all issues to persistent sync error log.

---

## 10. Required Tests Before Implementation

All tests must be added to `HouseholdBudgetTests`. No Swift production code changes until these tests exist.

### For Phase 1 (Backup Validator Extension)

- `testMakeBackupValidationReportBlocksWhenSchemaVersionExceedsCurrentVersion` — construct a snapshot with a `schemaVersion` above `currentSchemaVersion`, assert `.error` severity issue is present and `canRestore == false`.
- `testMakeBackupValidationReportBlocksWhenPaidEventHasOrphanedAccountName` — snapshot with a paid financial event whose `accountName` is not in the accounts array, assert blocking issue present.
- `testMakeBackupValidationReportBlocksWhenCategoryNameIsOrphaned` — snapshot with a financial event whose `categoryName` is not in the categories array, assert blocking issue present.
- `testMakeBackupValidationReportPassesWhenAllReferencesAreValid` — valid snapshot, assert no blocking issues, `canRestore == true`.

### For Phase 3 (SyncPreflightReport Model)

- `testSyncPreflightReportCanApplyIsFalseWhenAnyErrorPresent` — construct report with one `.error` issue, assert `canApply == false`.
- `testSyncPreflightReportCanApplyIsTrueWithOnlyWarnings` — construct report with only `.warning` issues, assert `canApply == true`.

### For Phase 4 (Master Data Validator)

- `testSyncPreflightValidatorBlocksWhenIncomingAccountIdIsInTombstoneStore` — add an account tombstone, pass incoming account with same ID, assert blocking error.
- `testSyncPreflightValidatorWarnsWhenIncomingAccountIdIsInGenericTombstoneWithNoTimestamp` — generic tombstone (no `deletedAt`), assert warning not error.
- `testSyncPreflightValidatorPassesCleanIncomingAccountWithNoConflicts` — clean payload, assert `canApply == true`.

### For Phase 6 (Financial Data Validator)

- `testSyncPreflightValidatorBlocksWhenIncomingFinancialEventIdIsInFinancialTombstoneStore` — tombstone for financial event, incoming record same ID, assert blocking error.
- `testSyncPreflightValidatorBlocksWhenIncomingEventAccountNameIsOrphaned` — incoming event with `accountName` not in accounts list, assert blocking error.
- `testSyncPreflightValidatorBlocksWhenIncomingEventCategoryNameIsOrphaned` — incoming event with `categoryName` not in categories list, assert blocking error.

---

## 11. Do Not Do Yet

The following are explicitly out of scope until the foundation phases above are complete:

- **Do not enable CloudKit automatic sync.** `WalletSyncFeatureFlags.isAutomaticCloudKitSyncEnabled` must remain `false`.
- **Do not implement conflict resolution.** Last-write-wins or merge strategies are post-validator concerns. The validator only blocks unsafe applies.
- **Do not add a `.error` severity to `BackupValidationSeverity` until the validator logic is ready** — adding the enum case without updating the report logic will silently change behavior.
- **Do not add `SyncPreflightValidator` to any sync pipeline** until Phase 7 is reached, all tests pass, and the validator has been reviewed against real sync payloads in a non-production environment.
- **Do not sync account or category calculated balances.** Balances are derived from posted financial events and must never be treated as a syncable field.
- **Do not sync `WalletDataSnapshot` fields that are device-local:** `iCloudSyncEnabled`, sync timestamps, last sync error, `localDataUpdatedAt`.
- **Do not add user-facing UI** for sync errors until the validator infrastructure exists and returns stable results.
- **Do not change `makeBackupValidationReport` in a way that changes existing `.warning` or `.info` output** — downstream UI and tests depend on current output.
- **Do not add migrations** as part of validation. The validator only reads; schema migration is a separate concern.

---

## 12. Smallest Safe Next Implementation Step

**Add `.error` severity to `BackupValidationSeverity` and add one blocking check to the existing backup validator.**

Specifically:

1. Add `case error` to `BackupValidationSeverity` in `WalletModels.swift`.
2. Add a `canRestore: Bool` computed property to `BackupValidationReport` that returns `true` only when `issues.filter { $0.severity == .error }.isEmpty`.
3. Add one blocking check to `makeBackupValidationReport(for:)`: if `snapshot.schemaVersion > WalletDataSnapshot.currentSchemaVersion`, add an `.error` issue with title "Incompatible schema version" and a detail string that includes the incoming and current version numbers.
4. Write the four tests listed in Section 10, Phase 1.
5. Commit only the model and validator changes and the new tests.
6. Do not wire `canRestore` into the restore UI yet — that is the following step.

This is safe because:
- It adds a new severity case without changing existing cases or existing issue output.
- The schema version check is a net-new condition that does not affect any currently-passing validation.
- `canRestore` is a new computed property that does not change any existing property.
- No Swift behavior changes outside `makeBackupValidationReport` and `BackupValidationReport`.
