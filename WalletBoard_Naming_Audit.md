# WalletBoard Naming Audit

**Date:** 2026-06-30  
**Branch:** `householdbudget-main`  
**Commit:** `cf16902` — Document sync safety preflight foundation checkpoint  
**Scope:** Documentation only. No Swift, Xcode, Info.plist, or data files were changed.

---

## 1. Executive Summary

**WalletBoard** is the chosen, App-Store-verified, final user-facing product name. It is already set as the app display name (`CFBundleDisplayName = WalletBoard`, `PRODUCT_NAME = WalletBoard`) and appears consistently in user-visible UI strings across the main app.

Two historical names remain embedded in the codebase:

- **HouseholdBudget** — the Xcode project name, folder name, bundle identifier, and test-target names. These are deeply structural and safe to leave in place indefinitely while the user-facing product name is already WalletBoard.
- **PocketWise** — an earlier product name that persists in: the Xcode target name, a large family of Swift type names (`PocketWiseSemanticColor`, `PocketWiseTheme`, `PocketWiseLoadingView`, `PocketWiseIconBadge`, view-modifier extensions), the backup file name shown in Files.app, the public web pages, and one UI test label (`"PocketWise Demo Card"`).

The immediate risk is **not** that users see the wrong product name on the home screen (that is already fixed). The risk is that PocketWise leaks into user-visible surfaces: the iCloud backup filename saved to Files.app, the demo credit card label visible in UI tests (and therefore potentially in the live app), and the public web pages. These require controlled cleanup.

---

## 2. Current Git State

| Field | Value |
|---|---|
| Branch | `householdbudget-main` |
| Tracking branch | `origin/householdbudget-main` |
| Latest commit | `cf16902` Document sync safety preflight foundation checkpoint |
| Working tree | **Clean** (no uncommitted changes before this audit file) |

---

## 3. Name Policy Recommendation

| Name | Role | Policy |
|---|---|---|
| **WalletBoard** | Final user-facing app/product/App Store name | Use exclusively in all user-visible strings, UI text, onboarding, and marketing |
| **HouseholdBudget** | Xcode project name, source folder, bundle identifier, test targets | Keep as-is indefinitely; rename only in a dedicated, planned Xcode rename phase |
| **PocketWise** | Historical Xcode target name; Swift type namespace; backup filename; public web pages | Do not expose to end users; phase out gradually — see Phase Plan below |
| **Wallet / WalletStore / WalletRoot** | Internal Swift model and service naming | Acceptable for now; no rename needed unless a deliberate refactor is planned |

---

## 4. Occurrence Inventory

### 4.1 User-Facing App UI Strings

These are strings directly visible to the user inside the app.

| File | Line(s) | Matched Name | Context | Classification | Recommendation |
|---|---|---|---|---|---|
| `HouseholdBudget/TodayView.swift` | 1164, 1216, 1220 | WalletBoard | "Welcome to WalletBoard", "Continue setting up WalletBoard", onboarding description | User-facing ✅ | Correct — keep |
| `HouseholdBudget/QuickTourView.swift` | 31, 33, 287, 573 | WalletBoard | Tour body text EN + AR, Label("WalletBoard", ...) | User-facing ✅ | Correct — keep |
| `HouseholdBudget/SetupAssistantViews.swift` | 134, 690 | WalletBoard | "Set up WalletBoard", setup description | User-facing ✅ | Correct — keep |
| `HouseholdBudget/WalletRootView.swift` | 1019, 1020 | WalletBoard | iCloud backup description text EN + AR | User-facing ✅ | Correct — keep |
| `HouseholdBudget/PocketWiseLoadingView.swift` | 6, 48 | WalletBoard | "Preparing your WalletBoard hub", loading label | User-facing ✅ | Correct — keep |
| `HouseholdBudget/CreditCardEditorView.swift` | 145 | WalletBoard | "WalletBoard uses a generic card icon..." tooltip | User-facing ✅ | Correct — keep |
| `HouseholdBudget/AppText.swift` | 61 | WalletBoard | "WalletBoard helps you plan your money clearly" | User-facing ✅ | Correct — keep |
| `HouseholdBudget/WalletStore.swift` | 2816 | WalletBoard | `appName: "WalletBoard"` (likely used in share/export text) | User-facing ✅ | Correct — keep |
| `HouseholdBudgetUITests/HouseholdBudgetUITests.swift` | 44 | PocketWise Demo Card | `XCTAssertTrue(app.staticTexts["PocketWise Demo Card"]...)` — asserts a label visible in the app UI | **User-facing ⚠️** | The demo credit card inside the app has label "PocketWise Demo Card" — **change to "WalletBoard Demo Card" in Phase 1** (requires updating both the UI string and this test assertion together) |
| `HouseholdBudget/DataBackupView.swift` | 9, 256 | PocketWiseBackup | `backupFileName = "PocketWiseBackup.json"` and `"PocketWiseBackup-<date>.json"` — the filename saved to iCloud / Files.app, visible to the user | **User-facing ⚠️** | Change to `WalletBoardBackup-<date>.json` in Phase 1 — **but verify restore logic is filename-agnostic before changing** |

