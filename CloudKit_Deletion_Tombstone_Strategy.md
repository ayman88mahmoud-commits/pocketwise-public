# CloudKit Deletion and Tombstone Strategy

Date: 2026-07-01
Branch: householdbudget-main
Phase: CloudKit Sync Preflight — Deletion & Tombstone Design
Status: Documentation only. Automatic CloudKit sync remains disabled and must stay disabled.

---

## 1. Executive Summary

Deletion propagation is the highest-severity failure class for future CloudKit record sync. A record removed on one device but still present on another will be re-downloaded and **silently resurrected** on the next sync cycle unless a durable, propagating deletion model exists. Because the app's delete paths reverse balance impacts before removing records, a resurrected financial record does not merely reappear — it **double-applies** money movements (income, expenses, debt postings, card payments). This must be settled before any sync gate is opened.

This document defines the deletion/tombstone model: the current reality, a per-model tombstone inventory, the highest-risk resurrection cases, propagation and tombstone-record policy, the on-record-vs-`WalletSyncStateStore` source-of-truth analysis, cascade rules, backup/restore interaction, delete-vs-update conflict outcomes, required dry-run checks, and migration/cutover considerations. It builds on `Sync_Identity_Deletion_Policy.md`, `Hard_Delete_Safety_Implementation_Plan.md`, and `CloudKit_Conflict_Resolution_Strategy.md`.

This is **documentation only**. It changes no code, flips no flags, and does **not** enable CloudKit sync. Manual iCloud full-snapshot backup remains the active safe cloud path.

---

## 2. Current Git State

| Property | Value |
|---|---|
| Branch | `householdbudget-main` |
| Remote tracking | `origin/householdbudget-main` |
| Latest commit | `e99805e` Document CloudKit conflict resolution strategy |
| Working tree | Clean — no uncommitted changes |
| Sync status | In sync — local matches `origin/householdbudget-main` |

