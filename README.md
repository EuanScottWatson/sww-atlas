# The SWW Atlas

A native iPhone travel journal for the existing Holiday Tracker server. Trips are stored on that server and are shared with its website. The app needs a connection to load and save trips; it does not queue changes offline.

The default server is `http://192.168.32.48:7780`; change it in Settings for Tailscale or another private address. The existing server has no authentication and uses HTTP. Keep it on a trusted private network; do not expose it publicly.

## Development and iPhone build

Run `npm ci` and `npx expo export --platform ios`. The GitHub Actions workflow builds an unsigned IPA on a Mac runner. Download the artifact and sign/install it with iLoader. Device functionality must be checked on an iPhone. This is a new app identity (`uk.sww.atlas`), separate from Fish On.
