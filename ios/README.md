# StrideCheck iOS (SwiftUI)

## Recent improvements

| Area | Change |
|------|--------|
| **Networking** | Request timeout reduced 45 s → 20 s. `URLSession.dataWithRetry(from:maxAttempts:)` adds exponential back-off (0.5 s → 1 s → 2 s) for transient failures on weather/air APIs. |
| **Security** | TLS proxy-trust delegate now guarded by `#if DEBUG` — never ships to users in release builds. |
| **Crash hardening** | `SnapshotCache.fileURL` force-unwrap replaced with a safe optional; save/load degrade gracefully if Application Support is unavailable. |
| **Widget** | Added **`.systemMedium`** family: two-column layout (Run Index hero left, Route Awareness right, context line, location). All widget variants now have explicit `accessibilityLabel` strings (combined element with full score/tier/location phrase). |
| **Repository hygiene** | `ios/.derived/` (≈2 000 Xcode build intermediates) untracked from git; `.gitignore` updated. Web prototype (`app.js`, `index.html`, `styles.css`) removed — app is the canonical product. |
| **Dead code** | `RunIndexWidgetState` and `RunIndexWidgetIntents` files cleaned to minimal stubs; pagination intents fully removed. |
| **CI** | GitHub Actions workflow at `.github/workflows/ios-ci.yml` — builds + tests on every push to main / feature / widget branches. |
| **Tests** | Unit test files added under `ios/StrideCheckTests/` (SnapshotCache round-trip, RunIndexWidgetPayload Codable, tier banding). See `ios/StrideCheckTests/README.md` for Xcode target wiring. |
| **Localization** | `Localizable.xcstrings` (String Catalog) added with all user-visible English strings as a baseline for future i18n. |

Native SwiftUI app for runner-focused conditions: weather, air quality, NWS alerts, a blended **run index** (environment uses **effective heat/cold**—feels-like plus NWS-style heat index and wind chill when applicable—via `HeatColdStress.swift`), optional **wearable readiness** (Apple Health baseline plus opt-in **Whoop**, **Oura**, and **Garmin Health API** for the index), and a **route awareness** index (environment plus optional crime-incident context). **Data sources** screens centralize credentials and toggles; **Strava** map overlays are **opt-in**. Includes a **Run Index** widget (small Home Screen + lock-screen accessories), offline cache, optional local notifications, and a **Route & 511** tab with MapKit and state 511 links.

## Project layout


| Area                 | Files                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| App                  | `StrideCheckApp.swift`, `ContentView.swift` (Conditions + Route tabs, top **edge frost** over status bar), `WearableDataSourcesView.swift` (run-index data sources), `MapDataSourcesView.swift` (Strava map overlay + OAuth client fields), `RouteTrafficMapView.swift` (MapKit traffic + overlays), `LaunchScreen.storyboard` (full-screen launch; avoids letterboxing on modern iPhones)                                                                                                                                                                                                                                       |
| State                | `ViewModels/ConditionsViewModel.swift` (load **sequencing**, benign **cancellation** handling; `ConditionsSnapshotReload` + notification name for wearable-driven refetch)                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| Location             | `Services/LocationService.swift`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| Conditions & scoring | `Services/ConditionsService.swift`, `Services/APIModels.swift`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| Networking / TLS     | `Services/StrideCheckHTTPSession.swift`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| Offline              | `Services/SnapshotCache.swift`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| Alerts               | `Services/RunWindowNotifier.swift`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Map / traffic        | `Services/State511Links.swift` (511 portal URLs), `Services/StateTrafficOverlayFeeds.swift` (curated per-state DOT ArcGIS GeoJSON queries), `Services/TrafficOverlayLoader.swift` (GeoJSON → points/polylines), `Services/StravaAPIClient.swift`, `Services/StravaOAuthService.swift`, `Services/StravaMapOverlayPreferences.swift` (map overlay **opt-in** + one-time migration), `Services/EncodedPolylineDecoder.swift`, `ViewModels/StravaLinkViewModel.swift` (shared via `environmentObject`; route refresh token)                                                                                                         |
| Wearables            | `Services/HealthKitReadinessFetcher.swift` (includes **Health authorization summary** for Data sources), `Services/HeatColdStress.swift` (heat index / wind chill for run-index **effective** temperature), `Services/OuraPersonalAPIClient.swift`, `Services/WhoopAPIClient.swift`, `Services/WhoopOAuthService.swift`, `Services/GarminAPIClient.swift`, `Services/GarminOAuthService.swift`, `Services/WearableReadinessAggregator.swift`, `Services/WearableRunIndexPreferences.swift` (Whoop/Oura/Garmin **use for run index** + migrations), `ViewModels/WhoopLinkViewModel.swift`, `ViewModels/GarminLinkViewModel.swift` |
| Secrets              | `Services/StrideCheckSecrets.swift`, `Services/KeychainCredentialStore.swift`, `StrideCheck/BuildConfig.xcconfig`, `Config/Secrets.xcconfig.template`                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| Crime (optional)     | `Services/CrimeIncidentsService.swift`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Signing              | `StrideCheck/StrideCheck.entitlements` (HealthKit + **App Group** `group.com.alearceo.StrideCheck` for widget data), `StrideCheckRunIndexWidget/StrideCheckRunIndexWidget.entitlements` (same App Group)                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Widget               | Target **StrideCheckRunIndexWidget** (`StrideCheckRunIndexWidget/`), shared types in `StrideCheck/WidgetShared/`; `Services/RunIndexWidgetExporter.swift` publishes after each successful conditions load. Tap opens **`stridecheck://run-index`** (Conditions tab).                                                                                                                                                                                                                                                                                                                                                               |


