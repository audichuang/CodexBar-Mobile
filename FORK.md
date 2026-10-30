# FORK.md: how this fork stays rebasable

This file is fork-owned. `AGENTS.md` belongs to upstream (do not edit it for fork rules; put rules here). Read this before changing any code in this repo.

The fork is a short stack of commits rebased onto each upstream release tag. A change is cheap to carry only if upstream's files barely differ. Everything below exists to keep that diff small, explicit and machine-checked.

## Rules

1. Fork code lives in fork-owned files. A file is fork-owned when it does not exist in the base tag. Allowed shapes: `*+Fork*.swift`, `*+Accounts.swift`, `Fork*.swift`, `Scripts/fork/`, `fork/`, `version.fork.env`, `CHANGELOG.fork.md`, `.github/README.md`, `CodexBarMobile/Config/Fork.xcconfig`, fork-only workflows, `Tests/**/*Fork*`.
2. An upstream-owned file may differ only through a declared hook: a call, a `source` line, a stored property, a `configFiles:` entry, an identity-constant swap. Each one is a row in `fork/footprint.tsv` with a line budget and a reason, and is listed in the catalogue below.
3. Identity strings (team, bundle ids, app group, iCloud container, repo URL, oslog subsystem) go through `ForkIdentity`, `CodexBarMobile/Config/Fork.xcconfig` and `Scripts/apply_fork_identity.sh`. Never hand-edit a literal.
4. Generated or structural files are regenerated, never hand-resolved (see Generated files).
5. `make fork-gate` must pass before every push. Do not raise a footprint budget to get green unless the change is a new declared hook; say why in the commit message and add it to the catalogue.

## Where new fork code goes

| You want to | Do this |
|---|---|
| Add behavior to a Swift type | Extension in a new `Type+Fork<Topic>.swift` next to the type. Upstream file gets at most one call or one stored property marked `// fork hook: <who uses it>`. |
| Add a new type, view, widget, test | New file, new name. Widget and app target membership comes from `CodexBarMobile/project.yml` source groups; regenerate the project. |
| Need a private member of an upstream type from your extension | Widen access to `internal` in the upstream file (one-line hook, comment it), do not copy the type. |
| Add an identity or URL constant | Add it to `Shared/ForkIdentity.swift` and `Sources/CodexBarCore/Sync/ForkIdentity.swift` (keep both equal; `ForkIdentityConsistencyTests` checks), then use `ForkIdentity.<name>`. |
| Add a localized string | Follow the localization scripts (see Generated files); xcstrings are union-merged. |
| Add a script or workflow | `Scripts/fork/<name>.sh` or a new workflow file. Edit an upstream script only for identity, within its footprint budget. |
| Add a test | New `*Fork*Tests.swift` or `<Upstream>Tests+Fork.swift`. Appending to an upstream test file counts against its budget; avoid. |
| Add a Mac/iOS behavior that must match across the sync wire | Add a case to `Tests/CodexBarTests/ForkSyncIntegrationTests.swift` (see Required tests). |

Naming: `+Fork<Topic>` for Mac and core extensions, `+Accounts` for the widget multi-account extensions, `Fork*` for stand-alone types. Do not name a new upstream-looking file; a name clash with a future upstream file turns into an add/add conflict.

If an upstream file needs more than a one-line hook, first try to move the logic into a fork-owned extension and leave the hook. Rows in the catalogue marked "inline" are existing exceptions where the logic still lives in the upstream file; do not copy that pattern, and shrink them when touched.

## Identity

