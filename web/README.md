# Nearest pharmacy: web app

Shows the pharmacy closest to you, how far it is, whether it is open and how to get there, on a map
and in a list. A static single-page app: no backend, no accounts, no API keys.

## Run it

Needs Node 22.12 or newer.

```sh
npm ci
npm run dev        # http://localhost:5173
```

`npm run build` writes `dist/`, `npm run preview` serves it, and `npm run typecheck` and
`npm run lint` check the code. Browsers share the location only on HTTPS or localhost; the address
search works anywhere.

## How it finds pharmacies

1. **Location:** the browser's geolocation, asked for only on click, or an address search.
2. **Pharmacies:** OpenStreetMap through [Overpass](https://overpass-api.de), within 2, 5, 20, then
   50 km, stopping at the first radius with three results.
3. **Fallback:** Overpass is a free shared service that often refuses or stalls. An attempt gets at most
   4 seconds and isn't retried. Then [Photon](https://photon.komoot.io) answers instead, and
   Nominatim looks up the opening hours, phone numbers and websites. If that fails, the page says so.
4. **Order:** straight-line (haversine) distance. Walking time, shown up to 5 km, assumes 5 km/h
   and is labeled as an estimate, because there is no routing service.

| Data | Service |
|---|---|
| Pharmacies | Overpass, then Photon with Nominatim |
| Address search | Nominatim |
| Map tiles | OpenFreeMap, drawn by MapLibre GL JS |

Coordinates or the search text go directly from the browser to these services. Nothing is stored.
Overpass and Photon get the position rounded to about 11 m.
Directions opens Google Maps; for a searched address, its coordinates go along as the start.

## Decisions

- **Search on submit only.** Nominatim's usage policy forbids autocomplete. Requests are limited to
  one per second and cached for the session.
- **Unknown is not closed.** Missing hours show "Hours unavailable". Hours that can't be evaluated are
  shown as listed: unparseable ones, public or school holiday rules (they depend on the country) and
  sunrise or sunset. Other hours ignore holidays, so the page says to call ahead.
- **The pharmacy's time zone.** Hours are evaluated where the pharmacy is, so searching another
  city gives the right answer.
- **OpenStreetMap data is untrusted.** It is rendered as text only, and links must be http(s).
- **Lazy loading.** The map and the opening hours parser are separate chunks, so the first view
  doesn't wait for them.
- **The map is optional.** Without WebGL or tiles, the list still has every pharmacy.

## Accessibility

- A live region announces the nearest result, and focus moves to it after a search. Someone who
  moved on while waiting keeps their place.
- The list is the full text equivalent of the map. Status is never shown by color alone.
- Light and dark follow the system, and reduced motion is respected.
- Everything works with native buttons, links and one form, so there are no custom keys to learn.

## Limits

- The public services have no uptime guarantee.
- OpenStreetMap entries can be missing or out of date.
- The search reaches 50 km and lists at most the nearest 20.

## Layout

```
src/domain/      types, distance, formatting, opening hours
src/services/    Overpass, Photon, Nominatim, geolocation
src/hooks/       search state, open states, media queries
src/components/  interface; map/ owns MapLibre
src/styles/      tokens and styles
```

`vercel.json` sets the Content Security Policy. A new service has to be added to its `connect-src`.

[opening_hours](https://github.com/opening-hours/opening_hours.js) is LGPL-3.0 and used unmodified, as
its own chunk.

Data © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), ODbL.
