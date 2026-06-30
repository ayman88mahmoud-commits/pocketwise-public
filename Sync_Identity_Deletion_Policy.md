# Sync Identity and Deletion Policy

## 1. Executive Summary

True iCloud record sync must not be implemented until the app has a settled identity and deletion policy. The current app is safe as a manual iCloud backup system because backup and restore operate on a whole snapshot selected by the user. Live multi-device sync is different: it merges independently edited records, must preserve identity forever, and must prevent deleted financial records from silently reappearing.

The app already has a strong foundation for many top-level records: most persistent user-data models have stable UUIDs, timestamps, and soft-delete fields. However, many relationships still depend on display names, subcategories are string-only, several delete paths hard-remove records from arrays, and sync tombstones are stored separately in `WalletSyncStateStore`. Those choices are workable locally, but they need explicit policy before metadata expansion, CloudKit schema work, or true sync.

CloudKit automatic record sync must remain disabled. Manual iCloud backup remains the active safe workflow.

## 2. Current Identity State

| Data group | Current identity strategy | Current state and sync implication |
| --- | --- | --- |
| Accounts | Stable UUID | `Account.id` is stable and should be kept forever. Relationships often still use `Account.name`, so account renames can break or mismerge records during future sync. |
| Categories | Stable UUID plus name-based references | `Category.id` is stable, but financial events, wallet events, merchant memories, budget items, summaries, purchases, and installment plans reference category names. Names are currently both display labels and relationship keys. |
| Subcategories | Name-based, nested, missing independent ID | Subcategories are `[String]` inside `Category`. There is no subcategory UUID, tombstone, createdAt, updatedAt, or independent deletion history. This is one of the largest identity gaps before sync. |
| Wallet events | Stable UUID with name-based dependencies | `WalletEvent.id` is stable. It references category, subcategory, and default account by names. Financial events can reference wallet event names. |
| Merchant memories | Stable UUID with name-based dependencies | `MerchantMemory.id` is stable. Defaults reference category, subcategory, and account by name. Merchant aliases are local matching data, not stable record identities. |
| Monthly budgets | Stable UUID plus composite logical month | `WalletMonthlyBudget.id` is stable and parent identity is preserved. The logical uniqueness is also year/month. Future sync needs a clear rule for duplicate budgets for the same month. |
| Monthly budget items | Stable UUID, nested under monthly budget | `WalletMonthlyBudgetItem.id` is stable and recent save logic preserves it by normalized category name. This matching strategy is temporary because it still depends on category display names. |
| Financial events | Stable UUID with many name-based references | `FinancialEvent.id` is stable. It references accounts, payment methods, wallet events, categories, and subcategories mainly by names. Some generated relationships use IDs, such as `sourceInstallmentPlanID` and `sourceRecurringEventID`. This is high risk for live sync. |
| Recurring schedule overrides | Stable UUID, nested | `RecurringScheduleOverride.id` is stable and nested in a financial event. It has createdAt and updatedAt, but no soft-delete field or independent mapper. |
| Installment plans | Stable UUID with mixed references | `InstallmentPlan.id` is stable. It references account, category, subcategory, and payment method by names, and can reference a credit card by stable `linkedCreditCardID`. |
| Debts | Stable UUID | `PersonDebt.id` is stable. The parent record has timestamps and soft-delete fields, but delete behavior currently hard-removes and writes a high-risk sync tombstone. |
| Debt entries | Stable UUID plus parent UUID | `PersonDebtEntry.id` is stable and `debtID` references the parent by UUID. The account relationship is name-based. |
| Credit cards | Stable UUID with name-based payment source | `CreditCard.id` is stable. Bank name and default payment account are strings. Card purchase and payment children reference the card by UUID. |
| Credit card purchases | Stable UUID plus parent card UUID | `CreditCardPurchase.id` is stable and `cardID` is a stable parent reference. Category and subcategory remain name-based. |
| Credit card payments | Stable UUID plus parent card UUID | `CreditCardPayment.id` is stable and `cardID` is a stable parent reference. `fromAccountName` is name-based and balance-impacting. |
| Historical monthly summaries | Stable UUID with name-based category labels | `HistoricalMonthlySummaryEntry.id` is stable. Category and subcategory references are strings. These records look user-entered/imported summary data, not derived dashboard totals. |
| Settings | Local-only scalar keys in UserDefaults and backup snapshot | Settings such as display name, app language, hidden balances, income mode, forecast horizon, and fee preferences are not modeled as independently syncable records. Some may be candidates for optional later sync; debug and sync gates must remain local-only. |
| Backup metadata | Backup container metadata, missing record identity by design | `WalletBackupMetadata` describes a manual backup snapshot. It should not be treated as a live syncable user record. |
| Sync tokens and tombstones | Local-only sync state and deletion marker scaffolding | `WalletSyncStateStore` stores CloudKit change token data and local deletion/tombstone dictionaries. These are sync scaffolding, not normal user data, and should not be part of ordinary manual backup until a specific restore/import policy exists. |

