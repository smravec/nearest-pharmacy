import { haversineM, walkMinutes } from '../domain/distance'
import type { LatLng, Pharmacy } from '../domain/types'
import { fetchJson, firstText, httpUrl, isRecord, ServiceError } from './http'

/**
 * Tried in order. Mirrors must be global and CORS-enabled. overpass.osm.ch is left out: it
 * returned an empty 200 for Helsinki.
 */
export const OVERPASS_ENDPOINTS: readonly string[] = ['https://overpass-api.de/api/interpreter']

export type UnmeasuredPharmacy = Omit<Pharmacy, 'distanceM' | 'walkMinutes'>

/** Drops duplicates, adds distances and sorts nearest first. */
export function rankByDistance(found: UnmeasuredPharmacy[], origin: LatLng): Pharmacy[] {
  const byId = new Map<string, Pharmacy>()
  for (const pharmacy of found) {
    if (byId.has(pharmacy.id)) continue
    const distanceM = haversineM(origin, pharmacy.position)
    byId.set(pharmacy.id, { ...pharmacy, distanceM, walkMinutes: walkMinutes(distanceM) })
  }
  return [...byId.values()].sort(
    (a, b) => a.distanceM - b.distanceM || (a.id < b.id ? -1 : 1),
  )
}

interface AddressParts {
  street?: string
  houseNumber?: string
  postcode?: string
  city?: string
}

const joinPresent = (parts: (string | undefined)[], separator: string) =>
  parts.filter(Boolean).join(separator)

export function formatAddress({ street, houseNumber, postcode, city }: AddressParts): string | undefined {
  const line = street && joinPresent([street, houseNumber], ' ')
  return joinPresent([line, joinPresent([postcode, city], ' ')], ', ') || undefined
}

/** A position from two untrusted values, or undefined unless both are finite numbers. */
export function toLatLng(lat: unknown, lng: unknown): LatLng | undefined {
  if (typeof lat !== 'number' || typeof lng !== 'number') return undefined
  return Number.isFinite(lat) && Number.isFinite(lng) ? { lat, lng } : undefined
}

function parseWheelchair(value: unknown): Pharmacy['wheelchair'] {
  if (value === 'designated') return 'yes'
  return value === 'yes' || value === 'limited' || value === 'no' ? value : undefined
}

function parseAddress(tags: Record<string, unknown>): string | undefined {
  const address = formatAddress({
    street: firstText(tags, 'addr:street', 'addr:place'),
    houseNumber: firstText(tags, 'addr:housenumber'),
    postcode: firstText(tags, 'addr:postcode'),
    city: firstText(tags, 'addr:city'),
  })
  return address ?? firstText(tags, 'addr:full')
}

function parseElement(element: unknown): UnmeasuredPharmacy | undefined {
  if (!isRecord(element)) return undefined
  const { type, id, center, tags } = element
  if (type !== 'node' && type !== 'way' && type !== 'relation') return undefined
  if (typeof id !== 'number') return undefined
  if (!isRecord(tags) || tags.amenity !== 'pharmacy') return undefined

  const position =
    toLatLng(element.lat, element.lon) ??
    (isRecord(center) ? toLatLng(center.lat, center.lon) : undefined)
  if (!position) return undefined

  return {
    id: `${type}/${id}`,
    name: firstText(tags, 'name', 'brand', 'operator') ?? 'Pharmacy',
    position,
    address: parseAddress(tags),
    phone: firstText(tags, 'phone', 'contact:phone', 'contact:mobile'),
    website: httpUrl(tags.website) ?? httpUrl(tags['contact:website']) ?? httpUrl(tags.url),
    openingHours: firstText(tags, 'opening_hours'),
    wheelchair: parseWheelchair(tags.wheelchair),
    source: 'overpass',
  }
}

export async function queryOverpass(
  endpoint: string,
  origin: LatLng,
  radiusM: number,
  signal: AbortSignal,
): Promise<Pharmacy[]> {
  const around = `${radiusM},${origin.lat.toFixed(6)},${origin.lng.toFixed(6)}`
  const data = `[out:json][timeout:5];nwr[amenity=pharmacy](around:${around});out center tags;`
  const body = await fetchJson(endpoint, {
    method: 'POST',
    body: new URLSearchParams({ data }),
    signal,
  })

  if (!isRecord(body) || !Array.isArray(body.elements)) {
    throw new ServiceError('Unexpected Overpass response')
  }
  // Overpass reports runtime errors this way, inside a 200 with partial or no elements.
  if (typeof body.remark === 'string' && body.remark) {
    throw new ServiceError(`Overpass: ${body.remark}`)
  }

  const found = body.elements.map(parseElement).filter((p) => p !== undefined)
  return rankByDistance(found, origin)
}