### 4.2 App Display Name / Info.plist / Build Settings

| File | Key / Line | Value | Classification | Recommendation |
|---|---|---|---|---|
| `HouseholdBudget/Info.plist` | `CFBundleDisplayName` | `WalletBoard` ✅ | App display name | Correct — keep |
| `HouseholdBudget.xcodeproj/project.pbxproj` | line 449, 488 | `PRODUCT_NAME = WalletBoard` | Main target build setting | Correct — keep |
| `HouseholdBudget.xcodeproj/project.pbxproj` | line 448, 487 | `PRODUCT_BUNDLE_IDENTIFIER = com.ayman.HouseholdBudget` | Bundle ID | Technical — do not change yet |
| `HouseholdBudget.xcodeproj/project.pbxproj` | line 41 | `WalletBoard.app` (built product ref) | Build artifact name | Correct — keep |
| `HouseholdBudget.xcodeproj/project.pbxproj` | lines 508, 528, 509, 529, 550, 570 | `PRODUCT_NAME = "$(TARGET_NAME)"` (test targets) | Test target build names | Technical — keep |

### 4.3 Xcode Project / Target / Scheme / Folder References

| File / Path | Name | Classification | Recommendation |
|---|---|---|---|
| `HouseholdBudget.xcodeproj/` | Xcode project file name | Technical — structural | Do not rename (Phase 4 only if needed) |
| `HouseholdBudget/` | Source folder name | Technical — structural | Do not rename |
| `HouseholdBudget.xcodeproj/project.pbxproj` line 129, 145 | `name = PocketWise` (app target name) | Technical — Xcode target | Do not rename (Phase 4 only if needed) |
| `HouseholdBudget.xcodeproj/project.pbxproj` line 148 | `productName = HouseholdBudget` | Technical — Xcode | Do not rename |
| `HouseholdBudget.xcodeproj/project.pbxproj` line 152, 168, 175, 191 | `HouseholdBudgetUITests`, `HouseholdBudgetTests` targets | Technical — test targets | Do not rename |
| `HouseholdBudget.xcodeproj/xcshareddata/xcschemes/HouseholdBudget.xcscheme` | Scheme name, `BlueprintName = "PocketWise"` | Technical — Xcode | Do not rename |
| `HouseholdBudget.xcodeproj/xcshareddata/xcschemes/HouseholdBudgetTests.xcscheme` | Tests scheme | Technical — Xcode | Do not rename |
| `HouseholdBudget.xcodeproj/project.pbxproj` line 49 | `Exceptions for "HouseholdBudget" folder in "PocketWise" target` | Technical — Xcode comment | Do not change |

### 4.4 Documentation Files

| File | Occurrences | Names Found | Classification | Recommendation |
|---|---|---|---|---|
| `iCloud_Sync_Readiness_Audit.md` | Multiple | HouseholdBudget | Documentation — internal | Update incrementally in Phase 2 |
| `Hard_Delete_Safety_Implementation_Plan.md` | Multiple | HouseholdBudget, WalletBoard | Documentation — internal | Update incrementally in Phase 2 |
| `Sync_Safety_Preflight_Foundation_Checkpoint.md` | Multiple | HouseholdBudget | Documentation — internal | Update incrementally in Phase 2 |
| `Sync_Metadata_Foundation_Audit.md` | Multiple | HouseholdBudget | Documentation — internal | Update incrementally in Phase 2 |
| `Sync_Preflight_Validation_Plan.md` | Multiple | HouseholdBudget | Documentation — internal | Update incrementally in Phase 2 |

### 4.5 GitHub / Repo / Public Page References

| File | Occurrences | Name | Classification | Recommendation |
|---|---|---|---|---|
| `public_pages/index.html` | Title, h1, body, nav | PocketWise | **Public-facing ⚠️** | Change to WalletBoard in Phase 2 |
| `public_pages/privacy.html` | App name references | PocketWise | **Public-facing ⚠️** | Change to WalletBoard in Phase 2 |
| `public_pages/support.html` | App name references | PocketWise | **Public-facing ⚠️** | Change to WalletBoard in Phase 2 |
| `public_pages/README.md` | App name references | PocketWise | Documentation | Change to WalletBoard in Phase 2 |

### 4.6 Backup / Export / Import Wording

