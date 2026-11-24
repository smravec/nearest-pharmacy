import type { Origin } from '../domain/types'
import { fetchJson, firstText, isRecord, ServiceError, sleep } from './http'
import type { OsmTags } from './osm'

// Nominatim's usage policy: at most one request per second, cached results, no autocomplete.
const NOMINATIM_ENDPOINT = 'https://nominatim.openstreetmap.org'
const MIN_INTERVAL_MS = 1_100
const SEARCH_TIMEOUT_MS = 8_000
const LOOKUP_TIMEOUT_MS = 4_000

const originsByQuery = new Map<string, Origin | null>()
const tagsById = new Map<string, OsmTags>()
let nextSlot = 0

async function waitForSlot(signal: AbortSignal): Promise<void> {
  const now = performance.now()
  const slot = Math.max(now, nextSlot)
  nextSlot = slot + MIN_INTERVAL_MS
  await sleep(slot - now, signal)
}

function parseCoordinate(value: unknown): number {
  const coordinate = typeof value === 'string' ? Number.parseFloat(value) : NaN
  if (!Number.isFinite(coordinate)) throw new ServiceError('Unexpected Nominatim response')
  return coordinate
}

function formatLabel(place: Record<string, unknown>, query: string): string {
  const address = isRecord(place.address) ? place.address : {}
  const road = firstText(address, 'road')
  const houseNumber = firstText(address, 'house_number')
  const city = firstText(address, 'city', 'town', 'village', 'municipality')

  const main =
    road && houseNumber
      ? `${road} ${houseNumber}`
      : (firstText(place, 'name') ?? firstText(place, 'display_name')?.split(',')[0] ?? query)
  return city && city !== main ? `${main}, ${city}` : main
}

function parsePlace(place: unknown, query: string): Origin {
  if (!isRecord(place)) throw new ServiceError('Unexpected Nominatim response')
  return {
    position: { lat: parseCoordinate(place.lat), lng: parseCoordinate(place.lon) },
    label: formatLabel(place, query),
    source: 'search',
  }
}

async function requestPlace(query: string, signal: AbortSignal): Promise<Origin | null> {
  const params = new URLSearchParams({ q: query, format: 'jsonv2', addressdetails: '1', limit: '1' })
  const body = await fetchJson(`${NOMINATIM_ENDPOINT}/search?${params}`, signal, SEARCH_TIMEOUT_MS)
  if (!Array.isArray(body)) throw new ServiceError('Unexpected Nominatim response')
  return body.length > 0 ? parsePlace(body[0], query) : null
}

/** Resolves to null when nothing matches. */
export async function geocode(query: string, signal: AbortSignal): Promise<Origin | null> {
  const normalized = query.trim().replace(/\s+/g, ' ')
  if (!normalized) return null

  const key = normalized.toLowerCase()
  const cached = originsByQuery.get(key)
  if (cached !== undefined) return cached

  await waitForSlot(signal)
  const origin = await requestPlace(normalized, signal)
  originsByQuery.set(key, origin)
  return origin
}

/** `node/123` is `N123` here. */
function toOsmId(id: string): string {
  const [type = '', number = ''] = id.split('/')
  return type.charAt(0).toUpperCase() + number
}

/** The OSM tags of pharmacies, by pharmacy id. */
export async function lookupTags(
  ids: string[],
  signal: AbortSignal,
): Promise<ReadonlyMap<string, OsmTags>> {
  const missing = ids.filter((id) => !tagsById.has(id))
  if (missing.length === 0) return tagsById

  await waitForSlot(signal)
  const params = new URLSearchParams({
    osm_ids: missing.map(toOsmId).join(','),
    format: 'jsonv2',
    extratags: '1',
    addressdetails: '0',
  })
  const body = await fetchJson(`${NOMINATIM_ENDPOINT}/lookup?${params}`, signal, LOOKUP_TIMEOUT_MS)
  if (!Array.isArray(body)) throw new ServiceError('Unexpected Nominatim response')

  // Objects that Nominatim leaves out are remembered too.
  for (const id of missing) tagsById.set(id, {})
  for (const place of body) {
    if (!isRecord(place) || !isRecord(place.extratags)) continue
    tagsById.set(`${place.osm_type}/${place.osm_id}`, place.extratags)
  }
  return tagsById
}
