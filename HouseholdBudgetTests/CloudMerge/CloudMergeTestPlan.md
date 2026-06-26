# Cloud Merge Test Plan

This folder is reserved for future true iCloud sync merge tests. These tests must validate merge behavior before any live CloudKit download can apply records to the wallet.

## P0 Fixture Names

- missing-account-reference
- duplicate-financial-event-id
- duplicate-recurring-paid-occurrence-identity
- account-balance-both-edited
- financial-event-paid-status-conflict
- credit-card-payment-no-double-apply
- person-debt-entry-no-double-apply
- delete-vs-edit-newer-delete
- monthly-budget-item-conflict-no-child-updated-at
- old-backup-restore-before-sync
- generated-previews-ignored

## Core Safety Rules

- Merge must stage first, not apply live directly.
- Merge must not call posting functions.
- Merge must not mutate balances through user-action APIs.
- Merge must block duplicate recurring paid occurrence identity.
- Merge must block missing required references for paid or balance-impacting records.
- Merge must keep generated previews out of sync.
- Merge must keep manual backup as safety before first live merge.

## Future Fixture Shape

Each future fixture should include:

- local wallet snapshot
- cloud records snapshot
- expected merged snapshot
- conflict report
- validation warnings
- shouldApplyLive flag

No fixture in this folder should require CloudKit networking.
