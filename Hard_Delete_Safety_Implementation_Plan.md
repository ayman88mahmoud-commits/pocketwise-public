# Hard Delete Safety Implementation Plan

## 1. Executive Summary

The app currently uses a manual iCloud backup workflow. CloudKit automatic sync is intentionally disabled and must remain disabled. When live iCloud sync is eventually introduced, every delete operation becomes a cross-device event: a record removed on one device may still exist on another. Without a durable deletion policy, those remote copies will reappear on the next sync cycle, silently resurrecting financial records, reversed balances, cancelled debts, and removed card payments.

Most of the app's delete paths are hard deletes: they remove records directly from in-memory arrays and persist the absence. Several paths also write sync tombstones or high-risk deletion markers to `WalletSyncStateStore`, which is a good foundation, but tombstones are stored separately from backup snapshots. A manual restore from an older backup can silently lose tombstone history and resurrect deleted records.

The specific risks before future sync are:

- `deleteFinancialEvent` reverses an account balance impact before removing the record. If the deletion tombstone is lost after a restore, a future sync cycle could re-download the record and re-apply the balance impact, double-counting income or expenses.
- `deleteCreditCardPayment` restores the source account balance before removing the payment. If the payment reappears from another device, the balance correction could double-apply.
- `deletePersonDebt` cascades to all linked debt entries and reverses their balance impacts. A resurrect event on another device could re-post all of those debt impacts.
- `deleteInstallmentPlanAndFutureEvents` removes unpaid generated installment events. If plan tombstones are lost, regenerated events could be duplicated.
- `resetToSampleData` and `removeSeedDataBeforeInitialCloudAdoptionIfSafe` both mass-clear all arrays with no tombstones. These are particularly dangerous if ever triggered on a device participating in a live sync zone.

None of these paths set `isDeleted` or `deletedAt` on the record before removing it. The record simply disappears from the local array. The only durable deletion trace is in `WalletSyncStateStore`, which is not included in normal manual backups.

This plan documents all hard-delete paths, classifies their risk, and recommends a safe phased approach. No Swift code, no test files, and no CloudKit behavior should be changed as a result of this document.

---

## 2. Current Delete Path Inventory

