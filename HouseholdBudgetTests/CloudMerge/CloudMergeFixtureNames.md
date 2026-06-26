# Cloud Merge Fixture Names

All 11 P0 fixture JSON files created as of Phase 0D-3.

P0 fixtures required before live download/apply:

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

P1 fixtures to add before two-device testing:

- category-rename-transaction-old-name
- account-rename-transaction-old-name
- recurring-template-edit-paid-occurrence
- credit-card-deleted-with-purchases
- person-debt-deleted-entry-added
- equal-timestamps-high-risk
- household-settings-merge

P2 fixtures can cover retry, tombstone retention, merchant memory, and rapid multi-device edits later.
