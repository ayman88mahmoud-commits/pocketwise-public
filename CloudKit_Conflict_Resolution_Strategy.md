# CloudKit Conflict Resolution Strategy

Date: 2026-07-01
Branch: householdbudget-main
Phase: CloudKit Sync Preflight — Conflict Resolution Design
Status: Documentation only. Automatic CloudKit sync remains disabled and must stay disabled.

---

## 1. Executive Summary

Before any CloudKit record-sync gate is opened, the app must have a written, agreed model for how it reasons about conflicts. Conflict resolution is the foundation every other sync decision depends on: deletion/tombstone semantics, merge policy, duplicate detection, and bootstrap ordering all reference the conflict model. Designing it first gives the eventual implementation a contract to satisfy and a test oracle to validate against.

This document defines conflict-resolution principles, a record-identity strategy, a per-model conflict policy, decisions for concrete conflict scenarios, deletion/tombstone requirements, name-based reference handling, recurring-event policy, backup-import interaction, cloud bootstrap behavior, severity levels, required UX, and a dry-run validation approach. It builds on two prior documents — `Sync_Identity_Deletion_Policy.md` and `Hard_Delete_Safety_Implementation_Plan.md` — and the completed relationship integrity and recurring checkpoints.

This is **documentation only**. It changes no code, flips no flags, and does **not** enable CloudKit sync. Manual iCloud full-snapshot backup via `WalletICloudSyncService` remains the active safe cloud path.

---

## 2. Current Git State

| Property | Value |
|---|---|
| Branch | `householdbudget-main` |
| Remote tracking | `origin/householdbudget-main` |
| Latest commit | `ad307e7` Document CloudKit sync preflight roadmap review |
| Working tree | Clean — no uncommitted changes |
| Sync status | In sync — local matches `origin/householdbudget-main` |