| Function | File | Model / Data Affected | Behavior | Sets `isDeleted`? | Sets `deletedAt`? | Writes Tombstone? | Affects Balances / Posting? | Risk | Notes |
|---|---|---|---|---|---|---|---|---|---|
| `deleteAccountIfUnused(_:)` | `WalletStore.swift:794` | `Account` | Hard delete: removes from `accounts` array | No | No | Yes — generic tombstone via `markSyncRecordDeletedLocally` | No direct balance change; account must be unused | Medium | Guard requires account to have no transactions. Tombstone written before removal. |
| `deleteCategoryIfUnused(_:)` | `WalletStore.swift:1064` | `Category` | Hard delete: removes from `categories` array | No | No | Yes — generic tombstone via `markSyncRecordDeletedLocally` | No | Medium | Guard requires category to be unused. Also clears inactive subcategory names. Tombstone written before removal. |
| `deleteSubcategoryIfUnused(_:in:)` | `WalletStore.swift:1141` | Nested subcategory `String` inside `Category` | Hard delete: removes string from `category.subcategories` and `inactiveSubcategoryNames` | No | No | No | No | High | Subcategories have no UUID, no `isDeleted`, no `deletedAt`, no tombstone. No sync identity exists at all. Cannot be safely synced. |
| `saveMonthlyBudget` removed-item path | `WalletStore.swift:1222` | `WalletMonthlyBudgetItem` | Hard delete: items not in new plan are removed from parent `items` array | No | No | Yes — high-risk tombstone via `markHighRiskRecordDeletedLocally` | No financial posting impact directly | Medium | Items are preserved by normalized category name. Removed items get high-risk tombstones. No `isDeleted` on the item model itself. |
| `deleteHistoricalMonthlySummary(_:)` | `WalletStore.swift:1767` | `HistoricalMonthlySummaryEntry` | Hard delete: removes from `historicalMonthlySummaries` array | No | No | Yes — generic tombstone via `markSyncRecordDeletedLocally` | No | Medium | These are user-entered or imported summary records, not derived. Tombstone written before removal. |
| `deleteCreditCardPurchase(_:)` | `WalletStore.swift:2124` | `CreditCardPurchase` | Hard delete: removes from `creditCardPurchases` array | No | No | Yes — high-risk tombstone via `markHighRiskRecordDeletedLocally` | No direct account balance impact (purchase tracks card balance, not cash account) | High | No `isDeleted` on the model. High-risk marker written before removal. Card statement balance is affected. |
| `deleteCreditCardPayment(_:)` | `WalletStore.swift:2192` | `CreditCardPayment` + source `Account.balance` | Hard delete: restores source account balance by adding back `payment.amount`, then removes payment from array | No | No | Yes — high-risk tombstone via `markHighRiskRecordDeletedLocally` | Yes — directly mutates source account `balance` before removal | High | Account name resolution is string-based. If the source account was renamed, the payment amount may be applied to the wrong account or the guard fails silently. Balance mutation happens before the tombstone is written. |
| `deletePersonDebt(_:)` | `WalletStore.swift:2754` | `PersonDebt` + all linked `PersonDebtEntry` records + account balances | Hard delete: reverses all linked debt entry balance impacts via `applyPersonDebtEntryImpact` with multiplier -1, tombstones all entries, tombstones parent debt, then removes all from arrays | No | No | Yes — high-risk tombstones for parent and all child entries | Yes — reverses balance impact of every linked debt entry | High | Cascades silently across all child entries. If a remote device still holds the debt, re-sync would re-post all entry impacts. Account name is string-based; mismatches on account rename could corrupt balances. |
| `deleteFinancialEvent(_:)` | `WalletStore.swift:3574` | `FinancialEvent` + source `Account.balance` | Hard delete: calls `reverseAccountImpactIfNeeded` before removing from array | No | No | Yes — financial event deletion marker via `markFinancialEventDeletedLocally` | Yes — reverses account balance impact (and transfer destination balance for transfer events) | High | Most dangerous path. Deletion reverses real money movements. If the record reappears from another device, the balance reversal does not undo itself automatically. Tombstone is written before removal. |
| `deleteMerchantMemory(_:)` | `WalletStore.swift:4075` | `MerchantMemory` | Hard delete: removes from `merchantMemories` array | No | No | Yes — generic tombstone via `markSyncRecordDeletedLocally` | No | Low | Merchant memories are local matching helpers. Tombstone written before removal. Safe candidate for future soft delete. |
| `deleteInstallmentPlanAndFutureEvents(_:)` | `WalletStore.swift:4214` | `InstallmentPlan` + unpaid generated `FinancialEvent` records | Hard delete: tombstones plan, removes plan, tombstones each unpaid generated event, removes those events. Paid installment events are left in place. | No | No | Yes — installment plan deletion marker + financial event markers for each unpaid event | Yes — unpaid installment events that were scheduled to post future balance impacts are removed | High | Paid events survive in `financialEvents` with no parent plan. If the plan reappears on another device, future events could be regenerated and duplicated. |
| `resetToSampleData()` | `WalletStore.swift:4406` | All arrays: accounts, categories, walletEvents, merchantMemories, installmentPlans, financialEvents, personDebts, personDebtEntries, monthlyBudgets, historicalMonthlySummaries, creditCards, creditCardPurchases, creditCardPayments + scalar settings | Hard bulk wipe: replaces all arrays with sample data or empty arrays. No tombstones written. | No | No | No | Yes — all balances, debts, and card payment history are wiped | High | Must never be reachable during any sync session. No tombstones are written for any records. If sync is ever enabled and this is called, the remote copy of all records would be treated as authoritative on the next fetch. |
| `removeSeedDataBeforeInitialCloudAdoptionIfSafe()` | `WalletStore.swift:4690` | All arrays (only if contents exactly match seed data) | Hard bulk wipe with guard: clears all arrays if and only if data exactly matches the sample seed. No tombstones written. | No | No | No | Yes — clears all arrays including financial records | High | Safer than `resetToSampleData` because of the exact-match guard, but still writes no tombstones. Intended for initial CloudKit adoption only. Must not be called outside that specific flow. |
| `deleteOverrideDraft(_:)` in `RecurringPaymentEditorView` | `RecurringPaymentEditorView.swift:745` | `RecurringScheduleOverride` (in-editor draft state only) | Removes override from local editor draft array before save is confirmed | No | No | No | No | Low | This removes an unsaved draft override, not a persisted override. No store mutation occurs until the parent recurring event is saved. |
| `removeOverride(year:month:)` in `RecurringPaymentEditorView` | `RecurringPaymentEditorView.swift:622` | `RecurringScheduleOverride` (in-editor draft state only) | Removes override from local editor draft array by year/month | No | No | No | No | Low | Same as above. Draft-only. No persisted data affected. |
| `PendingBankSMSImportStore.remove(importIdentity:)` | `BankSMSImportDraft.swift:58` | `BankSMSImportDraft` (UserDefaults-backed pending drafts) | Removes a pending import draft by identity key from UserDefaults | No | No | No | No | Low | Bank SMS import drafts are local workflow state. Removing a draft does not affect persisted financial records. These should remain local-only. |
| `clearWalletSyncZoneChangeTokenData()` | `WalletSyncStateStore.swift:77` | CloudKit zone change token (UserDefaults) | Removes the stored change token from UserDefaults | No | No | Not applicable | No | Medium | Loss of the change token forces a full re-fetch on the next sync cycle. Safe to clear locally, but can cause redundant CloudKit fetches and potential record conflicts if called at the wrong time. |
| `clearLocallyDeletedFinancialEventIDs()` | `WalletSyncStateStore.swift:109` | Financial event deletion markers (UserDefaults) | Clears all stored financial event tombstone IDs | No | No | Clears tombstones | No | High | If called before tombstones are pushed to CloudKit, deleted financial events could be resurrected from the remote copy. |
| `clearLocallyDeletedInstallmentPlanIDs()` | `WalletSyncStateStore.swift:137` | Installment plan deletion markers (UserDefaults) | Clears all stored installment plan tombstone IDs | No | No | Clears tombstones | No | High | Same resurrection risk as above, applied to installment plans and their future events. |
| `clearLocallyDeletedHighRiskRecordIDs()` | `WalletSyncStateStore.swift:176` | High-risk deletion markers for credit card purchases, payments, person debts, debt entries, monthly budget items (UserDefaults) | Clears all high-risk tombstone records | No | No | Clears tombstones | No | High | Clearing these before sync confirmation would allow all high-risk financial records to be resurrected. |
| `clearLocallyDeletedRecordIDs()` | `WalletSyncStateStore.swift:190` | Generic tombstones for accounts, categories, wallet events, merchant memories, historical summaries (UserDefaults) | Clears all generic sync tombstone records | No | No | Clears tombstones | No | Medium | Clears master-data tombstones. Lower financial risk than high-risk markers, but could resurrect deleted master data. |

