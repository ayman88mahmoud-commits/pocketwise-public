# Sync Relationship Account Warnings — Checkpoint Report

Date: 2026-07-01  
Branch: householdbudget-main  
Phase: Sync Relationship Integrity Preflight — Second Implementation Batch  
Status: Checkpoint closed. Documentation only. No CloudKit sync was enabled.

---

## 1. Executive Summary

This checkpoint documents the second read-only relationship integrity validation batch completed as part of the Sync Relationship Integrity Preflight phase. The goal of this batch was to add non-blocking `.warning` issues to `makeBackupValidationReport(for:)` for account name references that point to accounts not present in the backup snapshot.

The batch also confirmed that `InstallmentPlan.accountName` was already covered by an existing `.warning` check from a prior implementation, and added regression tests to lock that behavior in.

No restore blocking behavior was changed. No data was mutated. No CloudKit sync was enabled. The backup validation report now surfaces orphaned account references across `FinancialEvent` (unpaid non-transfer events) and `WalletEvent` (default account), providing complete account reference coverage alongside the category/subcategory coverage added in the first batch.

---

## 2. Current Git State

| Property | Value |
|---|---|
| Branch | `householdbudget-main` |
| Remote tracking | `origin/householdbudget-main` |
| Latest commit | `b09a062` Add relationship integrity warnings for account references |
| Working tree | Clean — no uncommitted changes |
| Sync status | In sync — local matches `origin/householdbudget-main` |

---

## 3. What Was Added

Two new `.warning` issues are now reported by `makeBackupValidationReport(for:)` when account name references cannot be resolved in the backup snapshot. Both are non-blocking.

| Warning Title | Source Model | Trigger Condition |
|---|---|---|
| `"Event references unknown account"` | `FinancialEvent` | `status != .paid`, `type != .transfer`, `accountName` is non-nil, non-empty, and not present in `snapshot.accounts` |
| `"Quick event unknown default account"` | `WalletEvent` | `defaultAccountName` is non-nil, non-empty, and not present in `snapshot.accounts` |

**Coverage design notes:**

- **Paid non-transfer events** were already covered by the existing `"Paid event missing account"` warning. The new check targets only **unpaid** non-transfer events, which were previously unchecked.
- **Transfer events** are excluded from the new check. Transfer source and destination account references were already covered by separate `.error` (empty) and `.warning` (non-empty but missing) checks that predate this batch.
- **`FinancialEvent.accountName` nil guard:** The field is `String?`. The new check is guarded by `if let accountName = event.accountName` so nil-account events produce no spurious warning.
- **`WalletEvent.defaultAccountName`** is `String?`. The check is guarded by `if let defaultAccount = event.defaultAccountName` so events with no default account produce no issue.

**`InstallmentPlan.accountName` — already covered:**  
This field was already checked by an existing `.warning` block ("Installment plan missing account") from a prior implementation. No new check was added. Three regression tests were added to confirm the existing behavior is stable.

---

## 4. Files Changed in Implementation Commit `b09a062`

| File | Change |
|---|---|
| `HouseholdBudget/WalletStore.swift` | Added unpaid non-transfer account warning inside the `financialEvents` loop; added default account warning inside the `walletEvents` loop |
| `HouseholdBudgetTests/BackupValidationTests.swift` | Added 12 new tests across four groups: FinancialEvent account (4), WalletEvent account (3), InstallmentPlan regression (3), account cross-cutting (2) |

No other files were changed. No Xcode project files, Info.plist, public pages, or backup schema files were modified.

---

## 5. Safety Guarantees

- **All new issues are `.warning` only.** No `.error` severity was added in this batch. `hasErrors` remains `false` for a snapshot that only has account reference issues.
- **Restore behavior remains unchanged.** The restore gate in `DataBackupView` checks `hasErrors`. Account reference warnings do not set `hasErrors`, so restore is not blocked.
- **`validateBackupSnapshot(_:)` was not changed.** The store-level restore gate is untouched.
- **`DataBackupView` import/restore behavior was not changed.** The restore preview and import function are unmodified.
- **Backup schema was not changed.** `WalletDataSnapshot` and its `CodingKeys` are unmodified.
- **No data mutation or auto-repair was added.** The validation report is purely read-only. No `FinancialEvent` or `WalletEvent` is modified as a result of these checks.
- **No orphan records are deleted.** A record referencing a missing account is reported and left intact.
- **CloudKit sync remains fully disabled.** No CloudKit gates, zones, upload/download pipelines, or feature flags were touched.

