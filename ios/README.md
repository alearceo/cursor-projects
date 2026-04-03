# StrideCheck iOS (SwiftUI)

This folder contains a native SwiftUI implementation scaffold for the runner conditions app.

## What is included

- `StrideCheckApp.swift`: app entry point.
- `ContentView.swift`: UI with location-first flow and zip fallback.
- `ViewModels/ConditionsViewModel.swift`: state + async loading.
- `Services/LocationService.swift`: CoreLocation permission and current coordinate.
- `Services/ConditionsService.swift`: Open-Meteo, Zippopotam, NWS requests + scoring.
- `Services/APIModels.swift`: API decoding models and display DTOs.

## Xcode setup

1. Create a new iOS app project in Xcode named `StrideCheck` (SwiftUI, Swift, iOS 17+).
2. Copy the files from `ios/StrideCheck` into your Xcode project (replace template files).
3. Enable **Location Updates** capability if needed later (not required for one-shot location requests).
4. Add this key in your target `Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>StrideCheck uses your location to detect local running conditions automatically.</string>
```

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
