# Sync Relationship Integrity Preflight — Audit and Implementation Plan

Date: 2026-07-01  
Branch: householdbudget-main  
App: WalletBoard  
Status: Documentation-only audit. No Swift, test, Xcode, or backup schema files changed.  
Automatic CloudKit sync: disabled. No sync mutation should be enabled yet.

---

## 1. Executive Summary

This phase prepares read-only relationship and orphan-reference validation across all WalletBoard data models before any future sync mutation is attempted.

The previous sync safety phase established:
- Blocking error severity for invalid model shapes
- Restore blocking when validation errors exist
- Full alignment between the backup report and the store-level restore gate

What is not yet done: no systematic check exists for **relationship integrity** — whether the named references and UUID references that link records together are internally consistent within a backup. An account name that appears in a financial event must exist in the accounts list. A category name referenced by a merchant memory must exist in the categories list. A `debtID` on a `PersonDebtEntry` must point to a real `PersonDebt`. These relationships use either name strings or UUIDs; both types are currently only partially validated.

This audit maps every cross-model reference, identifies which are already checked, which are missing, and proposes a minimal first implementation of read-only preflight validation that does not change restore behavior.

**True automatic CloudKit sync remains fully disabled. No sync mutation should be enabled yet.**

---

## 2. Current Git State

| Property | Value |
|---|---|
| Branch | `householdbudget-main` |
| Remote tracking | `origin/householdbudget-main` |
| Latest commit | `7f4cec3` Update public pages README to WalletBoard |
| Sync safety checkpoint commit | `cf16902` Document sync safety preflight foundation checkpoint |
| Checkpoint tag | `sync-safety-preflight-foundation` |
| Working tree | Clean — no uncommitted changes |
| Local vs remote | In sync — `origin/householdbudget-main` matches local HEAD |

GitHub's `main` branch is a separate branch used for public pages. It is not the app branch. Do not merge `main` into `householdbudget-main`.

---

## 3. Why This Phase Matters

### 3.1 Sync amplifies orphan references

Today, an orphaned reference (a financial event referencing a deleted account by name) is a local inconvenience. After sync, that orphaned reference can propagate to every device. A device that never deleted that account will now hold a record that references a name its peer no longer has. Sync conflict resolution cannot safely repair this because it cannot distinguish between "this account was deleted" and "this account was never here."

### 3.2 Name-based relationships break silently under rename

WalletBoard uses String-based relationships for accounts, categories, and subcategories. Every model that references an account does so by `accountName: String`, not by `UUID`. If a user renames "Cash" to "Wallet Cash" on Device A before sync, Device B receives the renamed account but all financial events on Device B still reference "Cash". The references are broken silently — no error is thrown, no UI warning appears, and the records are not invalid by current validation rules.

This is the highest-risk pattern in the codebase for sync correctness.

### 3.3 Restore validation is not enough

The existing `makeBackupValidationReport` catches many invalid shapes, but its relationship checks are inconsistent. Some name references are checked (credit card payment account, transfer source/destination), others are not (financial event category, wallet event category, installment plan category). UUID references for `PersonDebtEntry.debtID` and `CreditCardPurchase.cardID` are checked as errors, but `FinancialEvent.sourceInstallmentPlanID` is only a warning, and `FinancialEvent.sourceRecurringEventID` is not checked at all.

Read-only preflight validation that is separate from restore blocking is needed so that relationship integrity can be audited before any sync mutation without disrupting the current restore workflow.

---

## 4. Relationship Map

The table below lists every cross-model reference found in `WalletModels.swift` and `WalletStore.swift`. Risk levels reflect sync amplification potential, not just current restore impact.