- `Shared/ForkIdentity.swift` (iOS, widgets, `CodexBarSync`) and `Sources/CodexBarCore/Sync/ForkIdentity.swift` (Mac, core): constants for iCloud container, app group, repo URL, oslog subsystem, notification names.
- `CodexBarMobile/Config/Fork.xcconfig`: `FORK_TEAM`, `FORK_BUNDLE_PREFIX`, `FORK_APP_GROUP`, `FORK_ICLOUD_CONTAINER`; `project.yml` reads them as `$(FORK_*)` through `configFiles:`.
- `Scripts/apply_fork_identity.sh`: rewrites upstream identity strings (plists, entitlements, scripts, workflows) to the fork's. Idempotent. `--check` is read-only and fails when anything would change. Author credits and history files are excluded via `Scripts/fork_identity_excludes.txt`; add an exclude there rather than special-casing the script.
- After any upstream merge or rebase step that touches identity-bearing files, run `Scripts/apply_fork_identity.sh`, review the diff, commit.
- Release tags are `v<MARKETING>-mobile.<MOBILE>-audi.<FORK_PATCH>`. `FORK_PATCH` lives in `version.fork.env` (not `version.env`, which is upstream's). Changing the tag format or a bundle id also needs a change in the `codexbar-ops` repo.

## Generated files

Never resolve these by hand during a conflict. Take the upstream version of the file, then regenerate.

| File | Regenerate | Verified by |
|---|---|---|
| `CodexBarMobile/CodexBarMobile.xcodeproj/project.pbxproj` | `cd CodexBarMobile && xcodegen generate` | `Scripts/test_xcodegen_sync.sh` |
| `Sources/CodexBarCore/Generated/CodexParserHash.generated.swift` | `Scripts/regenerate-codex-parser-hash.sh` | `Scripts/regenerate-codex-parser-hash.sh check` |
| `*.xcstrings` (app and widget) | union-merge keys, then `node Scripts/sync-widget-locales.mjs` | `Scripts/test_fork_localization.sh`, `node Scripts/check-app-locales.mjs`, `python3 Scripts/audit_localized_keys.py` |
| `.github/README.md` provider block | regenerate the provider block only, then update the hash in `Scripts/check_fork_readme.sh` | `Scripts/check_fork_readme.sh`, `Scripts/test_fork_readme_guard.sh` |

When upstream changes Codex parsing, bump `parserLogicVersion` (in `Sources/CodexBarCore/Vendored/CostUsage/CostUsagePricing.swift`; fork parser revision logic is in `CostUsageScanner+ForkParserRevision.swift`) and regenerate the parser hash. The first run after that rebuilds the Codex cost cache on every machine.

## Extension-point catalogue

Source of truth is `fork/footprint.tsv` (path, max changed lines against the base tag, purpose). This catalogue says what each hook does. Every manifest row appears below; the budget is a ceiling, not a target.

### Build and repo plumbing

| File | Hook | Why |
|---|---|---|
| `Makefile` | `fork-gate` target and its `.PHONY` entry | `make fork-gate` runs `Scripts/fork_sync_gate.sh` |
| `Package.swift` | `CZstd` target and its dependency | decoder-only zstd for Codex `*.jsonl.zst` rollouts |
| `.gitignore` | ignore fork-only local artifacts | |
| `CodexBarMobile/project.yml` | `configFiles:` entries for `Fork.xcconfig`, `$(FORK_*)` ids, fork source groups | fork identity and fork-owned sources in each target |
| `CodexBarMobile/CodexBarMobile.xcodeproj/project.pbxproj` | generated | regenerate with xcodegen; budget grows with fork-owned source files |
| `docs/RELEASING.md` | fork release docs adaptation | |

### CI and release workflows

| File | Hook |
|---|---|
| `.github/workflows/release-cli.yml`, `.github/workflows/release-linux-desktop.yml` | identity values |
| `.github/workflows/release-mac-verify.yml` | identity plus fork release verify steps (inline) |

Fork-only: `.github/workflows/release-mac.yml`, `.github/README.md`.

### Identity adaptation of upstream scripts

These carry identity strings or fork packaging calls and nothing else. Larger fork logic goes to `Scripts/fork/` (for example `package_app.sh` calls `Scripts/fork/package_app_fork.sh`).

- Release and CI: `Scripts/acknowledgements.py`, `Scripts/changelog-to-html.sh`, `Scripts/check_fork_readme.sh`, `Scripts/check_pr_review_gate.sh`, `Scripts/check-release-assets.sh`, `Scripts/ci_macos_test_gate.sh`, `Scripts/cloudkit/deploy_schema.sh`, `Scripts/compile_and_run.sh`, `Scripts/deploy_quota_account_email_field.sh`, `Scripts/make_appcast.sh`, `Scripts/package_app.sh`, `Scripts/release.sh`, `Scripts/sign-and-notarize.sh`, `Scripts/sparkle_helpers.sh`, `Scripts/upload_ios_testflight.sh`, `Scripts/upstream-release-monitor.mjs`
- Their tests: `Scripts/test_acknowledgements.py`, `Scripts/test_fork_readme_guard.sh`, `Scripts/test_ios_upload_contract.sh`, `Scripts/test_package_product_paths.sh`, `Scripts/test_package_signing.sh`, `Scripts/test_pr_review_gate.sh`, `Scripts/test_release_cli_workflow.sh`, `Scripts/test_release_temp_cleanup.py`

### Entitlements and plists (identity values)

`CodexBarMobile/CodexBarMobile/CodexBarMobile.entitlements`, `CodexBarMobile/CodexBarMobile/Info.plist`, `CodexBarMobile/CodexBarMobilePushExtension/PushExtension.entitlements`, `CodexBarMobile/CodexBarMobileWidgetOptions/WidgetOptions.entitlements`, `CodexBarMobile/CodexBarMobileWidgets/WidgetExtension.entitlements`. Written by `apply_fork_identity.sh`.

### Localization

`CodexBarMobile/CodexBarMobile/Localizable.xcstrings`, `CodexBarMobile/CodexBarWidgetShared/WidgetConfiguration.xcstrings`, `Sources/CodexBarCore/Resources/Acknowledgements.json` (fork credits). Union-merge, regenerate.

### Mac app, core and sync

| File | Hook | Calls into |
|---|---|---|
| `Sources/CodexBar/CodexbarApp.swift` | `ForkIdentity` oslog and help URL; `cloudSyncCoordinator` property visible to the extension | `AppDelegate+ForkPush.swift` |
| `Sources/CodexBar/Settings/PreferencesAboutPane.swift` | repo URL via `ForkIdentity` | `ForkIdentity` |
| `Sources/CodexBar/Sync/CloudSyncCoordinator.swift` | `settings` and `scheduleResume(debounce:)` widened for the extension | `CloudSyncCoordinator+RemotePush.swift` |
| `Sources/CodexBar/Sync/CloudSyncEngine.swift` | stored properties (`settings`, `state`, pending/skipped hash maps, `forkSend`) and kick backoff call (partly inline) | `CloudSyncEngine+ForkSendTracking.swift`, `CloudSyncSnapshotSendKick.swift` |
| `Sources/CodexBar/Sync/CloudSyncPersistence.swift`, `Sources/CodexBar/Sync/SyncCoordinator.swift` | `accountLabel` published to iPhone (`syncedAccountLabel`) | `UsageSnapshot.accountLabel` |
| `Sources/CodexBarCore/Vendored/CostUsage/CostUsageScanner.swift` | archived-rollout mirror roots (`ensureMirrorRoots`, `existingMirrorRoots`) (partly inline) | `CodexArchivedRolloutMirror.swift`, `CostUsageScanner+ForkCoverage.swift`, `CostUsageScanner+ForkParserRevision.swift` |
| `Sources/CodexBarCore/Vendored/CostUsage/CostUsagePricing.swift` | `parserLogicVersion` value and its fork rationale comment | `CostUsageScanner+ForkParserRevision.swift` |
| `Sources/CodexBarCore/Generated/CodexParserHash.generated.swift` | generated | `Scripts/regenerate-codex-parser-hash.sh` |

### Shared (Mac and iOS)

`Shared/Models/UsageSnapshot.swift` adds optional `accountLabel` (additive wire field: old payloads decode as nil, old clients ignore it; `SyncWireFormatRoundTripTests` pins both directions). `Shared/iCloud/CloudConstants.swift`, `Shared/iCloud/CloudOperationDeadline.swift`, `Shared/iCloud/CloudSyncManager.swift`, `Shared/Notifications/NSEInvocationLog.swift` use `ForkIdentity` constants.

### iPhone app

| File | Hook |
|---|---|
| `CodexBarMobile/CodexBarMobile/CodexBarMobileApp.swift` | zone-change notification name via `ForkIdentity` |
| `CodexBarMobile/CodexBarMobile/ContentView.swift`, `CodexBarMobile/CodexBarMobile/Views/OnboardingView.swift` | repo URL and slug via `ForkIdentity` |
| `CodexBarMobile/CodexBarMobile/Storage/ModelContainerFactory.swift` | app group via `ForkIdentity` |
| `CodexBarMobile/CodexBarMobile/Models/ProviderAccountGroup.swift` | account title from `accountLabel` (inline) |
| `CodexBarMobile/CodexBarMobile/Models/WidgetActivityPublisher.swift` | publishes account records to widgets (inline) |
| `CodexBarMobile/CodexBarMobile/Views/ProviderDetailView.swift`, `CodexBarMobile/CodexBarMobile/Views/ProviderUsageView.swift`, `CodexBarMobile/CodexBarMobile/Views/TokenActivityView.swift` | account row, day-key hardening, Dynamic Type month labels (inline) |

### Widgets

| File | Hook | Calls into |
|---|---|---|
| `CodexBarMobile/CodexBarMobileWidgets/CodexBarWidgets.swift` | registers the two iOS 27 App Intent widgets | `AccountsQuotaWidget.swift`, `ServiceQuotaWidget.swift` |
| `CodexBarMobile/CodexBarMobileWidgets/CodexBarWidgetTimeline.swift`, `CodexBarMobile/CodexBarMobileWidgets/StatusWidgetTimeline.swift` | `accountChoice` parameter, oslog subsystem, accounts timeline provider (partly inline) | `+Accounts` extensions |
| `CodexBarMobile/CodexBarMobileWidgets/WidgetActivityTimeline.swift` | oslog subsystem via `ForkIdentity` | |
| `CodexBarMobile/CodexBarWidgetShared/CodexBarWidgetEntry.swift` | `accountChoice` stored property | |
| `CodexBarMobile/CodexBarWidgetShared/CodexBarWidgetSnapshot.swift`, `CodexBarMobile/CodexBarWidgetShared/ProviderSnapshotMerger.swift` | `accountLabel` and session fields carried through merge | `CodexBarWidgetSnapshot+Accounts.swift` |
| `CodexBarMobile/CodexBarWidgetShared/StatusWidgetConfigurationAdapter.swift`, `CodexBarMobile/CodexBarWidgetShared/WidgetActivityProjection.swift`, `CodexBarMobile/CodexBarWidgetShared/WidgetProviderCatalogue.swift`, `CodexBarMobile/CodexBarWidgetShared/WidgetProviderSelection.swift` | account-aware selection and catalogue (partly inline) | `WidgetProviderCatalogue+Accounts.swift` |
| `CodexBarMobile/CodexBarWidgetShared/WidgetConfigurationAppIntents.swift` | two App Intent kind names | `WidgetConfigurationAppIntents+Account.swift` |

### Tests added inside upstream test files

Budgeted because the fork's cases still sit in upstream test files: `CodexBarMobile/CodexBarMobileTests/MobileDisplayFormattingTests.swift`, `CodexBarMobile/CodexBarMobileTests/ProviderAccountGroupTests.swift`, `CodexBarMobile/CodexBarMobileTests/WidgetConfigurationAppIntentsTests.swift`, `Tests/CodexBarTests/AppGroupSupportTests.swift`, `Tests/CodexBarTests/CloudSyncDeviceRemovalTests.swift`, `Tests/CodexBarTests/CloudSyncPushRegistrationTests.swift`, `Tests/CodexBarTests/CloudSyncSettingsTests.swift`, `Tests/CodexBarTests/SyncCoordinatorMultiAccountTests.swift`, `Tests/CodexBarTests/SyncWireFormatRoundTripTests.swift`. New fork tests go into `+Fork` siblings instead.

## Check standard

`make fork-gate` runs `Scripts/fork_sync_gate.sh`. It stops at the first failing stage, prints elapsed time per stage and writes logs to `~/Library/Caches/codexbar-gate/gate-<stage>.log`.

| Tier | Command | When | Stages |
|---|---|---|---|
| Default (about 5 min on the Mini) | `make fork-gate` | every upstream sync and every push | 1 conflict markers; 2 identity `--check` and release/signing/readme guards; 3 footprint; 4 generated files (parser hash, xcodegen, localization); 5 version; 6 lint on changed Swift files (no more violations per rule than the base tag plus `fork/lint-allowance.tsv`); 7 `swift build`; 8 fork-scoped `swift test` filter |
| iOS | `make fork-gate ARGS='--ios --baseline ~/Library/Caches/codexbar-gate'` | iPhone, widget or shared model changes | default plus `CodexBarMobileTests` on simulator `CB iPhone 18 Pro Max`, diffed against the baseline |
| Full | `make fork-gate ARGS='--full --baseline ~/Library/Caches/codexbar-gate'` | before a release only | default plus the whole Mac `swift test` and the iOS tests, both diffed against baseline files |

No UI automation in any tier. Footprint check: `Scripts/fork/check_footprint.sh <base-tag>` fails when an upstream-owned file differs and is not in `fork/footprint.tsv`, or exceeds its budget; files new in the fork are always allowed.

Baselines: `baseline-mac-fail.txt` and `baseline-ios-fail.txt` in the gate directory list tests that already fail on the clean upstream tag. Regenerate them on the new tag during every sync (step 5 below). A fork-scoped suite must be fully green, not just free of new failures. Do not edit or delete a test to get green.

Required integration tests (extend them when you change the area):

| Area | Suites |
|---|---|
| Sync (Mac to iPhone wire, send tracking, multi-account) | `ForkSyncIntegrationTests`, `SyncWireFormatRoundTripTests`, `SyncCoordinatorMultiAccountTests`, `CloudSync*` |
| Widget accounts | `WidgetAccountRoundTripTests`, `WidgetProviderSelectionTests` (+Fork) |
| Cost scanning | `CostUsageStore*`, `CodexArchivedRollout*`, `CostUsageForkParserRevision*` |
| Identity | `ForkIdentityConsistencyTests`, `Scripts/test_fork_identity.sh` |
| Provider architecture | `ProviderArchitectureGatekeeper*` |

The default tier's `swift test --filter` list is `FORK_TEST_FILTER` in `Scripts/fork_sync_gate.sh`; add a new fork suite's name there.

Never run a source-built `codexbar` CLI against the real `~/Library/Caches/CodexBar`: it resets the installed app's cost cache to another schema. Use unit tests for cost scanning.

## Upstream sync by rebase

Replaces the old merge-based sync. The branch history stays a linear stack of fork commits on top of the newest upstream release tag. Use release tags of the `upstream-fork` remote, not its moving branch. Work in a worktree (`../wt-sync-<ver>`), keep the main checkout clean on `mobile-dev`.

1. Fetch and pick the tag: `git fetch upstream-fork --tags`; `NEW=v<ver>-mobile.<M>`, `OLD=` the current base tag (`git describe --tags --abbrev=0 --match 'v*-mobile.*' --exclude '*-audi.*'`). Only if upstream-fork lags and steipete has a needed fix, the base may be a steipete release tag; then the fork stack also carries the delta, and the tag comparison in gate stage 5 needs `--base-tag`.
2. Back up: `git branch backup/mobile-dev-pre-<ver> mobile-dev`; `git worktree add ../wt-sync-<ver> -b sync/<ver>-rebase mobile-dev`. Enable `git config rerere.enabled true` and `rerere.autoupdate true` (once per clone) so repeated conflicts replay.
3. Scripted todo. Build the todo with `GIT_SEQUENCE_EDITOR=<script> git rebase -i --onto $NEW $OLD`. The script must: `drop` commits whose only change is a `FORK_PATCH` bump (`git log --format='%h %s' --reverse $OLD..HEAD -- version.fork.env version.env`, then `git show --stat`); turn `fixup!` and pure-noise commits (style, lint, "fix typo" of an earlier fork commit) into `fixup`; leave everything else as `pick`. Review the generated todo before running it. A merge commit in the range means history was not linear: stop and ask.
4. Resolve conflicts by file class:
   - Fork-owned file: keep the fork side.
   - Upstream-owned file with a hook: take upstream's side, then re-apply the one-line hook. Never keep both versions of a block.
   - Identity strings: take upstream's side, then run `Scripts/apply_fork_identity.sh` after the step.
   - Generated files: take upstream's side, regenerate (Generated files table). Do not edit conflict markers in `project.pbxproj`, parser hash or xcstrings.
   - `README.md`, `appcast.xml`, `version.env`, `CHANGELOG.md`: take upstream's. The fork README is `.github/README.md`; the fork changelog is `CHANGELOG.fork.md`.
   - `Package.swift`, `project.yml`: take upstream's, re-add the fork entries listed in the catalogue.
   - A new upstream provider: it goes through the generic account bucket in `AccountIdentityComputer`; update the provider-architecture gatekeeper test expectations.
   `git rebase --continue` after each step; run `git diff --check`.
5. Baseline on the clean tag: `git worktree add ../wt-base-<ver> $NEW`; there, run `Scripts/fork/swift_scratch.sh test` and the iOS `xcodebuild test -only-testing:CodexBarMobileTests`, extract failing test names exactly as `fork_sync_gate.sh` does (`mac_fail_list`, `ios_fail_list`), and write them to `baseline-mac-fail.txt` and `baseline-ios-fail.txt` in `~/Library/Caches/codexbar-gate`. Remove the worktree afterwards. Skip this when `OLD` and `NEW` share the same upstream code (tag respin only).
6. Update version metadata: `UPSTREAM_VERSION` and `UPSTREAM_SYNC_DATE` in `version.env` come from upstream's merge; set `FORK_PATCH=1` in `version.fork.env`. Re-run `Scripts/apply_fork_identity.sh`, regenerate generated files, bump `parserLogicVersion` when upstream changed Codex parsing.
7. Review the rebase: `git range-diff $OLD..backup/mobile-dev-pre-<ver> $NEW..HEAD`. Every fork commit must map to its old one; look at each commit marked `!`, and confirm any dropped commit was intended.
8. Footprint and gate: `Scripts/fork/check_footprint.sh $NEW`, then `make fork-gate ARGS='--ios --baseline ~/Library/Caches/codexbar-gate'`. Before a release use `--full`. Fix failures with new commits on top, not by editing tests.
9. Push: `git push --force-with-lease=mobile-dev:<old tip sha> origin sync/<ver>-rebase:mobile-dev`. Pushing `mobile-dev` triggers an Xcode Cloud TestFlight build; confirm with the owner before pushing. Then remove the worktrees and the sync branch; keep `backup/mobile-dev-pre-<ver>` until the release is verified.
10. Release as usual (`Release Mac` workflow on `mobile-dev`). The first run after a parser bump rebuilds the Codex cost cache in batches over several refreshes; do not judge the fix on mid-rebuild numbers.
