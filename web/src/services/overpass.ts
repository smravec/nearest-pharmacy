import type { LatLng, Pharmacy } from '../domain/types'
import { fetchJson, firstText, isRecord, ServiceError } from './http'
import { formatAddress, parseDetails, rankByDistance, roundCoordinate, toLatLng } from './osm'
import type { OsmTags, UnmeasuredPharmacy } from './osm'

const OVERPASS_ENDPOINT = 'https://overpass-api.de/api/interpreter'

function parseAddress(tags: OsmTags): string | undefined {
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
    ...parseDetails(tags),
  }
}

export async function queryOverpass(
  origin: LatLng,
  radiusM: number,
  signal: AbortSignal,
  timeoutMs: number,
): Promise<Pharmacy[]> {
  const around = `${radiusM},${roundCoordinate(origin.lat)},${roundCoordinate(origin.lng)}`
  const data = `[out:json][timeout:5];nwr[amenity=pharmacy](around:${around});out center tags;`
  const body = await fetchJson(OVERPASS_ENDPOINT, signal, timeoutMs, {
    method: 'POST',
    body: new URLSearchParams({ data }),
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