| Source Model | Referenced Model/Entity | Reference Field | Reference Type | Current Risk | If Missing: Severity | Reason |
|---|---|---|---|---|---|---|
| `FinancialEvent` | `Account` | `accountName` (optional) | name string | **HIGH** | warning | Paid non-transfer events missing their account are data loss risk under sync. Not blocking today — can be nil for unpaid events. |
| `FinancialEvent` (transfer) | `Account` (source) | `accountName` (required for transfers) | name string | **HIGH** | error (empty) / warning (not found) | Empty source is already `.error`. Non-empty but unknown source is `.warning`. |
| `FinancialEvent` (transfer) | `Account` (destination) | `destinationAccountName` (required for transfers) | name string | **HIGH** | error (empty) / warning (not found) | Same pattern as source. Already covered. |
| `FinancialEvent` | `Category` | `categoryName` (optional) | name string | **HIGH** | warning | Not currently checked against the category list. A renamed category silently orphans all its events. |
| `FinancialEvent` | `Subcategory` | `subCategoryName` (optional) | name string | **HIGH** | warning | Not currently checked. See category risk above. |
| `FinancialEvent` | `InstallmentPlan` | `sourceInstallmentPlanID` (optional UUID) | UUID | medium | warning | Already reported as `.warning` when the plan is missing. Correct severity. |
| `FinancialEvent` | `FinancialEvent` (parent recurring) | `sourceRecurringEventID` (optional UUID) | UUID | medium | warning | **Not currently checked at all.** A recurring child event referencing a deleted parent is a dangling reference. |
| `WalletEvent` (quick event) | `Category` | `categoryName` | name string | **HIGH** | warning | **Not currently checked against the category list.** WalletEvents only have ID uniqueness validated. |
| `WalletEvent` (quick event) | `Subcategory` | `subCategoryName` | name string | **HIGH** | warning | **Not currently checked.** |
| `WalletEvent` (quick event) | `Account` | `defaultAccountName` (optional) | name string | low | info | Optional convenience reference. Low risk — not used for financial calculations. |
| `InstallmentPlan` | `Account` | `accountName` (optional) | name string | medium | warning | Already checked as `.warning` when account is missing. Correct severity. |
| `InstallmentPlan` | `CreditCard` | `linkedCreditCardID` (optional UUID) | UUID | medium | warning | Already checked as `.warning` when card is missing. Correct severity. |
| `InstallmentPlan` | `Category` | `categoryName` | name string | **HIGH** | warning | **Not currently checked against the category list.** Same rename risk as FinancialEvent. |
| `InstallmentPlan` | `Subcategory` | `subCategoryName` | name string | **HIGH** | warning | **Not currently checked.** |
| `CreditCardPurchase` | `CreditCard` | `cardID` (UUID) | UUID | **HIGH** | error | Already checked as `.error`. Correct — purchase without a card is unrecoverable. |
| `CreditCardPurchase` | `Category` | `categoryName` | name string | **HIGH** | error | Already checked as `.error` against the category list. |
| `CreditCardPurchase` | `Subcategory` | `subCategoryName` | name string | **HIGH** | error | Already checked as `.error`. |
| `CreditCardPayment` | `CreditCard` | `cardID` (UUID) | UUID | **HIGH** | error | Already checked as `.error`. |
| `CreditCardPayment` | `Account` | `fromAccountName` | name string | **HIGH** | error (empty) / warning (not found) | Already split correctly. |
| `CreditCardStatement` | `CreditCard` | `cardID` (UUID) | UUID | medium | warning | **Not currently checked in the backup report.** Statements without a card are orphaned. |
| `PersonDebtEntry` | `PersonDebt` | `debtID` (UUID) | UUID | **HIGH** | error | Already checked as `.error`. Correct — an entry without a parent debt is unrecoverable. |
| `PersonDebtEntry` | `Account` | `accountName` | name string | **HIGH** | error (empty) / warning (not found) | Already split correctly. |
| `MerchantMemory` | `Category` | `defaultCategoryName` | name string | medium | error | Already checked as `.error` (combined with name empty check). |
| `MerchantMemory` | `Subcategory` | `defaultSubCategoryName` | name string | medium | error | Already checked as `.error`. |
| `MerchantMemory` | `Account` | `defaultAccountName` (optional) | name string | low | info | **Not currently checked.** Optional convenience reference — not used for financial calculations. `.info` is appropriate. |
| `HistoricalMonthlySummaryEntry` | `Category` | `categoryName` | name string | medium | error | Already checked as `.error` against the category list. |
| `HistoricalMonthlySummaryEntry` | `Subcategory` | `subCategoryName` | name string | medium | error | Already checked as `.error`. |
| `MonthlyBudgetItem` | `Category` | `categoryName` | name string | medium | warning | Checked for empty name (→ `.error`) but **not checked against the category list**. A renamed category silently orphans budget items. |
| `CreditCard` | `Account` (default payment) | `defaultPaymentAccountName` (optional) | name string | low | warning | Already checked as `.warning` when account is missing. Correct severity. |