## Open and run

1. Open `ios/StrideCheck.xcodeproj` in Xcode.
2. Select the **StrideCheck** scheme and an iPhone simulator or device.
3. Build and run (**⌘R**).

### Device builds and HealthKit

The target uses the **HealthKit** capability. For a **physical device**, the App ID in the Apple Developer portal must have **HealthKit** enabled; then refresh or regenerate the provisioning profile (or use automatic signing and let Xcode fix it). Simulator builds do not hit that provisioning check the same way.

### Run Index widget

- **StrideCheckRunIndexWidget** is embedded in the app and shows the latest **run index** (colored score + Strong/Mixed/Tough) plus route awareness. Families: **system small**, **system medium**, **accessory circular**, **accessory rectangular**, **accessory inline** (lock screen / StandBy).
- **Medium widget layout:** Run Index hero on the left (large score + tier pill + context line + location) separated by a vertical divider from Route Awareness on the right (score + tier pill).
- The app writes a JSON payload to **shared `UserDefaults`** using App Group **`group.com.alearceo.StrideCheck`**, then calls `WidgetCenter.reloadTimelines(ofKind: "RunIndexNow")`. Enable the **App Groups** capability for **both** the main app and the widget extension in Xcode, and add the same group identifier to both App IDs in the Developer portal—otherwise the suite may be unavailable and the widget will show placeholder copy until signing matches.
- **Deep link:** widget taps use **`stridecheck://run-index`**; `ContentView` switches to the **Conditions** tab so the full breakdown is one tap away.

## Configuration: xcconfig, Keychain, and `Info.plist`

The **StrideCheck** target’s base configuration is `StrideCheck/BuildConfig.xcconfig`. It defines empty defaults for optional secrets, then `#include?`s `Config/Secrets.xcconfig` when you create it (gitignored).

1. Copy `Config/Secrets.xcconfig.template` → `Config/Secrets.xcconfig` (same folder).
2. Fill in values, or leave blank and use **Keychain** at runtime (see below).


