# The SWW Atlas

A personal travel tracker comprising a native Expo iPhone app at the repository root and the existing Python website and server in `website/`. Both use the same server records. See [website/README.md](website/README.md) for the deployment and excluded private data.

The app includes a trips register, annual and all-time statistics, country flags and a map, and a calendar for trips and individual events. Trip details show calendar events recorded during the trip and cross-year worksheet allocations; the map retains trips without coordinates. Original annual worksheet figures can be edited independently of live statistics. It uses pounds and UK dates. It connects automatically to the existing LAN or Tailscale server; saving requires a connection. The server has no login and must remain on a trusted private network. The app does not upload photos.

## Development

- `npm ci`
- `node tests/domain.cjs`
- `cd website && python3 -m unittest -q test_isolated.py`
- `npx expo export --platform ios`

The GitHub Actions workflow builds an unsigned IPA, which needs signing in iLoader. The app identifier is `uk.sww.atlas`; preserve it when updating an existing installation. A successful build does not replace checking the app on an iPhone.

## SwiftUI iPhone app

`ios-native/` contains the separate SwiftUI implementation. It uses the same server and bundle identifier as the React Native app. The `Build Swift iPhone app` workflow tests its calculations and produces an unsigned IPA for iLoader. The existing React Native source and workflow remain available. Native device testing is required before relying on the Swift app.
