# StrideCheck — Runner Road Conditions

iOS app that scores running conditions in real-time: weather, air quality, NWS alerts,
wearable readiness (Apple Health, Whoop, Oura, Garmin), and a route awareness index.
Includes a Home Screen widget (small + medium) and lock-screen accessories.

Full documentation, build instructions, and API key setup: **[`ios/README.md`](ios/README.md)**

## Repository layout

| Path | Contents |
|------|----------|
| `ios/` | Xcode project, Swift sources, widget extension, shared widget types |
| `ios/StrideCheckTests/` | Unit test files (wire target in Xcode — see `ios/StrideCheckTests/README.md`) |
| `.github/workflows/ios-ci.yml` | GitHub Actions CI: build + test on every push to main / feature branches |

## Quick start

```bash
# 1. Clone
git clone https://github.com/alearceo/runner-road-conditions.git
cd runner-road-conditions

# 2. Copy secrets template
cp ios/Config/Secrets.xcconfig.template ios/Config/Secrets.xcconfig
# Edit Secrets.xcconfig and fill in any optional API keys (Oura, Crimeometer, etc.)

# 3. Open in Xcode
open ios/StrideCheck.xcodeproj

# 4. Select iPhone 16 Simulator → ⌘R
```

## CI

GitHub Actions runs on every push to `main`, `cursor/**`, `widget/**`, and `feature/**` branches.
It builds the app for the iOS Simulator and runs the `StrideCheckTests` unit test target.

See `.github/workflows/ios-ci.yml` for the full workflow.

## Security notes

- API keys are resolved **Keychain-first**, then `Info.plist` build settings. Never commit `Secrets.xcconfig`.
- The TLS proxy-trust delegate (`StrideCheckHTTPSession`) is **debug builds only** (`#if DEBUG`). Release builds use standard system certificate validation.
- OAuth tokens are stored in the **Keychain** with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- Widget data is exchanged via **App Group shared `UserDefaults`** — no secrets cross the boundary.