*(This document's own commit advances the latest commit beyond `ad307e7`; the state above reflects the branch immediately before it was committed.)*

---

## 3. Current Sync Readiness Baseline

- **CloudKit automatic record sync is disabled.** `WalletSyncFeatureFlags.isAutomaticCloudKitSyncEnabled = false` and `isDeveloperCloudKitRecordSyncOverrideEnabled = false`; `canRunDeveloperCloudKitRecordSync` requires both and is `false`.
- **Manual iCloud snapshot backup is the active safe path.** `WalletICloudSyncService` stores a single full-snapshot `CKRecord` (`primaryWalletSnapshot`) — whole-document backup, not record-level sync.
- **Relationship validation is covered.** Category/subcategory, account, credit card, person debt, installment plan, and recurring references are validated in `makeBackupValidationReport` with correct severities.
- **Recurring orphan warning added.** `"Recurring occurrence missing series"` (`.warning`, non-blocking).
- **102 `BackupValidationTests`, 0 failures.** Production build succeeds.
- **Dry-run scaffolding exists.** `WalletSyncDryRunUploadPlanner`, `WalletSyncDryRunLoopController`, `WalletSyncMergePlanDryRun`, plus the master-data coordinator/pipeline and `WalletSyncStateStore` (change tokens + local deletion markers).
- **Identity foundation is strong but incomplete.** Every persisted model carries `id: UUID`, `createdAt`, `updatedAt`, `isDeleted`, `deletedAt`. Subcategories remain `[String]` with no independent identity, and many relationships are still name-based.

---

## 4. Conflict Resolution Principles

1. **Never silently lose financial data.** No merge may drop a transaction, payment, debt entry, or balance-affecting record without an explicit, reversible user action.
2. **Prefer non-destructive merges.** When in doubt, keep both versions and surface a review rather than overwrite.
3. **Preserve local user intent.** A user's deliberate edit on their device must not be silently discarded by a stale remote copy.
4. **Deletion must be explicit and reversible where possible.** A delete is a first-class, durable event — never an implicit "absence." Resurrection of deleted financial records is a correctness bug, not a cosmetic one.
5. **Warn/report before any destructive action.** Destructive merges require a visible warning and, for high-risk records, confirmation.
6. **Backup before sync.** A verified local/iCloud backup must exist before the first sync enable and before any destructive reconciliation.
7. **Sync must be explainable to the user.** Every automatic decision must be describable in the UI (what changed, when, from which device).
8. **Financial correctness is invariant.** Balances, debts, and posting must never double-apply or silently reverse as a side effect of a merge.

---

## 5. Record Identity Strategy

- **Stable UUID `id` is the primary identity** for every syncable record. IDs are preserved forever and never regenerated on rename, amount change, month change, or parent change (per `Sync_Identity_Deletion_Policy.md` §4).
- **`updatedAt` is an ordering signal only, not the whole policy.** It orders candidate versions but does not by itself authorize a destructive overwrite of financial data. Clock skew across devices means `updatedAt` is advisory.
- **`createdAt` is preserved** across merges; the earliest known `createdAt` wins so history is not rewritten.
- **`isDeleted` / `deletedAt` are the tombstone fields** already present on every persisted model. Today most delete paths hard-remove and write a separate marker in `WalletSyncStateStore`; the sync design should converge on the on-record soft-delete fields so tombstones travel with the record and survive backup/restore.
- **Name-based references are weaker and need special handling.** Account/category/subcategory/payment-method names are display labels used as relationship keys. They must not be treated as identity; they need reconciliation/reporting (already in place) and eventual stable-ID references.
- **Subcategories have no independent identity** (`[String]` inside `Category`). This is the single largest identity gap and must be resolved before subcategory-level sync.
- **Device/source metadata** (which device last wrote, a change tag) is not modeled yet and should be added as sync metadata later — never as a change to financial data models.

---

## 6. Per-Model Conflict Policy Table

Identity for all rows below is the stable UUID `id` unless noted. "LWW" = last-writer-wins by `updatedAt`.

| Model | Identity | Key Mutable Fields | Conflict Risk | Proposed Merge Rule | Deletion Rule | LWW Acceptable? | Manual Review? |
|---|---|---|---|---|---|---|---|
| `FinancialEvent` (one-off) | `id` | amount, date, account/category/subcategory names, status, note | High (balance-affecting) | LWW on non-financial fields; **divergent amount/account/status → manual review**, never silent overwrite | Soft-delete via `deletedAt`; tombstone must win over stale edit | No for amount/account/status | Yes on financial-field divergence |
| `WalletCategory` (`Category`) | `id` | name, subcategories `[String]` | High (name is a relationship key) | LWW on name; merge subcategory arrays as **union** pending subcategory identity | Soft-delete; block/report if still referenced | Partial | Yes if referenced on delete |
| Subcategory (embedded `[String]`) | none (name only) | membership in parent array | High (no identity) | Union of names within parent until real IDs exist | No independent tombstone today | No | Yes — flagged as unresolved identity gap |
| `WalletAccount` (`Account`) | `id` | name, balance, type | High (balance + name key) | LWW on name/type; **balance is derived from postings, not merged directly** | Soft-delete only if unused; block/report if referenced | No for balance | Yes if referenced on delete |
| `CreditCard` | `id` | name, limits, statement/due days, default account name, isActive | Medium | LWW on descriptive fields | Soft-delete; children (`cardID`) must be reconciled first | Yes for descriptive fields | Yes if purchases/payments exist |
| `CreditCardPurchase` | `id` (+ `cardID`) | amount, date, category/subcategory names | High (statement balance) | LWW on classification; **divergent amount → manual review** | Soft-delete; tombstone wins | No for amount | Yes on amount divergence |
| `CreditCardPayment` | `id` (+ `cardID`) | amount, date, `fromAccountName` | High (account balance) | **Divergent amount/account → manual review**; never silent | Soft-delete; tombstone wins over stale edit | No | Yes |
| `InstallmentPlan` | `id` | totals, count, dates, account/category names, `linkedCreditCardID` | High (generates events) | LWW on descriptive fields; **structural change (count/total) → manual review** | Soft-delete; **paid generated events preserved** | No for count/total | Yes on structural change |
| `PersonDebt` | `id` | personName, kind, originalAmount | High (balance via entries) | LWW on descriptive fields | Soft-delete cascades to entries — **must be tombstoned, not hard-removed** | No for amount/kind | Yes |
| `PersonDebtEntry` | `id` (+ `debtID`) | amount, `accountName`, entryType, date | High (balance) | **Divergent amount/account → manual review** | Soft-delete; tombstone wins | No | Yes |
| `WalletMonthlyBudget` / `WalletMonthlyBudgetItem` | `id` | year/month, categoryName, plannedAmount | Medium | LWW on planned amount; **duplicate budget for same month → dedupe by year/month + review** | Soft-delete | Yes for planned amount | Only on duplicate-month |
| `WalletEvent` (quick event) | `id` | category/subcategory/default-account names | Medium | LWW | Soft-delete | Yes | No |
| Recurring `FinancialEvent` parent/occurrence | parent `id`; occurrence `id` + `sourceRecurringEventID` + year/month | repeatRule, overrides; occurrence amount/status | High | See §10 — **never auto-delete paid occurrences**; de-dup occurrences by `(sourceRecurringEventID, year, month)` | Parent soft-delete must not orphan/resurrect paid occurrences | No | Yes |

---

## 7. Conflict Scenarios and Decisions

- **Same transaction edited on two devices** → same `id`, divergent balance-affecting fields. **Decision:** do not silently LWW; produce a manual-review conflict preserving both values; default keep-both-until-resolved.
- **Transaction deleted on one device and edited on another** → **Decision:** the deletion (tombstone) wins over a stale edit, but the deletion must be durable and surfaced ("this record was deleted on another device"); never let the edit resurrect it silently. Because deletes reverse balance impacts, resurrection would double-apply — forbidden.
- **Category renamed while another device adds transactions to the old category** → **Decision:** resolve by category `id` (rename is a field change on the same record); transactions keep pointing at the record; name-based lookups reconcile to the renamed label; report any unresolved name references.
- **Account deleted while another device logs spending against it** → **Decision:** block/report; an account with new remote postings is "still referenced." Do not delete; surface a conflict and require user resolution (deletion is only safe when unused).
- **Card deleted while purchases/payments still reference it** → **Decision:** block/report; reconcile children (`cardID`) first; card deletion must not orphan balance-affecting payments.
- **Recurring parent deleted while an occurrence is paid on another device** → **Decision:** preserve the paid occurrence; surface it as an orphaned-series warning (already implemented locally); never auto-delete the paid occurrence.
- **Installment plan edited while an event is generated/paid on another device** → **Decision:** paid events are preserved; structural plan changes (count/total) go to manual review; unpaid generated events may be regenerated only through a de-dup guard.
- **Manual backup import while sync is enabled** → see §11 — sync must pause and a backup/preview must precede any replacement.
- **First launch on a second device with existing local data** → see §12 — bootstrap with merge preview, never blind overwrite.
- **Cloud data older than local data** → **Decision:** local newer edits are preserved; older cloud values do not overwrite newer local financial fields; non-financial fields may LWW.
- **Local data older than cloud data** → **Decision:** symmetric; newer cloud values apply to non-financial fields; financial-field divergence still routes to review rather than silent overwrite.

---

## 8. Deletion and Tombstone Requirements

- **Why hard delete is risky in multi-device sync:** a record removed from a local array with no durable on-record tombstone can be re-downloaded from another device and silently resurrected. Because delete paths reverse balance impacts before removal (`deleteFinancialEvent`, `deleteCreditCardPayment`, `deletePersonDebt`, etc. — see `Hard_Delete_Safety_Implementation_Plan.md`), resurrection double-applies money movements.
- **What needs tombstones or soft delete:** all balance-affecting and user-entered records — financial events, card purchases/payments, person debts/entries, installment plans, accounts, categories, budgets, summaries. The on-record `isDeleted`/`deletedAt` fields already exist and should become the durable tombstone that travels with the record and survives backup/restore.
- **Subcategories** have no tombstone at all (`[String]`); they cannot be safely deleted under sync until they gain identity + tombstone.
- **Retention (conceptual):** tombstones must be retained at least as long as any device may hold a pre-deletion copy — practically, until all participating devices have acknowledged the deletion. A fixed short window risks resurrection; indefinite retention is the safe default until a compaction policy is designed.
- **Displaying referenced deleted objects:** a record that references a soft-deleted parent should display a clear "deleted" state rather than vanish or crash; the relationship warnings already surface these.
- **Why delete propagation must be designed before sync:** without a durable, propagating deletion model, the first sync cycle after a delete can resurrect financial records — the highest-severity failure class. This is the subject of the recommended next phase.

---

## 9. Name-Based Reference Risk

Name-based relationships break in these ways:
- **Renamed category/account:** every record keyed by the old name is orphaned unless resolved by the parent's stable `id`.
- **Duplicate names:** two categories/accounts with the same display name across devices collapse ambiguously.
- **Old transactions referencing old names:** historical records may intentionally preserve legacy labels the user saw, which must not be rewritten.
- **Cross-device rename/add race:** device A renames a category while device B adds transactions to the old name; on merge the new transactions appear orphaned.

**Recommendation:** do **not** attempt a full name→UUID migration inside this phase. The safe sequence is (1) keep reconciliation/reporting (already in place and passing 102 tests) as the near-term safety net, then (2) make a deliberate **UUID/name-reference migration decision** as its own documented phase, introducing stable-ID references alongside legacy names during a compatibility period (dual-write) so old backups remain decodable. Subcategory identity must be part of that decision.

---

## 10. Recurring and Generated Event Conflict Policy

- **Parent vs child:** a recurring series is a `FinancialEvent` with `repeatRule != .none`; a paid occurrence is a `FinancialEvent` with `sourceRecurringEventID` → parent `id`, plus `recurringOccurrenceYear`/`Month`. There is no separate recurring model.
- **Duplicate generation risk:** the de-dup key is `(sourceRecurringEventID, year, month)`. If the parent is duplicated across devices (two series with different `id`s), the key diverges and the same month can be paid twice. Merge must de-dup on this composite key.
- **Paid occurrence preservation:** paid occurrences are real, balance-affecting records and must be preserved even if their parent series is gone.
- **Parent deletion risk:** deleting a parent series must not delete or resurrect paid occurrences; orphaned occurrences are surfaced by the existing `.warning`.
- **Recommended rule:** **never delete paid occurrences automatically.** Recurring reconciliation (semantic parent validation, duplicate-generation prevention, orphan re-linking) is **deferred** until explicitly designed in its own phase.

---

## 11. Manual Backup Import vs Sync Policy

If, in a future world where sync is enabled, the user imports a manual backup:
- **Pause sync** for the duration of the import.
- **Require a fresh backup first** (backup-before-destructive-action).
- **Treat import as a candidate local replacement**, not an automatic cloud push.
- **Create a merge preview** (dry-run) showing creates/updates/deletes the import would cause versus current cloud state.
- **Upload replacement only after explicit confirmation.**
- **Never auto-push an imported snapshot** into the sync zone, and **never let an import silently clobber cloud state** or resurrect tombstoned records.

Import and record sync must be **mutually exclusive** operations.

---

## 12. Cloud Bootstrap Conflict Policy

- **First device with local data, cloud empty:** upload local as the initial cloud baseline (explicit, after backup). No conflict.
- **Second device with empty local data, cloud has data:** download cloud to hydrate. No conflict.
- **Second device with existing local data, cloud has data:** **merge preview required** — never blind overwrite in either direction; route financial-field divergence to review.
- **Cloud empty but local has data:** treat as first-upload with confirmation.
- **Multiple devices opening before initial sync completes:** serialize via the coordinator's overlap guard and availability check; do not allow concurrent initial uploads that could create duplicate baselines.
- **Universal rule:** the first sync on any device must be preceded by a verified backup and, when both sides hold data, a visible merge preview.

---

## 13. Proposed Conflict Severity Levels

1. **Auto-merge safe** — non-financial descriptive fields; LWW acceptable (e.g. note, color, display label on the same `id`).
2. **Warning only** — orphaned/dangling references, older-vs-newer non-financial divergence; surfaced, non-blocking (mirrors current `.warning` model).
3. **Manual review required** — divergent balance-affecting fields on the same `id` (amount, account, status); keep both until resolved.
4. **Blocking conflict** — structural corruption (duplicate identity baselines, missing parent for a balance-affecting child) that must be resolved before sync proceeds.
5. **Destructive action forbidden without confirmation** — any delete/overwrite that would drop or reverse financial data requires explicit user confirmation and a pre-action backup.

---

## 14. Required UI/UX Before Enabling Sync

- **Sync status** indicator (idle / syncing / paused / error).
- **Last synced time.**
- **Conflict warning** surface (count + entry point).
- **Manual review screen** to resolve divergent balance-affecting records (keep-both / choose version).
- **Backup-before-sync prompt** on first enable and before destructive reconciliation.
- **Sync paused / error state** with a clear recovery path.
- **Restore-from-backup option** always reachable, and mutually exclusive with active sync.

---

## 15. Dry-Run Validation Strategy

The existing `WalletSyncDryRun*` and `WalletSyncMergePlanDryRun` scaffolding should be the validation harness used **before** any write path is enabled:
- **Produce a merge plan** from local + (simulated or read-only) cloud state.
- **Count creates / updates / deletes** the plan would produce.
- **Surface warnings** (orphans, name mismatches, divergent financial fields) using the same severity model.
- **Perform no mutation.** No record is written to CloudKit or to the local store.
- **No upload/apply until explicitly allowed** in a later, separately-approved phase.

The dry-run must be exercisable in a test/TestFlight context and produce a human-readable plan that a reviewer can sign off on before any real sync.

---

## 16. Recommended Next Phase

**CloudKit Deletion and Tombstone Strategy — documentation-only.**

Deletion propagation is the highest-severity failure class (silent resurrection of balance-affecting records) and every merge rule in §6–§8 depends on a settled tombstone model. The next document should define: convergence on the on-record `isDeleted`/`deletedAt` fields, how tombstones travel through backup/restore, retention/compaction, cascade rules for parents (person debt → entries, plan → generated events), and how the existing `WalletSyncStateStore` markers relate to on-record tombstones. It must remain documentation-only and must not enable sync.

---

## 17. Do Not Do Yet

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

## 18. Verification for This Documentation Task

This file is the sole output of this task. No Swift files, test files, Xcode project files, Info.plist, entitlements, public pages, or backup schema files were modified. No feature flags were changed. Automatic CloudKit sync was not enabled. Financial calculations were not changed. Data models were not changed.