## 3. Relationship Risk Map

| Relationship | Current reference | Risk | Reason |
| --- | --- | --- | --- |
| Financial events to source account | `FinancialEvent.accountName` | High | Renaming an account on one device while another edits events can orphan or misapply balance-impacting records. |
| Financial transfers to destination account | `FinancialEvent.destinationAccountName` | High | Transfer integrity depends on both accounts resolving correctly. Name conflicts can corrupt transfer interpretation. |
| Financial events to categories | `FinancialEvent.categoryName` | High | Category rename or deletion can cause spending to classify differently across devices. |
| Financial events to subcategories | `FinancialEvent.subCategoryName` | High | Subcategories have no stable identity, so rename/delete conflicts are name-only. |
| Financial events to payment method | `FinancialEvent.paymentMethodName` | Medium | Payment method appears as a string, so there is no stable payment source identity to merge against. |
| Financial events to wallet events | `FinancialEvent.walletEventName` | Medium | Wallet event names can change independently from transaction records. |
| Wallet events to category/subcategory/account | Name fields | Medium | Templates can point at renamed or deleted display names. |
| Merchant memories to category/subcategory/account | Name fields | Medium | Suggestions can reapply stale categories or accounts after rename conflicts. |
| Monthly budget items to categories | `WalletMonthlyBudgetItem.categoryName` | Medium | Recent ID preservation matches by normalized category name. This is safe locally but fragile across renamed categories. |
| Installment plans to account/category/subcategory/payment method | Name fields | High | Generated future events and financial planning depend on these relationships. |
| Installment events to installment plan | `sourceInstallmentPlanID` | Low | This is already a stable UUID parent reference. |
| Debt entries to debts | `PersonDebtEntry.debtID` | Low | Parent relationship is stable UUID-based. |
| Debt entries to accounts | `PersonDebtEntry.accountName` | High | Debt entry application can affect balances; account renames are risky. |
| Credit card purchases to cards | `CreditCardPurchase.cardID` | Low | Parent card relationship is stable UUID-based. |
| Credit card purchases to categories/subcategories | Name fields | Medium | Classification can diverge on category rename. |
| Credit card payments to cards | `CreditCardPayment.cardID` | Low | Parent card relationship is stable UUID-based. |
| Credit card payments to source account | `CreditCardPayment.fromAccountName` | High | Payment deletion and creation affect account balances; account name conflicts are unsafe. |
| Credit card default payment account | `CreditCard.defaultPaymentAccountName` | Medium | Default account can point at a stale name after rename or delete. |
| Historical summaries to categories/subcategories | Name fields | Medium | Summary classification can drift if display names change. |
| Settings to app behavior | UserDefaults keys | Low | Most settings are local preference data. Syncing them is optional and should not precede core data identity work. |

## 4. Recommended Identity Policy

