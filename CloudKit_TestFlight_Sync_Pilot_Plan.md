# CloudKit TestFlight Sync Pilot Plan

Date: 2026-07-01
Branch: householdbudget-main
Phase: CloudKit Sync Preflight - TestFlight Sync Pilot Plan
Status: Documentation only. Automatic CloudKit sync remains disabled and must stay disabled.

---

## 1. Executive Summary

This document defines a safe TestFlight pilot plan for CloudKit sync-readiness validation and future disabled-by-default sync testing. The pilot is designed to validate dry-run reports, backup-first readiness, diagnostic export, and cross-device comparison before any real record-level sync behavior is allowed.

This plan does **not** enable CloudKit sync. It does not flip `WalletSyncFeatureFlags`, does not enable the persisted `WalletSyncMasterDataAutoSyncGate`, and does not authorize upload, download, apply, token, or zone writes. The active safe cloud workflow remains manual backup/import/export and the existing whole-snapshot iCloud backup path.

---

## 2. Current Git State

| Property | Value |
|---|---|
| Branch | `householdbudget-main` |
| Tracking branch | `origin/householdbudget-main` |
| Latest commit before this document | `a1021d5` Document CloudKit dry-run report schema |
| Working tree status before this document | Clean |
| Sync status with origin before this document | In sync with `origin/householdbudget-main` |

This document's commit advances the branch beyond `a1021d5`; the table records the verified state before creating this file.

---

## 3. Pilot Scope

Included:
- Dry-run validation planning and future dry-run report generation.
- Readiness reports using the schema from `CloudKit_Dry_Run_Report_Schema.md`.
- Manual backup-first workflow before any sync-related pilot step.
- Controlled tester rollout: developer only first, then one trusted family device pair, then a small external TestFlight group later.
- Cross-device iPhone/iPad report comparison.
- Safe diagnostic collection with redaction.
- Sync paused and rollback instructions.

Excluded:
- No automatic CloudKit sync.
- No destructive mutation.
- No live multi-device merge.
- No real record-level upload/apply/download unless a later disabled-by-default phase explicitly allows it.
- No token writes, zone writes, or CloudKit record mutation in the dry-run phases.
- No changes to backup JSON schema, restore/import/export behavior, financial calculations, or data models.

---

## 4. Pilot Goals

- Validate whether dry-run reports are useful to a human tester and machine-checkable for release gating.
- Confirm the backup-before-sync UX is clear and practical.
- Identify conflict, resurrection, tombstone, name-reference, duplicate-name, subcategory, payment-method, and recurring risks before any sync writes.
- Compare iPhone and iPad readiness reports for the same Apple ID scenario.
- Collect safe diagnostics: counts, readiness state, severity summaries, anonymized IDs, and issue titles.
- Avoid data loss, record resurrection, duplicate transactions, or double-apply of financial data.
- Define clear stop/go gates before any future implementation step.

---

## 5. Pilot Non-Goals

- Not enabling automatic CloudKit sync.
- Not testing live multi-device record merge yet.
- Not testing destructive deletes.
- Not replacing the manual backup/import/export workflow.
- Not changing the backup schema.
- Not changing data models or adding migration fields.
- Not changing financial calculations or posting behavior.
- Not adding app warnings or tests in this phase.

---

## 6. Tester Selection

| Group | Entry Criteria | Risk Level | Allowed Activity |
|---|---|---|---|
| Developer only | Local development devices, latest manual backup exported, report schema reviewed | Low | Documentation review, future dry-run-only validation, no sync writes |
| One trusted family device pair | One iPhone and one iPad on the same Apple ID, fresh manual backup, clear rollback path | Medium | Dry-run report generation and cross-device comparison only |
| Limited external TestFlight group later | Developer and family pair pass, diagnostics export works, no red reports, rollback instructions proven | Medium-high | Dry-run readiness validation only; no automatic sync |

No tester group may enter a phase that performs record-level upload/apply/download unless a later, separate, disabled-by-default implementation phase is approved and committed.

---

## 7. Required Pre-Pilot Checklist

