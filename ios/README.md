# Nearest pharmacy for iOS

A SwiftUI app that finds the pharmacy closest to you. It is an independent demo. No dependencies,
API keys or accounts.

## Run it

Open `NearestPharmacy.xcodeproj` in Xcode (developed with 27.2) and run it in a simulator with iOS 18 or
later. For a device, choose your own team under Signing & Capabilities.

To set a position in the simulator: Features › Location › Custom Location, for example Helsinki
Central (60.1719, 24.9414).

## How it works

1. **Where you are.** Location is requested only after you tap "Use my location". Without it, you can
   search for an address or place (Apple's search).
2. **Which pharmacies.** [Photon](https://photon.komoot.io) searches OpenStreetMap within 5, 15, 50,
   then 100 km, stopping at the first radius with a result. The app sorts them by straight-line distance.
3. **Details.** Photon has no opening hours. Tapping Details looks the pharmacy up in Apple Maps and
   shows Apple's place card, but only if the category, distance (150 m at most) and name all match. Otherwise
   the app says there are no details, or that Apple Maps couldn't be reached.

### Why not MapKit's pharmacy search?

I compared both at ten public points on 2026-11-24. MapKit's pharmacy category returned a vape shop in
Helsinki and a supplement store in Rovaniemi. OpenStreetMap had pharmacies within 5 km of nine of the
ten points, and 15 km was enough for the tenth. So OpenStreetMap decides what is nearest, and Apple
Maps only adds details.

This has a cost: OpenStreetMap can list a pharmacy that has closed. At one test point (Kallio, Helsinki)
the nearest one in OpenStreetMap is marked "Permanently Closed" in Apple Maps, and I could not find out
which is right. MapKit exposes no closure status in code, so the app only shows this after you tap
Details. The nearest card says so, and the Google Maps button opens a Google search for the pharmacy
(a link, no API key).

## Code

| Folder | Contents |
|---|---|
| `Domain/` | Value types, protocols, distance and formatting |
| `Services/` | Photon, Core Location, Apple place search and details |
| `Model/` | `AppModel`, the observable state the views bind to |
| `Views/` | SwiftUI screens |
| `Design/` | Colors, button styles, assets |

The services sit behind protocols, so `AppModel` doesn't depend on the network or on location.
Results of a search that has been replaced are ignored, even if they arrive late.

In Debug builds the launch argument `-failPharmacySearch` makes the first search fail, to show the
error screen and Try again.

## Limits

- Distances are straight lines, and walking time assumes 5 km/h.
- Photon is a free public service with no uptime promise and no fallback here. If it fails, the app
  says so and offers Try again. It never reports "no pharmacies" for a failed request.
- OpenStreetMap and Apple Maps can be out of date.
- Your position, or the place you search for, is sent to Photon and Apple. The Google Maps button sends
  that pharmacy's name and address, or its position, to Google.
- English only.
