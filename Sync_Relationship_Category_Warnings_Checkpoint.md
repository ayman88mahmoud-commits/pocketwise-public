# Sync Relationship Category Warnings — Checkpoint Report

Date: 2026-07-01  
Branch: householdbudget-main  
Phase: Sync Relationship Integrity Preflight — First Implementation Batch  
Status: Checkpoint closed. Documentation only. No CloudKit sync was enabled.

---

## 1. Executive Summary

This checkpoint documents the first read-only relationship integrity validation batch completed as part of the Sync Relationship Integrity Preflight phase. The goal of this batch was to add non-blocking `.warning` issues to `makeBackupValidationReport(for:)` for category and subcategory name references that point to categories not present in the backup snapshot.

No restore blocking behavior was changed. No data was mutated. No CloudKit sync was enabled. The backup validation report now surfaces orphaned category references to the user before restore, giving them visibility into potential data integrity issues without preventing restore.

This is the first systematic relationship integrity check across model types. Previous validation coverage only caught structurally invalid shapes (empty names, negative amounts, duplicate IDs). This batch extends coverage to semantic relationship validity — whether a referenced name actually exists in the snapshot.

---

## 2. Current Git State

| Property | Value |
|---|---|
| Branch | `householdbudget-main` |
| Remote tracking | `origin/householdbudget-main` |
| Latest commit | `5a21b01` Add relationship integrity warnings for category references |
| Working tree | Clean — no uncommitted changes |
| Sync status | In sync — local matches `origin/householdbudget-main` |

---

## 3. What Was Added

Seven new `.warning` issues are now reported by `makeBackupValidationReport(for:)` when category or subcategory name references cannot be resolved in the backup snapshot. All seven are non-blocking.

| Warning Title | Source Model | Trigger Condition |
|---|---|---|
| `"Financial event unknown category"` | `FinancialEvent` | `categoryName` is non-nil, non-empty, and not present in `snapshot.categories` |
| `"Financial event unknown subcategory"` | `FinancialEvent` | Parent `categoryName` exists in snapshot but `subCategoryName` is not listed under it |
| `"Quick event unknown category"` | `WalletEvent` | `categoryName` not present in `snapshot.categories` |
| `"Quick event unknown subcategory"` | `WalletEvent` | Parent `categoryName` exists but `subCategoryName` not listed under it |
| `"Installment plan unknown category"` | `InstallmentPlan` | `categoryName` not present in `snapshot.categories` |
| `"Installment plan unknown subcategory"` | `InstallmentPlan` | Parent `categoryName` exists but `subCategoryName` not listed under it |
| `"Budget item unknown category"` | `WalletMonthlyBudgetItem` | `categoryName` is non-empty and not present in `snapshot.categories` |

**Noise reduction design:** For the missing-category case, only the category warning is emitted — the subcategory warning is suppressed. This prevents one orphaned category reference from generating two issues for the same record.

**`FinancialEvent` nil safety:** The `categoryName` field on `FinancialEvent` is optional (`String?`). The check is guarded by `if let categoryName = event.categoryName, !categoryName.isEmpty` so nil category events (e.g., transfers, some income events) produce no category issue.

**`MonthlyBudgetItem` empty-name guard preserved:** The existing `.error` check for an empty `categoryName` fires before the new `.warning` check. An item with an empty name continues to block restore; only items with a non-empty name that is simply absent from the category list produce a `.warning`.

---

## 4. Files Changed in Implementation Commit `5a21b01`

| File | Change |
|---|---|
| `HouseholdBudget/WalletStore.swift` | Added 7 warning blocks inside `makeBackupValidationReport(for:)`: one inside the `financialEvents` loop, one new `walletEvents` loop, one inside the `installmentPlans` loop, one inside the `monthlyBudgets` items loop |
| `HouseholdBudgetTests/BackupValidationTests.swift` | Extended `makeSnapshot` helper to accept `walletEvents:` parameter; added 15 new tests |

No other files were changed. No Xcode project files, Info.plist, public pages, or backup schema files were modified.

---

## 5. Safety Guarantees