Before any tester participates:
- Latest manual JSON backup is exported and saved outside the app.
- Backup validation has no `.error` issues.
- Dry-run report, once available, is `greenReady` or `yellowReviewRequired` only.
- No `redBlocked` report.
- No `forbiddenDestructiveAction`.
- No balance-affecting conflict.
- No resurrection risk.
- No unreviewed manual backup import risk.
- iCloud account availability is documented.
- Same Apple ID scenario is documented for iPhone/iPad testing.
- Device pair is documented: model, OS version, app build, and TestFlight build number.
- Rollback instructions are available before testing starts.
- Sync feature flags remain off.
- Persisted sync gate remains off.

---

## 8. Pilot Phases

| Phase | Name | Allowed Work | Exit Criteria |
|---|---|---|---|
| Phase 0 | Documentation readiness only | Review policy stack and this pilot plan | All docs agree: no sync enablement, dry-run first |
| Phase 1 | Dry-run report generation only | Future report generation from local state without mutation | Reports export with schema fields and no sensitive raw values |
| Phase 2 | Cross-device dry-run comparison | Generate reports on iPhone and iPad, compare counts/readiness/issues | Differences are explainable; no red/forbidden outcomes |
| Phase 3 | Disabled-by-default sync diagnostics only | Future diagnostics behind existing flags, still no upload/apply/token writes | Diagnostics prove CloudKit availability and gate state safely |
| Phase 4 | Tiny opt-in record-level smoke test only after future approval | Separately approved, disabled-by-default, narrow record path | No duplicates, no financial mutation surprise, rollback proven |
| Phase 5 | Broader TestFlight pilot only after successful smoke test | Small external group with strict gates | Stable results across multiple device pairs |

Phase 4 and Phase 5 are not authorized by this document. They require separate review, implementation, commit, and explicit approval.

---

## 9. Dry-Run Report Collection

Testers generate:
- Local readiness report.
- Backup validation summary.
- CloudKit availability and feature-gate state.
- Merge bucket summary.
- Tombstone/deletion risk summary.
- UUID/name reference risk summary.
- Recurring risk summary.
- Bootstrap state summary.

Reports are generated:
- Before any sync-related pilot action.
- After exporting a fresh manual backup.
- On both iPhone and iPad during cross-device comparison.
- After a manual backup import, only if the pilot explicitly includes import-risk review.

Reports are exported:
- As JSON for machine comparison.
- Optionally as markdown for tester-readable summaries.
- With deterministic ordering and stable IDs.
- With redaction applied before sharing outside the developer.

Must redact or avoid:
- Real balances.
- Transaction notes.
- Personal account names where possible.
- Sensitive merchant or financial details.
- Raw CloudKit payload values.

iPhone/iPad comparison should check:
- Same readiness state or explainable difference.
- Similar model counts or explainable baseline difference.
- Same hard blockers, if any.
- No `redBlocked`, `forbiddenDestructiveAction`, resurrection, or balance-affecting conflict.

Readiness indicators:
- `greenReady`: eligible to proceed to the next dry-run-only phase.
- `yellowReviewRequired`: proceed only after documented review; no apply.
- `redBlocked`: stop the pilot.
- `grayNotAvailable`: resolve availability/gate/setup before continuing.

---

## 10. Safety Gates

Hard gates:
- `WalletSyncFeatureFlags.isAutomaticCloudKitSyncEnabled` must remain `false`.
- `WalletSyncFeatureFlags.isDeveloperCloudKitRecordSyncOverrideEnabled` must remain `false`.
- `WalletSyncFeatureFlags.canRunDeveloperCloudKitRecordSync` must remain `false`.
- `WalletSyncMasterDataAutoSyncGate` must remain off.
- No `redBlocked` report.
- No `forbiddenDestructiveAction`.
- No balance-affecting conflict.
- No resurrection risk.
- No delete-vs-update risk on balance-affecting records.
- No unreviewed manual backup import.
- No missing manual backup before pilot.
- No unexplained duplicate semantic transaction risk.
- No account/category/card deleted while still referenced.
- No tester proceeds without rollback instructions.

If any hard gate fails, the pilot stops.

---

## 11. Rollback Plan

If a failure occurs:
1. Stop the pilot immediately.
2. Keep sync disabled.
3. Do not flip flags or gates to investigate.
4. Do not attempt auto-repair.
5. Preserve and archive dry-run reports.
6. Capture screenshots and tester notes.
7. Restore from the latest manual backup only if the tester's visible app state is wrong or unsafe.
8. Document the incident before continuing.
9. Resume only after the root cause is understood and a separate reviewed plan exists.