**Legend — Risk Levels:**
- **HIGH:** Name-based reference that breaks silently on rename, or UUID reference where orphaned records are financially meaningful
- **medium:** UUID or name reference where an orphan is incorrect but does not affect financial calculations
- **low:** Optional convenience reference with no financial calculation impact

---

## 5. Existing Validation Coverage

### 5.1 Already blocking (.error) — blocks restore today

| Check | Location |
|---|---|
| Duplicate IDs across all 13 entity types | `makeBackupValidationReport` |
| Duplicate monthly budget item IDs | `makeBackupValidationReport` |
| Future schema version | `makeBackupValidationReport` |
| Empty account name | `makeBackupValidationReport` + `validateBackupSnapshot` |
| Duplicate account name (case-insensitive) | `makeBackupValidationReport` + `validateBackupSnapshot` |
| Empty category name | `makeBackupValidationReport` + `validateBackupSnapshot` |
| Duplicate category name (case-insensitive) | `makeBackupValidationReport` + `validateBackupSnapshot` |
| Invalid credit card shape (`isValidCreditCard`) | `makeBackupValidationReport` + `validateBackupSnapshot` |
| Invalid person debt (empty name / amount ≤ 0) | `makeBackupValidationReport` + `validateBackupSnapshot` |
| Invalid merchant memory (empty name / unknown category) | `makeBackupValidationReport` + `validateBackupSnapshot` |
| Invalid historical summary (bad period / amount / category) | `makeBackupValidationReport` + `validateBackupSnapshot` |
| Credit card purchase: missing card (UUID) | `makeBackupValidationReport` + `validateBackupSnapshot` |
| Credit card purchase: invalid category/subcategory | `makeBackupValidationReport` + `validateBackupSnapshot` |
| Credit card purchase: empty title | `makeBackupValidationReport` + `validateBackupSnapshot` |
| Credit card payment: missing card (UUID) | `makeBackupValidationReport` + `validateBackupSnapshot` |
| Credit card payment: empty `fromAccountName` | `makeBackupValidationReport` + `validateBackupSnapshot` |
| Transfer: empty source or destination account name | `makeBackupValidationReport` + `validateBackupSnapshot` |
| Transfer: source == destination | `makeBackupValidationReport` + `validateBackupSnapshot` |
| Person debt entry: missing parent `debtID` (UUID) | `makeBackupValidationReport` + `validateBackupSnapshot` |
| Person debt entry: empty account name | `makeBackupValidationReport` + `validateBackupSnapshot` |
| Invalid settings (negative fees, max < min) | `makeBackupValidationReport` + `validateBackupSnapshot` |
| Invalid financial event amount (≤ 0) | `makeBackupValidationReport` + `validateBackupSnapshot` |
| Monthly budget item: empty category name | `makeBackupValidationReport` + `validateBackupSnapshot` |
| Monthly budget item: negative planned amount | `makeBackupValidationReport` + `validateBackupSnapshot` |

### 5.2 Already non-blocking (.warning) — checked but do not block restore

| Check | Location | Why warning only |
|---|---|---|
| Paid non-transfer event with unknown/empty account | `makeBackupValidationReport` | `validateBackupSnapshot` does not throw for this |
| Transfer with non-empty but unknown source account | `makeBackupValidationReport` | `validateBackupSnapshot` does not throw for non-empty case |
| Transfer with non-empty but unknown destination | `makeBackupValidationReport` | Same |
| Credit card payment: non-empty but unknown `fromAccountName` | `makeBackupValidationReport` | `validateBackupSnapshot` does not throw for non-empty case |
| Person debt entry: non-empty but unknown account name | `makeBackupValidationReport` | Same |
| Installment event referencing missing plan (UUID) | `makeBackupValidationReport` | `validateBackupSnapshot` does not throw for this |
| Installment plan: non-empty but unknown account | `makeBackupValidationReport` | Same |
| Installment plan: missing linked credit card (UUID) | `makeBackupValidationReport` | Same |
| Installment plan: impossible amount or count | `makeBackupValidationReport` | Shape issue, not relationship |
| Installment plan: paid count exceeds total | `makeBackupValidationReport` | Count inconsistency, not relationship |
| Credit card: missing default payment account | `makeBackupValidationReport` | Optional convenience field |