- **All new issues are `.warning` only.** No `.error` severity was added in this batch. `hasErrors` remains `false` for a snapshot that only has category reference issues.
- **Restore behavior remains unchanged.** `DataBackupView.importPendingBackup()` and the restore preview gate on `hasErrors`. Category reference warnings do not set `hasErrors`, so restore is not blocked.
- **`validateBackupSnapshot(_:)` was not changed.** The store-level restore gate is untouched. Category reference issues are surfaced in the report only.
- **`DataBackupView` import/restore behavior was not changed.** The restore preview and import function are unmodified.
- **Backup schema was not changed.** `WalletDataSnapshot` and its `CodingKeys` are unmodified. No new fields were added.
- **No data mutation or auto-repair was added.** The validation report is purely read-only. No `FinancialEvent`, `WalletEvent`, `InstallmentPlan`, or `WalletMonthlyBudgetItem` is modified as a result of these checks.
- **No orphan records are deleted.** A record referencing a missing category is reported and left intact.
- **CloudKit sync remains fully disabled.** No CloudKit gates, zones, upload/download pipelines, or feature flags were touched.

---

## 6. Verification

| Check | Result |
|---|---|
| Test count | 62 tests |
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

The following relationship integrity checks have not yet been implemented. They are the recommended work for subsequent batches.

**Account reference warnings (highest priority — highest volume)**  
`FinancialEvent.accountName`, `WalletEvent.defaultAccountName`, `PersonDebtEntry.accountName`, `CreditCardPayment.fromAccountName`, and `InstallmentPlan.accountName` are partially checked today (some as errors for empty names, some as warnings for non-empty missing names). The coverage is inconsistent — some account name references in `FinancialEvent` for unpaid non-transfer events are not checked at all. A systematic sweep is needed.

**Credit card UUID reference warnings**  
`CreditCardStatement.cardID` is not currently validated in the backup report. Statements without a matching card in the snapshot are silently orphaned. This is a medium-risk gap.

**Person debt / debt entry reference warnings**  
`PersonDebtEntry.debtID` → `PersonDebt` is already checked as `.error` (UUID reference). `PersonDebtEntry.accountName` is partially checked. The remaining gap is verifying that the `PersonDebt` referenced by each entry has the correct `kind` to match the entry type — this is a semantic consistency check, not yet implemented.

**Installment event → installment plan warnings**  
`FinancialEvent.sourceInstallmentPlanID` is already checked as `.warning`. No additional gaps exist in the UUID reference direction. The reverse direction (installment plan with no matching events) is informational only and not currently planned.

**Recurring event references**  
`FinancialEvent.sourceRecurringEventID` is not checked against the financial event ID set. A recurring child event referencing a deleted parent is a dangling reference. This is medium risk but normal under current user workflows (recurring parent deletion is a supported action today).

**UUID-based relationship migration**  
The structural root cause of all name-based relationship fragility — that accounts, categories, and subcategories are referenced by String name rather than UUID — has not been addressed. This migration is explicitly deferred. It is the largest structural change in the codebase and requires a dedicated planning phase before any code is written.

---

## 8. Recommended Next Coding Task

**Task title:** Add read-only account reference warnings in `makeBackupValidationReport`

**Scope:** Audit all account name references across `FinancialEvent` (unpaid non-transfer events), `WalletEvent.defaultAccountName`, and `InstallmentPlan.accountName` for consistency. For any account name reference that is non-nil, non-empty, and not present in `snapshot.accounts`, append a `.warning` issue. All new checks must be `.warning` only — do not change restore blocking behavior. Do not change `validateBackupSnapshot`. Add focused tests for each new warning: valid reference produces no issue, missing reference produces `.warning`, nil/empty reference produces no issue. Confirm `hasErrors` remains false for warning-only account reference reports. Confirm `restoreFromBackupSnapshot` does not throw for warning-only account reference snapshots.

---

## 9. Do Not Do Yet

- **Do not enable automatic CloudKit sync.** The sync gates must remain closed.
- **Do not change restore blocking behavior.** Any new relationship check added in future batches must be `.warning` severity unless explicitly approved through a separate analysis.
- **Do not auto-repair data.** If a financial event references a missing category or account, do not update the event's fields. Silent data modification without user knowledge is worse than reporting the issue.
- **Do not mutate or delete orphan records.** Records with broken references must be preserved and reported — never deleted automatically.
- **Do not convert name-based references to UUIDs yet.** This migration requires its own dedicated planning phase. No model fields should be renamed or retyped in the near term.
- **Do not change the backup JSON schema.** No new fields should be added to `WalletDataSnapshot` as part of relationship integrity reporting work.
- **Do not change financial calculations.** The relationship integrity report is a diagnostic read of the snapshot. Balances, runway, debt amounts, and all derived values must remain unaffected.

---

## 10. Verification for This Documentation Task

This file is the sole output of this task. No Swift files, test files, Xcode project files, Info.plist, public pages, or backup schema files were modified. Automatic CloudKit sync was not enabled. Financial calculations were not changed. Data models were not changed.