Rollback is manual and user-confirmed. The pilot does not authorize automatic restore, repair, delete, merge, or CloudKit reset behavior.

---

## 12. User-Facing UX Requirements

Future pilot UX should include:
- Sync Readiness screen.
- Backup-before-sync prompt.
- Readiness color state: green, yellow, red, gray.
- Clear issue list grouped by severity.
- Export diagnostics button.
- Sync paused state.
- Rollback instructions.
- Plain-language description that dry-run/reporting does not change data.
- Clear distinction between manual backup and record-level sync.

The UX must not expose dangerous TestFlight-facing controls such as force upload, force sync, reset zone, purge, seed, token reset, or CloudKit record editing.

---

## 13. Diagnostic Data Policy

Can collect:
- Model counts.
- Anonymized record IDs.
- Severity summaries.
- Issue titles.
- Readiness states.
- Merge bucket counts.
- Feature flag and gate state.
- CloudKit availability state.
- Device class and OS version.
- App/TestFlight build number.

Should not collect:
- Real balances.
- Transaction notes.
- Full transaction descriptions.
- Personal account names where avoidable.
- Sensitive financial details.
- Raw CloudKit records.
- Full backup JSON files unless explicitly needed and privately handled.

Shared diagnostics should use summaries, not raw values.

---

## 14. Acceptance Criteria

Before moving beyond dry-run:
- No blocking issues on developer devices.
- Rollback instructions are tested and understandable.
- Manual backup export/import review flow is confirmed unchanged.
- Dry-run reports compare consistently across iPhone and iPad.
- Backup-first flow is confirmed before every sync-related pilot step.
- No unexplained merge classifications remain.
- No resurrection, forbidden destructive, or balance-affecting conflict remains unresolved.
- All critical risks are documented.
- Testers understand that sync is not enabled.
- Diagnostics can be exported without exposing sensitive financial details.

---

## 15. Failure Criteria

Stop the pilot if:
- Any data mutation happens unexpectedly.
- Any CloudKit feature flag is flipped unintentionally.
- The persisted auto-sync gate is enabled unintentionally.
- Restore/import behavior changes.
- Manual JSON backup/export/import becomes unavailable or altered.
- Any financial total changes unexpectedly.
- Any `redBlocked` report appears.
- Any `forbiddenDestructiveAction` appears.
- Any resurrection risk appears.
- Any balance-affecting conflict appears without a documented manual review path.
- Tester confusion appears around backup, restore, or sync safety.
- Diagnostics expose sensitive financial data.

---

## 16. Next Implementation Gate

If a future implementation step is ever approved, it must be:
- Tiny.
- Disabled by default.
- Behind existing feature flags.
- Dry-run only first.
- No upload writes.
- No apply writes.
- No token writes.
- No zone writes.
- No backup schema changes.
- No financial calculation changes.
- Reviewed and committed separately.

The first implementation step should prove report generation/export only. Any move toward live record sync must be a later, separately approved phase.

---

## 17. Recommended Next Phase

**Create a final CloudKit Preflight Consolidation Checkpoint — documentation-only.**

That checkpoint should summarize the full CloudKit preflight planning stack:
- Roadmap review.
- Conflict resolution strategy.
- Deletion/tombstone strategy.
- Bootstrap policy.
- UUID/name-based reference migration decision.
- Dry-run validation mode design.
- Dry-run report schema.
- This TestFlight sync pilot plan.

The checkpoint should decide whether to pause, continue documentation, or proceed to a tiny disabled-by-default dry-run implementation. It should not enable sync.

---

## 18. Do Not Do Yet

- Do not enable CloudKit sync.
- Do not flip feature flags.
- Do not enable the persisted sync gate.
- Do not change entitlements.
- Do not change CloudKit containers.
- Do not change upload/download/apply/token/zone logic.
- Do not change restore blocking behavior.
- Do not auto-repair or mutate data.
- Do not change the backup schema.
- Do not change financial calculations.
- Do not change data models.
- Do not change manual backup/import/export behavior.
- Do not merge with the GitHub `main` branch. This work stays on `householdbudget-main`.

---

## 19. Verification for This Documentation Task

This file is the sole intended output of this task. No Swift files, test files, Xcode project files, Info.plist, entitlements, public pages, backup schema files, or restore/import/export behavior should be modified. No feature flags should be changed. Automatic CloudKit sync should not be enabled. Financial calculations and data models should remain untouched.