### 5.3 Missing checks — not currently validated anywhere

| Missing Check | Models Affected | Risk |
|---|---|---|
| `FinancialEvent.categoryName` vs. category list | `FinancialEvent` | **HIGH** |
| `FinancialEvent.subCategoryName` vs. subcategory list under that category | `FinancialEvent` | **HIGH** |
| `WalletEvent.categoryName` vs. category list | `WalletEvent` | **HIGH** |
| `WalletEvent.subCategoryName` vs. subcategory list | `WalletEvent` | **HIGH** |
| `InstallmentPlan.categoryName` vs. category list | `InstallmentPlan` | **HIGH** |
| `InstallmentPlan.subCategoryName` vs. subcategory list | `InstallmentPlan` | **HIGH** |
| `MonthlyBudgetItem.categoryName` vs. category list (non-empty check exists but not existence check) | `MonthlyBudgetItem` | medium |
| `FinancialEvent.sourceRecurringEventID` vs. financial event IDs | `FinancialEvent` | medium |
| `CreditCardStatement.cardID` vs. credit card list | `CreditCardStatement` | medium |
| `MerchantMemory.defaultAccountName` vs. account list | `MerchantMemory` | low |
| `WalletEvent.defaultAccountName` vs. account list | `WalletEvent` | low |

### 5.4 Checks that are unsafe to make blocking immediately

The following checks must NOT be upgraded to `.error` without additional analysis. Making them blocking would risk breaking restore for legitimate old backups:

| Check | Why unsafe to block immediately |
|---|---|
| `FinancialEvent.categoryName` vs. category list | A financial event may legitimately reference a category that was later deleted. Old backups from before a category deletion would fail. Needs upgrade path. |
| `FinancialEvent.subCategoryName` vs. subcategory list | Same as above. |
| `WalletEvent.categoryName/subCategoryName` | Same pattern. |
| `InstallmentPlan.categoryName/subCategoryName` | Same pattern. |
| `MonthlyBudgetItem.categoryName` vs. category list | Budget items referencing deleted categories are historically valid. |
| `FinancialEvent.sourceRecurringEventID` | A recurring parent can be deleted while children persist — this is a normal user action today. |
| `MerchantMemory.defaultAccountName` | Optional convenience field — nil or stale values are acceptable. |

---

## 6. Proposed Read-Only Preflight Model

### 6.1 Recommendation: extend `makeBackupValidationReport` rather than a separate report

**Reason:** A separate `WalletRelationshipIntegrityReport` would duplicate the snapshot traversal infrastructure, create a second report type that the restore UI must understand, and require new UI wiring. The existing `BackupValidationReport` infrastructure already supports `.warning` (non-blocking) and `.error` (blocking), is already shown in the restore preview, and is already fed into the restore gate.

The missing relationship checks belong in `makeBackupValidationReport` as `.warning` issues. They are non-blocking (they do not prevent restore), but they are surfaced to the user before restore so they can make an informed decision. This is the smallest safe approach.

**Only one new type is needed**, and only if the warnings need to be visually distinguished in the restore preview UI in a future phase: a `relationshipGroup` flag on `BackupValidationIssue`. This is not needed for the first implementation.

### 6.2 If a separate report is preferred in the future

If the team later wants to run relationship integrity checks at times other than restore preview (e.g., on app launch, or as a pre-sync gate), the following names are appropriate:

