# CloudKit Sync Preflight Roadmap Review

Date: 2026-07-01
Branch: householdbudget-main
Phase: CloudKit Sync Preflight Roadmap Review
Status: Documentation only. Automatic CloudKit sync remains disabled and must stay disabled.

---

## 1. Executive Summary

The app is in a **preflight** posture for CloudKit record sync: the sync scaffolding is compiled and gated, backup/restore validation is mature and regression-protected, and relationship integrity has been audited across every model. **Automatic CloudKit record sync is intentionally disabled and must remain disabled.**

The only active, production-safe cloud workflow is **manual iCloud snapshot backup** via `WalletICloudSyncService`, which stores a single full-snapshot `CKRecord` (`primaryWalletSnapshot`) — this is a whole-document backup, not record-level multi-device sync. True record sync (per-record upload/download/apply/merge) exists only as gated, developer-override scaffolding and never runs automatically.

This document consolidates completed preflight work, the current gate state, remaining structural risks, conflict scenarios, and the checklist that must be satisfied before any sync gate is opened. It changes no code and enables nothing.

---

## 2. Current Git State

| Property | Value |
|---|---|
| Branch | `householdbudget-main` |
| Remote tracking | `origin/householdbudget-main` |
| Latest commit | `0cdc139` Document final recurring relationship checkpoint |
| Working tree | Clean — no uncommitted changes |
| Sync status | In sync — local matches `origin/householdbudget-main` |

