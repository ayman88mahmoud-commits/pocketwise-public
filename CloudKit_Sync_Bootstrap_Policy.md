# CloudKit Sync Bootstrap Policy

Date: 2026-07-01
Branch: householdbudget-main
Phase: CloudKit Sync Preflight — Bootstrap Policy Design
Status: Documentation only. Automatic CloudKit sync remains disabled and must stay disabled.

---

## 1. Executive Summary

Bootstrap is the moment sync begins on a device — the first upload, the first download, or the first merge of an existing local dataset with existing cloud data. It is the single most dangerous point in a sync system's life because it is where duplicate baselines, silent overwrites, and resurrected deletions are created. The deletion/tombstone audit (`f0690d8`) showed that tombstones do not travel in `WalletDataSnapshot`, so the first sync cannot reconstruct historical deletion history — making a **cutover baseline** policy mandatory before any gate opens.

This document defines the bootstrap model: the problem statement, bootstrap modes, first-upload and first-download policies, existing-local-plus-existing-cloud handling, the cutover baseline and tombstone guarantee, backup-import interaction, duplicate detection, a bootstrap validation checklist, failure/rollback policy, and required UX. It builds on `CloudKit_Conflict_Resolution_Strategy.md`, `CloudKit_Deletion_Tombstone_Strategy.md`, the relationship integrity checkpoints, and the recurring checkpoints.

This is **documentation only**. It changes no code, flips no flags, and does **not** enable CloudKit sync. Manual iCloud full-snapshot backup via `WalletICloudSyncService` remains the active safe cloud path.

---

## 2. Current Git State

| Property | Value |
|---|---|
| Branch | `householdbudget-main` |
| Remote tracking | `origin/householdbudget-main` |
| Latest commit | `f0690d8` Document CloudKit deletion tombstone strategy |
| Working tree | Clean — no uncommitted changes |
| Sync status | In sync — local matches `origin/householdbudget-main` |

