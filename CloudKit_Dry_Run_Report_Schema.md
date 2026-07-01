# CloudKit Dry-Run Report Schema

Date: 2026-07-01
Branch: householdbudget-main
Phase: CloudKit Sync Preflight — Dry-Run Report Schema
Status: Documentation only. Automatic CloudKit sync remains disabled and must stay disabled.

---

## 1. Executive Summary

The dry-run validation mode design (`1bd3e1c`) defined *what* checks a no-mutation dry-run must run. This document defines the *format* those checks produce: a stable, machine-checkable, human-readable report schema. A stable schema is required before a TestFlight sync pilot or any implementation, because the pilot's entire value is being able to **export a report, compare it across devices (iPhone vs iPad), and make a programmatic go/no-go decision** — none of which is possible without an agreed shape for the report.

The schema deliberately extends the existing, already-`Codable` validation types (`BackupValidationSeverity`: `error`/`warning`/`info`; `BackupValidationIssue { id, severity, title, detail, recordID? }`) and the existing dry-run summaries (`WalletSyncDryRunUploadSummary`, `WalletSyncDryRunLoopSummary`) rather than inventing an unrelated model, so the future implementation can build on what exists.

This is **documentation only**. It changes no code, adds no types, flips no flags, and does **not** enable CloudKit sync. It is a design specification for a report a future dry-run *would* produce.

---

## 2. Current Git State

| Property | Value |
|---|---|
| Branch | `householdbudget-main` |
| Remote tracking | `origin/householdbudget-main` |
| Latest commit | `1bd3e1c` Document CloudKit dry-run validation mode design |
| Working tree | Clean — no uncommitted changes |
| Sync status | In sync — local matches `origin/householdbudget-main` |