- Every syncable record must keep its existing UUID forever.
- Never regenerate IDs for existing records, even when names, amounts, months, or parent records change.
- Records should eventually reference other records by stable IDs where practical.
- Names should remain display labels, not the source of truth for relationships.
- During a compatibility period, new fields may store both a stable ID and the legacy name so old backups remain decodable and user-visible labels remain understandable.
- Do not convert every relationship at once. Start with master data and the highest-risk relationship paths.
- Do not blindly migrate historical records. Historical financial records may need legacy labels preserved exactly as the user saw them.
- Monthly budget items currently match by normalized category name when preserving item identity. This is a temporary local safety bridge, not a final sync identity policy.
- Subcategories need a deliberate identity design before sync. A safe future design likely needs subcategory IDs, category parent IDs, tombstone handling, and compatibility with existing string arrays.

## 5. Deletion Policy Options

### A. Model-level soft delete only

Benefits:
- Easy to reason about in Codable models and manual backups.
- Deleted records can carry `isDeleted`, `deletedAt`, and timestamps with the record itself.
- Restore/import can show or validate deleted records using the same model schema.

Risks:
- Existing delete paths often hard-remove records from arrays, so converting all deletes at once would change behavior.
- Soft-deleted financial records must never be included in totals, dashboards, balances, or generated payment logic.
- Backups could contain deleted records unless the UI and validation clearly define what that means.

Backup/export/import impact:
- Newer backups become more complete because deletion history travels with the record.
- Older backups without soft-delete metadata must decode safely with defaults.

Restore/import behavior:
- Restore can preserve deletion state if the backup includes it.
- Import needs rules for whether deleted records suppress existing live records.

Sync conflict behavior:
- Delete-wins is easier when `deletedAt` is part of the record.
- Requires retention policy so tombstones are not purged too early.

Developer complexity:
- Moderate. The model shape is understandable, but every query and calculation must exclude deleted records correctly.

### B. Sync tombstone store only

Benefits:
- Fits existing hard-delete behavior because records can be removed from arrays while deletion markers remain in `WalletSyncStateStore`.
- Avoids keeping deleted financial records in user-facing arrays.
- Existing sync scaffolding already has deletion marker concepts for financial events, installment plans, high-risk records, and generic record tombstones.

Risks:
- Tombstones are separate from manual backup data today, so restore/import can lose deletion history.
- A missing tombstone can resurrect a deleted record from another device.
- Users cannot understand or review deletion history from normal backup contents.

Backup/export/import impact:
- Current manual backups stay simple, but future sync-aware backups would need an explicit tombstone section if tombstones matter after restore.

Restore/import behavior:
- Older backups cannot express deletion history beyond absence of records.
- Newer backups would need clear precedence rules if tombstones are added.

Sync conflict behavior:
- Works for hard-deleted records if tombstones are durable and replicated.
- Conflict resolution must compare tombstone timestamps against remote record updates.

Developer complexity:
- Moderate to high. The system must keep sidecar tombstone state consistent with model arrays, backups, and CloudKit records.

### C. Hybrid model soft delete plus sync tombstone store

Benefits:
- Best fit for the current app because many models already have `isDeleted` and `deletedAt`, while active delete paths often hard-remove records and record tombstones.
- High-risk financial records can avoid resurrection even when hard-deleted locally.
- Future model-level soft delete can be introduced gradually for selected records without breaking existing manual backup behavior.

Risks:
- Two deletion sources require strict precedence rules.
- Tombstone retention and backup inclusion must be designed before live sync.
- Developers must avoid treating soft-deleted records and tombstones as independent conflicting truths.

Backup/export/import impact:
- Current manual backups can remain unchanged.
- Future sync-aware backups can add a clearly named tombstone section only after restore/import policy is tested.

Restore/import behavior:
- Restore can remain snapshot-based for user clarity.
- Live sync can use tombstones for delete-wins behavior.

Sync conflict behavior:
- Supports delete-wins for hard-deleted records and model-level deleted records.
- Requires deterministic conflict policy using `updatedAt` and `deletedAt`.