*(This document's own commit advances the latest commit beyond `f0690d8`; the state above reflects the branch immediately before it was committed.)*

---

## 3. Current Baseline

- **CloudKit automatic record sync is disabled.** `WalletSyncFeatureFlags.isAutomaticCloudKitSyncEnabled = false`, `isDeveloperCloudKitRecordSyncOverrideEnabled = false`; `canRunDeveloperCloudKitRecordSync` is `false`. The persisted `WalletSyncMasterDataAutoSyncGate` defaults off.
- **Manual iCloud snapshot backup remains the safe path.** `WalletICloudSyncService` stores a single whole-snapshot `CKRecord` (`primaryWalletSnapshot`), stamped `updatedAt = snapshot.exportedAt`, with `fetchRemoteMetadata` / `upload` / `downloadSnapshot`. This is **snapshot-level last-writer-wins**, not record-level merge — and must not be conflated with record sync bootstrap.
- **Record-level sync scaffolding exists but is gated.** Coordinator, pipeline, apply-plan, CK record adapter, private-DB boundary, availability checker, and dry-run planner/merge/loop are compiled but unreachable through any automatic path.
- **Relationship validation has 102 `BackupValidationTests`, 0 failures.**
- **Deletion/tombstone strategy is documented** (`f0690d8`), including the on-record vs `WalletSyncStateStore` marker analysis.
- **No durable backup-carried tombstone list exists yet.** `WalletDataSnapshot` carries only live arrays plus settings/metadata; deletion history is not serialized.
- **Existing manual-import UX is a strong template.** `DataBackupView` already: opens a review preview, blocks restore when `validationReport.hasErrors`, replaces app data only after explicit confirmation, and warns the user to export a fresh backup first.

---

## 4. Bootstrap Problem Statement

Core risks the bootstrap policy must neutralize:
- **Cloud empty, local has data** — the first device must establish the baseline without accidentally creating duplicates on retry.
- **Cloud has data, local empty** — a new device must hydrate from cloud, but only after validating the cloud payload.
- **Both cloud and local have data** — the highest-risk case; a naive merge or overwrite can duplicate records or destroy one side.
- **Older device opens with stale data** — a device that has been offline may hold pre-cutover state and must not push stale writes or resurrect deleted records.
- **Backup import before/after bootstrap** — a full-snapshot import interleaved with record sync can clobber cloud state.
- **Deletion history missing before cutover** — historical deletions are unknowable to the first sync; without a cutover baseline, deleted records can resurrect.
- **Duplicate record creation if identity matching is wrong** — if bootstrap matches by anything other than the stable UUID `id` (e.g. name), it can create duplicate categories/accounts or double transactions.

---

## 5. Bootstrap Modes

| Mode | Safe behavior | Unsafe behavior (forbidden) |
|---|---|---|
| **First device, cloud empty** | Require backup; dry-run; upload local as the initial baseline after confirmation; stamp cutover baseline | Blind auto-upload; retry that creates duplicate baselines |
| **New device, cloud has data, local empty** | Validate cloud payload; preview; hydrate local after confirmation | Silent hydrate without validation; accepting a malformed cloud payload |
| **Existing device, cloud has data, local has data** | Merge preview / dry-run; classify creates/updates/deletes/conflicts; block on balance-affecting conflicts; manual review | Silent merge; last-writer-wins on money-impacting records; either-direction overwrite |
| **Cloud reset / recovery mode** | Require explicit user intent + fresh backup; treat as first-upload with confirmation | Automatic re-baseline that discards cloud or local silently |
| **TestFlight pilot mode** | Gated pilot in a test container; dry-run only until explicitly promoted; no production data risk | Running pilot against the production container; enabling writes without sign-off |

---

## 6. First Upload Policy

Rules for the first device uploading local data to cloud:
- **Require a manual backup before first upload.** A verified local/iCloud backup must exist and be recoverable.
- **Dry-run first.** Produce a read-only plan (via the dry-run scaffolding) before any write.
- **Count records by model.** The plan reports counts per model so the user/reviewer can sanity-check volume.
- **Validate the backup report has no errors.** `makeBackupValidationReport` must show `hasErrors == false` (same gate `DataBackupView` already enforces for restore).
- **Warn on relationship warnings.** Surface (non-blocking) orphan/dangling warnings for review before upload.
- **Establish a bootstrap baseline timestamp.** Record the cutover moment.
- **Establish "tombstones guaranteed from this point forward."** Commit to durable deletion propagation from the baseline onward.
- **No automatic destructive operations.** The first upload creates the baseline; it must never delete or overwrite pre-existing cloud data without explicit confirmation.

---

## 7. First Download Policy

Rules for a new/empty device hydrating from cloud:
- **Require cloud snapshot/records validation.** The incoming payload must pass validation before it is applied.
- **Local empty can accept cloud after preview.** With no local data at risk, hydrate after a confirmation preview.
- **Local non-empty must not be silently overwritten.** If any local data exists, downgrade to the existing-local-plus-existing-cloud path (§8).
- **Back up local first if any local data exists.** Never replace local data without a recoverable backup.
- **Show clear user confirmation before replacing local data.** Mirror the existing import UX: preview → confirm → replace.

---

## 8. Existing Local + Existing Cloud Policy

- **Never silently merge.** Both sides holding data is a review-required event.
- **Create a merge preview / dry-run plan.** Use the existing dry-run scaffolding to compute the plan without mutation.
- **Classify creates / updates / deletes / conflicts** per model, matched strictly by stable UUID `id`.
- **Block if balance-affecting conflicts exist.** Divergent amount/account/status on the same `id` halts automatic progress.
- **Manual review required** to resolve balance-affecting conflicts (keep-both / choose version).
- **No last-writer-wins for money-impacting records.** LWW is acceptable only for non-financial descriptive fields (per the conflict-severity model).

---

## 9. Cutover Baseline and Tombstone Guarantee

- **Historical deletions before first sync cannot be known** if they are not in the snapshot — and they are not (no tombstone field in `WalletDataSnapshot`).
- **Bootstrap must define a cutover point.** At first enable, the current local (or agreed baseline) state becomes the authoritative baseline.
- **Tombstones are reliable only from cutover forward** unless a separate tombstone migration is designed. Pre-cutover deletions are out of scope for propagation.
- **Require backup-before-cutover.** The cutover must be recoverable from a verified backup.
- **Cloud should record baseline metadata later.** A future baseline marker (timestamp, originating device, schema version) should live in the cloud zone so every device can recognize the same cutover — designed later, not now.
- **Old devices must be handled carefully.** A device that missed the cutover must reconcile to the baseline (treated as existing-local-plus-existing-cloud) rather than pushing stale pre-cutover state.

---

## 10. Manual Backup Import Policy During Sync

Recommended future behavior when a user imports a manual backup while sync is enabled:
- **Block import while sync is active, or pause sync and require a backup first.** Import and live record sync must not run interleaved.
- **Show a merge preview before replacing data.** Reuse the existing import preview + dry-run to classify the effect.
- **Never upload an imported replacement automatically without confirmation.**
- **Treat the imported backup as potentially lacking tombstone history.** Because backups carry no tombstones, an import can reintroduce records that were deleted post-cutover; reconciliation against known tombstones is required so import cannot resurrect them.
- **Import and live sync remain mutually exclusive** unless a preview + explicit confirmation bridges them.

---

## 11. Duplicate Detection Policy

Conceptual duplicate checks bootstrap and merge must apply:
- **Stable UUID match is primary.** Same `id` = same record; never create a second record for an existing `id`.
- **Semantic transaction duplicate detection** (secondary, advisory) — amount + date + title + account heuristics (the app already has `possibleDuplicateTransaction` logic locally) to flag likely duplicates created independently on two devices with different `id`s.
- **Recurring generated occurrences** — de-dup by `(sourceRecurringEventID, year, month)`; a duplicated parent series across devices is the main divergence source.
- **Credit card payment/purchase duplicates** — same `cardID` + amount + date should be flagged; both are balance/statement-affecting.
- **Monthly budgets** — dedupe by `(year, month, categoryName)`; two budgets for the same month must reconcile, not coexist.
- **Name-based duplicate risk for categories/accounts** — two records with the same display name but different `id`s across devices must be surfaced (name is not identity).

---

## 12. Bootstrap Validation Checklist

Before bootstrap proceeds on any device, all of the following must hold:
- [ ] Backup validation report has **no errors** (`hasErrors == false`).
- [ ] Relationship warnings reviewed.
- [ ] Recurring warnings reviewed.
- [ ] Dry-run merge plan generated (creates/updates/deletes/conflicts counted).
- [ ] Tombstone baseline (cutover) established.
- [ ] Local backup exported and verified.
- [ ] Cloud account available (via the availability checker).
- [ ] Device identity available if needed for tie-breaking/metadata.
- [ ] User confirms the initial direction (use-this-device vs download-from-cloud).

---

## 13. Failure and Rollback Policy

| Failure | Recommended handling |
|---|---|
| **Failed upload** | Abort cleanly; no partial baseline; retry must be idempotent (match by `id`, never duplicate). |
| **Failed download** | Do not apply a partial payload; keep local intact; surface error. |
| **Partial apply** | Treat as failed; roll back to pre-apply state; never leave a half-merged dataset. |
| **Validation failure** | Halt bootstrap; report the blocking issues; do not proceed. |
| **User cancels** | No changes committed; local and cloud remain as they were. |
| **Rollback from manual backup** | The pre-cutover backup is the recovery vehicle; restore replaces app data with confirmation (existing UX). |
| **Sync paused until safe** | On any unresolved failure, sync stays paused; the user is guided to a safe state before re-enabling. |

---

## 14. Required User UX Before Bootstrap

- **Sync setup screen** (entry point, current status).
- **Backup-before-sync prompt** (mandatory, recoverable).
- **"Use this device as source" confirmation** (first-upload direction).
- **"Download from iCloud" confirmation** (first-download direction).
- **Conflict preview** (creates/updates/deletes/conflicts, with manual review for balance-affecting conflicts).
- **Sync paused / error state** with a clear recovery path.
- **Rollback instructions** (how to restore from the pre-cutover backup).

---

## 15. Recommended Next Phase

**UUID / Name-Based Reference Migration Decision — documentation-only.**

**Why this must precede any implementation step:** the bootstrap and merge policies defined here match records by **stable UUID `id`**, but many relationships (account, category, subcategory, payment method) are still keyed by **display name**, and subcategories have **no identity at all** (`[String]`). Duplicate detection (§11), existing-local-plus-existing-cloud merge (§8), and cross-device rename handling all degrade to name-guessing until reference identity is decided. A written migration decision — whether to introduce stable-ID references (with dual-write compatibility so old backups remain decodable), how to give subcategories identity, and what to defer — is the last foundational design gap before any code that touches sync. It must be documented and agreed before implementation so the eventual bootstrap/merge code has an identity contract to build against.

After that decision, the safe order continues: sync dry-run validation mode design → TestFlight pilot plan → only then a tiny, disabled-by-default implementation step.

---

## 16. Do Not Do Yet

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

## 17. Verification for This Documentation Task

This file is the sole output of this task. No Swift files, test files, Xcode project files, Info.plist, entitlements, public pages, or backup schema files were modified. No feature flags were changed. Automatic CloudKit sync was not enabled. Financial calculations were not changed. Data models were not changed.
