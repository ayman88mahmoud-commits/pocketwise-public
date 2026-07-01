# Sync Recurring Relationship Audit — Documentation Report

Date: 2026-07-01
Branch: householdbudget-main
Phase: Recurring Relationship Audit — Documentation First
Status: Audit only. No production code changed. No CloudKit sync was enabled.

---

## 1. Executive Summary

Recurring relationship references **do exist** in the data model and **are included in `WalletDataSnapshot`**, but backup validation **does not currently check them**.

The recurring feature is modeled entirely **within** `FinancialEvent` — there is no separate `RecurringEvent`, `RecurringPayment`, or recurring-template model. A recurring series and its paid occurrences are both `FinancialEvent` records stored in the same `financialEvents` list:

- A **recurring series (parent)** is a `FinancialEvent` with `repeatRule != .none`. Its `id` is the series identity.
- A **paid occurrence (child)** is a `FinancialEvent` with `status == .paid`, `repeatRule == .none`, and `sourceRecurringEventID` set to the parent series `id`, plus `recurringOccurrenceYear` / `recurringOccurrenceMonth`.

The single serialized cross-record recurring reference is **`FinancialEvent.sourceRecurringEventID`** (`UUID?`), which points at a parent series `FinancialEvent.id` in the same list. This reference is **not** validated by `makeBackupValidationReport`, is **not** enforced by `validateBackupSnapshot`, and has **no** regression tests.

A real orphan path exists: `deleteFinancialEvent` removes a single event by `id` and does **not** cascade to paid occurrences, so deleting a recurring series parent leaves its paid-occurrence children with a `sourceRecurringEventID` pointing at a now-missing parent. This is a genuine relationship-integrity gap, but it is **financially harmless** — an orphaned paid occurrence remains a valid standalone paid event and its balances are unaffected.

**Conclusion:** a small read-only `.warning` coding task is warranted next (mirroring the `sourceInstallmentPlanID` pattern), not an error/blocking check.

---

## 2. Current Git State

| Property | Value |
|---|---|
| Branch | `householdbudget-main` |
| Remote tracking | `origin/householdbudget-main` |
| Latest commit | `79c6786` Document final sync relationship integrity checkpoint |
| Working tree | Clean — no uncommitted changes |
| Sync status | In sync — local matches `origin/householdbudget-main` |