---

## 3. High-Risk Delete Paths

The following paths carry the highest risk before any future iCloud sync is introduced. They are listed in order from most to least dangerous.

### 3.1 `deleteFinancialEvent(_:)` — Critical

This is the most dangerous delete path in the app. Deleting a financial event reverses its account balance impact via `reverseAccountImpactIfNeeded` before removing the record. The tombstone (`markFinancialEventDeletedLocally`) is written to `WalletSyncStateStore` in UserDefaults.

If the tombstone is lost (e.g. after a manual backup restore that does not include UserDefaults tombstone state), and the event reappears from a remote CloudKit record, the balance reversal that happened locally does not undo itself. The re-downloaded event would then re-apply its balance impact, resulting in a double-counted income or expense movement.

Transfer events are especially risky: they affect two account balances (source and destination). Double-posting a transfer affects two accounts simultaneously.

### 3.2 `deleteCreditCardPayment(_:)` — Critical

This path mutates the source account balance directly (`accounts[accountIndex].balance += payment.amount`) before removing the payment record. The account is resolved by `fromAccountName`, which is a string match.

Risks:
- If the source account has been renamed since the payment was recorded, the balance mutation either fails silently (returning `false`) or applies to a wrong account.
- If the payment reappears from a remote device, the payment amount would be deducted from the source account balance again without the reversal unwinding, resulting in a double balance deduction.
- The tombstone is written after the balance mutation, not before.

### 3.3 `deletePersonDebt(_:)` — Critical

This path cascades across all linked `PersonDebtEntry` records, reversing each entry's balance impact via `applyPersonDebtEntryImpact(entry, multiplier: -1)` before removing the parent and all children. High-risk tombstones are written for all entries and the parent.

Risks:
- If the parent debt reappears on another device, all child debt entries could be re-synced and their balance impacts re-applied.
- Debt entries reference their account by `accountName` (string). An account rename between when entries were created and when the debt is deleted could leave some entries without a valid account to reverse.
- The cascade is silent: no per-entry confirmation or rollback if one entry fails to reverse.

### 3.4 `deleteInstallmentPlanAndFutureEvents(_:)` — High

This path removes an installment plan and all of its unpaid generated events, writing tombstones for each. Paid installment events survive in the `financialEvents` array without a parent plan reference.