*(This review's own commit advances the latest commit beyond `0cdc139`; the state above reflects the branch immediately before this document was committed.)*

---

## 3. Completed Preflight Work

- **CloudKit UI / debug gating.** Every developer record-sync action in `WalletRootView` is guarded by `WalletSyncFeatureFlags.canRunDeveloperCloudKitRecordSync` (~25 call sites). Hidden debug UI cannot upload, download, apply, or mutate sync records while the flags are off.
- **CloudKit pipeline gates.** Scene-phase auto-sync is guarded by `isAutomaticCloudKitSyncEnabled`; the master-data coordinator (`runIfAllowed`) additionally gates on a persisted enable flag, an overlap guard, a rate limit, and an iCloud availability check.
- **Backup validation blocking errors.** `validateBackupSnapshot` throws on structurally unrecoverable states (invalid amounts, missing parents, empty required names, duplicate IDs, invalid settings), blocking restore.
- **Restore-blocking backup validation coverage.** `makeBackupValidationReport` mirrors those errors and adds a restore-blocking report surface used by `DataBackupView`.
- **Relationship integrity preflight.** Category/subcategory, account, credit card, person debt, and installment plan references are all validated with correct severities and locked by tests (see final checkpoint `79c6786`).
- **Recurring relationship audit and warning.** `FinancialEvent.sourceRecurringEventID` orphan links are surfaced as a non-blocking `.warning` (`4d3d8da`), audited and documented (`7b6c3b7`, `f5f8af5`, `0cdc139`).
- **Final test count: 102 `BackupValidationTests`, 0 failures.** Production build succeeds against `generic/platform=iOS Simulator`.

---

## 4. Current CloudKit Gate State

**Controlling flags — `WalletSyncFeatureFlags` (compile-time constants):**

| Flag | Value | Effect |
|---|---|---|
| `isAutomaticCloudKitSyncEnabled` | `false` | Master switch for automatic record sync; gates scene-phase auto-sync in `WalletRootView` |
| `isDeveloperCloudKitRecordSyncOverrideEnabled` | `false` | Separate local override required so hidden debug UI cannot act by accident |
| `canRunDeveloperCloudKitRecordSync` | `false` (derived) | Requires **both** flags true; gates every developer record-sync action |

**Is automatic sync disabled?** Yes. Both master flags are `false`, and the derived `canRunDeveloperCloudKitRecordSync` requires both to be true, so it is `false`.

**Gated code paths:**
- Scene-phase foreground auto-sync trigger (`handleAutoSyncGateForScenePhase`) — gated by `isAutomaticCloudKitSyncEnabled`.
- All developer upload/download/apply/zone/token actions in `WalletRootView` — gated by `canRunDeveloperCloudKitRecordSync`.
- Master-data coordinator `runIfAllowed` — additionally gated by the persisted `WalletSyncMasterDataAutoSyncGate` (UserDefaults, **defaults off**), overlap guard, rate limit, and availability check.

**Can upload/download/apply/token/zone operations run automatically?** No. With the compile-time flags off, none of the record-level boundary operations in `WalletSyncRealCloudKitPrivateDatabaseBoundary` are reachable through any automatic path.

**Remaining visible developer/debug surfaces:** a debug panel in `WalletRootView` exposes the persisted auto-sync gate toggle and record-sync buttons, but each action re-checks the feature flags and returns early with a message (e.g. "CloudKit record sync is disabled by WalletSyncFeatureFlags. Manual iCloud backup remains the safe workflow."). The persisted gate can be toggled in debug, but the compile-time flags still block all record-sync effects.

**Entitlements:** the iCloud container `iCloud.com.ayman.HouseholdBudget` and the CloudKit service entitlement are present (required for the manual snapshot backup). Their presence does **not** enable record sync — the feature flags do, and they are off.

---

## 5. Data Integrity Readiness

- **Backup schema safety.** `WalletDataSnapshot` and all `CodingKeys` are stable; the preflight phases added no schema fields. Decoding is defensive (`decodeIfPresent` with defaults).
- **Restore validation safety.** `validateBackupSnapshot` blocks restore on structurally unrecoverable states; `makeBackupValidationReport` provides a full read-only report surface.
- **Warning vs error behavior.** `.error` blocks restore (structural corruption); `.warning` is non-blocking (orphaned/dangling references). This contract is consistent across all batches and verified by tests.
- **Relationship warning coverage.** Category/subcategory, account, credit card, person debt, and installment plan references are covered with correct severities.
- **Recurring warning coverage.** `sourceRecurringEventID` orphan links are surfaced as a non-blocking `.warning`.
- **Remaining name-based relationship weakness.** Accounts, categories, and subcategories are still matched by trimmed `String` name rather than a stable UUID. Reporting can surface mismatches but cannot eliminate the underlying fragility — this is the single largest structural risk for multi-device sync.

---

## 6. Relationship Coverage Summary

| Relationship | Coverage Status | Warning / Error | Restore | Test Coverage |
|---|---|---|---|---|
| Categories / subcategories | Covered | `.warning` (unknown ref); `.error` for empty budget-item name | Non-blocking (unknown); blocking (empty) | Yes |
| Accounts | Covered | `.warning` (unknown ref); `.error` for empty debt-entry account | Non-blocking (unknown); blocking (empty) | Yes |
| Credit cards | Covered | `.error` (purchase/payment missing card); `.warning` (plan linked card) | Blocking (purchase/payment); non-blocking (linked card) | Yes |
| Person debts | Covered | `.error` (structural, missing parent, empty account); `.warning` (unknown non-empty account) | Blocking (structural); non-blocking (unknown account) | Yes |
| Installment plans | Covered | `.warning` (event missing plan) | Non-blocking | Yes |
| Recurring source links | Covered | `.warning` (occurrence missing series) | Non-blocking | Yes |

---

## 7. Remaining Structural Risks Before True Sync

- **Name-based references instead of UUIDs.** Accounts/categories/subcategories are matched by name; renames and casing/whitespace differences break links across devices.
- **Possible semantic recurring parent mismatch.** The recurring check verifies the parent `id` exists but not that it still has `repeatRule != .none`.
- **No recurring reconciliation/repair.** Orphaned occurrences are reported, never re-linked or cleaned up.
- **No conflict-resolution strategy.** There is no defined policy for reconciling divergent edits to the same record across devices.
- **No merge policy for concurrent edits.** Field-level vs record-level merge, and last-writer-wins vs deterministic precedence, are undecided.
- **No deterministic device priority / source-of-truth policy.** No rule decides which device wins on tie.
- **No sync tombstone / deletion-propagation policy beyond current hard-delete safety docs.** Hard deletes are documented as safe for local restore, but there is no cross-device deletion-propagation model.
- **No migration plan for existing local data into CloudKit.** First-upload/bootstrap semantics for an existing local dataset are undefined.
- **No staged rollout / test-account strategy.** No TestFlight-only pilot or test-container plan exists yet.

---

## 8. CloudKit Conflict Risk Analysis

- **Same transaction edited on two devices.** Two divergent versions of one `FinancialEvent.id`; without a merge policy, one silently overwrites the other.
- **Category renamed on one device while transactions are added on another.** Name-based references on the second device point at the old name; the rename orphans them on merge.
- **Account/card/debt deleted on one device while referenced elsewhere.** A referenced parent removed on device A leaves dangling references on device B (the exact orphan class the preflight warnings surface locally).
- **Recurring parent deleted on one device while an occurrence is marked paid on another.** Produces an orphaned paid occurrence with a dangling `sourceRecurringEventID` after merge.
- **Manual backup import performed while sync is enabled.** A full-snapshot restore concurrent with record sync can reintroduce deleted records or clobber cloud state — restore and record sync must be mutually exclusive.
- **App opened on iPhone and iPad with old snapshots.** Two stale local datasets converging without a bootstrap policy can duplicate records or resurrect deletions.

---

## 9. Required Pre-Enable Checklist

Before automatic CloudKit sync may be enabled, all of the following must be complete:

- [ ] Complete conflict-resolution design (record-level and field-level policy)
- [ ] Complete deletion / tombstone strategy (cross-device deletion propagation)
- [ ] Complete UUID / reference migration decision (name-based → stable-ID policy)
- [ ] Complete local-to-cloud first-upload policy (bootstrap of existing local data)
- [ ] Complete cloud-to-local first-download policy (initial hydrate on a new device)
- [ ] Complete duplicate-detection strategy (prevent double records / double recurring generation)
- [ ] Complete recovery / rollback plan (safe path back if sync corrupts state)
- [ ] Complete TestFlight-only sync pilot plan (gated pilot, test container)
- [ ] Complete user-visible sync status / error UX plan
- [ ] Complete backup-before-sync requirement (mandatory local/iCloud backup before first enable)

---

## 10. Recommended Next Phase

**CloudKit Conflict Resolution Strategy — documentation-only.**

This is the correct next step because conflict resolution is the foundation every other sync decision depends on: deletion/tombstone semantics, merge policy, duplicate detection, and bootstrap ordering all reference the conflict model. It must be designed and documented **before any code change that enables sync**, so that the eventual implementation has a written contract to satisfy and a test oracle to validate against. No flags are flipped and no sync code is written in this phase.

---

## 11. Safe Future Phase Order

1. **CloudKit Conflict Resolution Strategy** doc
2. **CloudKit Deletion / Tombstone Strategy** doc
3. **UUID / name-reference migration decision** doc
4. **Sync bootstrap policy** doc (first upload / first download ordering)
5. **Sync dry-run validation mode** design (builds on the existing `WalletSyncDryRun*` / `WalletSyncMergePlanDryRun` scaffolding — validation only, no writes)
6. **TestFlight pilot plan**
7. **Only then** consider a tiny, disabled-by-default implementation step

---

## 12. Do Not Do Yet

- **Do not enable automatic CloudKit sync.**
- **Do not flip feature flags** (`isAutomaticCloudKitSyncEnabled`, `isDeveloperCloudKitRecordSyncOverrideEnabled`, or the persisted auto-sync gate).
- **Do not change entitlements.**
- **Do not change CloudKit containers.**
- **Do not change restore blocking behavior.**
- **Do not auto-repair or mutate data.**
- **Do not change the backup schema.**
- **Do not change financial calculations.**
- **Do not merge with the GitHub `main` branch.** This work stays on `householdbudget-main`.

---

## 13. Verification for This Documentation Task

This file is the sole output of this task. No Swift files, test files, Xcode project files, Info.plist, entitlements, public pages, or backup schema files were modified. No feature flags were changed. Automatic CloudKit sync was not enabled. Financial calculations were not changed. Data models were not changed.
