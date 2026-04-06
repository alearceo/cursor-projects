# StrideCheckTests

Unit test files for the StrideCheck iOS app.

## Wiring the test target in Xcode (one-time setup)

Because modifying `project.pbxproj` by hand is fragile, the test target must be
added through Xcode once:

1. **File → New → Target** → choose **Unit Testing Bundle**
2. Name it `StrideCheckTests`, set **Target to Be Tested** to `StrideCheck`
3. In the new target's **Build Phases → Compile Sources**, add all `*.swift` files
   from this folder
4. Run **Cmd+U** to verify tests pass

The CI workflow (`/.github/workflows/ios-ci.yml`) runs `xcodebuild test -scheme StrideCheck`
and will automatically pick up the target once it exists in the project file.

## Test files

| File | What it covers |
|------|----------------|
| `SnapshotCacheTests.swift` | JSON round-trip, `cachedAt` timestamp, `formattedSavedAt` |
| `RunIndexWidgetPayloadTests.swift` | `RunIndexTierKind` banding, Codable round-trip, backward-compatible decode defaults |
