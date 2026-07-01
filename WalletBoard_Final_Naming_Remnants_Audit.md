# WalletBoard Final Naming Remnants Audit

**Date:** 2026-07-01  
**Branch:** `householdbudget-main`  
**Commit:** `d544d47` — Rename public pages to WalletBoard  
**Scope:** Documentation only. No Swift, test, Xcode, Info.plist, or HTML files were changed.

---

## 1. Executive Summary

User-facing app branding is **now correctly WalletBoard** everywhere a user can see it. The app display name, home screen label, onboarding strings, tour, backup filename, public HTML pages, and demo credit card label all say WalletBoard.

What remains of PocketWise falls into two tightly bounded categories:

1. **Internal Swift type namespace** — `PocketWiseSemanticColor`, `PocketWiseTheme`, `PocketWiseLoadingView`, `PocketWiseIconBadge`, and related types/modifiers. These names are invisible to users; they are compiler-only identifiers used in ~21 Swift files. Renaming them is a large refactor with no user-visible benefit at this time.

2. **Technical/structural Xcode identifiers** — the Xcode target is still named `PocketWise`, environment key strings used only in UI test infrastructure still carry the `POCKETWISE_` prefix, the test fixture file is still named `PocketWise-Demo-Household-TestData.json`, and the developer deployment guide (`public_pages/README.md`) still mentions PocketWise. None of these are user-visible.

No PocketWise strings remain in any user-facing UI, any exported file shown to the user, or any public web page. The product identity transition is complete from the user's perspective.

---

## 2. Current Git State

| Field | Value |
|---|---|
| Branch | `householdbudget-main` |
| Tracking branch | `origin/householdbudget-main` |
| Latest commit | `d544d47` Rename public pages to WalletBoard |
| Working tree | **Clean** |

---

## 3. Remaining PocketWise Inventory

### 3.1 Public Pages — Developer Deployment Documentation

| File | Matched Text | Context | Classification | Recommendation |
|---|---|---|---|---|
| `public_pages/README.md` | `PocketWise` (×4) | Page title, folder description, deploy instructions, "App name: PocketWise" metadata note | Developer-facing documentation | **Change now** — safe one-file text update, no code involved |

### 3.2 Xcode Project / Target / Scheme / Build Settings

| File | Matched Text | Context | Classification | Recommendation |
|---|---|---|---|---|
| `HouseholdBudget.xcodeproj/project.pbxproj` | `name = PocketWise` (target name, line 145) | Xcode app target identity; `PRODUCT_NAME = WalletBoard` is already set separately so the product output is already WalletBoard | Internal technical — Xcode | **Keep for now** — do not change without dedicated Xcode rename plan |
| `HouseholdBudget.xcodeproj/project.pbxproj` | `Build configuration list for PBXNativeTarget "PocketWise"` (line 594) | Xcode build config comment | Internal technical — Xcode | **Keep for now** |
| `HouseholdBudget.xcodeproj/project.pbxproj` | `Exceptions for "HouseholdBudget" folder in "PocketWise" target` (lines 49, 62) | Xcode excluded-sources comment | Internal technical — Xcode | **Keep for now** |
| `HouseholdBudget.xcodeproj/project.pbxproj` | `target = DF0F356B2FC8D38E00BA4BC7 /* PocketWise */` (lines 54, 235, 293, 298) | Object reference to app target | Internal technical — Xcode | **Keep for now** |
| `HouseholdBudget.xcodeproj/xcshareddata/xcschemes/HouseholdBudget.xcscheme` | `BlueprintName = "PocketWise"` (lines 20, 79, 96) | Scheme references to app target by its Xcode name | Internal technical — Xcode | **Keep for now** |

### 3.3 Swift Internal Types and View Modifiers

These identifiers appear across approximately 21 Swift source files. They are never shown to the user; they exist only at compile time.