| Build setting (xcconfig)                         | `Info.plist` key (expanded)                  | Runtime behavior                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| ------------------------------------------------ | -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `OURA_PERSONAL_ACCESS_TOKEN`                     | `OuraPersonalAccessToken`                    | **Keychain** wins if a value is stored (generic password service `com.alearceo.StrideCheck.credentials`, account `oura.pat`); otherwise plist from build.                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `CRIMEOMETER_API_KEY`                            | `CrimeometerAPIKey`                          | Same Keychain service; account `crimeometer.key` overrides plist.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `WHOOP_CLIENT_ID` / `WHOOP_CLIENT_SECRET`        | `WhoopClientId` / `WhoopClientSecret`        | **Keychain** (`whoop.oauth.client_id` / `whoop.oauth.client_secret`) wins when both are saved from **Data sources**; otherwise plist/xcconfig. Used for OAuth code exchange; **access/refresh tokens** are stored in Keychain after sign-in.                                                                                                                                                                                                                                                                                                                                   |
| `STRAVA_CLIENT_ID` / `STRAVA_CLIENT_SECRET`      | `StravaClientId` / `StravaClientSecret`      | **Keychain** (`strava.oauth.client_id` / `strava.oauth.client_secret`) wins when both are saved from **Map data sources**; otherwise plist/xcconfig. In [Strava API settings](https://www.strava.com/settings/api), set **Authorization Callback Domain** to **`localhost`** and use redirect URI **`stridecheck://localhost/strava-oauth`** (must match `StravaRedirectURI` in `Info.plist` / build exactly). Strava rejects bare custom hosts like `stridecheck://strava-oauth` without a registered domain. Override `StravaRedirectURI` only if you use another allowed pattern. Default scopes: `read`, `activity:read`. For **private** activities, change the scope string in `StravaOAuthService.swift` to include `activity:read_all` and re-authorize.                                 |
| `GARMIN_CONSUMER_KEY` / `GARMIN_CONSUMER_SECRET` | `GarminConsumerKey` / `GarminConsumerSecret` | **Keychain** (`garmin.oauth.consumer_key` / `garmin.oauth.consumer_secret`) wins when both are saved from **Data sources**; otherwise plist/xcconfig. Requires a **Garmin Connect Developer Program** app. Register redirect `**stridecheck://garmin-oauth`** (override with `GarminRedirectURI` in `Info.plist` if needed). OAuth uses **PKCE**; **access/refresh tokens** are stored in Keychain after sign-in. Wellness `**dailies`** are fetched for sleep, stress-derived readiness, and HRV when the API returns them—decode failures fall back to Health-only behavior. |


**Deprecated (removed):** `TrafficOverlayGeoJSONURL` / `TRAFFIC_OVERLAY_GEOJSON_URL` — the app no longer reads a custom GeoJSON URL from plist. Use **Apple Maps traffic** on the Route tab plus **per-state feeds** in `StateTrafficOverlayFeeds.swift` (Option C), or open the official 511 link.

**Whoop OAuth:** Register the app at [WHOOP Developer](https://developer.whoop.com). Add redirect URI `**stridecheck://whoop-oauth`** (or set `WhoopRedirectURI` in `Info.plist` to match your custom scheme). Users can enter **Client ID** and **Client secret** in **Data sources** (saved to Keychain) or rely on build-time plist/xcconfig. After sign-in, **access/refresh tokens** live in the **Keychain**. **Data sources for run index** (Conditions tab → card): **Use for run index** is per integration. Whoop API data is used only when connected **and** that toggle is on (connecting sets the toggle on; disconnect clears it).

**Oura:** Optional **Keychain** token from **Data sources** (or build-time plist). The **Use for run index** toggle must be on for the Oura API to affect the score; otherwise only Apple Health (and other Health-sourced data) applies.

**Garmin:** **Data sources** → **Garmin**: enter **Consumer Key** and **Consumer Secret** (Keychain or plist/xcconfig), **Connect Garmin** (browser OAuth), then **Use for run index**. Disconnect clears tokens and turns the toggle off. Connecting sets the toggle on. A **one-time migration** (`WearableRunIndexPreferences.applyGarminToggleMigrationIfNeeded()` in `StrideCheckApp`) turns **Use for run index** on if a Garmin access token already exists. `WearableReadinessAggregator` merges Garmin with Whoop/Oura/Health using the same readiness fields (sleep, readiness score, HRV) as other sources when enabled.

**Strava OAuth:** **Map data sources** (Route & 511 card → **Map data sources**, or Conditions → Data sources → **Map data sources (Strava)**): **Client ID**, **Client secret** (Keychain or plist), **Connect Strava**, optional **Show Strava routes on map** (`UserDefaults`; **off** for new installs). Polylines load only when **signed in and overlay is on**—no silent Strava API fetch for the map. **Callback domain:** set Strava’s **Authorization Callback Domain** to **`localhost`**; default app redirect is **`stridecheck://localhost/strava-oauth`** (custom URL scheme + `localhost` host). Re-connect Strava after changing redirect settings. **One-time migration:** if a Strava access token already exists, the overlay toggle is turned **on** once so existing users keep prior behavior. After sign-in, tokens live in the **Keychain**. The app requests recent activities and decodes **summary polylines** for **Run**, **TrailRun**, **VirtualRun**, and **Walk** types. Strava’s [API agreement](https://www.strava.com/legal/api) applies; do not replicate the Strava product or cache aggressively. `StravaLinkViewModel` is owned by `ContentView` and injected with `environmentObject` so Route and Map data sources share connection state.

**Security note:** The documented OAuth **authorization code** flow typically expects a **client secret** at token exchange time. Embedding `WHOOP_CLIENT_SECRET` or `STRAVA_CLIENT_SECRET` in a shipping app is weak; for production, prefer a **small backend** that holds the secret and exchanges the code for tokens, then issues tokens to the app.

### CI and `Info.plist` merge pattern

Xcode merges **target build settings** with `**INFOPLIST_FILE`**: any `$(VARIABLE)` in `Info.plist` is expanded from **xcconfig / build settings** at build time. You do **not** need a separate plist merge step if keys already use `$(OURA_PERSONAL_ACCESS_TOKEN)`-style placeholders.

Example CI step before `xcodebuild`:

```bash
cat > ios/Config/Secrets.xcconfig <<EOF
OURA_PERSONAL_ACCESS_TOKEN = ${OURA_PAT:-}
CRIMEOMETER_API_KEY = ${CRIMEOMETER_KEY:-}
WHOOP_CLIENT_ID = ${WHOOP_CLIENT_ID:-}
WHOOP_CLIENT_SECRET = ${WHOOP_CLIENT_SECRET:-}
STRAVA_CLIENT_ID = ${STRAVA_CLIENT_ID:-}
STRAVA_CLIENT_SECRET = ${STRAVA_CLIENT_SECRET:-}
GARMIN_CONSUMER_KEY = ${GARMIN_CONSUMER_KEY:-}
GARMIN_CONSUMER_SECRET = ${GARMIN_CONSUMER_SECRET:-}
EOF
xcodebuild -project ios/StrideCheck.xcodeproj -scheme StrideCheck -destination 'generic/platform=iOS Simulator' build
```

Use your CI system’s **secret store** for those environment variables; keep `Secrets.xcconfig` out of git (see repo `.gitignore`).

## Product behavior

### Conditions tab

- **Location first**, optional **5-digit zip** fallback; pull-to-refresh when location or zip is available.
- **Navigation bar hidden** so the title scrolls with content; full-width grouped layout.
- **Top edge treatment:** a taller **frosted / grouped-background gradient** under the status bar (time, Dynamic Island, cellular/Wi‑Fi) so scrolling content does not wash out system chrome—aligned in spirit with the Route tab’s bottom **ultra-thin material** card.
- **Data sources for run index** — **Apple Health** read-access summary, **Whoop**, **Oura**, **Garmin** (consumer key/secret + OAuth + **Use for run index**), and a link to **Map data sources (Strava)**. Third-party APIs affect the score only when enabled; **Apple Health** is read when the user has granted access (baseline when third-party **Use for run index** toggles are off).
- **Migrations at launch (`StrideCheckApp`):** `WearableRunIndexPreferences.applyMigrationIfNeeded()` — if a Whoop or Oura token already exists (Keychain or non-placeholder plist), the matching **Use for run index** toggle defaults **on**. `WearableRunIndexPreferences.applyGarminToggleMigrationIfNeeded()` — if a Garmin access token already exists, **Use for run index** for Garmin defaults **on** once. `StravaMapOverlayPreferences.applyMigrationIfNeeded()` — if a Strava access token already exists, **Show Strava routes on map** defaults **on** once.
- **Run index** — environmental score with tier styling (green / amber / red), using **effective** temperature (Open-Meteo feels-like blended with **heat index** and **wind chill** when applicable); adjusted by **wearable readiness** when data exists. **Route awareness** is a **separate** score (`AwarenessEngine`): night, NWS alerts, and optional crime context do **not** change the run index number (see comment in `ConditionsService.swift` before `ScoreEngine.compute`).
- **Hint banner:** when there is **no personal signal** for the index (no usable Health samples for the pipeline and no third-party slice) **and** Whoop, Oura, and Garmin are all **off** for the run index, an inline banner links to **Data sources** so users know how to fix denied Health or disabled wearables.
- **Wearables & readiness** — rows for data source, readiness score, sleep, HRV, strain proxy; explanatory bullets may be added to the run index list.
- **Auto-refresh after wearables:** when Whoop or Garmin **connects** or **disconnects**, Oura token is **saved** or **removed**, or **Use for run index** toggles change, the app posts `strideCheckReloadConditionsSnapshot` and **refetches** conditions if a **coordinate** or valid **zip** is available—no need to pull-to-refresh for run metrics alone.
- **Route awareness** — daylight, weather, air quality, NWS alerts, and **optional** third-party **crime-incident density** (with explicit disclaimers: incomplete, delayed, not a substitute for judgment or official safety resources).
- **Right now** / **Air & comfort** / **Next 12 hours** / **Active alerts**.
- **Offline:** last successful snapshot is stored under Application Support; if a fetch fails and nothing is in memory, the cache loads. A banner shows when you are viewing a **cached** copy.

### Conditions fetch behavior (implementation)

- **Overlapping loads** (e.g. pull-to-refresh plus a new GPS fix) use a monotonic **load sequence** so only the **latest** fetch updates `snapshot`, `errorMessage`, and `isLoading`—avoids stale data overwriting newer results and stuck spinners.
- **Cancellation** (`CancellationError`, `URLError.cancelled`) from superseded tasks is **not** shown as a user-visible error.

### Notifications

- Toggle **Strong run alerts** (stored in `UserDefaults`). When enabled, the app may schedule a **throttled** local notification if the run index is high after a refresh (see `RunWindowNotifier.swift`).

### Route & 511 tab

- Map uses `**MKMapView`** with `**showsTraffic**` so **Apple’s live traffic** colors appear where MapKit provides them (Option A).
- Map centered on the last conditions coordinate; link to **state 511** (or FHWA directory fallback).
- **State DOT geometry (Option C):** for selected states, the app requests **GeoJSON** from curated **ArcGIS FeatureServer** layers (`StateTrafficOverlayFeeds.swift`) using a bbox around your map center. Results render as **orange** polylines and **orange** incident-style markers. Feeds break or move; extend the registry as needed. States without a registry entry rely on traffic + 511 only.
- **Strava:** the bottom card includes **Map data sources** (NavigationLink) for credentials, OAuth, the **Show Strava routes on map** switch, and **Refresh routes**. **Purple** polylines appear only when the user has opted in and is signed in. **Teal** marker is the conditions location.
- **Suggested routes (beta, MVP):** the **Suggested routes** card lets you pick a workout type (**Easy**, **Intervals**, **Long run**) and **Find routes near here**. The app builds **out-and-back** candidates using **MapKit walking directions** (`MKDirections`) in several compass directions from your map center, scores them with **rule-based** distance / ascent / grade constraints (`WorkoutRouteIntent`, `RouteSuggestionService`—no LLM), and samples elevation via the public **Open-Elevation** API (`OpenElevationClient`, `https://api.open-elevation.com`). Up to three matches are listed; tap a row to draw it as a **green** polyline. Suggestions are **not** turn-by-turn navigation; verify roads, access, and safety yourself. If elevation data fails, the engine may fall back to distance-only fits. Changing the conditions location clears suggestions.

## Corporate proxy (Zscaler / SSL inspection)

If you see `ATS failed system trust`, `TLS Trust evaluation failed (-9802)`, or `NSURLErrorDomain Code=-1200` for API hosts, the network may be **SSL-inspecting** HTTPS.

**In-app mitigation:** `Info.plist` adds **ATS exceptions** (CT + forward-secrecy relaxed) for the API domains in use, including `open-meteo.com`, `weather.gov`, `zippopotam.us`, `crimeometer.com`, `ouraring.com`, `strava.com`, `whoop.com`, `garmin.com` (subdomains where applicable), and `arcgis.com` (subdomains where applicable). `StrideCheckHTTPSession` supplies `URLCredential(trust:)` for an internal **host allowlist** (including Garmin OAuth/API hosts, `*.arcgis.com`, common `*.dot.gov` GIS hosts used by state overlays, and **`api.open-elevation.com`** for route-suggestion elevation sampling).

**Still failing?** Trust your org’s inspection root on the device/Simulator, or ask IT to bypass inspection for the hostnames the app calls.

## Harmless console noise (can ignore)

- `Failed to send CA Event for app launch measurements` — Apple internal metrics.
- `Gesture: System gesture gate timed out` / `Result accumulator timeout` — common Simulator / keyboard timing.
- `Unable to simultaneously satisfy constraints` on `_UIRemoteKeyboardPlaceholderView` — keyboard layout quirk; `scrollDismissesKeyboard` reduces frequency.

### Simulator / system services (not app bugs)

These often appear when using the **Simulator**, **MapKit**, or **debugging**; they reflect sandboxed daemons and entitlements your app does not (and should not) have:

- `usermanagerd` / `personaAttributesForPersonaType` / (501) Invalidation handler — user-persona XPC; Simulator noise.
- `RBSServiceErrorDomain` / `Client not entitled` / `com.apple.runningboard.process-state` / `elapsedCPUTimeForFrontBoard` — RunningBoard; common when the debugger or Simulator asks for process state your app is not entitled to.
- `PerfPowerTelemetryClientRegistrationService` / Sandbox restriction (159) — power/performance telemetry; blocked in the Simulator sandbox.
- `PPSClientDonation` / `Maps / SpringfieldUsage` / `Permission denied` — MapKit internal metrics donation; Simulator often denies it.
- `Failed to locate resource named "default.csv"` / `fopen failed for data file` / `Errors found! Invalidating cache` — Geo/Map-related caches on Simulator; usually self-healing.
- `unable to make sandbox extension: Operation not permitted` — Simulator file/sandbox limitation.

The Route tab uses a **full-area `MKMapView`** (via `RouteTrafficMapView`) with **traffic enabled**, standard map type, POIs filtered out, and a **bottom safe-area inset** for the 511 card. Brief MapKit / Metal messages on Simulator tab switches are often benign.

## API / data notes

- **Open-Meteo** — forecast, `is_day`, optional daily sunrise/sunset fields.
- **Open-Meteo Air Quality** — US AQI / PM2.5 (best effort).
- **api.weather.gov** — active alerts for the coordinate.
- **Crimeometer** — endpoint and query parameters may evolve; if counts stay at zero or requests fail, verify API docs and your key/plan. Parsing tolerates several JSON shapes (`incidents`, `results`, `data`, etc.).
- **Oura** — field names follow v2 `usercollection` JSON; if Oura changes schemas, update `OuraPersonalAPIClient.swift`.
- **Whoop** — v2 developer API (`api.prod.whoop.com`); see `WhoopAPIClient.swift` if field names change.
- **Garmin** — OAuth (`connect.garmin.com`, `diauth.garmin.com`) and Wellness API (`apis.garmin.com`); `GarminAPIClient` requests `**dailies`** with a date range. Response shapes vary by program/version; the client is best-effort and tolerates decode failures by returning no slice.
- **Strava** — v3 endpoints (`www.strava.com/api/v3`); activity list and `map.summary_polyline` fields; see `StravaAPIClient.swift` and [Strava’s docs](https://developers.strava.com/docs/reference/).
- **State DOT overlays** — ArcGIS `FeatureServer/.../query?f=geojson` with an envelope around the map center; layer URLs live in `StateTrafficOverlayFeeds.swift` and must be maintained when agencies change services.

## Research: alternatives to Crimeometer (no code in this repo)

Crimeometer is convenient for a **generic “incidents near a point”** API, but licensing, coverage, and pricing may not fit every product. Candidates to evaluate on a **separate branch** or spike:


| Direction                                         | Notes                                                                                                                                                                         |
| ------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **FBI Crime Data Explorer (CDE)**                 | Official U.S. incident and aggregated data via their API; strong for research and some geographies, not a real-time “heat map” for runners. Terms and attribution matter.     |
| **State / city open data (Socrata, ArcGIS hubs)** | Many police departments publish **calls for service** or **reported incidents** with lat/lon; quality and refresh cadence vary. Often free but **per-city integration** work. |
| **Microsoft Azure Maps crime tile layers**        | Historical U.S. crime indexes as map layers (not raw incidents); different mental model than point incidents.                                                                 |
| **Commercial risk / location intelligence APIs**  | Vendors (e.g. LexisNexis, insurers’ data partners) offer licensed crime/risk scores; typically **enterprise contracts**, not mobile freemium.                                 |
| **User-reported / community safety apps**         | Ethically and legally sensitive; usually not appropriate to scrape; partnership would be required.                                                                            |


**Practical takeaway:** Replacing Crimeometer usually means either **official bulk data** (CDE, local open data) with custom geospatial queries, or a **commercial** licensed feed—not a drop-in swap. Keep disclaimers that **no dataset is complete or real-time** for personal safety decisions.