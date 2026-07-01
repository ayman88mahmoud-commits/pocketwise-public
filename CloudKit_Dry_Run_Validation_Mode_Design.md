# CloudKit Dry-Run Validation Mode Design

Date: 2026-07-01
Branch: householdbudget-main
Phase: CloudKit Sync Preflight — Dry-Run Validation Mode Design
Status: Documentation only. Automatic CloudKit sync remains disabled and must stay disabled.

---

## 1. Executive Summary

Every sync decision documented so far — conflict resolution, deletion/tombstone handling, bootstrap ordering, and the UUID/name reference migration — specifies read-only checks the system must perform **before** a single record is uploaded, downloaded, or applied. A dry-run validation mode is the harness that runs all of those checks together and produces a no-mutation plan a human (or a TestFlight pilot) can review before any write path is ever enabled. Without it, the first real sync would be the first time the accumulated policy is exercised — which is unacceptable for a financial app.

This document designs that dry-run validation mode at design level only: its inputs, its output report, its validation categories, merge-plan classification, severity levels, and bootstrap/tombstone/reference/recurring policies. It builds directly on the existing `WalletSyncDryRunUploadPlanner`, `WalletSyncMergePlanDryRun`, and `WalletSyncDryRunLoopController` scaffolding, and on the prior CloudKit strategy documents.

This is **documentation only**. It changes no code, adds no types, flips no flags, and does **not** enable CloudKit sync. Manual iCloud full-snapshot backup remains the active safe cloud path.

---

## 2. Current Git State

| Property | Value |
|---|---|
| Branch | `householdbudget-main` |
| Remote tracking | `origin/householdbudget-main` |
| Latest commit | `05dc010` Document UUID name reference migration decision |
| Working tree | Clean — no uncommitted changes |
| Sync status | In sync — local matches `origin/householdbudget-main` |