---

## 6. Verification

| Check | Result |
|---|---|
| Test count | 74 tests |
| Test failures | 0 |
| Build target | `HouseholdBudget` — `generic/platform=iOS Simulator` |
| Build result | `** BUILD SUCCEEDED **` |
| CloudKit files changed | None |
| Xcode project files changed | None |
| Info.plist changed | None |
| Backup schema changed | None |
| Financial calculation logic changed | None |
| `validateBackupSnapshot` changed | No |
| `DataBackupView` restore/import behavior changed | No |

---

## 7. Remaining Relationship Risks

The following relationship integrity checks have not yet been implemented.

**Credit card UUID reference warnings (next recommended batch)**  
`CreditCardStatement.cardID` is not currently validated in the backup report. Statements without a matching card in the snapshot are silently orphaned. Additionally, the coverage of `CreditCardPurchase.cardID` and `CreditCardPayment.cardID` should be audited for completeness — both are currently `.error` (blocking), which is correct, but confirming no gaps exist is part of a complete audit.

**Person debt / debt entry reference warnings**  
`PersonDebtEntry.debtID` → `PersonDebt` is already checked as `.error` (UUID reference). `PersonDebtEntry.accountName` is already split into `.error` (empty) and `.warning` (non-empty missing). The remaining gap is the semantic consistency check between entry type and debt kind — this is low priority and out of scope for the current phase.

**Installment event → installment plan warnings**  
`FinancialEvent.sourceInstallmentPlanID` is already checked as `.warning` when the plan is missing. No additional gaps exist in this direction.

**Recurring event parent references**  
`FinancialEvent.sourceRecurringEventID` is not checked against the financial event ID set. A recurring child event referencing a deleted parent is a dangling UUID reference. This is medium risk but reflects a normal user workflow (deleting a recurring series parent while keeping paid occurrences). Deferred.

**UUID-based relationship migration**  
The structural root cause of all name-based relationship fragility — that accounts, categories, and subcategories are referenced by String name rather than UUID — has not been addressed. This migration is explicitly deferred. It is the largest structural change in the codebase and requires a dedicated planning phase.

---

## 8. Recommended Next Coding Task

**Task title:** Add read-only credit card reference warnings in `makeBackupValidationReport`

**Scope:** Audit all credit card UUID references across `CreditCardStatement` (if included in the backup snapshot) and confirm existing coverage for `CreditCardPurchase.cardID` and `CreditCardPayment.cardID`. For any credit card UUID reference that is present but unresolved in `snapshot.creditCards`, append a `.warning` issue. All new checks must be `.warning` only — do not change restore blocking behavior. Do not change `validateBackupSnapshot`. Add focused tests for each new warning: valid reference produces no issue, missing UUID reference produces `.warning`. Confirm `hasErrors` remains false for warning-only credit card reference reports. Confirm `restoreFromBackupSnapshot` does not throw for warning-only credit card reference snapshots.

---

## 9. Do Not Do Yet

- **Do not enable automatic CloudKit sync.** The sync gates must remain closed.
- **Do not change restore blocking behavior.** Any new relationship check added in future batches must be `.warning` severity unless explicitly approved through a separate analysis.
- **Do not auto-repair data.** If a financial event references a missing account, do not update the event's fields.
- **Do not mutate or delete orphan records.** Records with broken references must be preserved and reported — never deleted automatically.
- **Do not convert name-based references to UUIDs yet.** This migration requires its own dedicated planning phase.
- **Do not change the backup JSON schema.** No new fields should be added to `WalletDataSnapshot` as part of relationship integrity reporting work.
- **Do not change financial calculations.** The relationship integrity report is a diagnostic read of the snapshot. Balances, runway, debt amounts, and all derived values must remain unaffected.

---

## 10. Verification for This Documentation Task

This file is the sole output of this task. No Swift files, test files, Xcode project files, Info.plist, public pages, or backup schema files were modified. Automatic CloudKit sync was not enabled. Financial calculations were not changed. Data models were not changed.