*(This audit's own commit advances the latest commit beyond `79c6786`; the state above reflects the branch immediately before this document was committed.)*

---

## 3. Recurring Models Found

| Model / Type | File | Codable | In `WalletDataSnapshot` | Identity Fields | Relationship Fields |
|---|---|---|---|---|---|
| `FinancialEvent` (recurring series role) | `WalletModels.swift:465` | Yes | Yes — via `financialEvents` | `id` | `repeatRule` (marks it a series); no outbound recurring reference — it is the parent target |
| `FinancialEvent` (paid occurrence role) | `WalletModels.swift:465` | Yes | Yes — via `financialEvents` | `id` | `sourceRecurringEventID: UUID?` → parent series `id`; `recurringOccurrenceYear: Int?`; `recurringOccurrenceMonth: Int?` |
| `RecurringPaidOccurrenceIdentity` | `WalletModels.swift:459` | Yes | **No** — computed helper only (`FinancialEvent.recurringPaidOccurrenceIdentity`), never serialized as its own list | `sourceRecurringEventID`, `year`, `month` | Value-only; not a stored record |
| `RecurringScheduleOverride` | `WalletModels.swift:398` | Yes | Yes — inline inside `FinancialEvent.recurringScheduleOverrides` (array on the parent series) | `id` | None — inline value carrying `year`, `month`, `amount`, `isSkipped`; no cross-model reference |
| `RepeatRule` | `WalletModels.swift:362` | Yes | Yes — inline enum on `FinancialEvent` | n/a | Value only |
| `RecurringEndKind` | `WalletModels.swift:371` | Yes | Yes — inline optional enum on `FinancialEvent` | n/a | Value only |
| `RecurringAmountMode` | `WalletModels.swift:379` | Yes | Yes — inline optional enum on `FinancialEvent` | n/a | Value only |

**There is no separate recurring model, list, or storage key.** Recurring state lives entirely inside `FinancialEvent`. `WalletDataSnapshot` has no `recurringEvents` / `recurringPayments` field — recurring series and occurrences are ordinary `financialEvents` entries.

---

## 4. Recurring Relationship Reference Map

| Source Model | Reference Field | Target Model / List | Optional / Required | Codable / Backed Up | Current Validation | Severity | Risk if Not Validated |
|---|---|---|---|---|---|---|---|
| `FinancialEvent` (paid occurrence) | `sourceRecurringEventID` | Parent series `FinancialEvent.id` in `snapshot.financialEvents` | Optional (`UUID?`, nil for non-recurring events) | Yes — serialized | **None** — not checked in `makeBackupValidationReport`, not enforced by `validateBackupSnapshot` | n/a (unvalidated) | Orphaned paid occurrence whose parent series was deleted; dangling parent link survives restore silently. Financially harmless but invisible to the user and to sync reconciliation. |
| `FinancialEvent` (paid occurrence) | `recurringOccurrenceYear` / `recurringOccurrenceMonth` | (period key, not a record reference) | Optional | Yes — serialized | None | n/a | Low — used only for occurrence de-duplication; not a cross-record reference. |
| `FinancialEvent` (series) | `recurringScheduleOverrides[]` | inline `RecurringScheduleOverride` values | Optional | Yes — serialized inline | None needed | n/a | None — inline values with no outbound reference. |
| `RecurringPaidOccurrenceIdentity` | `sourceRecurringEventID` | Parent series `id` | Required (within the helper) | Not serialized as a record | Not applicable | n/a | None — computed helper, never persisted independently. |

**Explicit note on `FinancialEvent.sourceRecurringEventID`:** this is the one and only serialized recurring cross-record reference, it is currently unvalidated, and it is the sole candidate for a future read-only `.warning` check.

---

## 5. Current Backup Validation Coverage

**`makeBackupValidationReport(for:)` (`WalletStore.swift:2915`):** contains no reference to `sourceRecurringEventID`, `repeatRule`, or any recurring field. Recurring parent/child linkage is entirely unchecked. The function does validate other `FinancialEvent` references (amount, account, category/subcategory, `sourceInstallmentPlanID`), but not the recurring parent link.

**`validateBackupSnapshot(_:)` (`WalletStore.swift:3623`):** contains no recurring reference checks. It does not throw for an orphaned `sourceRecurringEventID`. Restore is therefore never blocked on a missing recurring parent.

**`BackupValidationTests.swift`:** contains no recurring test cases (`recurring`, `sourceRecurring`, `repeatRule` all absent). There is zero regression coverage for recurring relationships.

---

## 6. Restore / Import Safety

Orphaned recurring references **can currently be restored and imported without any block**. Because `sourceRecurringEventID` is not referenced by `validateBackupSnapshot`, a snapshot containing a paid occurrence whose parent series is absent will:

- Pass `validateBackupSnapshot` (no throw).
- Produce **no** issue in `makeBackupValidationReport` (no warning, no error).
- Restore silently via `restoreFromBackupSnapshot` / `DataBackupView` import.

This is the current, intended behavior and **is not changed by this audit**. The orphaned occurrence restores as a normal paid `FinancialEvent`; its balances and month totals are correct. The only loss is the relationship link back to a series that no longer exists — which is invisible to the user today.

---

## 7. Delete / Editing Safety

**Delete:** `deleteFinancialEvent` (`WalletStore.swift:3972`) removes exactly one event by `id` and reverses its account impact. It does **not** cascade to related paid occurrences. Deleting a recurring **series parent** therefore leaves every persisted paid occurrence (`sourceRecurringEventID == series.id`) in place with a now-dangling parent link. This is the primary way an orphaned `sourceRecurringEventID` is created in normal use.

**Marking paid:** `markRecurringOccurrencePaid` (`WalletStore.swift:1598`) creates a persisted paid `FinancialEvent` with `sourceRecurringEventID = series.id`. At creation time the parent exists, so the link is valid; it only becomes orphaned if the parent series is later deleted.

**Synthesized occurrences:** unpaid upcoming occurrences produced by `recurringOccurrenceEvent` (`WalletStore.swift:2469`) are ephemeral display objects — they are **not** persisted and **not** in the snapshot, so they cannot orphan.

**Editing:** editing a series does not change its `id`, so editing does not orphan existing paid occurrences. Only deletion of the parent series orphans children.

This section is documentation only — no delete or edit behavior is being changed.

---

## 8. Sync Risk Analysis

Recurring parent/child references matter before CloudKit true sync for several reasons:

- **Orphaned generated events:** a paid occurrence synced to another device without its parent series (deleted on one device, occurrence created on another) becomes a permanent orphan with a dangling `sourceRecurringEventID`.
- **Duplicate recurring generation:** the paid-occurrence de-dup key is `(sourceRecurringEventID, year, month)` via `paidRecurringOccurrence`. If the parent series is duplicated across devices (two series records with different `id`s), the de-dup key diverges and the same month can be paid twice.
- **Stale parent links:** after cross-device edits, a child may reference a parent `id` that was superseded, leaving the link technically valid but semantically stale.
- **Deleted recurring templates:** deleting a series on device A while device B still generates or pays occurrences produces orphaned children on merge.
- **Cross-device conflict risk:** because the relationship is a bare `UUID` with no backreference or cascade, a naive last-writer-wins merge cannot detect that a child has lost its parent. A read-only warning surfaces these cases for a human before any automated reconciliation is designed.

None of these are addressed today; they are the reason a read-only reporting layer should precede any sync work.

---

## 9. Severity Recommendation

**Recommendation: warning only.**

An orphaned `sourceRecurringEventID` does **not** corrupt restore and does **not** affect any financial calculation — the paid occurrence is a self-contained, valid paid event. Blocking restore on it would be user-hostile and would contradict the phase's non-blocking design. It should therefore be reported as a non-blocking `.warning`, exactly like `FinancialEvent.sourceInstallmentPlanID` (`"Installment event missing plan"`).

- **No issue:** rejected — the orphan is real and worth surfacing before sync.
- **Warning only:** **recommended** — surfaces the dangling link without changing restore behavior.
- **Error / blocking:** rejected — no restore corruption risk; escalation would break the established non-blocking contract.

---

## 10. Recommended Next Coding Task

**A gap exists.** Recommended small, read-only coding task:

**Task title:** Add read-only recurring relationship warning in `makeBackupValidationReport`

**Scope:** In the existing `financialEvents` loop of `makeBackupValidationReport(for:)`, add a single non-blocking `.warning` (e.g. `"Recurring occurrence missing series"`) when `event.sourceRecurringEventID` is non-nil and the referenced ID is not present in the set of `financialEvents` IDs (the parent series set). Guard on nil so ordinary non-recurring events produce no warning. Do not change `validateBackupSnapshot`. Do not change restore behavior. Add focused regression tests: valid parent series → no warning; missing parent series → `.warning` with `hasErrors == false`; nil `sourceRecurringEventID` → no warning; warning-only report does not block `restoreFromBackupSnapshot`. This mirrors the installment plan reference batch exactly.

---

## 11. Do Not Do Yet

- **Do not enable automatic CloudKit sync.** The sync gates must remain closed.
- **Do not change restore blocking behavior.** Any recurring check added later must be `.warning` severity.
- **Do not auto-repair recurring records.** Do not re-link an orphaned occurrence to a series or recreate a missing series.
- **Do not mutate or delete orphan records.** Orphaned paid occurrences must be preserved and reported, never removed.
- **Do not regenerate recurring events.** Do not synthesize or persist occurrences as part of validation.
- **Do not change the backup JSON schema.** No new fields on `WalletDataSnapshot` or `FinancialEvent`.
- **Do not change financial calculations.** Balances, runway, month totals, and paid-occurrence de-dup logic must remain unaffected.

---

## 12. Verification for This Documentation Task

This file is the sole output of this task. No Swift files, test files, Xcode project files, Info.plist, public pages, or backup schema files were modified. Automatic CloudKit sync was not enabled. Financial calculations were not changed. Data models were not changed.