Developer complexity:
- Highest, but safest for this app because it aligns with current code and financial safety constraints.

## 6. Recommended Deletion Policy

Use a hybrid policy for future syncable records:

- Keep model-level soft-delete fields where they already exist.
- Use model-level soft delete for records that can safely remain in local storage without affecting calculations or visible lists.
- Keep sync tombstones for hard-delete paths and high-risk financial records that should not remain in active arrays.
- Treat deletion markers as delete-wins sync records once true sync exists.
- Never allow a remote active record to resurrect a locally deleted financial record unless a future explicit restore/import flow chooses that outcome.
- Do not include sync tokens or tombstones in normal manual backups until the app has a tested restore/import policy for them.

This is the safest policy because financial records must not silently reappear after deletion, deleted records must not be resurrected from another device, manual backup must remain understandable, hard delete paths already exist, `WalletSyncStateStore` already has tombstone concepts, and many models already have `isDeleted`/`deletedAt` fields.

## 7. Hard Delete Audit

| Function | Model affected | Removes from array | Sets `isDeleted` / `deletedAt` | Writes tombstone | Risk before sync | Recommended future action |
| --- | --- | --- | --- | --- | --- | --- |
| `deleteAccountIfUnused(_:)` | `Account` | Yes | No | Generic record tombstone via `markSyncRecordDeletedLocally` | Medium | Keep unused guard. Before sync, define whether account deletion is soft-delete or hard-delete plus durable tombstone. |
| `deleteCategoryIfUnused(_:)` | `Category` | Yes | No | Generic record tombstone via `markSyncRecordDeletedLocally` | Medium | Keep unused guard. Add category deletion tests before sync and define interaction with name-based historical labels. |
| `deleteSubcategoryIfUnused(_:in:)` | Nested subcategory string | Yes, from category string arrays | No | No | High | Do not sync subcategories until they have an identity and deletion policy. |
| `saveMonthlyBudget(year:month:plannedAmountsByCategory:)` removed item path | `WalletMonthlyBudgetItem` | Yes, omitted items are removed from parent items array | No | High-risk monthly budget item tombstone | Medium | Keep current ID preservation. Before sync, define whether removed budget items are soft-deleted or tombstoned globally. |
| `deleteHistoricalMonthlySummary(_:)` | `HistoricalMonthlySummaryEntry` | Yes | No | Generic record tombstone via `markSyncRecordDeletedLocally` | Medium | Decide whether historical summaries should be syncable or treated as imported/manual summary data with delete tombstones. |
| `deleteCreditCardPurchase(_:)` | `CreditCardPurchase` | Yes | No | High-risk deletion marker | High | Keep hard-delete behavior unchanged for now. Before sync, require delete-wins tests and card statement safety tests. |
| `deleteCreditCardPayment(_:)` | `CreditCardPayment` and source account balance | Yes | No | High-risk deletion marker | High | Do not live-sync until payment operations are idempotent and balance mutation is isolated from sync validation. |
| `deletePersonDebt(_:)` | `PersonDebt` and linked `PersonDebtEntry` records | Yes | No | High-risk deletion markers for parent and entries | High | Define parent/child delete cascade policy and tombstone retention before sync. |
| `deleteFinancialEvent(_:)` | `FinancialEvent` and account impact | Yes | No | Financial event deletion marker | High | Do not sync financial events until posting/reversal is idempotent and remote deletes cannot double-apply balance changes. |
| `deleteMerchantMemory(_:)` | `MerchantMemory` | Yes | No | Generic record tombstone via `markSyncRecordDeletedLocally` | Low | Safe candidate after master-data identity tests, but still needs tombstone backup policy. |
| `deleteInstallmentPlanAndFutureEvents(_:)` | `InstallmentPlan` and unpaid generated `FinancialEvent` records | Yes | No | Installment plan deletion marker plus financial event deletion markers | High | Require generated-event identity policy and no-duplicate-posting rules before planning or actual sync. |
| `clearAllData()` / test reset paths | All local arrays and local sync state | Yes | Not applicable | Clears local state | High if used as sync behavior | Keep local-only. Never treat full local reset as a CloudKit delete cascade without an explicit user-confirmed sync policy. |

