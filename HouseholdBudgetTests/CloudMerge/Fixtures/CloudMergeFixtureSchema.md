# Cloud Merge Fixture Schema

Cloud merge fixtures are test-only inputs for future record-level sync merge tests. They are not app backup files, not `WalletDataSnapshot` exports, and not CloudKit records. They describe local record state, cloud record state, and the expected staged merge decision before any live wallet data can be changed.

Fixture JSON files should be small, readable, deterministic, and safe to share. Use fake names, fake UUIDs, and ISO-8601 date strings. Do not include real household data, real account names, real balances, or personal information.

## Top-Level Sections

- `fixtureName`: Stable fixture identifier. This should match the fixture file name without `.json`.
- `purpose`: Short explanation of the merge behavior being protected.
- `localState`: Minimal local test records needed to create the conflict or warning.
- `cloudState`: Minimal cloud-side test records needed to create the conflict or warning.
- `expectedStagedResult`: Expected non-live staging decision. This should describe whether records are blocked, quarantined, deduped, or marked for review.
- `expectedReport`: Expected conflict or warning report fields. Include severity, code, message, and referenced record IDs where useful.
- `shouldApplyLive`: Boolean gate for whether the future merge engine may apply the staged result to live wallet data.
- `safetyNotes`: Explicit statements about forbidden side effects such as posting transactions, mutating balances, marking items paid, or generating recurring records.

## Record Style

Fixture records may use simplified source-of-truth shapes instead of full production models. Include only fields required to express the merge case. If a field is omitted, the future merge test should treat it as irrelevant to that fixture.

Use stable fake UUID strings so expected reports can reference records deterministically.

## Live Apply Rule

P0 fixtures should default to `shouldApplyLive: false` unless the fixture specifically proves that live application is safe. Blocking or review-required cases must remain staged only.

## Safety Rule

Fixture parsing must not instantiate `WalletStore`, write `UserDefaults`, call CloudKit, call posting APIs, mutate balances, mark recurring items paid, or create generated recurring occurrences.