| Swift Name | Files Affected | Context | Classification | Recommendation |
|---|---|---|---|---|
| `PocketWiseSemanticColor` | ~20 view files | Theme color enum used for icon badges, tints, UI style | Internal technical | **Keep for now** (Phase B / optional) |
| `PocketWiseTheme` | Several view files | Static theme values (card background, etc.) | Internal technical | **Keep for now** |
| `PocketWiseLoadingView` | `HouseholdBudgetApp.swift`, `PocketWiseLoadingView.swift` | Splash/loading screen struct | Internal technical | **Keep for now** |
| `PocketWiseLoadingBackground` | `PocketWiseLoadingView.swift` | Private loading animation view | Internal technical | **Keep for now** |
| `PocketWiseHub` | `PocketWiseLoadingView.swift` | Private loading hub view | Internal technical | **Keep for now** |
| `PocketWiseIconBadge` | Multiple view files | Reusable icon badge component | Internal technical | **Keep for now** |
| `PocketWiseCardStyle` | View files | Card styling type | Internal technical | **Keep for now** |
| `PocketWiseChipStyle` | View files | Chip styling type | Internal technical | **Keep for now** |
| `PocketWiseInputFieldStyle` | View files | Input field styling type | Internal technical | **Keep for now** |
| `.pocketWiseChip(...)` | View modifier call sites | SwiftUI view modifier | Internal technical | **Keep for now** |
| `.pocketWiseInputField(...)` | View modifier call sites | SwiftUI view modifier | Internal technical | **Keep for now** |

**Source files containing these Swift type usages (not exhaustive):**  
`AccountManagementView.swift`, `AddExpenseView.swift`, `AddFutureItemView.swift`, `AddInstallmentPlanView.swift`, `AddRecurringPaymentView.swift`, `AddTransferView.swift`, `BudgetPlanningCenterView.swift`, `BudgetRootView.swift`, `BudgetSharedRows.swift`, `CashTimelineView.swift`, `CategoryManagementView.swift`, `CategorySubcategoryPickerView.swift`, `CreditCardEditorView.swift`, `CreditCardsView.swift`, `DataBackupView.swift`, `PocketWiseLoadingView.swift`, `PocketWiseTheme.swift`, `RecurringMonthlyAmountsSection.swift`, `RunwayChartView.swift`, `SetupAssistantViews.swift`, `TodayDisplayPrimitives.swift`, `TodayView.swift`, `TransactionsView.swift`, `WalletRootView.swift`

### 3.4 Swift Internal Constants (UI Test Infrastructure)

These are string constants used exclusively in the UI test launch environment. They are never displayed to users.

| File | Matched Text | Context | Classification | Recommendation |
|---|---|---|---|---|
| `HouseholdBudget/HouseholdBudgetApp.swift:130` | `"POCKETWISE_UITEST_SUITE"` | Static string key for test environment variable | Internal technical — test infra | **Keep for now** — rename only as part of coordinated test refactor |
| `HouseholdBudget/HouseholdBudgetApp.swift:131` | `"POCKETWISE_UITEST_DEMO_JSON"` | Static string key for test environment variable | Internal technical — test infra | **Keep for now** |
| `HouseholdBudget/HouseholdBudgetApp.swift:144` | `"PocketWiseUITest-\(UUID())"` | Default fallback suite name used in app when running under UI tests | Internal technical — test infra | **Keep for now** |

### 3.5 Tests and Fixtures