| File | Line | Name | User Visible? | Classification | Recommendation |
|---|---|---|---|---|---|
| `HouseholdBudget/DataBackupView.swift` | 9, 256 | `PocketWiseBackup.json`, `PocketWiseBackup-<date>.json` | **Yes — appears in iCloud / Files.app** | **Risky ⚠️** | Change to `WalletBoardBackup-<date>.json` in Phase 1 only after confirming restore logic is not filename-dependent |

### 4.7 Tests

| File | Occurrences | Name | Classification | Recommendation |
|---|---|---|---|---|
| `HouseholdBudgetUITests/HouseholdBudgetUITests.swift` | Lines 17–18 | `POCKETWISE_UITEST_SUITE`, `POCKETWISE_UITEST_DEMO_JSON` | Internal — env keys | Keep for now; rename in Phase 4/5 only with coordinated refactor |
| `HouseholdBudgetUITests/HouseholdBudgetUITests.swift` | Line 44 | `"PocketWise Demo Card"` | **Tests a user-visible label ⚠️** | Change in Phase 1 together with the live credit card label |
| `HouseholdBudgetUITests/HouseholdBudgetUITests.swift` | Line 56 | `HouseholdBudgetTests/Fixtures/PocketWise-Demo-Household-TestData.json` | Internal — file path | Keep; rename only with fixture file rename in Phase 4/5 |
| `HouseholdBudgetTests/Fixtures/PocketWise-Demo-Household-TestData.json` | Filename | PocketWise | Internal — test fixture | Do not rename yet |
| `HouseholdBudgetTests/WalletStoreFinancialInvariantTests.swift` | Various | WalletBoard (in assertions/comments) | Internal — tests | Correct — keep |
| `HouseholdBudgetTests/BackupValidationTests.swift` | Various | PocketWise, WalletBoard | Internal — tests | Keep for now |
| `HouseholdBudgetTests/DemoBackupFixtureTests.swift` | Various | PocketWise, WalletBoard | Internal — tests | Keep for now |
| All `HouseholdBudgetTests/CloudMerge/WalletSync*.swift` | Various | WalletBoard in assertions | Internal — tests | Correct — keep |

### 4.8 Internal Swift Type Names and Model / Service Names

These are **not user-visible** but are pervasive throughout the codebase (~21 Swift files).

| Swift Name | Where Used | Classification | Recommendation |
|---|---|---|---|
| `PocketWiseSemanticColor` | ~20 Swift view files | Internal — theme type | Do not rename yet (Phase 5) |
| `PocketWiseTheme` | View files, backgrounds | Internal — theme type | Do not rename yet (Phase 5) |
| `PocketWiseLoadingView` | Loading screen | Internal — view type | Do not rename yet (Phase 5) |
| `PocketWiseLoadingBackground` | Loading screen | Internal — private view | Do not rename yet (Phase 5) |
| `PocketWiseHub` | Loading screen | Internal — private view | Do not rename yet (Phase 5) |
| `PocketWiseIconBadge` | Many views | Internal — component | Do not rename yet (Phase 5) |
| `.pocketWiseChip(...)` | View modifier extension | Internal — modifier | Do not rename yet (Phase 5) |
| `.pocketWiseInputField(...)` | View modifier extension | Internal — modifier | Do not rename yet (Phase 5) |
| `WalletStore` | Central data store | Internal — model | Acceptable — keep |
| `WalletRootView` | Root navigation view | Internal — view | Acceptable — keep |
| `POCKETWISE_UITEST_SUITE` | UI test env key | Internal — test infra | Keep for now |
| `POCKETWISE_UITEST_DEMO_JSON` | UI test env key | Internal — test infra | Keep for now |

---

## 5. Safe Rename Plan

### Phase 1 — User-Facing Text Only (Highest Priority, Lowest Risk)

Change only strings that a user can directly read or observe.

| Item | File | Change |
|---|---|---|
| Demo credit card label | Wherever the card data is seeded / defined | `"PocketWise Demo Card"` → `"WalletBoard Demo Card"` |
| UI test assertion | `HouseholdBudgetUITests/HouseholdBudgetUITests.swift:44` | Update to match new label |
| Backup filename | `HouseholdBudget/DataBackupView.swift:9,256` | `PocketWiseBackup` → `WalletBoardBackup` — **only after confirming restore logic is filename-agnostic** |

> **Pre-condition for backup rename:** Read `DataBackupView.swift` restore path to confirm it matches files by content/format, not by filename prefix. If restore relies on the `PocketWise` prefix, add a backward-compat read path first.

### Phase 2 — Documentation / Public Pages / Support Pages

Update public-facing pages and internal markdown docs.

| Item | Files |
|---|---|
| Public website name | `public_pages/index.html`, `privacy.html`, `support.html`, `README.md` — change "PocketWise" → "WalletBoard" throughout |
| Internal docs | `iCloud_Sync_Readiness_Audit.md`, `Sync_*.md`, `Hard_Delete_*.md` — update references to HouseholdBudget/PocketWise in headings and prose |

