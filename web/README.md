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
2. **Pharmacies:** OpenStreetMap through [Overpass](https://overpass-api.de), within 1, 2, 5, then
   10 km, stopping at the first radius with a result.
3. **Fallback:** Overpass is a free shared service and is sometimes at capacity. A quick failure
   other than an HTTP 4xx is retried once, and an attempt gets at most 4 seconds. Then [Photon](https://photon.komoot.io)
   answers instead. It has no opening hours or phone numbers, and the page says so.
4. **Order:** straight-line (haversine) distance. Walking time assumes 5 km/h and is labeled as an
   estimate, because there is no routing service.

| Data | Service |
|---|---|
| Pharmacies | Overpass, then Photon |
| Address search | Nominatim |
| Map tiles | OpenFreeMap, drawn by MapLibre GL JS |

Coordinates or the search text go directly from the browser to these services. Nothing is stored.
Directions opens Google Maps; for a searched address, its coordinates go along as the start.

## Decisions

- **Search on submit only.** Nominatim's usage policy forbids autocomplete. Requests are limited to
  one per second and cached for the session.
- **Unknown is not closed.** Missing or unparseable hours show "Hours unavailable". So do hours with
  public or school holiday rules (they depend on the country) and sunrise or sunset. Other hours
  ignore holidays, and the page says so.
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
- Keyboard: `/` search, `↑` `↓` `Home` `End` move in the list, `Enter` shows the pharmacy on the map,
  `Esc` clears the selection and leaves the map.

## Limits

- The public services have no uptime guarantee.
- OpenStreetMap entries can be missing or out of date.
- On the day daylight saving starts in the browser's time zone, clock times within the skipped hour
  count as an hour later when opening hours are evaluated.

## Layout

```
src/domain/      types, distance, formatting, opening hours
src/services/    Overpass, Photon, Nominatim, geolocation
src/hooks/       search state, open states, keyboard
src/components/  interface; map/ owns MapLibre
src/styles/      tokens and styles
```

`vercel.json` sets the Content Security Policy. A new service has to be added to its `connect-src`.

[opening_hours](https://github.com/opening-hours/opening_hours.js) is LGPL-3.0 and used unmodified, as
its own chunk.

Data © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), ODbL.
