# StrideCheck iOS (SwiftUI)

Native SwiftUI app for runner-focused conditions: weather, air quality, NWS alerts, a blended **run index**, optional **wearable readiness**, and a **route awareness** index (environment plus optional crime-incident context). Includes offline cache, optional local notifications, and a **Route & 511** tab with MapKit and state 511 links.

## Project layout

| Area | Files |
|------|--------|
| App | `StrideCheckApp.swift`, `ContentView.swift` |
| State | `ViewModels/ConditionsViewModel.swift` |
| Location | `Services/LocationService.swift` |
| Conditions & scoring | `Services/ConditionsService.swift`, `Services/APIModels.swift` |
| Networking / TLS | `Services/StrideCheckHTTPSession.swift` |
| Offline | `Services/SnapshotCache.swift` |
| Alerts | `Services/RunWindowNotifier.swift` |
| Map / traffic | `Services/State511Links.swift` (state 511 URLs) |
| Wearables | `Services/HealthKitReadinessFetcher.swift`, `Services/OuraPersonalAPIClient.swift`, `Services/WearableReadinessAggregator.swift` |
| Crime (optional) | `Services/CrimeIncidentsService.swift` |
| Signing | `StrideCheck/StrideCheck.entitlements` (HealthKit) |

## Open and run

1. Open `ios/StrideCheck.xcodeproj` in Xcode.
2. Select the **StrideCheck** scheme and an iPhone simulator or device.
3. Build and run (**⌘R**).

### Device builds and HealthKit

The target uses the **HealthKit** capability. For a **physical device**, the App ID in the Apple Developer portal must have **HealthKit** enabled; then refresh or regenerate the provisioning profile (or use automatic signing and let Xcode fix it). Simulator builds do not hit that provisioning check the same way.

## Configuration (optional keys in `Info.plist`)

| Key | Purpose |
|-----|---------|
| `OuraPersonalAccessToken` | If set (non-empty), the app calls Oura Cloud `v2/usercollection` for recent daily readiness, sleep, and activity. Create a token at [Oura personal access tokens](https://cloud.ouraring.com/personal-access-tokens). **Prefer a local xcconfig or untracked override for real tokens** so they are not committed. |
| `CrimeometerAPIKey` | If set, the app requests nearby **reported** incidents from [Crimeometer](https://www.crimeometer.com/) for the route awareness index. Empty = crime layer disabled. Same caution: do not commit production secrets. |

**Whoop:** There is no public personal-access-token flow comparable to Oura’s. If **Whoop → Apple Health** sync is enabled, **HealthKit** can still supply HRV, sleep, and activity proxies used in the run index.

## Product behavior

### Conditions tab

- **Location first**, optional **5-digit zip** fallback; pull-to-refresh when location or zip is available.
- **Navigation bar hidden** so the title scrolls with content; full-width grouped layout.
- **Run index** — environmental score with tier styling (green / amber / red); can be adjusted by **wearable readiness** when data exists.
- **Wearables & readiness** — rows for data source (Health / Oura), readiness score, sleep, HRV, strain proxy; explanatory bullets may be added to the run index list.
- **Route awareness** — daylight, weather, air quality, NWS alerts, and **optional** third-party **crime-incident density** (with explicit disclaimers: incomplete, delayed, not a substitute for judgment or official safety resources).
- **Right now** / **Air & comfort** / **Next 12 hours** / **Active alerts**.
- **Offline:** last successful snapshot is stored under Application Support; if a fetch fails and nothing is in memory, the cache loads. A banner shows when you are viewing a **cached** copy.

### Notifications

- Toggle **Strong run alerts** (stored in `UserDefaults`). When enabled, the app may schedule a **throttled** local notification if the run index is high after a refresh (see `RunWindowNotifier.swift`).

### Route & 511 tab

- Map centered on the last conditions coordinate; link to **state 511** (or FHWA directory fallback). Copy explains that live 511 map geometry is not drawn inside StrideCheck yet.

## Corporate proxy (Zscaler / SSL inspection)

If you see `ATS failed system trust`, `TLS Trust evaluation failed (-9802)`, or `NSURLErrorDomain Code=-1200` for API hosts, the network may be **SSL-inspecting** HTTPS.

**In-app mitigation:** `Info.plist` adds **ATS exceptions** (CT + forward-secrecy relaxed) for the API domains in use, including `open-meteo.com`, `weather.gov`, `zippopotam.us`, **`crimeometer.com`**, and **`ouraring.com`** (subdomains where applicable). `StrideCheckHTTPSession` supplies `URLCredential(trust:)` for an internal **host allowlist** only.

**Still failing?** Trust your org’s inspection root on the device/Simulator, or ask IT to bypass inspection for the hostnames the app calls.

## Harmless console noise (can ignore)

- `Failed to send CA Event for app launch measurements` — Apple internal metrics.
- `Gesture: System gesture gate timed out` / `Result accumulator timeout` — common Simulator / keyboard timing.
- `Unable to simultaneously satisfy constraints` on `_UIRemoteKeyboardPlaceholderView` — keyboard layout quirk; `scrollDismissesKeyboard` reduces frequency.

### Simulator / system services (not app bugs)

These often appear when using the **Simulator**, **MapKit**, or **debugging**; they reflect sandboxed daemons and entitlements your app does not (and should not) have:

- **`usermanagerd` / `personaAttributesForPersonaType` / (501) Invalidation handler** — user-persona XPC; Simulator noise.
- **`RBSServiceErrorDomain` / `Client not entitled` / `com.apple.runningboard.process-state` / `elapsedCPUTimeForFrontBoard`** — RunningBoard; common when the debugger or Simulator asks for process state your app is not entitled to.
- **`PerfPowerTelemetryClientRegistrationService` / Sandbox restriction (159)** — power/performance telemetry; blocked in the Simulator sandbox.
- **`PPSClientDonation` / `Maps / SpringfieldUsage` / `Permission denied`** — MapKit internal metrics donation; Simulator often denies it.
- **`Failed to locate resource named "default.csv"`** / **`fopen failed for data file`** / **`Errors found! Invalidating cache`** — Geo/Map-related caches on Simulator; usually self-healing.
- **`unable to make sandbox extension: Operation not permitted`** — Simulator file/sandbox limitation.

The Route tab uses a **full-area map** with **flat** standard map style and a **bottom safe-area inset** for the 511 card to avoid laying out `Map` at **0×0** (which caused `CAMetalLayer ignoring invalid setDrawableSize` and `clip: empty path` in some layouts). If those Metal messages still appear briefly when switching tabs, they are often benign MapKit timing on Simulator.

## API / data notes

- **Open-Meteo** — forecast, `is_day`, optional daily sunrise/sunset fields.
- **Open-Meteo Air Quality** — US AQI / PM2.5 (best effort).
- **api.weather.gov** — active alerts for the coordinate.
- **Crimeometer** — endpoint and query parameters may evolve; if counts stay at zero or requests fail, verify API docs and your key/plan. Parsing tolerates several JSON shapes (`incidents`, `results`, `data`, etc.).
- **Oura** — field names follow v2 `usercollection` JSON; if Oura changes schemas, update `OuraPersonalAPIClient.swift`.

## Future enhancements

- Deeper **Whoop** integration via OAuth (developer.whoop.com) if you need first-party recovery/strain instead of Health mirroring.
- Richer **511** or DOT map overlays where feed formats allow.
- Move secrets to **Keychain** or **xcconfig** templates and document a `Info.plist` merge pattern for CI.