Risks:
- If the plan reappears from another device, the app may regenerate future installment events that now duplicate paid event records (since the paid events were never tombstoned).
- The generated events that were tombstoned have stable UUIDs, but if those IDs are not durable across restore cycles, regeneration could assign new IDs and create duplicates.

### 3.5 `deleteCreditCardPurchase(_:)` — High

The purchase is removed from the `creditCardPurchases` array and a high-risk tombstone is written. Unlike credit card payments, there is no direct account balance mutation on deletion, but card balance tracking is affected.

Risks:
- If the purchase reappears from another device, the card's tracked balance changes without a corresponding reversal.
- No `isDeleted` or `deletedAt` field exists on the purchase model.

### 3.6 `saveMonthlyBudget` removed-item path — High (for sync)

When a monthly budget is saved with fewer categories than before, the removed items are hard-deleted from the parent `items` array. High-risk tombstones are written for each removed item. Items are identified and preserved by normalized category name, not UUID alone.

Risks:
- If a category is renamed between budget saves, normalization may not match the original item, causing the old item to be tombstoned while a new one is created with a new UUID.
- ID reuse across devices is prevented only as long as tombstone records are durable and included in sync state.

### 3.7 `resetToSampleData()` — Catastrophic if reached during sync

This path wipes all arrays and replaces them with sample data, with no tombstones written for any records. If this were ever called while a CloudKit sync session was active, all local financial records would disappear without any deletion markers, and the remote CloudKit copy would be treated as the authoritative state on the next fetch cycle.

This path must remain blocked by UI-level confirmation and must never be reachable from any sync-triggered code path.

### 3.8 `clearLocallyDeletedFinancialEventIDs()`, `clearLocallyDeletedHighRiskRecordIDs()`, `clearLocallyDeletedInstallmentPlanIDs()` — High

These `WalletSyncStateStore` methods clear tombstone markers from UserDefaults before those markers have been confirmed delivered to CloudKit. They are synchronous and do not verify delivery. If called at the wrong point in a sync cycle, any undelivered tombstones are permanently lost, and the corresponding records will be treated as active on the next CloudKit fetch.

---

## 4. Safe Deletion Target Policy

### 4.1 Master Data
Covers: `Account`, `Category`, `WalletEvent`, `MerchantMemory`

Target policy: soft delete preferred.

These records are referenced throughout the app by name. Deleting them hard-removes the anchor that financial records, budget items, and planning data rely on. Soft delete (`isDeleted = true`, `deletedAt = now`) allows these records to remain decodable and prevents orphaned name references from causing interpretation errors. Hard delete should only be permitted for records that are provably unused, and even then a tombstone must be durable before any sync session.

### 4.2 Planning Data
Covers: `InstallmentPlan`, `WalletMonthlyBudget`, `WalletMonthlyBudgetItem`, recurring `FinancialEvent` series

Target policy: soft delete for parent records; tombstone for generated child events.

Planning records affect future event generation. Soft-deleting a plan rather than hard-removing it preserves the record and its generated-event relationship for audit purposes. Future unpaid events should be tombstoned individually as they are today, but the tombstones must be durable across backup restore cycles.

### 4.3 Actual Financial Data
Covers: `FinancialEvent`, `CreditCardPurchase`, `CreditCardPayment`, `PersonDebt`, `PersonDebtEntry`

Target policy: do not change yet. When ready, use hybrid: soft delete for in-place audit trail + high-risk tombstone for cross-device delete-wins.

These records have direct balance, debt, and payment posting effects. Any deletion must be preceded by a full reversal of posting effects (as is currently the case), but the record must persist in a soft-deleted state with `isDeleted = true` and `deletedAt` set so that the deletion can be communicated to remote devices and proved durable. Hard delete with only a UserDefaults tombstone is not safe for sync.

### 4.4 Derived Data
Covers: `HistoricalMonthlySummaryEntry`

Target policy: soft delete or tombstone acceptable; treat as importable summary data.

These records appear to be user-entered or imported monthly summaries, not computed dashboard values. They can be tombstoned safely today. A future soft-delete approach would allow audit of what summaries were removed.

### 4.5 Local-Only Workflow State
Covers: `BankSMSImportDraft` (UserDefaults), `RecurringScheduleOverride` draft state (in-editor), pause/resume SMS identities

Target policy: keep hard delete as-is. Never sync.

These are transient workflow artifacts. They should remain local-only and never be included in CloudKit sync or backup tombstone state.

