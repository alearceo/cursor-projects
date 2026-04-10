# StrideCheck repo improvements — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the approved phased repo improvements: clean git history for existing work, resilient CI, optional SwiftLint gate, split scoring engines into their own files, and remove vendor OAuth literals from `project.pbxproj`.

**Architecture:** Phases are sequential. Phase 1 is pure git. Phase 2 touches only `.github/workflows/ios-ci.yml` and `ios/README.md`. Phase 3 adds `ios/.swiftlint.yml` and a CI step. Phase 4 moves `ScoreEngine` and `AwarenessEngine` into new Swift files and registers them in `project.pbxproj` (no API changes). Phase 5 deletes duplicate `STRAVA_*` / `WHOOP_*` assignments from the StrideCheck target’s inline `XCBuildConfiguration` so `StrideCheck/BuildConfig.xcconfig` + gitignored `Secrets.xcconfig` remain the single source of truth.

**Tech Stack:** Git, GitHub Actions, Xcode 16.x, Swift 5, xcodebuild, SwiftLint (Homebrew on `macos-15`), optional `brew`.

---

## Resolved decisions (from spec open items)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| SwiftFormat vs SwiftLint | **SwiftLint** | Single config file, common on iOS OSS; `only_rules` whitelist avoids a massive first-time format diff. |
| CI simulator | **`generic/platform=iOS Simulator`** for build + test | Works across Xcode minor versions when a named device is missing; if the test runner rejects generic, fallback is documented in Task 7. |
| Phase 1 commit count | **One** cohesive commit after staging all review files | Fastest path to clean tree; split only if you need finer bisect later. |

---

### Task 1: Phase 1 — Stage and commit all StrideCheck review changes

**Files:**
- Modify (stage): all paths listed in `git status` under `runner-road-conditions` except already-committed `docs/superpowers/specs/`
- New (stage): `ios/StrideCheck/ConditionsReloadCenter.swift`, `ConditionsTabView.swift`, `RouteAnd511View.swift`, `TopEdgeFrostFade.swift`, `Services/ConditionsFetching.swift`, `StrideCheckTests/ConditionsScoringTests.swift`

- [ ] **Step 1: Verify working tree**

Run:

```bash
cd /Users/aarceoferia/Projects/runner-road-conditions
git status -sb
```

Expected: modified files under `.github/`, `README.md`, `ios/`, and untracked Swift/test files as in the prior review.

- [ ] **Step 2: Stage everything for the review implementation**

Run:

```bash
git add .github/workflows/ios-ci.yml README.md ios/
```

Expected: `git diff --cached --stat` shows non-zero insertions for workflow, README, Xcode project, StrideCheck sources, tests.

- [ ] **Step 3: Commit**

Run:

```bash
git commit -m "chore(stridecheck): CI pipefail, test target, UI split, reload center, scoring tests"
```

Expected: `git status -sb` shows clean tree (or only unrelated local files).

- [ ] **Step 4: Push branch**

Run:

```bash
git push -u origin HEAD
```

Expected: remote updates; open a PR to `main` with a short body listing CI, README clone URL, Xcode test target, `ConditionsTabView` / `RouteAnd511View`, `ConditionsReloadCenter`, `ConditionsFetching`, `ConditionsScoringTests`.

---

### Task 2: Phase 2 — CI `generic` simulator destination

**Files:**
- Modify: `.github/workflows/ios-ci.yml` (env `DESTINATION`)
- Modify: `ios/README.md` (CI / local test paragraph)

- [ ] **Step 1: Edit workflow env**

In `.github/workflows/ios-ci.yml`, set:

```yaml
    env:
      XCODE_PROJECT: ios/StrideCheck.xcodeproj
      SCHEME: StrideCheck
      DESTINATION: "generic/platform=iOS Simulator"
```

Remove the old `name=iPhone 16,OS=latest` string.

- [ ] **Step 2: Document in ios/README**

In `ios/README.md`, in the CI section (or Quick start), add one sentence:

> GitHub Actions uses destination `generic/platform=iOS Simulator` so builds do not depend on a specific simulator display name.

- [ ] **Step 3: Local verification**

Run (adjust `-derivedDataPath` if you like):

```bash
cd /Users/aarceoferia/Projects/runner-road-conditions/ios
xcodebuild test -project StrideCheck.xcodeproj -scheme StrideCheck -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/scdd CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

Expected: `** TEST SUCCEEDED **` (or, if your Xcode errors on generic for tests, stop and use Task 3 fallback instead of merging).

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ios-ci.yml ios/README.md
git commit -m "ci(ios): use generic iOS Simulator destination"
```