### Phase 3 — App Store Metadata

Update App Store Connect listing, screenshots, keywords, and support URL to use WalletBoard consistently.

### Phase 4 — Optional Xcode Target / Project / Folder Rename

Only if needed for App Store submission clarity or team onboarding.

| Risk | Notes |
|---|---|
| **High** | Renaming Xcode targets and the `.xcodeproj` file requires updating every reference in `project.pbxproj`, all schemes, CI scripts, and any external tooling |
| **Prerequisite** | Full Xcode project backup + dedicated branch; test suite must pass before and after |
| **Targets to rename** (if proceeding) | `PocketWise` target → `WalletBoard`; `HouseholdBudgetUITests` → `WalletBoardUITests`; `HouseholdBudgetTests` → `WalletBoardTests` |
| **Bundle ID** | `com.ayman.HouseholdBudget` → `com.ayman.WalletBoard` — this is an **App Store breaking change** requiring a new app record or a transfer; do not do this casually |

### Phase 5 — Optional Internal Swift Type Rename

Only if the team decides internal code consistency is worth the effort.

| Risk | Notes |
|---|---|
| **Medium** | `PocketWiseSemanticColor`, `PocketWiseTheme`, `PocketWiseIconBadge`, `.pocketWiseChip`, `.pocketWiseInputField` appear in ~21 Swift files |
| **Approach** | Use Xcode rename refactor (not find-replace) to safely update all call sites |
| **Prerequisite** | All tests green; Phase 1–4 complete |

---

## 6. Do Not Change Yet

The following must **not** be changed without a dedicated, planned rename phase:

- [ ] Xcode project file name (`HouseholdBudget.xcodeproj`)
- [ ] Xcode target names (`PocketWise`, `HouseholdBudgetUITests`, `HouseholdBudgetTests`)
- [ ] Xcode scheme names
- [ ] Source folder name (`HouseholdBudget/`)
- [ ] Bundle identifier (`com.ayman.HouseholdBudget`) — changing this on an existing App Store app requires a new submission record
- [ ] Swift model and store class names (`WalletStore`, `WalletRootView`, `PocketWiseSemanticColor`, etc.)
- [ ] Test fixture filename (`PocketWise-Demo-Household-TestData.json`)
- [ ] UI test environment key names (`POCKETWISE_UITEST_SUITE`, `POCKETWISE_UITEST_DEMO_JSON`)
- [ ] CloudKit container references or entitlements
- [ ] Backup file format or restore behavior (read-path backward compatibility)
- [ ] GitHub remote URL or repo name
- [ ] Any merge to `main` until changes are reviewed on `householdbudget-main`

---

## 7. Recommended Immediate Next Step

**Phase 1 only:** Change the demo credit card label and backup filename prefix — the two places where PocketWise is currently user-visible inside the app.

Specifically:
1. Find where the demo credit card name `"PocketWise Demo Card"` is defined as data (likely in `WalletStore.swift` or a fixture seed) and change it to `"WalletBoard Demo Card"`.
2. Update the UI test assertion at `HouseholdBudgetUITests/HouseholdBudgetUITests.swift:44` in the same commit.
3. Read the restore logic in `DataBackupView.swift` to confirm filename independence, then rename `PocketWiseBackup` → `WalletBoardBackup` in a separate, isolated commit.

Do all three changes on `householdbudget-main`. Run the full test suite after each change. Do not change anything else until Phase 1 is verified in the app.

---

## 8. Key Findings Summary

| Finding | Severity | Status |
|---|---|---|
| `CFBundleDisplayName` is already `WalletBoard` | — | ✅ Correct |
| `PRODUCT_NAME` is already `WalletBoard` | — | ✅ Correct |
| User-facing UI strings (onboarding, tour, settings) already say WalletBoard | — | ✅ Correct |
| Xcode target name is still `PocketWise` | Low | ⏳ Keep for now |
| Bundle ID is still `com.ayman.HouseholdBudget` | Low | ⏳ Keep — do not change without App Store plan |
| `"PocketWise Demo Card"` label visible in live app UI | **Medium** | ⚠️ Fix in Phase 1 |
| Backup filename `PocketWiseBackup-<date>.json` visible in Files.app | **Medium** | ⚠️ Fix in Phase 1 (verify restore first) |
| Public pages (`public_pages/`) still say PocketWise throughout | **Medium** | ⚠️ Fix in Phase 2 |
| `PocketWiseSemanticColor`, `PocketWiseTheme`, etc. — ~21 Swift files | Low | ⏳ Phase 5 / optional |
| Internal docs reference HouseholdBudget as project name | Low | ⏳ Phase 2 / optional |