### 4.6 Debug and Sync State
Covers: CloudKit change tokens, sync gate flags, `WalletSyncStateStore` tombstone dictionaries, debug category records

Target policy: keep local-only. Never include in normal manual backups. Never sync as user data.

Clear operations on tombstone stores (`clearLocallyDeletedFinancialEventIDs`, etc.) must only be called after confirmed delivery to CloudKit. Today these are called in places that may not guarantee delivery. That call ordering must be audited before any sync session is enabled.

---

## 5. Do Not Convert Yet

The following delete paths must not be modified until the prerequisites in sections 6 and 7 are satisfied.

| Path | Why Not Yet |
|---|---|
| `deleteFinancialEvent` | Balance reversal is tightly coupled to the hard delete. Converting to soft delete requires decoupling reversal from removal, adding posting/reversal idempotency tests, and proving that soft-deleted events are excluded from all balance calculations, dashboards, and forecasts. |
| `deleteCreditCardPayment` | Same balance mutation coupling. Additionally, the account name resolution is string-based; a rename between payment creation and deletion can already cause silent failures. Both issues must be resolved before soft delete. |
| `deletePersonDebt` | Cascades to multiple child entries and multiple account balance mutations. The cascade order, rollback behavior on partial failure, and name-based account resolution all need tests before any model change. |
| `deleteInstallmentPlanAndFutureEvents` | Generated event deduplication and plan ID stability across restore cycles must be proven by tests before the delete behavior changes. |
| `deleteCreditCardPurchase` | High-risk marker path is already in place. Hold until card balance safety rules are tested. |
| `saveMonthlyBudget` removed-item path | The ID preservation behavior by normalized category name is a local bridge that depends on category display names. Changing the delete behavior here before fixing the category name dependency would make the bridge less predictable. |
| `resetToSampleData` | Must not be changed. Must remain fully blocked from any sync code path. |
| `removeSeedDataBeforeInitialCloudAdoptionIfSafe` | Must not be changed. Intended only for the initial CloudKit adoption flow. No tombstones should be added until the adoption flow is fully designed. |
| All `WalletSyncStateStore` clear methods | Must not be called until tombstone delivery to CloudKit is confirmed. Call ordering must be audited as part of sync pipeline work, not deletion policy work. |

---

## 6. Suggested Implementation Order

### Phase 1: Tests Around Existing Delete Behavior (No Code Change)

Write tests that document and assert current delete behavior without modifying it. Each test should pass against the current codebase and serve as a regression baseline.

- Assert that `deleteFinancialEvent` reverses the correct account balance.
- Assert that `deleteCreditCardPayment` restores the source account balance.
- Assert that `deletePersonDebt` reverses all linked entry balance impacts.
- Assert that `deleteInstallmentPlanAndFutureEvents` removes only unpaid events and leaves paid events intact.
- Assert that `deleteCategoryIfUnused` writes a tombstone before removing the record.
- Assert that `deleteAccountIfUnused` writes a tombstone before removing the record.
- Assert that `deleteSubcategoryIfUnused` writes no tombstone (documenting the gap).
- Assert that `resetToSampleData` writes no tombstones.

### Phase 2: Validation and Reporting Layer (Additive Only)

Add read-only validation that detects impossible deletion states without changing delete behavior.

- Detect a live record and a tombstone for the same UUID in the same store.
- Detect a paid installment event with no parent installment plan and no tombstone for the plan.
- Detect a debt entry whose parent debt is missing from the store and has no tombstone.
- Detect a financial event referencing an account name that does not match any active or soft-deleted account.

These validators should produce diagnostic output only. They must not modify data.

### Phase 3: Convert Low-Risk Master Data Deletes to Soft Delete

Convert `deleteAccountIfUnused` and `deleteCategoryIfUnused` to set `isDeleted = true` and `deletedAt = Date()` before removing from the array.

Prerequisites:
- Phase 1 tests must exist and pass.
- Computed properties that filter active records (e.g. `activeAccounts`, `activeCategories`) must already exclude `isDeleted == true` records — which they do via the existing `isDeleted` filters at lines 165 and 169 of `WalletStore.swift`.
- Tombstone must still be written.
- The record must still be removed from the array (existing array-based storage does not yet support keeping soft-deleted records in the array).

### Phase 4: Convert Planning Data Deletes Carefully

Convert `deleteHistoricalMonthlySummary`, `deleteMerchantMemory`, and the monthly budget item removal path to soft-delete patterns.