---

### Task 3: Phase 2 fallback (only if generic test fails on CI or locally)

**Files:**
- Modify: `.github/workflows/ios-ci.yml`

- [ ] **Step 1: Add non-blocking destinations listing**

After “Select Xcode”, add:

```yaml
      - name: List simulator destinations (diagnostic)
        continue-on-error: true
        run: xcodebuild -project "$XCODE_PROJECT" -scheme "$SCHEME" -showdestinations
```

- [ ] **Step 2: Pin DESTINATION**

Set `DESTINATION` to a name that appears in the log for `OS=26.x` or `OS=18.x` iPhone simulator, e.g.:

```yaml
DESTINATION: "platform=iOS Simulator,name=iPhone 16,OS=18.3.1"
```

(Document the exact string in a workflow comment.)

- [ ] **Step 3: Commit**

```bash
git commit -am "ci(ios): pin simulator destination after diagnostics"
```

---

### Task 4: Phase 3 — SwiftLint config (minimal whitelist)

**Files:**
- Create: `ios/.swiftlint.yml`
- Modify: `.github/workflows/ios-ci.yml`
- Modify: `ios/README.md`

- [ ] **Step 1: Add `ios/.swiftlint.yml`**

Create file with this content (whitelist-only; expand later):

```yaml
# Minimal ruleset — add opt_in_rules gradually to avoid huge diffs.
only_rules:
  - trailing_newline
  - trailing_whitespace
  - vertical_whitespace
included:
  - StrideCheck
  - StrideCheckTests
excluded:
  - StrideCheckRunIndexWidget
```

- [ ] **Step 2: Run SwiftLint locally**

Run:

```bash
cd /Users/aarceoferia/Projects/runner-road-conditions/ios
swiftlint lint --strict
```

Expected: exit 0. If violations appear, fix files or temporarily add `excluded:` paths **only** with a comment `TODO: remove after cleanup` (do not leave permanent blanket excludes without TODO).

- [ ] **Step 3: Add CI step**

After “Show build tools” (or before “Build”), add:

```yaml
      - name: SwiftLint
        run: |
          brew install swiftlint
          cd ios && swiftlint lint --strict
```

- [ ] **Step 4: Document local run**

In `ios/README.md` add:

```markdown
### SwiftLint

From `ios/`: `swiftlint lint --strict` (install via Homebrew: `brew install swiftlint`).
```

- [ ] **Step 5: Commit**

```bash
git add ios/.swiftlint.yml .github/workflows/ios-ci.yml ios/README.md
git commit -m "chore(ios): add SwiftLint whitelist and CI step"
```

---

### Task 5: Phase 4 — Extract `ScoreEngine` and `AwarenessEngine`

**Files:**
- Create: `ios/StrideCheck/Services/ScoreEngine.swift`
- Create: `ios/StrideCheck/Services/AwarenessEngine.swift`
- Modify: `ios/StrideCheck/Services/ConditionsService.swift` (delete the two moved `enum` blocks)
- Modify: `ios/StrideCheck.xcodeproj/project.pbxproj` (PBXFileReference + PBXBuildFile + Services group + Sources phase)

- [ ] **Step 1: Create `ScoreEngine.swift`**

New file starts with `import Foundation`, then paste **verbatim** the entire `enum ScoreEngine { ... }` block from `ios/StrideCheck/Services/ConditionsService.swift` (from the line `enum ScoreEngine {` through its closing `}` immediately before `enum AwarenessEngine`), including `private static func isWet` inside that enum. Do not alter method bodies.

- [ ] **Step 2: Create `AwarenessEngine.swift`**

New file starts with `import Foundation`, then paste **verbatim** the entire `enum AwarenessEngine { ... }` block from the same file (from `enum AwarenessEngine {` through its closing `}` at file end before any stray markers), including its private `isWet`.

- [ ] **Step 3: Remove moved code from `ConditionsService.swift`**

Delete `enum ScoreEngine { ... }` and `enum AwarenessEngine { ... }` only. Keep `private enum WeatherCode` and struct `ConditionsService` unchanged.

- [ ] **Step 4: Register files in Xcode**

In `project.pbxproj`:

1. Add `PBXFileReference` entries for `ScoreEngine.swift` and `AwarenessEngine.swift` (unique IDs; follow existing `HeatColdStress.swift` pattern).
2. Add `PBXBuildFile` entries linking them to the StrideCheck target Sources phase.
3. Add both file refs under the `Services` group next to `ConditionsService.swift`.

- [ ] **Step 5: Test**

```bash
cd /Users/aarceoferia/Projects/runner-road-conditions/ios
xcodebuild test -project StrideCheck.xcodeproj -scheme StrideCheck -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/scdd2 CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

Expected: **TEST SUCCEEDED**; `ConditionsScoringTests` still passes.

- [ ] **Step 6: Commit**

```bash
git add ios/StrideCheck/Services/ScoreEngine.swift ios/StrideCheck/Services/AwarenessEngine.swift ios/StrideCheck/Services/ConditionsService.swift ios/StrideCheck.xcodeproj/project.pbxproj
git commit -m "refactor(ios): move ScoreEngine and AwarenessEngine to own files"
```

---

### Task 6: Phase 5 — Remove OAuth literals from `project.pbxproj`

**Files:**
- Modify: `ios/StrideCheck.xcodeproj/project.pbxproj`
- Verify: `ios/StrideCheck/BuildConfig.xcconfig` still defines empty defaults + `#include?` Secrets
- Modify (optional): `ios/Config/Secrets.xcconfig.template` if any key is undocumented

- [ ] **Step 1: Remove inline secrets from StrideCheck Debug configuration**

In `project.pbxproj`, locate `AA0000000000000000000062 /* Debug */` (StrideCheck app target). Delete these **lines** from `buildSettings` if present:

```
				STRAVA_CLIENT_ID = 220697;
				STRAVA_CLIENT_SECRET = 5866720ec1c4a995da9677fb90b4020c7b44100d;
				WHOOP_CLIENT_ID = "15180130-f7ca-4578-a72e-7e30ef87f3c2";
				WHOOP_CLIENT_SECRET = 4e5b91a2d2f30d2ad1f0c4d441bcea84840b261d7ef0e56fed635aeb9be0bdd7;
```

(Exact values may differ; remove any `STRAVA_CLIENT_*` and `WHOOP_CLIENT_*` assignments here.)

- [ ] **Step 2: Remove same from Release**

In `AA0000000000000000000063 /* Release */`, delete the same four keys.

- [ ] **Step 3: Confirm xcconfig supplies keys**

`BuildConfig.xcconfig` must still contain:

```
WHOOP_CLIENT_ID =
WHOOP_CLIENT_SECRET =
STRAVA_CLIENT_ID =
STRAVA_CLIENT_SECRET =
#include? "../../Config/Secrets.xcconfig"
```

- [ ] **Step 4: Local developer setup**

Copy template to secrets file and fill for local runs:

```bash
cp ios/Config/Secrets.xcconfig.template ios/Config/Secrets.xcconfig
# Edit Secrets.xcconfig — do not commit
```

Build StrideCheck in Xcode once; OAuth screens should still work when values are present.

- [ ] **Step 5: Verify no secrets in pbxproj**

```bash
cd /Users/aarceoferia/Projects/runner-road-conditions
git grep -E 'STRAVA_CLIENT_SECRET|WHOOP_CLIENT_SECRET|5866720|4e5b91a' ios/StrideCheck.xcodeproj/project.pbxproj || true
```

Expected: **no output** (exit 1 from grep is OK meaning no matches).

- [ ] **Step 6: Commit**

```bash
git add ios/StrideCheck.xcodeproj/project.pbxproj
git commit -m "security(ios): drop Strava/Whoop literals from Xcode project settings"
```

---

## Self-review (plan vs spec)

| Spec section | Task coverage |
|--------------|---------------|
| Phase 1 git hygiene | Task 1 |
| Phase 2 CI destination | Tasks 2–3 |
| Phase 3 SwiftLint | Task 4 |
| Phase 4 split ConditionsService | Task 5 |
| Phase 5 remove secrets | Task 6 |
| Testing strategy | Verification steps in Tasks 2, 4, 5 |

No intentional placeholders: all file paths and key names are concrete.

---

## Execution handoff

**Plan complete and saved to** `docs/superpowers/plans/2026-04-10-repo-improvements.md`.

**Two execution options:**

1. **Subagent-driven (recommended)** — Dispatch a fresh subagent per task; review between tasks for fast iteration (subagent-driven-development skill).

2. **Inline execution** — Run tasks in this session in order with checkpoints (executing-plans skill).

**Which approach do you want?**