| File | Matched Text | Context | Classification | Recommendation |
|---|---|---|---|---|
| `HouseholdBudgetTests/Fixtures/PocketWise-Demo-Household-TestData.json` | Filename itself | JSON fixture file loaded by both unit tests and UI tests via hardcoded path | Internal technical — test fixture | **Keep for now** — renaming requires updating all three path strings that reference it simultaneously |
| `HouseholdBudgetUITests/HouseholdBudgetUITests.swift:17` | `"POCKETWISE_UITEST_SUITE"` | Environment dict key — must match `HouseholdBudgetApp.swift:130` | Internal technical — test infra | **Keep for now** (paired with app-side key) |
| `HouseholdBudgetUITests/HouseholdBudgetUITests.swift:18` | `"POCKETWISE_UITEST_DEMO_JSON"` | Environment dict key — must match `HouseholdBudgetApp.swift:131` | Internal technical — test infra | **Keep for now** (paired with app-side key) |
| `HouseholdBudgetUITests/HouseholdBudgetUITests.swift:56` | `"HouseholdBudgetTests/Fixtures/PocketWise-Demo-Household-TestData.json"` | Hardcoded path to fixture — must match actual filename | Internal technical — test fixture path | **Keep for now** (tied to fixture filename) |
| `HouseholdBudgetTests/BackupValidationTests.swift:166` | `"Fixtures/PocketWise-Demo-Household-TestData.json"` | Hardcoded path to fixture | Internal technical — test fixture path | **Keep for now** (tied to fixture filename) |
| `HouseholdBudgetTests/DemoBackupFixtureTests.swift:114` | `"Fixtures/PocketWise-Demo-Household-TestData.json"` | Hardcoded path to fixture | Internal technical — test fixture path | **Keep for now** (tied to fixture filename) |

### 3.6 Historical Documentation and Audit Files

These files document past naming decisions. They mention PocketWise accurately as historical context and should not be altered retroactively.

| File | Matched Text | Classification | Recommendation |
|---|---|---|---|
| `WalletBoard_Naming_Audit.md` | PocketWise throughout | Historical audit — documents prior state | **Do not change** — historical record |
| `WalletBoard_Backup_Filename_Rename_Audit.md` | PocketWise throughout | Historical audit — references old prefix | **Do not change** — historical record |

### 3.7 User-Facing App UI Strings

A thorough search of all Swift view files confirms **no remaining user-visible PocketWise strings**. All user-facing occurrences identified in the initial naming audit have been resolved:

| Previously user-facing | Status |
|---|---|
| `"PocketWise Demo Card"` credit card label | ✅ Renamed to `"WalletBoard Demo Card"` (commit `d644186`) |
| `PocketWiseBackup-<date>.json` backup filename | ✅ Renamed to `WalletBoardBackup-<date>.json` (commit `abf14f0`) |
| public_pages HTML titles and body copy | ✅ Renamed to WalletBoard (commit `d544d47`) |

---

## 4. WalletBoard Current Coverage

| Surface | WalletBoard Present? | Source |
|---|---|---|
| App display name on home screen | ✅ Yes | `Info.plist CFBundleDisplayName = WalletBoard` |
| Xcode `PRODUCT_NAME` (main target) | ✅ Yes | `project.pbxproj` lines 449, 488 |
| Built app product | ✅ Yes | `WalletBoard.app` (lines 41, 119, 149) |
| `TEST_HOST` path in unit tests | ✅ Yes | `project.pbxproj` lines 557, 578 |
| Onboarding / QuickTour strings | ✅ Yes | `QuickTourView.swift` |
| Today screen welcome strings | ✅ Yes | `TodayView.swift` |
| Setup assistant strings | ✅ Yes | `SetupAssistantViews.swift` |
| iCloud backup description text | ✅ Yes | `WalletRootView.swift` |
| Loading screen label | ✅ Yes | `PocketWiseLoadingView.swift` |
| Credit card network tooltip | ✅ Yes | `CreditCardEditorView.swift` |
| App tagline text | ✅ Yes | `AppText.swift` |
| `appName` share/export string | ✅ Yes | `WalletStore.swift:2816` |
| Backup export filename prefix | ✅ Yes | `DataBackupView.swift` — `WalletBoardBackup-<date>.json` |
| Demo credit card label (data + test) | ✅ Yes | Fixture JSON + UITest assertion |
| `public_pages/index.html` | ✅ Yes | Page title, h1, body |
| `public_pages/privacy.html` | ✅ Yes | Page title, h1, all paragraphs |
| `public_pages/support.html` | ✅ Yes | Page title, h1, all paragraphs |
| Audit documentation files | ✅ Yes | `WalletBoard_Naming_Audit.md`, `WalletBoard_Backup_Filename_Rename_Audit.md` |

