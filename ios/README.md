# StrideCheck iOS (SwiftUI)

This folder contains a native SwiftUI implementation scaffold for the runner conditions app.

## What is included

- `StrideCheckApp.swift`: app entry point.
- `ContentView.swift`: UI with location-first flow and zip fallback.
- `ViewModels/ConditionsViewModel.swift`: state + async loading.
- `Services/LocationService.swift`: CoreLocation permission and current coordinate.
- `Services/ConditionsService.swift`: Open-Meteo, Zippopotam, NWS requests + scoring.
- `Services/StrideCheckHTTPSession.swift`: shared `URLSession` + server-trust handling for API TLS behind SSL inspection.
- `Services/APIModels.swift`: API decoding models and display DTOs.

## Open and run

1. Open `ios/StrideCheck.xcodeproj` in Xcode.
2. Select the `StrideCheck` scheme and an iPhone simulator/device.
3. Build and run.

The project already includes `NSLocationWhenInUseUsageDescription` in `StrideCheck/Info.plist`.

## Corporate proxy (Zscaler / SSL inspection)

If you see `ATS failed system trust`, `TLS Trust evaluation failed (-9802)`, or `NSURLErrorDomain Code=-1200` for `api.open-meteo.com`, `air-quality-api.open-meteo.com`, or `api.weather.gov`, your network is **SSL-inspecting** HTTPS and presenting a **Zscaler-signed** certificate instead of the real public CA chain. iOS rejects that unless the Zscaler root is trusted.

**In-app mitigation:** `Info.plist` adds **ATS exceptions** for `open-meteo.com`, `weather.gov`, and `zippopotam.us` (subdomains included), disabling **Certificate Transparency** and **forward-secrecy** requirements for those hosts only. `StrideCheckHTTPSession` answers **server-trust** with `URLCredential(trust:)` for the same host allowlist.

**Still failing?** Install your org’s Zscaler root on the Simulator/device and enable full trust, **or** ask IT to **bypass SSL inspection** for the API hostnames above.

## Harmless console noise (can ignore)

- `Failed to send CA Event for app launch measurements` — Apple internal metrics; not an app bug.
- `Gesture: System gesture gate timed out` / `Result accumulator timeout` — common Simulator / keyboard timing.
- `Unable to simultaneously satisfy constraints` on `_UIRemoteKeyboardPlaceholderView` — known UIKit keyboard layout quirk when the software keyboard is visible; usually harmless. SwiftUI’s `scrollDismissesKeyboard` reduces how often it appears.

## Product behavior

- On launch, it requests location permission and fetches conditions from the current device location.
- If permission is denied, user can still type a zip code as fallback.
- Displays:
  - run index + verdict,
  - current weather and wind,
  - AQI/PM2.5,
  - next 12-hour strip,
  - active NWS alerts.

## Next recommended enhancements

- Cache latest snapshot for offline viewing.
- Add local notifications for high-score run windows.
- Add route-level overlays (city-specific 511 feeds if available).