- `WalletRelationshipIntegrityReport` — analogous to `BackupValidationReport`
- `WalletRelationshipIntegrityIssue` — analogous to `BackupValidationIssue`
- `WalletRelationshipIntegritySeverity` — analogous to `BackupValidationSeverity`
- `makeRelationshipIntegrityReport(for snapshot: WalletDataSnapshot) -> WalletRelationshipIntegrityReport` — analogous to `makeBackupValidationReport`

This separate report would be appropriate when sync is closer to being enabled — it would be the pre-sync gate that runs before any CloudKit mutation. It is not needed now.

### 6.3 Decision for first implementation

**Extend `makeBackupValidationReport`** by adding the missing category/subcategory existence checks for `FinancialEvent`, `WalletEvent`, `InstallmentPlan`, and `MonthlyBudgetItem` as `.warning` issues. This adds coverage without changing restore behavior.

---

## 7. Proposed Checks for First Implementation

The first coding task should add exactly the following checks to `makeBackupValidationReport(for:)`. All must be `.warning` severity. None should change restore-blocking behavior.

### 7.1 FinancialEvent → Category/Subcategory existence

**Condition:** `event.categoryName` is non-nil and non-empty, and either:
- `validCategories` does not contain it, or
- `validSubcategoriesByCategory[event.categoryName]` does not contain `event.subCategoryName`

**Severity:** `.warning`

**Restore behavior:** unchanged — warnings do not block restore

**Required test:**
- financial event with unknown category name → `.warning` in report
- financial event with valid category but unknown subcategory → `.warning` in report
- financial event with nil category → no issue
- valid backup with all events referencing existing categories → no category issue

**Risk of false positives:** Low if scoped to non-nil, non-empty `categoryName`. A nil category is valid for some event types (transfers, some income). The check must be conditional on `categoryName != nil && !categoryName.isEmpty`.

### 7.2 WalletEvent → Category/Subcategory existence

**Condition:** `event.categoryName` or `event.subCategoryName` not found in the category/subcategory sets

**Severity:** `.warning`

**Restore behavior:** unchanged

**Required test:**
- wallet event with unknown category → `.warning`
- wallet event with valid category but unknown subcategory → `.warning`
- valid wallet events → no issue

**Risk of false positives:** Low. WalletEvent `categoryName` is non-optional — always present.

### 7.3 InstallmentPlan → Category/Subcategory existence

**Condition:** `plan.categoryName` or `plan.subCategoryName` not found in the category/subcategory sets

**Severity:** `.warning`

**Restore behavior:** unchanged

**Required test:**
- installment plan with unknown category → `.warning`
- installment plan with valid category, unknown subcategory → `.warning`
- valid installment plan → no issue

**Risk of false positives:** Low. `categoryName` is non-optional on `InstallmentPlan`.

### 7.4 MonthlyBudgetItem → Category existence

**Condition:** `item.categoryName` is non-empty (already checked) and `validCategories` does not contain it

**Severity:** `.warning`

**Restore behavior:** unchanged (the current `.error` check for empty name is preserved unchanged)

**Required test:**
- monthly budget item referencing unknown category → `.warning`
- monthly budget item with empty category → still `.error` (regression check)
- valid monthly budget item → no issue

**Risk of false positives:** Low to medium. Budget items may reference categories that were created in the same month but later deleted. If the backup is from after the deletion, the check correctly flags it. If the backup is from before, the reference was valid at backup time — but since we restore the categories from the backup too, this case should not produce a false positive.

### 7.5 What to defer from the first implementation

- `FinancialEvent.sourceRecurringEventID` — defer; normal user action to delete recurring parents
- `CreditCardStatement.cardID` — defer; verify CreditCardStatement is included in backup first
- `MerchantMemory.defaultAccountName` — defer; low risk, `.info` would be appropriate but not urgent
- `WalletEvent.defaultAccountName` — defer; low risk, optional field

---

## 8. Test Plan

The following tests must be added to `BackupValidationTests.swift` in the next coding task. No test should change restore-blocking behavior — all new tests verify `.warning` issues only.

### Category/subcategory reference tests (FinancialEvent)