---

## 5. HouseholdBudget Current Role

HouseholdBudget remains in the following structural positions and should stay there until a dedicated Xcode rename phase is planned:

| Location | Value | Why it stays |
|---|---|---|
| Xcode project filename | `HouseholdBudget.xcodeproj` | Renaming an `.xcodeproj` requires updating every internal reference in `project.pbxproj`, all schemes, CI tooling, and any scripts — high blast radius |
| Source folder | `HouseholdBudget/` | Folder rename in Xcode requires updating group paths in `project.pbxproj` and every relative import that depends on the path |
| Bundle identifier | `com.ayman.HouseholdBudget` | Changing an existing App Store app's bundle ID requires a new App Store record or a transfer; the app's iCloud entitlements, CloudKit containers, and user data association are tied to this identifier |
| Test targets | `HouseholdBudgetUITests`, `HouseholdBudgetTests` | Dependent on bundle IDs `com.ayman.HouseholdBudgetUITests` and `com.ayman.HouseholdBudgetTests`; renaming requires coordinated changes across test plans, schemes, and CI |
| Internal documentation | `iCloud_Sync_Readiness_Audit.md` etc. | Historical record — accurate description of project structure at time of writing |

**Key insight:** `PRODUCT_NAME = WalletBoard` is already set in build settings, which means the compiled `.app`, the home screen icon label, and the App Store display name are already WalletBoard — independent of the Xcode project/target name. The HouseholdBudget project/folder name is a developer concern only and has no user-facing consequence in the current build.

---

## 6. Recommended Cleanup Plan

### Phase A — Developer Documentation (Safe now, minimal risk)

Update `public_pages/README.md` to say WalletBoard in the app name references. This is a pure markdown text file with no code dependencies.

- Change `# PocketWise GitHub Pages Content` → `# WalletBoard GitHub Pages Content`
- Change `PocketWise` in description and metadata note → `WalletBoard`
- No code, no build, no Xcode changes needed.

### Phase B — Internal Swift Type Rename (Optional, low urgency)

Rename `PocketWiseSemanticColor`, `PocketWiseTheme`, `PocketWiseLoadingView`, `PocketWiseIconBadge`, and related types/modifiers from `PocketWise` prefix to `WalletBoard` prefix.

- **Prerequisite:** All tests green; dedicated feature branch; use Xcode's built-in rename refactor (not find-replace) to safely update all call sites across ~21 files simultaneously.
- **User impact:** Zero — these are compiler-only identifiers.
- **Risk:** Medium — large change surface; if done manually, easy to miss a call site.
- **Verdict:** Acceptable to leave indefinitely. Only worth doing if the team wants internal code to match the product name, or if these types become part of a shared framework.

### Phase C — Test Infrastructure Rename (Bundle with Phase B or later)

Rename `POCKETWISE_UITEST_SUITE`, `POCKETWISE_UITEST_DEMO_JSON` environment keys and the `PocketWise-Demo-Household-TestData.json` fixture file.

- **Prerequisite:** Must rename the fixture file, both hardcoded path strings in tests (`HouseholdBudgetUITests.swift:56`, `BackupValidationTests.swift:166`, `DemoBackupFixtureTests.swift:114`), and both app-side key constants (`HouseholdBudgetApp.swift:130–131`) in a single atomic commit to avoid broken test paths.
- **Risk:** Low if done atomically; breaking if done partially.

### Phase D — Xcode Project / Target / Bundle Identifier Rename (Dedicated plan required)