Prerequisites:
- Phase 3 complete.
- Tests exist for each path.
- Soft-deleted items must be excluded from budget calculations, merchant memory suggestions, and summary views.

### Phase 5: Convert Actual Financial Records Only After Balance Safety Rules Exist

This phase covers `deleteFinancialEvent`, `deleteCreditCardPayment`, `deletePersonDebt`, and `deleteCreditCardPurchase`.

Prerequisites:
- Posting and reversal must be idempotent: applying or reversing the same event twice must produce the same result as doing it once.
- Soft-deleted financial events must be excluded from all balance calculations, dashboards, forecasts, and export output.
- All name-based account resolution in delete paths must be replaced with stable ID resolution or a validated name-to-ID lookup that fails explicitly on mismatch.
- End-to-end tests must prove that a delete followed by a restore produces the correct final balance.

### Phase 6: Future Sync Tombstone Integration

After Phases 1–5, tombstones and soft-delete state can be designed for CloudKit delivery.

- Define tombstone retention period (minimum: longer than the longest expected offline period for any device).
- Define delivery confirmation requirement before `clearLocallyDeleted*` methods are called.
- Define backup tombstone section format and schema version.
- Design restore conflict resolution: tombstone vs. active record, snapshot restore vs. merge.

CloudKit sync must remain disabled throughout all phases until Phase 6 is fully designed and tested.

---

## 7. Required Tests Before Any Delete Code Change

The following tests must exist and pass before any delete-related Swift code is modified. Tests are listed by the invariant they must protect.

### Financial Event Deletion
- Deleting a paid financial event reverses the source account balance by exactly the event amount.
- Deleting a transfer event reverses both the source and destination account balances.
- Deleting a financial event writes a tombstone with the correct UUID and timestamp before the record is removed from the array.
- A deleted financial event does not appear in dashboard totals, category spending calculations, or forecast projections.
- Restoring a backup that contains a financial event after that event was deleted locally does not double-count the balance impact.

### Credit Card Payment Deletion
- Deleting a credit card payment restores the source account balance by exactly the payment amount.
- Deleting a credit card payment when the source account name has changed since the payment was created fails explicitly and does not corrupt any balance.
- Deleting a credit card payment writes a high-risk tombstone before the payment is removed.
- A deleted payment does not appear in the card ledger or statement views.

### Debt Deletion
- Deleting a person debt reverses the balance impact of every linked debt entry.
- Deleting a person debt when one entry's account name has changed reverses only the entries whose accounts can be resolved.
- Deleting a person debt writes high-risk tombstones for the parent and all child entries before removal.
- After deleting a debt, none of its child entries remain in `personDebtEntries`.

### Category Deletion
- Deleting a category does not modify any existing financial event's category name.
- Deleting a category does not modify any historical monthly summary's category label.
- Deleting a category writes a tombstone before removal.
- Financial events referencing the deleted category's name still decode and display correctly after the category is removed.

### Subcategory Deletion
- Deleting a subcategory does not modify any existing financial event's subcategory name.
- After subcategory deletion, no tombstone is written (documenting the current gap).

### Budget Item Deletion
- Removing a budget item by saving a budget without it writes a high-risk tombstone with the item's original UUID.
- The same UUID is never reused for a new budget item in the same month.
- A budget item restored from backup after being removed locally does not create a duplicate entry.

### Installment Plan Deletion
- Deleting an installment plan removes only unpaid generated events and leaves paid events in place.
- Each removed unpaid event has a tombstone written before removal.
- After deleting a plan, no future installment events are regenerated on the next save cycle.
- Paid installment events that survived the plan deletion continue to display correctly in transaction history.

### Reset Paths
- `resetToSampleData` writes no tombstones for any removed record.
- `removeSeedDataBeforeInitialCloudAdoptionIfSafe` returns `false` if any non-seed record exists.
- `removeSeedDataBeforeInitialCloudAdoptionIfSafe` writes no tombstones when it succeeds.

### Restore and Backup
- A manual backup taken after deleting a financial event does not contain the deleted event.
- A manual backup taken after deleting a financial event does not contain UserDefaults tombstone data.
- Restoring a backup that predates a deletion does not restore the deleted record's balance impact.

---

## 8. Backup and Restore Impact

### Current State

Manual backups are whole-snapshot exports of the current in-memory arrays. They do not include UserDefaults tombstone state from `WalletSyncStateStore`. A backup taken after a deletion reflects the post-deletion state of all arrays, but carries no deletion history that would allow a future sync engine to communicate the deletion to other devices.

