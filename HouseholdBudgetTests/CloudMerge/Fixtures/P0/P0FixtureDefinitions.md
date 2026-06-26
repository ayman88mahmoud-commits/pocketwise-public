# P0 Cloud Merge Fixture Definitions

These fixture definitions describe the minimum cases required before any future true iCloud sync engine can apply downloaded records to live wallet data. They are documentation only. They do not define CloudKit records, do not run networking, and do not apply wallet mutations.

Every P0 fixture must stage downloaded data first, validate references and duplicate identities, report conflicts or warnings, and decide whether live apply is allowed. Live apply must never call user-action posting APIs or balance mutation paths.

## missing-account-reference

Purpose: Validate that a paid or balance-impacting transaction cannot be applied when its source account is missing locally and cannot be resolved from cloud records.

Local state: The wallet has existing accounts, categories, and financial events, but does not contain the account ID referenced by the incoming paid financial event.

Cloud state: A FinancialEvent record references a missing account ID and is marked paid or otherwise balance-impacting.

Expected staged result: The cloud event is staged as blocked. It is not merged into live events and is not allowed to affect balances.

Expected conflict/warning report: Missing required account reference for a paid or balance-impacting record. User review or reference repair is required.

shouldApplyLive expected value: false.

Balance safety requirement: Do not post the event, do not mutate account balances, and do not infer a replacement account by name.

Why it is P0: Applying a paid event with a missing account can corrupt balances or attach spending to the wrong account.

## duplicate-financial-event-id

Purpose: Validate that local and cloud records with the same FinancialEvent ID merge deterministically instead of creating duplicate transactions.

Local state: A FinancialEvent exists with a stable ID and local fields.

Cloud state: A FinancialEvent exists with the same stable ID and either newer fields, older fields, or conflicting edits.

Expected staged result: The merge stages a single resulting event for that ID. If timestamps clearly determine the winner, the newer event is selected. If timestamps are missing or equal with different high-risk fields, the record is flagged for review.

Expected conflict/warning report: Duplicate FinancialEvent ID detected. Include winning side or conflict-review requirement.

shouldApplyLive expected value: true only when the winner is deterministic and non-destructive; false when high-risk fields conflict without a clear timestamp winner.

Balance safety requirement: The merged event must not be posted again. Balance-impacting effects must not be re-applied.

Why it is P0: Duplicate transactions are one of the highest-risk sync failures in a finance app.

## duplicate-recurring-paid-occurrence-identity

Purpose: Validate that paid recurring occurrences are de-duplicated by recurring identity, not only by event ID.

Local state: A paid FinancialEvent exists with sourceRecurringEventID, recurringOccurrenceYear, and recurringOccurrenceMonth.

Cloud state: Another paid FinancialEvent exists with a different ID but the same sourceRecurringEventID, recurringOccurrenceYear, and recurringOccurrenceMonth.

Expected staged result: The duplicate occurrence is blocked or requires review. The merge must not keep both paid events as separate transactions.

Expected conflict/warning report: Duplicate paid recurring occurrence identity detected for the same source recurring event and occurrence month.

shouldApplyLive expected value: false until a deterministic dedupe rule or user review resolves which paid occurrence survives.

Balance safety requirement: Do not double-apply the recurring payment. Do not create another paid transaction. Do not mark future generated previews paid.

Why it is P0: Recurring duplicates can silently double-deduct rent, subscriptions, loans, or other household commitments.

## account-balance-both-edited

Purpose: Validate high-risk conflict handling when both devices edit the same account balance.

Local state: An Account has a locally edited balance and updatedAt after the last known sync.

Cloud state: The same Account has a different balance edited on another device after the last known sync.

Expected staged result: The account is staged as a high-risk conflict. The merge should preserve both values for review instead of blindly choosing one.

Expected conflict/warning report: Account balance edited on both devices. Manual review required.

shouldApplyLive expected value: false.

Balance safety requirement: Do not adjust the live balance automatically. Do not rebuild by applying transactions during this merge.

Why it is P0: Balances are financial state. A wrong automatic winner can lose real money state.

## financial-event-paid-status-conflict

Purpose: Validate safe handling when paid/unpaid status differs between local and cloud.

Local state: A FinancialEvent exists locally with one paid status, such as unpaid planned item or paid actual transaction.

Cloud state: The same FinancialEvent ID has the opposite paid status, or a paid occurrence identity conflicts with an unpaid generated or planned version.

Expected staged result: The event is staged. A clear timestamp winner may be selected only if applying it does not require posting side effects. Otherwise it requires review.

Expected conflict/warning report: Paid status conflict for a financial event. Include local status, cloud status, timestamps, and whether the record is balance-impacting.

shouldApplyLive expected value: false for balance-impacting status flips unless a future merge engine has a safe non-posting state-merge path.

Balance safety requirement: Do not call mark-paid logic, unpay logic, posting functions, or balance mutation APIs during merge.

