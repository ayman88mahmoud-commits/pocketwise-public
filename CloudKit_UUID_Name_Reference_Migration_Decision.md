# CloudKit UUID / Name-Based Reference Migration Decision

Date: 2026-07-01
Branch: householdbudget-main
Phase: CloudKit Sync Preflight — Reference Identity Decision
Status: Documentation only. Automatic CloudKit sync remains disabled and must stay disabled.

---

## 1. Executive Summary

Name-based relationships are the single largest structural risk before CloudKit true sync. When a category, account, or subcategory is referenced by its display **name** rather than a stable **UUID**, any cross-device rename, duplicate name, or deletion breaks or mis-merges the referencing records. Because many of these references are balance-affecting (accounts on transactions, accounts on debt entries and card payments), a broken reference during a multi-device merge can misclassify spending or misroute a balance correction.

This document decides, **at design level only**, how the app should handle name-based relationships before true sync. It inventories every name-based and UUID-based reference, evaluates migration options, and recommends a **hybrid staged migration**: keep existing name fields for backward compatibility and display, add optional stable-ID reference fields later for the highest-risk relationships with dual-write during a transition, validate both in dry-run, and give subcategories real identity (or restrict subcategory-level sync) before true sync.

This is **documentation only**. It changes no schema, adds no fields, flips no flags, and does **not** enable CloudKit sync. It builds on `CloudKit_Conflict_Resolution_Strategy.md`, `CloudKit_Deletion_Tombstone_Strategy.md`, `CloudKit_Sync_Bootstrap_Policy.md`, `Sync_Identity_Deletion_Policy.md`, and `Sync_Relationship_Integrity_Final_Checkpoint.md`.

---

## 2. Current Git State

| Property | Value |
|---|---|
| Branch | `householdbudget-main` |
| Remote tracking | `origin/householdbudget-main` |
| Latest commit | `2929ae3` Document CloudKit sync bootstrap policy |
| Working tree | Clean — no uncommitted changes |
| Sync status | In sync — local matches `origin/householdbudget-main` |