A restore overwrites all arrays with the backup's contents. If the backup predates a deletion, the restore brings the deleted record back. This is expected behavior for a manual user-selected restore, but it becomes unsafe if:
- A future sync session is active when the restore occurs.
- The restored record's balance has already been reversed locally, and re-importing the record re-applies the balance impact.
- CloudKit still holds the record and has already been told it is deleted.

### Future Guidance

- Manual backup must remain a snapshot-based restore flow. A restore should restore exactly the records visible in the backup.
- Future backup versions should include a clearly versioned schema field so the app can distinguish old backups (no tombstone section) from new backups (with optional tombstone section).
- If a future backup format includes tombstones, the import flow must present the tombstone section separately from the main record list and require explicit user confirmation before applying deletion history.
- If a newer backup contains both a tombstone for a UUID and an active record with the same UUID, the import validation must reject or flag the conflict before restore completes.
- Older backups without tombstones must restore cleanly with their record arrays as authoritative. Absence of a tombstone section must never be treated as a deletion instruction.
- Manual restore and live sync must use different conflict resolution rules. Manual restore uses the user's explicit intent (the selected backup is the target state). Live sync uses timestamp-based merge and delete-wins rules.

---

## 9. Sync Impact

This section is planning documentation only. No CloudKit behavior is changed.

### Tombstone Delivery and Durability

`WalletSyncStateStore` currently stores tombstones in UserDefaults under separate keys for financial events, installment plans, high-risk records, and generic records. These are local-only and are not included in CloudKit sync state or manual backups.

For future sync, tombstones must be delivered to CloudKit before the local `clearLocallyDeleted*` methods are called. If the app terminates or loses connectivity after writing a local tombstone but before delivering it, the tombstone must survive app restarts and be re-delivered on the next sync cycle. UserDefaults tombstone storage already survives app restarts, which provides this durability, but the clear methods must be made conditional on confirmed delivery.

### Delete-Wins Policy

For future CloudKit sync, a delete should win over a concurrent edit when the tombstone's timestamp (`deletedAt`) is later than the remote record's `updatedAt`. This requires:
- Every delete writes a timestamped tombstone.
- Every record update writes an `updatedAt` timestamp.
- The sync merge logic compares these timestamps before deciding whether to apply a remote record or suppress it with a local tombstone.

Currently, `deleteFinancialEvent`, `deleteCreditCardPayment`, `deletePersonDebt`, and `deleteCreditCardPurchase` all write timestamped tombstones (`markHighRiskRecordDeletedLocally` includes `deletedAt`). The generic `markSyncRecordDeletedLocally` does not write a timestamp, only an ID. This gap must be closed before delete-wins logic can be implemented for master data records.

### Resurrection Prevention

The highest risk in live sync is a deleted financial record reappearing from another device and re-applying its balance impact. Prevention requires:
- Tombstones must be checked before any remote record is applied locally.
- Applying a remote record must be idempotent: applying the same record twice must not double the balance impact.
- The sync pipeline must never apply a record whose UUID appears in the local tombstone store, regardless of the remote record's `updatedAt` timestamp.

Currently, the sync pipeline is fully disabled. These rules must be designed and tested before the pipeline is enabled for any record type.

### Subcategory Gap

Subcategories currently have no UUID, tombstone, or sync identity. They cannot participate in future CloudKit sync in their current form. Any sync implementation must treat subcategories as embedded string arrays within `Category` records, with the entire `Category` record as the unit of sync and conflict resolution for subcategory changes.

---

## 10. Delete Behavior Baseline Tests Added

### Tests Added

Three new tests were added as part of the Phase 1 baseline. They are in `HouseholdBudgetTests/WalletStoreFinancialInvariantTests.swift` and `HouseholdBudgetTests/WalletStoreTestabilityTests.swift`.

| Test | File | What It Asserts |
|---|---|---|
| `testDeletePersonDebtReversesLinkedEntryBalanceImpact` | `WalletStoreFinancialInvariantTests` | Lending 200 decreases cash; deleting the debt restores cash to original; parent and child entries are removed. |
| `testDeleteSubcategoryIfUnusedRemovesSubcategoryAndWritesNoTombstone` | `WalletStoreTestabilityTests` | The subcategory is removed from the category; other subcategories are unaffected; no parent-category tombstone is written; financial events are untouched. |
| `testResetToSampleDataWritesNoTombstonesForClearedRecords` | `WalletStoreTestabilityTests` | After `resetToSampleData`, cleared financial events and credit card payments are absent from the store; no financial event tombstone or high-risk tombstone is written for any cleared record. |