## 8. Restore and Import Policy

Manual restore/import should remain different from live sync. A manual backup is a user-selected snapshot; live sync is an ongoing merge of records from multiple devices.

Future guidance:

- Older backups without tombstones should restore as authoritative snapshots of the records they contain.
- Absence of a record in an older manual backup should not be interpreted as a durable cross-device delete unless the user is performing an explicit full restore.
- Newer backups with tombstones, if added later, must include a schema version and validation so the app can explain what deletion history is being restored.
- If a newer backup contains both a deleted marker and an active record for the same ID, validation should flag it before restore/import.
- In live sync, a newer deletion marker should normally win over an older active record.
- In manual restore, user intent matters: restoring a backup may intentionally bring the app back to the backup's visible state.
- Restore/import should not silently merge CloudKit tombstones into manual backups until there is a dedicated review flow and tests.
- Pending import drafts, debug sync state, CloudKit gates, and change tokens should remain local-only unless a future policy says otherwise.

## 9. Source Device Metadata Policy

Future syncable records may eventually need additive optional metadata:

- `createdByDeviceID`
- `lastModifiedByDeviceID`
- `importedFromBackupID`
- `sourceAppVersion`
- `sourceSchemaVersion`

These fields should be optional, backward-compatible, and decoded with safe defaults for older backups. They should not be added until identity and deletion rules are settled, because source metadata helps diagnose conflicts but does not solve name-based relationships or deletion resurrection by itself.

Local-only state should remain local-only:

- Debug flags
- CloudKit gates and feature flags
- Sync tokens
- CloudKit zone state
- UI state that is device preference rather than household data
- Pending import drafts
- Developer-only diagnostics

## 10. Phase Plan

Phase 0: Keep CloudKit sync disabled.

Phase 1: Continue documentation and tests for identity, deletion, validation, and restore/import behavior.

Phase 2: Fix identity preservation gaps that do not change user behavior, following the monthly budget item ID preservation pattern.

Phase 3: Implement deletion policy foundations with tests before any record sync. This includes tombstone precedence, retention, and backup/restore rules.

Phase 4: Add additive optional metadata only where needed and only with backward-compatible decoding.

Phase 5: Build master-data dry-run mapper tests that prove no financial records, balances, or postings are touched.

Phase 6: Implement master-data CloudKit behavior behind disabled gates only. Do not enable production sync.

Phase 7: Prepare planning data after master-data identities and deletion behavior are stable.

Phase 8: Consider actual financial data only after balance safety, idempotent posting, conflict policy, and duplicate prevention are proven.

## 11. Do Not Do Yet

- No true sync.
- No transaction sync.
- No balance sync.
- No CloudKit schema changes.
- No source-device metadata implementation yet.
- No category ID migration yet.
- No subcategory migration yet.
- No destructive migration.
- No automatic conflict resolver.
- No auto-fixing existing user records.
- No CloudKit zone creation.
- No record upload or download.
- No sync pipeline runs.

## 12. Recommendations

Do not implement source-device metadata next. It would improve diagnostics, but it would not solve the current relationship and deletion risks.

Do not migrate category relationships next. Category and subcategory migration should wait until a compatibility strategy exists for legacy names, historical labels, and subcategory identity.

Implement deletion policy foundations before any CloudKit implementation, but start with validation and tests rather than model mutation. The smallest safe next implementation step is a focused deletion-invariant test suite that documents current hard-delete and tombstone behavior for each high-risk path, without changing app behavior.

After that, the next safest production-code step would be a small, additive validation layer that detects impossible deletion states, such as an active record and a tombstone for the same ID in the same validation input. CloudKit sync should remain disabled throughout this work.