Rename the Xcode target (`PocketWise` → `WalletBoard`), Xcode project (`HouseholdBudget.xcodeproj` → `WalletBoard.xcodeproj`), and source folder (`HouseholdBudget/` → `WalletBoard/`).

- **Bundle ID change** (`com.ayman.HouseholdBudget` → `com.ayman.WalletBoard`) is an **App Store breaking change** — requires either a new App Store record or a formal bundle ID migration. CloudKit containers and entitlements are tied to the current bundle ID.
- **Verdict:** Do not do this without a formal plan, a backup tag, a dedicated branch, and explicit App Store Connect decisions. The current build ships correctly as WalletBoard without this change.

---

## 7. Do Not Change Yet

- **Bundle identifier** `com.ayman.HouseholdBudget` — changing on an existing App Store app requires a new submission or formal migration
- **CloudKit containers and entitlements** — tied to current bundle ID; changing without a migration plan loses user data associations
- **Xcode project name** `HouseholdBudget.xcodeproj` — requires dedicated rename plan and backup tag
- **Xcode target name** `PocketWise` — safe to ignore; `PRODUCT_NAME = WalletBoard` already overrides what ships
- **Swift types** `PocketWiseTheme`, `PocketWiseSemanticColor`, `PocketWiseLoadingView`, `PocketWiseIconBadge`, etc. — user-invisible; rename only under Phase B with Xcode's rename refactor tool
- **Test fixture filename** `PocketWise-Demo-Household-TestData.json` — must be renamed atomically with all three path strings that reference it
- **UI test env keys** `POCKETWISE_UITEST_SUITE`, `POCKETWISE_UITEST_DEMO_JSON` — must be renamed atomically with their paired app-side constants
- **Backup JSON schema** (`WalletDataSnapshot`, `schemaVersion`) — not a naming concern; do not change
- **Restore/import logic** — no naming dependency; do not touch
- **Historical audit markdown files** — do not alter retroactively

---

## 8. Recommended Immediate Next Step

**Update `public_pages/README.md` from PocketWise to WalletBoard.**

This is the only remaining PocketWise reference that:
- Is in the `public_pages/` directory alongside the already-updated HTML files
- Represents developer-facing documentation (not compiled code or Xcode structure)
- Has zero risk — it is a plain markdown file with no dependencies
- Will be visible to any developer reading the deployment guide, which should reflect the current product name

Specific changes needed (4 occurrences):
- Heading: `# PocketWise GitHub Pages Content` → `# WalletBoard GitHub Pages Content`
- Description: `static GitHub Pages content for PocketWise` → `static GitHub Pages content for WalletBoard`
- Deploy instruction: `repository intended for PocketWise public content` → `repository intended for WalletBoard public content`
- Metadata: `App name: PocketWise` → `App name: WalletBoard`

After that, the only remaining PocketWise occurrences will be entirely internal: Xcode target name, Swift type names, and test infrastructure — all safely deferrable.

---

## 9. Key Findings Summary

| Category | Count of files | Remaining PocketWise? | Action |
|---|---|---|---|
| User-facing app UI strings | 0 | ✅ None | Complete |
| App display name / Info.plist / PRODUCT_NAME | 0 | ✅ None | Complete |
| Exported backup filename | 0 | ✅ None | Complete |
| Public HTML pages | 0 | ✅ None | Complete |
| `public_pages/README.md` | 1 | ⚠️ 4 occurrences | **Update now (Phase A)** |
| Xcode target name | 1 | ⚠️ `PocketWise` target | Keep — no user impact |
| Swift internal types/modifiers | ~21 | ⚠️ `PocketWise*` prefix | Keep — Phase B optional |
| UI test env keys + app constants | 2 | ⚠️ `POCKETWISE_*` keys | Keep — Phase C atomic |
| Test fixture filename | 1 | ⚠️ `PocketWise-Demo-*.json` | Keep — Phase C atomic |
| Historical audit docs | 2 | ⚠️ By design | Do not change |