*(This document's own commit advances the latest commit beyond `e99805e`; the state above reflects the branch immediately before it was committed.)*

---

## 3. Current Deletion Reality

- **Delete paths hard-remove records.** `deleteFinancialEvent`, `deleteCreditCardPurchase`, `deleteCreditCardPayment`, `deletePersonDebt` (cascading to entries), `deleteInstallmentPlanAndFutureEvents`, `deleteAccountIfUnused`, `deleteCategoryIfUnused`, `deleteSubcategoryIfUnused`, `deleteHistoricalMonthlySummary`, and `deleteMerchantMemory` all remove the record directly from the in-memory array. None set `isDeleted`/`deletedAt` on the record before removing it.
- **Several delete paths reverse financial effects first.** `deleteFinancialEvent` calls `reverseAccountImpactIfNeeded` (and reverses transfer destination impact); `deleteCreditCardPayment` adds `payment.amount` back to the source account; `deletePersonDebt` reverses every linked entry's balance impact. The reversal happens **before** removal, so a later resurrection re-posts the impact without re-reversing.
- **Every persisted model has `isDeleted`/`deletedAt` fields**, and the `active*` accessors filter `!$0.isDeleted`. The soft-delete *read* layer exists, but the *write* (delete) layer bypasses it by hard-removing.
- **Deleted records do NOT remain in `WalletDataSnapshot`.** Because deletes hard-remove, the snapshot contains only live records. The snapshot has **no tombstone/deletion field** — its CodingKeys are the live arrays plus settings and backup metadata.
- **`WalletSyncStateStore` stores separate deletion markers** in UserDefaults, keyed by the sync zone name, in four buckets: `locallyDeletedFinancialEventIDs`, `locallyDeletedInstallmentPlanIDs`, `locallyDeletedHighRiskRecordIDs` (per entity), and a generic `locallyDeletedRecordIDs`. Financial-event and installment-plan markers store `id → deletedAt` maps and have DTO mappers for future sync.
- **Backup/restore preserves only live arrays, not tombstones.** Manual backups serialize `WalletDataSnapshot`, which excludes both the hard-removed records and the `WalletSyncStateStore` markers. Restoring an older backup therefore **loses deletion history** — the exact resurrection vector called out in `Hard_Delete_Safety_Implementation_Plan.md`.

---

## 4. Model Tombstone Inventory

Fields confirmed from `WalletModels.swift`. "Currently deleted via" reflects the live delete path behavior.

| Model | id | updatedAt | isDeleted | deletedAt | Currently Deleted Via | Financial Impact if Resurrected | Tombstone Required Before Sync |
|---|---|---|---|---|---|---|---|
| `FinancialEvent` | Yes | Yes | Yes | Yes | Hard-remove (reverses balance) | **High** — re-posts income/expense/transfer | **Yes (critical)** |
| `Account` | Yes | Yes | Yes | Yes | Hard-remove if unused | Medium — balances derive from postings; resurrect could re-enable stale references | Yes |
| `Category` | Yes | Yes | Yes | Yes | Hard-remove if unused | Low-medium — reclassification drift | Yes |
| Subcategory (`[String]` in `Category`) | **No** | No | No | No | Hard-remove string from array | Low-medium (classification) | **Yes — no identity/tombstone exists (largest gap)** |
| `CreditCard` | Yes | Yes | Yes | Yes | Hard-remove | Medium — orphans purchases/payments | Yes |
| `CreditCardPurchase` | Yes | Yes | Yes | Yes | Hard-remove (high-risk marker) | **High** — statement balance | **Yes** |
| `CreditCardPayment` | Yes | Yes | Yes | Yes | Hard-remove (restores account balance) | **High** — account balance double-apply | **Yes (critical)** |
| `InstallmentPlan` | Yes | Yes | Yes | Yes | Hard-remove + remove unpaid events | High — duplicate regeneration of events | **Yes** |
| `PersonDebt` | Yes | Yes | Yes | Yes | Hard-remove, cascade to entries | **High** — re-posts all entry impacts | **Yes (critical)** |
| `PersonDebtEntry` | Yes (+`debtID`) | Yes | Yes | Yes | Hard-remove (high-risk marker) | **High** — balance impact | **Yes** |
| `WalletMonthlyBudget` | Yes | Yes | Yes | Yes | Soft fields exist; item edits hard-remove | Low — planning only | Yes (lower priority) |
| `WalletMonthlyBudgetItem` | Yes | Yes | Yes | Yes | Hard-remove on plan save (high-risk marker) | Low — planning only | Yes (lower priority) |
| `WalletEvent` (quick event) | Yes | Yes | Yes | Yes | Hard-remove | Low — template only | Yes (lower priority) |

---

## 5. Highest-Risk Resurrection Cases

- **Deleted paid `FinancialEvent` resurrected.** The deletion already reversed the account balance; resurrection re-posts income/expense (and transfer destination) impact with no compensating reversal — silent double-count. Highest-severity.
- **Deleted `CreditCardPayment` resurrected.** Deletion added the amount back to the source account; resurrection re-subtracts it — account balance double-apply, and `fromAccountName` is name-based so a rename can misroute the correction.
- **Deleted `CreditCardPurchase` resurrected.** Re-inflates the card statement balance; classification (name-based category) may also drift.
- **Deleted `PersonDebt` / `PersonDebtEntry` resurrected.** `deletePersonDebt` cascades and reverses every linked entry; resurrection re-posts the entire debt's balance impact across all entries.
- **Deleted `InstallmentPlan` resurrected or future events recreated.** Paid installment events survive with no parent; if the plan reappears, unpaid future events can be regenerated and duplicated (de-dup key divergence).
- **Deleted account/category/card resurrected while references still exist.** A resurrected parent re-validates stale name-based references and can silently reactivate relationships the user intended to remove.

---

## 6. Deletion Propagation Policy

- **Delete must converge across devices.** A deletion is a durable, propagating event, not a local absence. Every participating device must eventually reflect it.
- **Tombstone wins over a stale update — unless the update is balance-affecting.** For non-financial fields, the tombstone supersedes an older edit. For balance-affecting divergence (a device edited amount/account while another deleted), route to **manual review** rather than silently honoring either side.
- **Resurrecting balance-affecting records must be blocked or manually reviewed.** A record whose deletion reversed money movement may not be silently re-created by sync.
- **Paid/settled children must not be auto-deleted silently.** Paid recurring occurrences, paid installment events, and posted debt entries are preserved.
- **Parent delete with existing children → warning / manual review** unless explicitly confirmed. A parent may only be deleted cleanly when it is unused (matching current `...IfUnused` guards); otherwise surface the conflict.

---

## 7. Tombstone Record Policy

A tombstone should carry the minimum needed to converge deletion and support user review:

- **`id`** — the stable UUID of the deleted record (primary key for convergence).
- **`modelType` / entity** — which model the tombstone applies to (already modeled as `WalletSyncRecordEntity`).
- **`deletedAt`** — authoritative deletion timestamp (already stored; markers keep `max(existing, new)`).
- **`previousUpdatedAt`** (optional) — the record's last-known `updatedAt` at deletion, to adjudicate delete-vs-update ordering.
- **`deletionSource` / device** (optional, later) — which device issued the delete, for explainable UX and deterministic tie-breaking.
- **Minimal display name** (optional) — a human-readable label (e.g. transaction title, person name) so the manual-review UI can describe what was deleted without rehydrating the full record.
- **Retention (concept):** retain a tombstone at least until all participating devices have acknowledged it. A fixed short TTL risks resurrection from a device that syncs late; indefinite retention is the safe default until a compaction policy is designed.
- **Compaction (concept):** once convergence is provable (all devices past the tombstone's change token / acknowledgment), tombstones may be compacted. Compaction must never run during an active sync where a device could still hold a pre-deletion copy.

---

## 8. On-Record Tombstones vs `WalletSyncStateStore` Markers

**On-record `isDeleted`/`deletedAt` preserved in `WalletDataSnapshot`:**
- *Pros:* the tombstone travels with the record through backup/restore and (future) cloud records; the `active*` filter already hides them; no separate index can drift out of sync; restoring a backup carries deletion history.
- *Cons:* soft-deleted records remain in the arrays (larger snapshots); requires the delete paths to switch from hard-remove to soft-delete; needs a compaction story so arrays don't grow unbounded.

**Separate `WalletSyncStateStore` markers (current):**
- *Pros:* keeps live arrays lean; already implemented with `deletedAt` maps and DTO mappers for sync; isolates sync scaffolding from user-data models.
- *Cons:* markers live in UserDefaults and are **not** included in `WalletDataSnapshot`, so backups/restores lose them; two sources of truth (the removed record vs the marker) can diverge; a restore of an old backup silently resurrects records the markers "knew" were deleted.

**Why sync likely needs deletion data that travels with backup/snapshot/cloud records:** the resurrection vector is precisely that deletion history does not travel with the data. Any durable sync model needs tombstones co-located with the records they retire so that backup, restore, and cloud fetch all agree.

**Recommended source of truth:** converge on **on-record soft-delete** (`isDeleted`/`deletedAt`) as the durable, backup-carried tombstone, with `WalletSyncStateStore` markers retained as a **secondary index / bridge** for the existing scaffolding and change-token bookkeeping. This is a documented recommendation only — no code change is made here.

---

## 9. Parent/Child Cascade Rules

| Parent → Child | Recommended Policy on Parent Delete |
|---|---|
| Recurring `FinancialEvent` (series) → paid occurrences | **Retain children.** Never auto-delete paid occurrences; surface orphaned-series `.warning` (already implemented). |
| `InstallmentPlan` → generated/paid events | **Retain paid events; block/manual-review unpaid future events.** Paid events survive; unpaid regeneration must pass a de-dup guard. |
| `PersonDebt` → `PersonDebtEntry` | **Cascade as tombstones, not hard-remove.** Each entry must get a durable tombstone; reversal of impacts must be idempotent so resurrection cannot double-post. |
| `CreditCard` → purchases/payments | **Block/manual-review while children exist.** Reconcile `cardID` children first; card deletion must not orphan balance-affecting payments. |
| `Account` / `Category` / `CreditCard` referenced by transactions | **Block/report (only delete when unused).** Matches current `...IfUnused` guards; surface a conflict if remote postings still reference it. |

---

## 10. Manual Backup / Restore Interaction

- **Tombstones should be included in backups.** For deletion history to survive a restore, the backup must carry tombstone information (on-record soft-delete is the recommended vehicle). Today it does not, which is a documented gap.
- **Restore must not reintroduce deleted records as live records.** A restored record that is tombstoned (locally or in the restored data) must remain deleted; restore must reconcile against known tombstones rather than blindly rehydrating arrays.
- **Avoiding resurrection on restore:** restore should treat a record present in the backup but tombstoned in current/known deletion history as deleted, not live — never silently un-delete.
- **Backup import while sync is enabled (future):** pause sync, require a fresh backup first, produce a merge preview (dry-run), and upload a replacement only after explicit confirmation.
- **Why import and live sync must be mutually exclusive or gated by a merge preview:** a full-snapshot import concurrent with record sync can clobber cloud state or resurrect tombstoned records; the two operations cannot run interleaved without a preview and confirmation.

---

## 11. Conflict Rules for Delete vs Update

| Scenario | Recommended Outcome |
|---|---|
| **Local delete vs remote update** | Tombstone wins for non-financial fields; **balance-affecting update → manual review** (do not silently resurrect). |
| **Local update vs remote delete** | Symmetric; remote tombstone wins for non-financial fields; balance-affecting local update → manual review. |
| **Delete vs delete** | Converge to deleted; keep the earliest `deletedAt`; no conflict. |
| **Delete parent vs update child** | Preserve the child if it is paid/settled; surface orphaned-reference warning; do not delete the child implicitly. |
| **Delete child vs update parent** | Honor the child tombstone; the parent update proceeds; report if the parent still expects the child. |
| **Stale device reintroducing a deleted record** | **Blocked** for balance-affecting records; the record stays deleted and the stale write is rejected/queued for review. This is the primary resurrection guard. |

---

## 12. Required Validation / Dry-Run Checks

Before any deletion is allowed to sync, the existing dry-run scaffolding (`WalletSyncDryRunUploadPlanner`, `WalletSyncMergePlanDryRun`, `WalletSyncDryRunLoopController`) should produce a read-only plan that:
- **Counts incoming deletes** (tombstones arriving from cloud) and their affected models.
- **Counts outgoing deletes** (local tombstones to propagate).
- **Detects balance-affecting resurrected records** — any create that matches a known tombstone id.
- **Detects parent-deleted-while-child-exists** — dangling references after a parent tombstone.
- **Detects stale updates to deleted records** — an update whose id is tombstoned.
- **Produces warnings before any mutation** — using the established severity model, with **no** writes and **no** upload/apply.

---

## 13. Migration Considerations

- **Current local data lacks retained tombstones for historically deleted records.** Past hard-deletes wrote UserDefaults markers (for some models) but no on-record tombstone, and manual backups carry neither.
- **First sync cannot know old deletions unless tombstones exist.** Records deleted before a tombstone guarantee existed cannot be distinguished from records that should sync.
- **A cutover baseline strategy is required.** Define a "from this point forward" tombstone guarantee: at first sync enable, the current local state becomes the baseline, and only deletions after cutover are guaranteed to propagate. Pre-cutover deletions are out of scope for propagation.
- **Backup-before-sync is mandatory.** A verified backup must precede first enable so the cutover is recoverable.
- **"From this point forward" tombstone guarantee.** Commit to durable on-record tombstones from cutover onward, so that after the baseline every delete propagates and no post-cutover deletion silently resurrects.

---

## 14. Recommended Next Phase

**Sync Bootstrap Policy — documentation-only.**

**Justification:** the audit shows the deletion model and the bootstrap model are tightly coupled through the **cutover baseline** (§13). The single largest concrete gap surfaced here — tombstones do not travel in `WalletDataSnapshot`, so the first sync cannot reconstruct deletion history — is fundamentally a bootstrap question: how the first upload/first download is ordered, how the baseline is established, when the "from this point forward" tombstone guarantee begins, and how backup-before-sync is enforced. Sequencing bootstrap next keeps the "how does the first sync start safely" thread continuous and directly consumes the deletion decisions made here.

The **UUID / Name-Based Reference Migration Decision** remains a required parallel track (it underpins merge correctness for name-keyed relationships and subcategory identity) and should follow immediately after the bootstrap policy, before any implementation step.

---

## 15. Do Not Do Yet

- **Do not enable automatic CloudKit sync.**
- **Do not flip feature flags** (`isAutomaticCloudKitSyncEnabled`, `isDeveloperCloudKitRecordSyncOverrideEnabled`, or the persisted auto-sync gate).
- **Do not change entitlements.**
- **Do not change CloudKit containers.**
- **Do not change upload/download/apply logic.**
- **Do not change restore blocking behavior.**
- **Do not auto-repair or mutate data.**
- **Do not change the backup schema.**
- **Do not change financial calculations.**
- **Do not merge with the GitHub `main` branch.** This work stays on `householdbudget-main`.

---

## 16. Verification for This Documentation Task

This file is the sole output of this task. No Swift files, test files, Xcode project files, Info.plist, entitlements, public pages, or backup schema files were modified. No feature flags were changed. Automatic CloudKit sync was not enabled. Financial calculations were not changed. Data models were not changed.