- `testFinancialEventWithUnknownCategoryIsReportedAsWarning`
- `testFinancialEventWithUnknownSubcategoryIsReportedAsWarning`
- `testFinancialEventWithNilCategoryProducesNoCategoryIssue`
- `testFinancialEventWithValidCategoryProducesNoCategoryIssue`
- `testFinancialEventCategoryWarningDoesNotBlockRestore`

### Category/subcategory reference tests (WalletEvent)

- `testWalletEventWithUnknownCategoryIsReportedAsWarning`
- `testWalletEventWithUnknownSubcategoryIsReportedAsWarning`
- `testWalletEventWithValidCategoryProducesNoIssue`
- `testWalletEventCategoryWarningDoesNotBlockRestore`

### Category/subcategory reference tests (InstallmentPlan)

- `testInstallmentPlanWithUnknownCategoryIsReportedAsWarning`
- `testInstallmentPlanWithUnknownSubcategoryIsReportedAsWarning`
- `testInstallmentPlanWithValidCategoryProducesNoIssue`

### Category reference tests (MonthlyBudgetItem)

- `testMonthlyBudgetItemWithUnknownCategoryIsReportedAsWarning`
- `testMonthlyBudgetItemWithEmptyCategoryRemainsBlockingError` (regression)
- `testMonthlyBudgetItemWithValidCategoryProducesNoIssue`

### Cross-cutting tests

- `testWarningOnlyRelationshipIssuesDoNotBlockRestore` — a snapshot with all four warning types above passes `restoreFromBackupSnapshot` without throwing
- `testOldBackupWithValidCategoriesProducesNoRelationshipWarnings` — smoke test using a representative valid snapshot
- `testFinancialCalculationsAreUnchangedAfterRelationshipValidationAdded` — verify that store financial totals are not affected by the new checks (read-only contract)

---

## 9. Do Not Do Yet

The following actions must not be taken in the next implementation task or any task until explicitly planned:

- **Do not enable automatic CloudKit sync.** The sync gates must remain closed.
- **Do not mutate any data** during the relationship integrity check. The validator is read-only.
- **Do not auto-repair orphan references.** If a financial event references a missing category, do not update the event's `categoryName`. Silently fixing data without user knowledge is worse than reporting it.
- **Do not delete orphan records.** A financial event referencing a missing account must not be deleted automatically.
- **Do not change restore-blocking behavior** in the first relationship integrity implementation. All new checks must be `.warning`. Any upgrade to `.error` requires a separate explicit decision with full analysis of false-positive risk.
- **Do not convert name-based references to UUIDs yet.** This is the largest structural change in the codebase and requires its own dedicated planning phase.
- **Do not rename models or fields.** Changing `accountName` to `accountID` is out of scope for this phase.
- **Do not change the backup JSON schema.** No new fields should be added to `WalletDataSnapshot` as part of this validation work.
- **Do not change financial calculations.** The relationship integrity report is a diagnostic read of the snapshot. It does not affect balances, running totals, runway, debt amounts, or any other derived value.
- **Do not run CloudKit upload or download pipelines.** No records should move between the device and CloudKit.

---

## 10. Recommended Next Prompt

**Task title:** Add read-only relationship integrity warnings for category references in financial events, wallet events, installment plans, and monthly budget items

**Scope:** Extend `makeBackupValidationReport(for:)` in `WalletStore.swift` to add `.warning` issues when `FinancialEvent.categoryName`, `WalletEvent.categoryName`, `InstallmentPlan.categoryName`, or `MonthlyBudgetItem.categoryName` references a category name that is not present in `snapshot.categories` (and similarly for subcategory names). Use the already-built `validCategories` and `validSubcategoriesByCategory` sets that are constructed earlier in the same function. All new checks must be `.warning` severity only — they must not block restore. Add the 17 tests listed in Section 8 of `Sync_Relationship_Integrity_Preflight_Audit.md`. Do not change any other Swift behavior. Do not enable CloudKit sync. Do not change financial calculations. Do not change the backup format. Commit with message: `Add relationship integrity warnings for category references`.

---

## 11. Verification

This file is the sole output of this task. No Swift files, test files, Xcode project files, Info.plist, public pages, or backup schema files were modified. Automatic CloudKit sync was not enabled. Financial calculations were not changed. Data models were not changed.
