import type { LatLng } from './types'

const EARTH_RADIUS_M = 6_371_008.8
const WALKING_M_PER_MIN = 5000 / 60
/** Further than this, nobody walks to a pharmacy. */
const MAX_WALK_M = 5000

const toRadians = (degrees: number) => (degrees * Math.PI) / 180

/** Great-circle distance in meters. */
export function haversineM(a: LatLng, b: LatLng): number {
  const sinLat = Math.sin(toRadians(b.lat - a.lat) / 2)
  const sinLng = Math.sin(toRadians(b.lng - a.lng) / 2)
  const h = sinLat ** 2 + Math.cos(toRadians(a.lat)) * Math.cos(toRadians(b.lat)) * sinLng ** 2
  // Rounding can push h slightly past 1 for antipodal points.
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(h)))
}

export function walkMinutes(distanceM: number): number | undefined {
  if (distanceM > MAX_WALK_M) return undefined
  return Math.max(1, Math.round(distanceM / WALKING_M_PER_MIN))
}
