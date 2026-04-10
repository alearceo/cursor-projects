# StrideCheckTests

Unit test files for the StrideCheck iOS app.

The **StrideCheckTests** target is defined in `StrideCheck.xcodeproj` and is included in the shared **StrideCheck** scheme. Open the project in Xcode and run **⌘U**, or use the CI workflow (`.github/workflows/ios-ci.yml`) which runs `xcodebuild test -scheme StrideCheck`.

## Test files

| File | What it covers |
|------|----------------|
| `SnapshotCacheTests.swift` | JSON round-trip, `cachedAt` timestamp, `formattedSavedAt` |
| `RunIndexWidgetPayloadTests.swift` | `RunIndexTierKind` banding, Codable round-trip, backward-compatible decode defaults |
| `ConditionsScoringTests.swift` | `HeatColdStress`, `ScoreEngine`, `AwarenessEngine`, `ConditionsError.invalidZip` |
