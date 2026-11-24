# Nearest pharmacy

Finds the pharmacy closest to you. Web app: **https://nearest-pharmacy.vercel.app**

![The web app showing the nearest pharmacy, a map and a list](docs/web.jpg)

![The iOS app: the nearest pharmacy, its hours in Apple's place card, and dark mode](docs/ios.jpg)

- [`web/`](web/): the web app (Vite, React, TypeScript)
- [`ios/`](ios/): the iOS app (SwiftUI, MapKit)

```sh
cd web && npm ci && npm run dev     # http://localhost:5173, needs Node 22.12 or newer
open ios/NearestPharmacy.xcodeproj  # then run it in a simulator with iOS 18 or later
```

An independent demo. Not affiliated with any pharmacy or healthcare provider.
