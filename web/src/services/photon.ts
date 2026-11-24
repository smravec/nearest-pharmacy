import type { LatLng, Pharmacy } from '../domain/types'
import { fetchJson, firstText, isRecord, ServiceError } from './http'
import { formatAddress, rankByDistance, roundCoordinate, toLatLng } from './osm'
import type { UnmeasuredPharmacy } from './osm'

const PHOTON_ENDPOINT = 'https://photon.komoot.io/reverse'
/** The server's maximum. */
const RESULT_LIMIT = 50
const TIMEOUT_MS = 6_000

const OSM_TYPES: Record<string, string> = { N: 'node', W: 'way', R: 'relation' }

function parseFeature(feature: unknown): UnmeasuredPharmacy | undefined {
  if (!isRecord(feature) || !isRecord(feature.properties) || !isRecord(feature.geometry)) {
    return undefined
  }
  const { properties, geometry } = feature
  const type = OSM_TYPES[String(properties.osm_type)]
  if (!type || typeof properties.osm_id !== 'number') return undefined
  if (properties.osm_value !== 'pharmacy' || !Array.isArray(geometry.coordinates)) return undefined

  const [lng, lat] = geometry.coordinates as unknown[]
  const position = toLatLng(lat, lng)
  if (!position) return undefined

  return {
    id: `${type}/${properties.osm_id}`,
    name: firstText(properties, 'name') ?? 'Pharmacy',
    position,
    address: formatAddress({
      street: firstText(properties, 'street'),
      houseNumber: firstText(properties, 'housenumber'),
      postcode: firstText(properties, 'postcode'),
      city: firstText(properties, 'city'),
    }),
  }
}

/** The nearest pharmacies. Photon has no phone numbers, websites or opening hours. */
export async function queryPhoton(
  origin: LatLng,
  radiusM: number,
  signal: AbortSignal,
): Promise<Pharmacy[]> {
  const params = new URLSearchParams({
    lat: roundCoordinate(origin.lat),
    lon: roundCoordinate(origin.lng),
    osm_tag: 'amenity:pharmacy',
    radius: String(radiusM / 1000), // km
    limit: String(RESULT_LIMIT),
  })
  const body = await fetchJson(`${PHOTON_ENDPOINT}?${params}`, signal, TIMEOUT_MS)

  if (!isRecord(body) || !Array.isArray(body.features)) {
    throw new ServiceError('Unexpected Photon response')
  }
  const found = body.features.map(parseFeature).filter((p) => p !== undefined)
  return rankByDistance(found, origin)
}