*(This document's own commit advances the latest commit beyond `1bd3e1c`; the state above reflects the branch immediately before it was committed.)*

---

## 3. Existing Report Inputs

The schema consolidates inputs the scaffolding already provides:
- **Upload summary counts** — `WalletSyncDryRunUploadSummary { totalDTOCount, totalRecordCount, countsByEntity: [WalletSyncRecordEntity: Int], warnings: [String] }` (outbound plan incl. deletion DTOs).
- **Create/update merge classification** — `WalletSyncMergePlanDryRun` via `WalletSyncMergePlanLocalStateReading` (`contains<Model>(id:)`, `<model>UpdatedAt(id:)`), matched by UUID + `updatedAt`.
- **Changed/deleted cloud counts** — `WalletSyncDryRunLoopSummary { changedRecordCount, deletedRecordCount, sampleDeletedRecordNames }` from the read-only `fetchChangedRecords(since:)` path.
- **Backup validation issues** — `BackupValidationReport` (`issues`, `hasErrors`, `errorCount`, `warningCount`, `infoCount`).
- **Relationship warnings** — the category/account/card/debt/installment `.warning` issues.
- **Recurring warnings** — `"Recurring occurrence missing series"` (`.warning`).
- **CloudKit availability and gates** — account availability, feature flag state, and the persisted sync gate state.

---

## 4. Schema Design Goals

- **Machine-checkable** — every gate decision (`safeToUpload`, etc.) is a boolean derivable from fields.
- **Human-readable** — titles/messages and a readiness color a person understands.
- **Exportable** — serializable to JSON (and an optional markdown summary).
- **Comparable across devices** — deterministic field ordering and stable IDs so two devices' reports diff cleanly.
- **Stable for TestFlight diagnostics** — versioned schema so pilot reports remain comparable over builds.
- **No mutation implied** — the report is a read-only artifact; producing it changes nothing.
- **Clear blocking decision** — a single readiness status plus explicit safety booleans.
- **Clear user-facing explanation** — a plain-language summary string.

---

## 5. Top-Level Report Shape

Conceptual top-level fields (design-level, not a Swift declaration):

| Field | Type (conceptual) | Meaning |
|---|---|---|
| `reportID` | UUID | Unique per dry-run |
| `schemaVersion` | Int | Report schema version for cross-build comparison |
| `generatedAt` | Date | When the dry-run ran |
| `appVersion` / `build` | String? | Populated later if available |
| `deviceLabel` / `anonDeviceID` | String? | Anonymized device identity, later |
| `dryRunMode` | enum | e.g. `uploadPlan`, `mergePreview`, `bootstrap` |
| `sourceSnapshotSummary` | object | Local model counts + snapshot metadata |
| `cloudStateSummary` | object | Cloud changed/deleted counts, availability |
| `readinessStatus` | enum | green / yellow / red / gray (§7) |
| `severitySummary` | object | Counts per severity (§6) |
| `operationSummary` | object | Counts per merge bucket (§9) |
| `issues` | array | `IssueSchema[]` (§8) |
| `mergeBuckets` | object | Bucketed record items (§9) |
| `validationInputs` | object | Backup report + flag/gate state |
| `financialSafetyFlags` | object | §11 booleans |
| `tombstoneSection` | object | §12 |
| `referenceSection` | object | §13 |
| `recurringSection` | object | §14 |
| `bootstrapSection` | object | §15 |
| `recommendations` | array | Ordered human actions |
| `safeToUpload` | Bool | §16 |
| `safeToApply` | Bool | §16 |
| `safeToEnableSync` | Bool | §16 |
| `requiresManualReview` | Bool | §16 |
| `requiresBackupFirst` | Bool | §16 |
| `requiresSyncPaused` | Bool | §16 |

---

## 6. Severity Enum

Extends the existing `BackupValidationSeverity` (`info`/`warning`/`error`) into five dry-run levels. Mapping: existing `.info`→`info`, `.warning`→`warning`, `.error`→`blockingError`; two new levels are added for sync semantics.

| Severity | Meaning | User Visible | Blocks Upload | Blocks Apply | Requires Manual Review |
|---|---|---|---|---|---|
| `info` | Descriptive only (counts, direction) | Optional | No | No | No |
| `warning` | Non-blocking; review advised (orphans, non-financial divergence) | Yes | No | No | No |
| `manualReviewRequired` | Same-`id` financial divergence, name/id mismatch, recurring dup risk | Yes | Conditional | Yes | Yes |
| `blockingError` | Must resolve first (backup errors, missing tombstone, unavailable account, pending import) | Yes | Yes | Yes | Yes |
| `forbiddenDestructiveAction` | Would drop/reverse financial data or resurrect a tombstoned record | Yes | Yes | Yes | Yes (+ confirmation + backup) |

---

## 7. Readiness Status Enum

| Status | Applies when |
|---|---|
| `greenReady` | No `blockingError`, no `forbiddenDestructiveAction`, no `manualReviewRequired`; only info/warning present |
| `yellowReviewRequired` | At least one `manualReviewRequired`, but no `blockingError` / `forbiddenDestructiveAction` |
| `redBlocked` | Any `blockingError` or `forbiddenDestructiveAction` present |
| `grayNotAvailable` | Dry-run could not run (CloudKit unavailable, flags off, no data, fetch failed) |

---

## 8. Issue Schema

Each issue extends `BackupValidationIssue` (`id`, `severity`, `title`, `detail`, `recordID?`) with sync-specific fields:

| Field | Type | Notes |
|---|---|---|
| `issueID` | UUID | Stable per issue |
| `severity` | severity enum | §6 |
| `title` | String | Short label (reuses existing issue titles where applicable) |
| `message` | String | Detail (maps to existing `detail`) |
| `affectedModel` | String | e.g. `FinancialEvent` |
| `affectedRecordID` | UUID? | Maps to existing `recordID` |
| `affectedField` | String? | e.g. `accountName`, `amount` |
| `localValueSummary` | String? | Redactable summary, not raw balance |
| `cloudValueSummary` | String? | Redactable summary |
| `suggestedAction` | String? | Human next step |
| `blocksUpload` | Bool | |
| `blocksApply` | Bool | |
| `requiresManualReview` | Bool | |
| `relatedPolicyDocument` | String? | e.g. `CloudKit_Deletion_Tombstone_Strategy.md` |
| `debugDetails` | String? | Optional; behind debug gating only |

---

## 9. Merge Bucket Schema

Buckets (matched strictly by stable UUID `id`):

`createLocalToCloud`, `createCloudToLocal`, `updateLocalToCloud`, `updateCloudToLocal`, `deleteLocalToCloud`, `deleteCloudToLocal`, `conflictManualReview`, `blockedDestructiveAction`, `ignoredNoChange`.

Each record item:

| Field | Type | Notes |
|---|---|---|
| `model` | String | Model name |
| `id` | UUID | Stable identity |
| `localUpdatedAt` | Date? | From `<model>UpdatedAt(id:)` |
| `cloudUpdatedAt` | Date? | From cloud record |
| `direction` | enum | localToCloud / cloudToLocal / none |
| `reason` | String | Why it landed in this bucket |
| `financialImpact` | Bool | Balance-affecting model/field |
| `relationshipImpact` | Bool | Touches a reference (account/category/etc.) |
| `deletionImpact` | Bool | Involves a tombstone |

---

## 10. Model Count Summary

`sourceSnapshotSummary` / `cloudStateSummary` counts (mirroring `countsByEntity`):

- `financialEvents`
- `categories`
- `accounts`
- `creditCards`
- `creditCardPurchases`
- `creditCardPayments`
- `installmentPlans`
- `personDebts`
- `personDebtEntries`
- `monthlyBudgets` / `monthlyBudgetItems`
- `quickEvents` (`WalletEvent`)
- `tombstones` / `deletionMarkers` (financial event, installment plan, high-risk, generic)

Each may carry `localCount`, `cloudCount`, and `deltaCount`.

---

## 11. Financial Safety Flags

Top-level booleans that drive the gate:
- `hasBalanceAffectingConflicts`
- `hasResurrectionRisk`
- `hasDeleteVsUpdateConflict`
- `hasManualBackupImportRisk`
- `hasDuplicateFinancialEvents`
- `hasDuplicateSemanticTransactions`
- `hasRecurringDuplicateRisk`
- `hasMissingReferencedAccount`
- `hasMissingReferencedCategory`
- `hasNameUUIDMismatch`

Any of `hasBalanceAffectingConflicts`, `hasResurrectionRisk`, or `hasDeleteVsUpdateConflict` being true forces at least `yellowReviewRequired` and blocks `safeToApply`.

---

## 12. Tombstone / Deletion Section

`tombstoneSection` fields:
- `localTombstones` — count + ids (on-record `isDeleted`/`deletedAt` and `WalletSyncStateStore` markers).
- `cloudTombstones` — count + ids from the read-only fetch.
- `tombstonesMissingFromSnapshot` — deletions in `WalletSyncStateStore` not reflected in `WalletDataSnapshot` (the split-brain gap).
- `resurrectedRecordCandidates` — cloud create/update whose `id` is locally tombstoned → `forbiddenDestructiveAction`.
- `deleteVsUpdateConflicts` — id tombstoned one side, updated other.
- `parentDeletedWhileChildExists` — dangling references after a parent tombstone.
- `staleDeviceReintroducingDeletedRecord` — a stale write reviving a tombstoned id.

---

## 13. UUID / Name Reference Section

`referenceSection` fields (per the migration decision):
- `nameOnlyReferences` — name present, no UUID (compatibility backfill needed).
- `uuidTargetMissing` — dangling id reference.
- `uuidTargetRenamed` — id resolves but display name changed (reconcile, not conflict).
- `duplicateNames` — same name, different ids.
- `subcategoryAmbiguities` — no identity to disambiguate.
- `paymentMethodAmbiguities` — free-string, no model.
- `recommendedMigrationStatus` — per relationship: `mustSolveBeforeSync` / `deferWithWarning` / `safeAsIs` / `needsIdentityModel`.

---

## 14. Recurring Section

`recurringSection` fields:
- `missingParentSeries` — `sourceRecurringEventID` not in the financial event id set (existing `.warning`).
- `parentNotRecurring` — parent id present but `repeatRule == .none` (semantic mismatch).
- `duplicateGeneratedOccurrences` — collisions on `(sourceRecurringEventID, year, month)`.
- `paidOccurrencePreservationIssues` — any plan that would remove a paid occurrence.
- `parentDeleteVsChildPaidConflicts` — parent tombstoned while a paid occurrence exists.

---

## 15. Bootstrap Section

`bootstrapSection` fields:
- `cloudEmptyLocalHasData` — Bool → recommend first-upload.
- `cloudHasDataLocalEmpty` — Bool → recommend first-download.
- `bothHaveData` — Bool → recommend merge-preview (manual review).
- `cloudResetRecovery` — Bool → destructive-if-nonempty.
- `cutoverBaselineReady` — Bool → tombstone guarantee established.
- `backupBeforeSyncSatisfied` — Bool → verified recoverable backup exists.
- `userConfirmationRequired` — Bool → direction confirmation needed.

---

## 16. Decision Logic

- **`safeToUpload`** = no `blockingError` AND no `forbiddenDestructiveAction` AND `backupBeforeSyncSatisfied` AND CloudKit available.
- **`safeToApply`** = `safeToUpload` AND no `manualReviewRequired` AND no `hasBalanceAffectingConflicts` AND no `hasResurrectionRisk` AND no `hasDeleteVsUpdateConflict`.
- **`safeToEnableSync`** = `safeToApply` AND `cutoverBaselineReady` AND `readinessStatus == greenReady`.
- **`requiresManualReview`** = any issue with `requiresManualReview == true`.
- **`requiresBackupFirst`** = `backupBeforeSyncSatisfied == false` OR any `forbiddenDestructiveAction`.
- **`requiresSyncPaused`** = `readinessStatus == redBlocked` OR `hasManualBackupImportRisk`.

---

## 17. Example Report (illustrative pseudo-JSON, fake data)

```json
{
  "reportID": "00000000-0000-0000-0000-0000000000AA",
  "schemaVersion": 1,
  "generatedAt": "2026-07-01T12:00:00Z",
  "dryRunMode": "mergePreview",
  "readinessStatus": "yellowReviewRequired",
  "severitySummary": { "info": 3, "warning": 2, "manualReviewRequired": 1, "blockingError": 0, "forbiddenDestructiveAction": 0 },
  "operationSummary": { "createLocalToCloud": 4, "updateCloudToLocal": 1, "conflictManualReview": 1, "ignoredNoChange": 120 },
  "sourceSnapshotSummary": { "financialEvents": 120, "accounts": 3, "categories": 8 },
  "cloudStateSummary": { "changedRecordCount": 5, "deletedRecordCount": 1 },
  "issues": [
    {
      "issueID": "00000000-0000-0000-0000-0000000000B1",
      "severity": "manualReviewRequired",
      "title": "Financial event amount conflict",
      "message": "Same id has different amounts on two devices.",
      "affectedModel": "FinancialEvent",
      "affectedRecordID": "00000000-0000-0000-0000-0000000000C7",
      "affectedField": "amount",
      "localValueSummary": "local newer",
      "cloudValueSummary": "cloud differs",
      "suggestedAction": "Review and choose a version.",
      "blocksUpload": false,
      "blocksApply": true,
      "requiresManualReview": true,
      "relatedPolicyDocument": "CloudKit_Conflict_Resolution_Strategy.md"
    }
  ],
  "financialSafetyFlags": { "hasBalanceAffectingConflicts": true, "hasResurrectionRisk": false },
  "bootstrapSection": { "bothHaveData": true, "cutoverBaselineReady": false, "backupBeforeSyncSatisfied": true },
  "safeToUpload": true,
  "safeToApply": false,
  "safeToEnableSync": false,
  "recommendations": ["Resolve 1 amount conflict for 'Groceries' on 'Main Wallet'.", "Establish cutover baseline before enabling sync."]
}
```

---

## 18. TestFlight Export Requirements

- **Export as JSON** later, for machine comparison.
- **Optional human-readable markdown summary** later, for tester feedback.
- **Redact personal/financial details where possible** — value *summaries* ("local newer"), not raw amounts, in user-facing/shared output.
- **Include counts and IDs but avoid balances** in any user-facing export.
- **Compare reports between iPhone/iPad** — deterministic ordering + stable ids so a diff is meaningful.
- **Attach to tester feedback if needed** — with financial fields redacted.

---

## 19. Recommended Next Phase

**TestFlight Sync Pilot Plan — documentation-only.**

**Why after the schema:** the pilot's core mechanic is generating this report on multiple devices, exporting it, and comparing — which is only possible once the report format is fixed. With the schema defined here, the pilot plan can specify concretely: which dry-run modes to run, what a passing report looks like (`greenReady`, `safeToApply`), how to diff iPhone vs iPad reports, redaction rules for shared diagnostics, and the exit criteria that would gate a later tiny disabled-by-default implementation step. Sequencing the pilot after the schema means the pilot has a precise artifact to produce and evaluate.

---

## 20. Do Not Do Yet

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

## 21. Verification for This Documentation Task

This file is the sole output of this task. No Swift files, test files, Xcode project files, Info.plist, entitlements, public pages, or backup schema files were modified. No feature flags were changed. Automatic CloudKit sync was not enabled. Financial calculations were not changed. Data models were not changed.
