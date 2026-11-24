import type { LatLng, Origin, Pharmacy } from './types'

export function formatDistance(distanceM: number): string {
  const rounded = Math.round(distanceM / 10) * 10
  return rounded < 1000 ? `${Math.max(rounded, 10)} m` : `${(distanceM / 1000).toFixed(1)} km`
}

/** Search radii are whole kilometers. */
export function formatRadius(radiusM: number): string {
  return `${radiusM / 1000} km`
}

export function formatWalk(minutes: number): string {
  return `${minutes} min walk`
}

/** `tel:` link for the first number in an OSM phone value, or undefined if it can't be dialed. */
export function telHref(phone?: string): string | undefined {
  const first = phone?.split(/[;,]/)[0]?.trim()
  // A slash either separates two numbers or belongs to an area code, and we can't tell which.
  if (!first || /[\p{L}/]/u.test(first)) return undefined

  const international = first.startsWith('+')
  // "+358 (0)9 …": the trunk zero is only dialed without the country code.
  const digits = (international ? first.replace('(0)', '') : first).replace(/\D/g, '')
  if (digits.length < 3 || digits.length > 15) return undefined
  return `tel:${international ? '+' : ''}${digits}`
}

const latLngParam = ({ lat, lng }: LatLng) => `${lat},${lng}`

/** Google Maps walking directions. A GPS origin is left out so that Maps uses the live position. */
export function directionsUrl(origin: Origin, pharmacy: Pharmacy): string {
  const params = new URLSearchParams({
    api: '1',
    destination: latLngParam(pharmacy.position),
    travelmode: 'walking',
  })
  if (origin.source === 'search') params.set('origin', latLngParam(origin.position))
  return `https://www.google.com/maps/dir/?${params}`
}
