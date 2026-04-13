# StrideCheck repo improvements — design (phased)

**Date:** 2026-04-10  
**Status:** Approved direction — phased delivery covering git hygiene, CI, tooling, structure, and secrets.

## Goal

Improve repository health and maintainability without changing product behavior, except where explicitly noted (e.g. removing secrets from versioned build settings).

## Non-goals

- Backend-for-OAuth or new features (separate initiative).
- Visual or UX changes.
- Replacing third-party APIs or crime/traffic data sources.

## Phases (order is mandatory)

### Phase 1 — Git hygiene

**Outcome:** Clean, reviewable history; no long-lived dirty tree for the already-implemented review items.

- Commit modified and untracked files from the StrideCheck review implementation (CI, README, Xcode project + scheme, new Swift sources, tests).
- Prefer either:
  - **One** cohesive commit titled e.g. `chore: StrideCheck review — CI, tests, UI split, reload center`, or
  - **Two–three** commits: (docs + CI), (Xcode + tests), (Swift modules).
- Push branch and open a PR to `main` (or merge per team practice).

**Success criteria:** `git status` clean on the feature branch after push; PR describes scope; reviewers can build and run tests locally.

### Phase 2 — CI destination and logs

**Outcome:** CI fails only on real build/test failures, not on transient or mismatched simulator names.

- Keep `set -o pipefail` and failure propagation from `xcodebuild`.
- Resolve `DESTINATION` drift between GitHub `macos-15` / Xcode 16.x and local Xcode 26.x simulators:
  - Prefer `generic/platform=iOS Simulator` for **build**, and for **test** use a destination that exists on the runner (document the chosen pattern in `ios/README.md`).
  - If generic test destination is insufficient for the test host, fall back to `xcodebuild -showdestinations` in a diagnostic CI step (non-blocking) and pin a simulator name documented in the workflow comment.

**Success criteria:** Green CI on `push`/`pull_request` for the StrideCheck scheme; documented destination choice.

### Phase 3 — SwiftFormat or SwiftLint (pick one in implementation plan)

**Outcome:** Consistent Swift style with automated enforcement.

- Add configuration under `ios/` (e.g. `.swiftformat` or `.swiftlint.yml`).
- CI: run the tool in **check** mode (non-writing) so PRs fail on violations.
- README: one paragraph on how to run fix/lint locally.

**Success criteria:** CI job runs in &lt; 2 minutes incremental; no unrelated mass reformat in the same PR as functional changes (optional dedicated “format baseline” commit).

### Phase 4 — Split `ConditionsService.swift`

**Outcome:** Smaller files, same behavior.

- Move `ScoreEngine` and `AwarenessEngine` to dedicated Swift files (module-internal `enum` or `struct` as today).
- Leave orchestration, geocoding, and API fetch helpers in `ConditionsService` (or split further only if still &gt; ~400 lines after engine extraction).

**Success criteria:** All existing unit tests pass; no public API changes.

### Phase 5 — Remove embedded client secrets from Xcode project

**Outcome:** No long-lived vendor client secrets in `project.pbxproj` or committed xcconfig.

- Remove `STRAVA_*`, `WHOOP_*`, and similar literals from `PBX` build settings; use empty defaults in committed config and real values only in gitignored `Secrets.xcconfig` and/or CI-injected `Secrets.xcconfig` (already documented pattern in `ios/README.md`).
- Verify local Debug still works when `Secrets.xcconfig` is present.

**Success criteria:** `git grep` for known secret patterns in `project.pbxproj` returns nothing sensitive; README still accurate.

## Risks

- **Phase 5** may require every developer to maintain local `Secrets.xcconfig`; mitigate with clear template and CI secrets.
- **Phase 3** baseline format may create a large one-time diff; isolate in its own commit/PR.

## Testing strategy

- After Phases 1–2 and 4–5: `xcodebuild test -scheme StrideCheck` on simulator.
- Phase 3: lint/format job must pass on clean tree after baseline.

## Open decisions (resolve in implementation plan)

- SwiftFormat vs SwiftLint.
- Exact CI simulator destination string for GitHub Actions macOS 15 image.
- Single vs multiple commits for Phase 1.