*(This document's own commit advances the latest commit beyond `05dc010`; the state above reflects the branch immediately before it was committed.)*

---

## 3. Current Dry-Run Scaffolding Inventory

| Component | Produces | Currently CAN evaluate | Currently CANNOT evaluate |
|---|---|---|---|
| `WalletSyncDryRunUploadPlanner` | `WalletSyncDryRunUploadSummary { totalDTOCount, totalRecordCount, countsByEntity, warnings }` | Outbound upload plan from the store: DTO counts per `WalletSyncRecordEntity`, including deletion DTOs (e.g. `installmentPlanDeletion`); adapts DTOs to CKRecords for a count | Cloud state, conflicts, merge direction, relationship/name-id correctness, tombstone resurrection |
| `WalletSyncMergePlanDryRun` | Merge classification via `WalletSyncMergePlanLocalStateReading` (`contains<Model>(id:)`, `<model>UpdatedAt(id:)` for every model) | Per-record create-vs-update classification by **UUID presence** and **`updatedAt` ordering** across all models | Financial-field conflict severity, name/id reconciliation, tombstone/resurrection detection, bootstrap direction |
| `WalletSyncDryRunLoopController` | `WalletSyncDryRunLoopSummary { changedRecordCount, deletedRecordCount, sampleDeletedRecordNames }` via a read-only `fetchChangedRecords(since:)` | Inbound change/delete counts from the cloud zone (read-only fetch by change token), with sampled deleted record names | Semantic classification, relationship impact, resurrection risk, financial conflict review |

**Summary of the gap:** the scaffolding already covers **outbound counts** (planner), **UUID+`updatedAt` create/update classification** (merge plan), and **inbound change/delete counts** (loop controller). What is missing is a **consolidation layer** that unifies these into a single severity-ranked report and adds relationship, tombstone/resurrection, name-id, and financial-conflict checks. This document designs that consolidation layer conceptually.

---

## 4. Dry-Run Design Goals

- **No mutation** — the dry-run never writes to the local store or CloudKit.
- **No upload.**
- **No download apply** — reads may fetch (as the loop controller already does read-only), but nothing is applied to local state.
- **No token writes** — the change token is read, never advanced/committed.
- **No zone creation** unless already safely gated by existing flags (and even then, not as part of validation).
- **No restore/import mutation.**
- **Human-readable report** for a person reviewing sync readiness.
- **Machine-checkable severity** so a gate can decide "not ready" programmatically.
- **Safe for TestFlight pilot review** — exportable, comparable across devices, no production data risk.

---

## 5. Dry-Run Inputs

The dry-run should compare and consume:
- **Local `WalletDataSnapshot`** (or the live store) — the local truth.
- **Cloud records or a cloud snapshot preview** — via the read-only `fetchChangedRecords(since:)` path (no apply).
- **Sync state metadata** — change token (read-only), last dry-run results.
- **Tombstone markers** — the `WalletSyncStateStore` local deletion markers (financial event, installment plan, high-risk, generic) plus on-record `isDeleted`/`deletedAt`.
- **Backup validation report** — `makeBackupValidationReport` output (`hasErrors`, warnings).
- **Feature flag / gate state** — `WalletSyncFeatureFlags` and the persisted `WalletSyncMasterDataAutoSyncGate`.
- **Device identity** (later, if available) — for tie-breaking and cross-device comparison.

---

## 6. Dry-Run Output Report

A future consolidated report should contain:
- **Summary counts** — totals across categories.
- **Creates** (local→cloud and cloud→local).
- **Updates** (local→cloud and cloud→local).
- **Deletes** (local→cloud tombstone and cloud→local tombstone).
- **Conflicts** — same `id`, divergent fields; financial-field conflicts flagged for manual review.
- **Warnings** — non-blocking relationship/name-id/orphan issues.
- **Blocking issues** — anything that must be resolved before proceeding.
- **Relationship issues** — orphaned category/account/card/debt/installment/recurring references.
- **Tombstone/resurrection issues** — records that would be resurrected or deletions that cannot propagate.
- **Bootstrap direction recommendation** — first-upload / first-download / merge-preview / blocked.
- **User-facing explanation** — a plain-language readiness summary (green/yellow/red).

---

## 7. Validation Categories

| Check | Severity | Blocking? | Required before upload | Required before apply | Resolution |
|---|---|---|---|---|---|
| Backup validation errors (`hasErrors`) | Blocking error | Yes | Yes | Yes | Manual fix |
| Relationship warnings (category/account/etc.) | Warning | No | Review | Review | Manual review |
| Recurring missing-series warnings | Warning | No | Review | Review | Manual review |
| Tombstone missing from snapshot | Blocking error | Yes | Yes | Yes | Design/backfill (cutover) |
| Resurrected deleted record risk | Forbidden destructive | Yes | Yes | Yes | Manual review / block |
| Name/UUID mismatch | Manual review | Conditional | Review | Yes | Manual review |
| Duplicate names (accounts/categories) | Warning→review | Conditional | Review | Review | Manual review |
| Duplicate semantic transactions | Warning | No | Review | Review | Manual review |
| Recurring duplicate occurrence risk | Manual review | Conditional | Review | Yes | De-dup on `(sourceRecurringEventID, year, month)` |
| Account/category/card deleted while referenced | Blocking error | Yes | Yes | Yes | Manual review |
| Manual backup import pending/active | Blocking error | Yes | Yes | Yes | Pause sync / mutually exclusive |
| CloudKit availability | Blocking error | Yes | Yes | Yes | Retry when available |
| Feature flag / gate state | Info/blocking | Conditional | Yes | Yes | Gate check |

---

## 8. Merge Plan Classification

The dry-run should classify each record into exactly one bucket, matched strictly by stable UUID `id`:
- **Create local→cloud** — `id` present locally, absent in cloud.
- **Create cloud→local** — `id` present in cloud, absent locally.
- **Update local→cloud** — same `id`, local `updatedAt` newer, non-financial or reconcilable.
- **Update cloud→local** — same `id`, cloud `updatedAt` newer, non-financial or reconcilable.
- **Local delete → cloud tombstone** — `id` tombstoned locally, still present in cloud.
- **Cloud delete → local tombstone** — `id` tombstoned in cloud, still present locally.
- **Conflict — manual review** — same `id`, divergent **balance-affecting** fields (amount/account/status), regardless of `updatedAt`.
- **Blocked destructive action** — any classification that would drop or reverse financial data, or resurrect a tombstoned record.

The existing `WalletSyncMergePlanDryRun` already supports the create/update distinction via `contains<Model>(id:)` + `<model>UpdatedAt(id:)`; the delete/conflict/blocked buckets are the additions this design specifies.

---

## 9. Severity Levels

1. **Info** — descriptive, no action (counts, direction).
2. **Warning** — non-blocking; surfaced for review (orphans, older-vs-newer non-financial divergence, duplicate names).
3. **Manual review required** — same-`id` divergence in balance-affecting fields, name/id mismatch, recurring duplicate risk.
4. **Blocking error** — must be resolved before sync proceeds (backup errors, missing tombstones, referenced-parent deletion, unavailable account, pending import).
5. **Forbidden destructive action** — would drop/reverse financial data or resurrect a tombstoned balance-affecting record; never auto-executed, requires explicit confirmation + backup.

---

## 10. Bootstrap Dry-Run Policy

| Bootstrap case | Dry-run behavior |
|---|---|
| **First device, cloud empty** | Report all local as create local→cloud; require backup + no-errors; recommend first-upload direction |
| **New device, local empty, cloud has data** | Report all cloud as create cloud→local; recommend first-download after validation |
| **Local and cloud both have data** | Full merge classification; block on any balance-affecting conflict; recommend merge-preview (manual review) |
| **Cloud reset / recovery** | Treat as first-upload with confirmation; flag as destructive-if-cloud-nonempty |
| **TestFlight pilot** | Run in a test container; produce exportable summary; never apply |

---

## 11. Tombstone / Deletion Dry-Run Policy

Checks the dry-run must perform:
- **Missing durable tombstones** — a record deleted locally with no on-record `isDeleted`/`deletedAt` and no durable marker that would survive backup → flag (cutover gap).
- **Split-brain tombstone markers** — deletion present in `WalletSyncStateStore` but not reflected on-record or in the snapshot → flag inconsistency.
- **Resurrected balance-affecting records** — a cloud create/update whose `id` is locally tombstoned → **forbidden destructive**, block.
- **Delete vs update conflicts** — `id` tombstoned on one side, updated on the other → manual review (tombstone wins for non-financial; financial → review).
- **Parent deleted while child exists** — dangling reference after a parent tombstone → warning/blocking depending on balance impact.
- **Hard-deleted local records with only sync-state markers** — records gone from arrays but present in `WalletSyncStateStore` markers → flag that the tombstone does not travel in the snapshot.

---

## 12. UUID / Name Reference Dry-Run Policy

Checks aligned with the migration decision (`05dc010`):
- **Name exists but UUID missing** — reference needs backfill (compatibility period).
- **UUID target missing** — dangling reference (existing orphan-warning class).
- **UUID target exists but display name changed** — reconcile display; not a conflict.
- **Duplicate names** — same display name, different `id`s across devices → review.
- **Subcategory ambiguity** — no identity to distinguish rename vs new subcategory → flag; subcategory sync restricted.
- **Payment method free-string ambiguity** — no `PaymentMethod` model; treat as label, flag if used as a merge key.

---

## 13. Recurring Dry-Run Policy

Checks for recurring relationships:
- **Missing parent series** — `sourceRecurringEventID` not in the financial event id set (existing `.warning`).
- **Parent exists but is not recurring** — parent `id` present but `repeatRule == .none` (semantic mismatch not covered by the current first-layer check) → flag for review.
- **Duplicate generated occurrences** — two occurrences sharing `(sourceRecurringEventID, year, month)` → de-dup review.
- **Paid occurrence preservation** — verify no plan would delete a paid occurrence.
- **Parent delete vs child paid conflict** — parent tombstoned while a paid occurrence exists → preserve child, warn.

---

## 14. User-Facing Dry-Run UX

- **Sync Readiness screen** — the entry point, summarizing readiness.
- **Green / yellow / red readiness state** — green = ready, yellow = warnings/review, red = blocking/forbidden.
- **Issue list grouped by severity** — info / warning / manual review / blocking / forbidden.
- **Backup-before-sync prompt** — mandatory and recoverable.
- **Conflict preview** — the merge plan with balance-affecting conflicts highlighted.
- **"Sync paused until resolved"** — explicit paused state when red.
- **Developer diagnostics hidden unless debug mode** — raw counts/DTO details behind the existing debug gating.

---

## 15. TestFlight Pilot Use

- **Run the dry-run before enabling sync** — it is the gate, not an afterthought.
- **Export the dry-run summary** — a stable, shareable artifact.
- **Compare across devices** — two devices' summaries should reconcile; divergence is a finding.
- **No mutation** — the pilot exercises only read-only planning.
- **Collect diagnostics safely** — no financial data leakage; counts and severities, not raw records, in shared output.
- **Only allow a tiny, disabled-by-default implementation step later** — after the pilot validates the dry-run, and never before.

---

## 16. Recommended Next Phase

**Dry-Run Report Schema — documentation-only.**

**Justification:** this document defines the report **conceptually** (categories, severity, buckets), but the TestFlight pilot (§15) depends on a **stable, comparable, machine-checkable report format** to export and diff across devices. The concrete next artifact is therefore a defined report schema — field names, types, a severity enum, the create/update/delete/conflict bucket shapes, and a serialization format for cross-device comparison — that both the future dry-run implementation and the pilot consume. Designing the schema before the pilot ensures the pilot has something precise to produce and compare. The **TestFlight Sync Pilot Plan** follows immediately once the schema exists, and only then a tiny disabled-by-default implementation step.

---

## 17. Do Not Do Yet

- **Do not enable automatic CloudKit sync.**
- **Do not flip feature flags** (`isAutomaticCloudKitSyncEnabled`, `isDeveloperCloudKitRecordSyncOverrideEnabled`, or the persisted auto-sync gate).
- **Do not change entitlements.**
- **Do not change CloudKit containers.**
- **Do not change upload/download/apply/token/zone logic.**
- **Do not change restore blocking behavior.**
- **Do not auto-repair or mutate data.**
- **Do not change the backup schema.**
- **Do not change financial calculations.**
- **Do not merge with the GitHub `main` branch.** This work stays on `householdbudget-main`.

---

## 18. Verification for This Documentation Task

This file is the sole output of this task. No Swift files, test files, Xcode project files, Info.plist, entitlements, public pages, or backup schema files were modified. No feature flags were changed. Automatic CloudKit sync was not enabled. Financial calculations were not changed. Data models were not changed.