Why it is P0: Paid/unpaid conflicts can either hide unpaid obligations or double-apply real transactions.

## credit-card-payment-no-double-apply

Purpose: Validate that downloaded credit card payment records do not double-apply account and card balances.

Local state: A credit card payment may already exist locally, or the target card/account balances already reflect the payment.

Cloud state: A CreditCardPayment record exists for the same payment or a payment with matching identity fields.

Expected staged result: The payment is deduped or staged as a candidate merge. It is not applied through payment-posting APIs.

Expected conflict/warning report: Credit card payment requires non-posting merge; duplicate or balance-impacting payment check required.

shouldApplyLive expected value: true only for a safe record-state merge with no balance side effects; false if duplicate identity or balance impact cannot be proven safe.

Balance safety requirement: Do not decrease bank balance again and do not decrease card balance again.

Why it is P0: Credit card payments affect two sides of the wallet and are easy to double-apply.

## person-debt-entry-no-double-apply

Purpose: Validate that downloaded person debt payment/repayment entries do not double-apply wallet balances or debt totals.

Local state: A PersonDebt and its entries exist locally, possibly already including the payment or repayment.

Cloud state: A PersonDebtEntry record exists for the same debt movement or a matching debt/payment identity.

Expected staged result: The entry is deduped or staged for review. The merge must not trigger debt payment posting behavior.

Expected conflict/warning report: Person debt entry requires non-posting merge; duplicate or balance-impacting entry check required.

shouldApplyLive expected value: true only when the entry identity is unique and can be merged as record state without side effects; false when duplicate or balance impact is ambiguous.

Balance safety requirement: Do not apply cash/account movement again. Do not change debt totals through user-action APIs.

Why it is P0: Person debt records can affect both household cash and owed/receivable state.

## delete-vs-edit-newer-delete

Purpose: Validate tombstone precedence when one device deletes a record and the other edits an older copy.

Local state: A record exists locally with an edit timestamp older than the cloud deletion timestamp.

Cloud state: The same record is represented as deleted with a newer deletedAt or equivalent tombstone timestamp.

Expected staged result: The newer delete wins. The live record should be removed or marked deleted only through a safe merge path.

Expected conflict/warning report: Newer cloud delete beats older local edit. Include tombstone metadata.

shouldApplyLive expected value: true only when the delete is newer, references are safe, and deletion can be represented without posting side effects.

Balance safety requirement: Do not reverse transactions or rebalance accounts automatically during tombstone application.

Why it is P0: Delete/edit conflicts are common during sync and must not resurrect records or cause side effects.

## monthly-budget-item-conflict-no-child-updated-at

Purpose: Validate that conflicting monthly budget item edits are not silently resolved when child items lack independent updatedAt metadata.

Local state: A WalletMonthlyBudget contains a category/item amount edited locally.

Cloud state: The same month/category budget item has a different amount edited on another device.

Expected staged result: The monthly budget item conflict is staged for review or resolved only at the parent budget level if metadata supports it.

Expected conflict/warning report: Monthly budget item conflict cannot be safely resolved without child updatedAt metadata.

shouldApplyLive expected value: false when both sides changed and no reliable child timestamp exists.

Balance safety requirement: Budget changes must not mutate account balances or transactions.

Why it is P0: Budget item conflicts can silently change the household plan if resolved incorrectly.

## old-backup-restore-before-sync

Purpose: Validate that a device restored from an old manual backup cannot overwrite newer cloud records without review.

Local state: The wallet appears valid but contains older data restored from a backup and may have stale timestamps or missing sync metadata.

Cloud state: Cloud records contain newer wallet state from another device.

Expected staged result: The merge blocks broad overwrite behavior and stages a review warning before any live apply.

Expected conflict/warning report: Local data may be restored from an old backup. First merge requires backup and review before applying.

shouldApplyLive expected value: false.

Balance safety requirement: Do not replace current cloud-backed financial state from an old local snapshot automatically.

Why it is P0: Old backup restore is a realistic recovery path and can otherwise erase newer iPhone/iPad data.

## generated-previews-ignored

Purpose: Validate that generated recurring previews, forecast outputs, credit card due rows, and other derived UI items are never synced as source-of-truth records.

Local state: The wallet can generate future recurring previews, planned rows, forecast outputs, or derived due rows from persisted source records.

Cloud state: Incoming records include generated-preview-like data or records without persisted source identity.

Expected staged result: Generated previews are ignored or blocked from live apply. Only persisted templates, actual transactions, and saved source records are candidates for merge.

Expected conflict/warning report: Generated or derived record ignored because previews must not be synced.

shouldApplyLive expected value: false for generated preview records.

Balance safety requirement: Do not create transactions from previews and do not mark generated future items paid during sync.

Why it is P0: Syncing generated previews can create fake obligations, duplicate future rows, or paid transactions that were never user-confirmed.