*(This document's own commit advances the latest commit beyond `2929ae3`; the state above reflects the branch immediately before it was committed.)*

---

## 3. Current Identity Baseline

- **Models with stable UUID `id`:** `Account`, `Category`, `WalletEvent`, `MerchantMemory`, `FinancialEvent`, `InstallmentPlan`, `RecurringScheduleOverride`, `PersonDebt`, `PersonDebtEntry`, `WalletMonthlyBudget`, `WalletMonthlyBudgetItem`, `HistoricalMonthlySummaryEntry`, `CreditCard`, `CreditCardPurchase`, `CreditCardPayment`.
- **Models with `createdAt` / `updatedAt` / `isDeleted` / `deletedAt`:** all of the above persisted models carry the full timestamp + soft-delete field set (verified in `WalletModels.swift`). `RecurringScheduleOverride` has `createdAt`/`updatedAt` but no soft-delete fields.
- **Relationships still using display names:** account, category, subcategory, payment method, wallet-event, and reimbursement-category references across `FinancialEvent`, `WalletEvent`, `InstallmentPlan`, `WalletMonthlyBudgetItem`, `PersonDebtEntry`, `CreditCardPurchase`, `CreditCardPayment`, `CreditCard`, `MerchantMemory`, and `HistoricalMonthlySummaryEntry`.
- **Entities with no identity at all:** **subcategories** (`Category.subcategories: [String]`, plus `inactiveSubcategoryNames: [String]`) and **payment methods** (free `String`; there is no `PaymentMethod` model). These have no UUID, no timestamps, and no tombstone.

---

## 4. Name-Based Relationship Inventory

| Source Model | Field | Target Concept | Target Identity Available? | Current Validation | Sync Risk | Migration Recommendation |
|---|---|---|---|---|---|---|
| `FinancialEvent` | `categoryName` | Category | Yes — `Category.id` exists | `.warning` unknown category | High (classification) | Add optional category ID (dual-write) |
| `FinancialEvent` | `subCategoryName` | Subcategory | **No identity** | `.warning` unknown subcategory | High | Requires subcategory identity first |
| `FinancialEvent` | `accountName` | Account | Yes — `Account.id` exists | `.warning` unknown account (paid/unpaid) | **High (balance)** | Add optional account ID (dual-write) — priority |
| `FinancialEvent` | `destinationAccountName` | Account (transfer dest) | Yes — `Account.id` | `.error` empty / `.warning` missing | **High (transfer)** | Add optional account ID (dual-write) — priority |
| `FinancialEvent` | `paymentMethodName` | Payment method | **No model** | Not validated | Medium | Decide payment-method identity model or keep as label |
| `FinancialEvent` | `walletEventName` | WalletEvent | Yes — `WalletEvent.id` (referenced by name) | Not validated by name | Medium | Optional ID later; low priority |
| `FinancialEvent` | `reimbursementCategoryName` | Category | Yes — `Category.id` | Not separately validated | Medium | Optional ID later |
| `WalletEvent` | `categoryName` | Category | Yes | `.warning` unknown category | Medium | Optional ID later |
| `WalletEvent` | `subCategoryName` | Subcategory | **No identity** | `.warning` unknown subcategory | Medium | Requires subcategory identity |
| `WalletEvent` | `defaultAccountName` | Account | Yes | `.warning` unknown default account | Medium | Optional ID later |
| `InstallmentPlan` | `accountName` | Account | Yes | `.warning` missing account | High (generates events) | Add optional account ID (dual-write) |
| `InstallmentPlan` | `categoryName` | Category | Yes | `.warning` unknown category | Medium | Optional ID later |
| `InstallmentPlan` | `subCategoryName` | Subcategory | **No identity** | `.warning` unknown subcategory | Medium | Requires subcategory identity |
| `InstallmentPlan` | `paymentMethodName` | Payment method | **No model** | Not validated | Low-medium | Keep as label / decide model |
| `WalletMonthlyBudgetItem` | `categoryName` | Category | Yes | `.warning`/`.error` (empty) | Medium | Optional ID later; dedupe by year/month/category |
| `PersonDebtEntry` | `accountName` | Account | Yes | `.error` empty / `.warning` missing | **High (balance)** | Add optional account ID (dual-write) — priority |
| `CreditCardPurchase` | `categoryName` / `subCategoryName` | Category / Subcategory | Partial (subcat none) | Not separately relationship-validated | Medium | Category ID later; subcategory needs identity |
| `CreditCardPayment` | `fromAccountName` | Account | Yes | Validated in card payment path | **High (balance)** | Add optional account ID (dual-write) — priority |
| `CreditCard` | `defaultPaymentAccountName` | Account | Yes | `.warning` default account | Medium | Optional ID later |
| `MerchantMemory` | `defaultCategoryName` / `defaultSubCategoryName` | Category / Subcategory | Partial | `.error` invalid merchant memory | Medium | Category ID later; subcategory needs identity |
| `HistoricalMonthlySummaryEntry` | category / subcategory names | Category / Subcategory | Partial | Name-based only | Low-medium | Preserve legacy labels; do not rewrite history |

---

## 5. UUID-Based Relationship Inventory

| Source Model | Field | Target Model | Validation Behavior | Severity | Migration Status |
|---|---|---|---|---|---|
| `CreditCardPurchase` | `cardID` | `CreditCard` | Missing card reported | `.error` (blocking) | Already stable — no migration needed |
| `CreditCardPayment` | `cardID` | `CreditCard` | Missing card reported | `.error` (blocking) | Already stable — no migration needed |
| `InstallmentPlan` | `linkedCreditCardID` | `CreditCard` | Missing linked card reported | `.warning` | Already stable — no migration needed |
| `PersonDebtEntry` | `debtID` | `PersonDebt` | Missing parent reported | `.error` (blocking) | Already stable — no migration needed |
| `FinancialEvent` | `sourceInstallmentPlanID` | `InstallmentPlan` | Missing plan reported | `.warning` | Already stable — no migration needed |
| `FinancialEvent` | `sourceRecurringEventID` | `FinancialEvent` (series) | Missing series reported | `.warning` | Already stable — no migration needed |

These UUID references are the model to extend name-based relationships toward: they are stable, validated, and safe for cross-device merge.

---

## 6. Subcategory Identity Gap

- Subcategories are stored as **`[String]` inside `Category`** (`subcategories`), with a parallel `inactiveSubcategoryNames: [String]`.
- There is **no subcategory UUID**, **no `createdAt`/`updatedAt`**, and **no `deletedAt`/tombstone**.
- Consequently a subcategory **rename or delete cannot be safely synced** at the subcategory level: there is no identity to match across devices, so a rename on one device and an add on another cannot be reconciled, and a delete leaves no tombstone.
- **Options for a future identity model:**
  1. Promote subcategories to a struct with `id: UUID`, `name`, parent `categoryID`, `createdAt`/`updatedAt`, and `isDeleted`/`deletedAt`, stored as `[Subcategory]` — with a compatibility decoder that reads legacy `[String]`.
  2. Keep `[String]` for display but add a side identity map (name → UUID) for sync only — lighter but fragile.
  3. Restrict subcategory-level sync entirely until option 1 is implemented (categories sync; subcategory membership is treated as category-owned value data, not independently syncable).

Until one of these is chosen, subcategory sync must be **restricted**, not attempted.

---

## 7. Migration Options

**Option A — Keep name-based references, rely on warnings/reconciliation**
- Safety: low for sync; medium locally. Complexity: none. Backward compat: perfect. CloudKit suitability: poor (renames/duplicates break merges). Risk to users: high under sync. **Not recommended** as the end state (acceptable only as the current pre-sync bridge).

**Option B — Add UUID reference fields, keep names for display/compatibility**
- Safety: high. Complexity: medium (dual-write, dual-read, compatibility decoders). Backward compat: strong (names stay; UUIDs optional). CloudKit suitability: strong (merge on UUID, display on name). Risk to users: low (additive). **Recommended** for high-risk relationships.

**Option C — Fully migrate to UUID references, remove name-based relationships**
- Safety: high once complete. Complexity: **high** (data migration, historical-label loss risk, big-bang cutover). Backward compat: breaks old backups if names removed. CloudKit suitability: strong. Risk to users: high during migration. **Not recommended** as a near-term step; removal of name fields is deferred indefinitely.

**Option D — Hybrid by risk level**
- Safety: high where it matters. Complexity: medium, staged. Backward compat: strong. CloudKit suitability: strong for balance-affecting paths. Risk to users: low. **Recommended** — apply Option B to high-risk (balance-affecting) relationships first, defer low-risk ones, and give subcategories identity separately.

---

## 8. Recommended Decision

**Adopt a hybrid staged migration (Option D, built on Option B).**

1. **Keep existing name fields** for backward compatibility and display. They remain the human-readable labels the user sees and keep old backups decodable.
2. **Add optional UUID reference fields later** for high-risk (balance-affecting) relationships first: account references on `FinancialEvent` (`accountName`, `destinationAccountName`), `PersonDebtEntry.accountName`, `CreditCardPayment.fromAccountName`, and `InstallmentPlan.accountName`; then category references.
3. **Dual-write name + id during the transition** so both are always populated for new/edited records; **dual-read** with UUID preferred and name as fallback.
4. **Validate both during backup/sync dry-run** — flag name/id disagreement, missing id with present name, and id pointing at a missing/renamed target.
5. **Defer removal of name fields** indefinitely (no Option C big-bang).
6. **Give subcategories stable identity before true sync, or restrict subcategory sync** (per §6). Subcategory-level sync is off the table until identity exists.

This decision is design-level only; no fields are added in this task.

---

## 9. Per-Relationship Migration Priority

**Must solve before true sync (balance-affecting):**
- Account references: `FinancialEvent.accountName`, `FinancialEvent.destinationAccountName`, `PersonDebtEntry.accountName`, `CreditCardPayment.fromAccountName`, `InstallmentPlan.accountName`.

**Can defer but must warn (already have `.warning` coverage):**
- Category references: `FinancialEvent.categoryName`, `WalletEvent.categoryName`, `InstallmentPlan.categoryName`, `WalletMonthlyBudgetItem.categoryName`, `CreditCard.defaultPaymentAccountName`, `WalletEvent.defaultAccountName`.

**Needs identity model before it can sync (special):**
- Subcategory references everywhere (`subCategoryName`) — blocked on §6.
- Payment method references (`paymentMethodName`) — no model exists; decide identity or keep as pure label.

**Safe as-is (already UUID):**
- `cardID`, `linkedCreditCardID`, `debtID`, `sourceInstallmentPlanID`, `sourceRecurringEventID`.

**Needs manual review UX:**
- Cross-device rename conflicts and duplicate-name collisions for accounts and categories.

---

## 10. Backward Compatibility Strategy

- **Existing backups must still import.** No change may make an older `WalletDataSnapshot` undecodable.
- **Old records with only names must remain readable.** Name is preserved as the display label and the fallback relationship key.
- **New optional UUID fields (when implemented) must be additive** and decoded with `decodeIfPresent` so older backup versions without them still load.
- **Restore must tolerate missing UUID fields** — absence means "resolve by name" during the compatibility period.
- **Migration must be lazy or previewed, not destructive** — populate UUIDs on read/edit or via a previewed batch, never a silent rewrite of historical records (which could alter labels the user deliberately kept).

---

## 11. Dry-Run / Validation Requirements

Future dry-run checks the validation harness should perform (read-only):
- **Name exists but UUID missing** — record needs backfill.
- **UUID exists but name changed** — display label drift; reconcile.
- **UUID missing target** — dangling reference (like current orphan warnings).
- **Duplicate names** — two accounts/categories with the same display name but different `id`s.
- **Renamed categories/accounts** — same `id`, changed name across devices.
- **Subcategory ambiguity** — no identity to disambiguate a rename vs a new subcategory.
- **Conflicting name/id pairs** — the name resolves to a different `id` than the stored UUID.

---

## 12. UX Requirements

- **Rename conflict review** — surface same-`id` name divergence for user resolution.
- **Duplicate category/account warning** — flag same-name/different-`id` collisions before merge.
- **"Linked to deleted category/account" display** — show a clear deleted-reference state rather than a blank or a crash.
- **Subcategory migration explanation** — if subcategories gain identity, explain the change without alarming users.
- **Manual review before auto-fixing references** — never silently rewrite a reference; require confirmation for anything balance-affecting.

---

## 13. CloudKit Impact

- **Merge policies:** UUID references let merges resolve on stable identity instead of guessing by name — the precondition for correct field-level merges.
- **Conflict resolution:** removes an entire class of false conflicts caused by renames; same-`id` rename becomes a field update, not an orphaning event.
- **Deletion/tombstone policy:** stable references let a deleted parent be recognized across devices; name-only references cannot reliably detect the same deletion.
- **Bootstrap policy:** the existing-local-plus-existing-cloud merge (bootstrap §8) depends on UUID matching to avoid duplicate baselines.
- **Duplicate detection:** UUID is the primary key; name-based duplicate detection stays advisory/secondary.
- **Offline edits on multiple devices:** dual-write name+id lets an offline device's edits reconcile on reconnect by identity rather than by fragile name matching.

---

## 14. Recommended Next Phase

**CloudKit Dry-Run Validation Mode Design — documentation-only.**

**Justification:** the conflict, deletion, bootstrap, and this identity decision have now each specified read-only checks the system must perform before any write (orphan detection, tombstone/resurrection detection, merge classification, name/id reconciliation). The natural consolidation is to design a single **dry-run validation mode** — built on the existing `WalletSyncDryRunUploadPlanner`, `WalletSyncMergePlanDryRun`, and `WalletSyncDryRunLoopController` scaffolding — that produces a human-readable, no-mutation plan exercising all of those checks together. This is the harness that validates every prior decision (including the name/id dual-read reconciliation) before a single record is ever written, and the bootstrap merge plan is one of its outputs. Designing it next turns the accumulated policy into a concrete, testable validation contract while still writing zero sync code.

After that: TestFlight pilot plan → only then a tiny, disabled-by-default implementation step.

---

## 15. Do Not Do Yet

- **Do not enable automatic CloudKit sync.**
- **Do not flip feature flags** (`isAutomaticCloudKitSyncEnabled`, `isDeveloperCloudKitRecordSyncOverrideEnabled`, or the persisted auto-sync gate).
- **Do not change entitlements.**
- **Do not change CloudKit containers.**
- **Do not change upload/download/apply logic.**
- **Do not change restore blocking behavior.**
- **Do not auto-migrate or mutate data.**
- **Do not change the backup schema.**
- **Do not change financial calculations.**
- **Do not merge with the GitHub `main` branch.** This work stays on `householdbudget-main`.

---

## 16. Verification for This Documentation Task

This file is the sole output of this task. No Swift files, test files, Xcode project files, Info.plist, entitlements, public pages, or backup schema files were modified. No feature flags were changed. Automatic CloudKit sync was not enabled. Financial calculations were not changed. Data models were not changed.
