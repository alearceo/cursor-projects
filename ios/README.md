# StrideCheck iOS (SwiftUI)

This folder contains a native SwiftUI implementation scaffold for the runner conditions app.

## What is included

- `StrideCheckApp.swift`: app entry point.
- `ContentView.swift`: UI with location-first flow and zip fallback.
- `ViewModels/ConditionsViewModel.swift`: state + async loading.
- `Services/LocationService.swift`: CoreLocation permission and current coordinate.
- `Services/ConditionsService.swift`: Open-Meteo, Zippopotam, NWS requests + scoring.
- `Services/APIModels.swift`: API decoding models and display DTOs.

## Open and run

1. Open `ios/StrideCheck.xcodeproj` in Xcode.
2. Select the `StrideCheck` scheme and an iPhone simulator/device.
3. Build and run.

The project already includes `NSLocationWhenInUseUsageDescription` in `StrideCheck/Info.plist`.

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