### Delete Paths Covered by Existing Tests (Before This Change)

The following paths were already covered before this task:

- `deleteFinancialEvent` — tombstone written, event removed, balance reversed, `updatedAt` advanced (`WalletStoreTestabilityTests`, `WalletStoreFinancialInvariantTests`)
- `deleteCreditCardPurchase` — high-risk tombstone written, purchase removed (`WalletStoreTestabilityTests`)
- `deleteCreditCardPayment` — high-risk tombstone written, payment removed, source account balance restored (`WalletStoreTestabilityTests`)
- `deletePersonDebt` — tombstones for parent and child entries written, arrays cleared (`WalletStoreTestabilityTests`)
- `saveMonthlyBudget` removed-item path — high-risk tombstone written per removed item, ID not reused (`WalletStoreTestabilityTests`)
- `deleteInstallmentPlanAndFutureEvents` — plan deletion marker written, plan removed (`WalletStoreTestabilityTests`)
- `deleteFinancialEvent` on recurring income series — future occurrences removed, cash unchanged (`WalletStoreFinancialInvariantTests`)

### Delete Paths Still Not Covered by Tests

| Path | Why Not Yet |
|---|---|
| `deleteCategoryIfUnused` | Requires additional setup: a used/unused guard must be satisfied (category may have no financial events, wallet events, installment plans, or summaries referencing it). The tombstone path is structurally identical to `deleteAccountIfUnused` and can be covered later. |
| `deleteAccountIfUnused` | Same as above — guard requires no existing transactions. Test setup is straightforward but was not a gap for the current phase. |
| `deletePersonDebt` with mismatched account name | Account resolution is string-based. Testing the silent-failure path (account renamed before delete) requires a specific setup; deferred to Phase 2 validation tests. |
| `deleteInstallmentPlanAndFutureEvents` leaving paid events intact | Requires first marking installment events as paid, then deleting the plan. The paid-event survival assertion is documented but not yet tested in isolation. |
| `removeSeedDataBeforeInitialCloudAdoptionIfSafe` | Requires the store to contain exactly the sample seed data; no writes tombstones. The behavior is documented and guarded; deferred to sync adoption design phase. |
| `clearLocallyDeleted*` methods in `WalletSyncStateStore` | These clear tombstone markers and are dangerous before CloudKit delivery is confirmed. Tests require the sync pipeline design to be settled first. |
| Restore/import bringing back a deleted record | Requires a backup encode/decode round-trip combined with a delete. Deferred to the backup integration test phase. |

### Why No Deletion Behavior Was Changed

All three new tests assert the existing behavior exactly as it is. No production Swift code was modified. The tests serve as regression baselines: if any future soft-delete or tombstone policy change inadvertently alters the behavior documented here, these tests will catch it before release.

### Remaining Risks

- `deletePersonDebt` when the source account has been renamed still silently fails to reverse the balance impact. The existing tombstones are still written, but balance state is incorrect. This must be addressed before any balance-affecting sync path is enabled.
- `resetToSampleData` writes no tombstones and leaves the sync tombstone store in whatever state it was in before the call. If the store ever had active tombstones from a prior sync session and `resetToSampleData` is called, those tombstones persist in UserDefaults without any matching live records. The call-ordering risk during sync is now documented with a test proving the no-tombstone gap.
- Subcategory deletion still has no identity, no tombstone, and no sync strategy. The new baseline test explicitly documents and asserts the current tombstone gap.

---

## 11. Recommendation

The smallest safe next implementation step is a focused test suite that documents the current hard-delete and tombstone behavior for each high-risk path without modifying any Swift code.

Specifically:
1. Write tests that assert `deleteFinancialEvent` reverses the exact account balance and writes a tombstone.
2. Write tests that assert `deleteCreditCardPayment` restores the source account balance and writes a tombstone.
3. Write tests that assert `deletePersonDebt` reverses all child entry balance impacts and tombstones all children.
4. Write a test that asserts `deleteSubcategoryIfUnused` writes no tombstone, explicitly documenting the gap.
5. Write a test that asserts `resetToSampleData` writes no tombstones.

These tests will provide a regression baseline that proves the app's current deletion behavior is safe and predictable before any policy changes are made. They are the entry gate for every subsequent phase in this plan.

No Swift production code should change as part of this step. No CloudKit behavior should change. No migration should run. No backup format should change.
