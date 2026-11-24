export interface LatLng {
  lat: number
  lng: number
}

/** The point distances are measured from. */
export interface Origin {
  position: LatLng
  label: string
  source: 'gps' | 'search'
  /** GPS accuracy radius in meters, when the browser reports one. */
  accuracyM?: number
}

export interface Pharmacy {
  /** `node/123`, `way/123` or `relation/123`: the same in every source. */
  id: string
  name: string
  position: LatLng
  /** Straight-line distance from the origin, in meters. */
  distanceM: number
  /** Only within walking distance. */
  walkMinutes?: number
  address?: string
  phone?: string
  /** Always http(s). */
  website?: string
  /** Raw OSM `opening_hours` value. */
  openingHours?: string
  wheelchair?: 'yes' | 'limited' | 'no'
}

/** `unknown` covers missing and unparseable hours. It never means closed. */
export interface OpenState {
  status: 'open' | 'closed' | 'unknown'
}

export interface PharmacyResult {
  /** Sorted by distance, nearest first. */
  pharmacies: Pharmacy[]
  /** The radius that produced the result, in meters. */
  radiusM: number
  /** Only the nearest are listed: there are more within the radius. */
  truncated?: boolean
  /** Opening hours, phone numbers, websites and wheelchair access couldn't be loaded. */
  detailsMissing?: boolean
}

export type LocationProblem = 'denied' | 'unavailable' | 'timeout' | 'unsupported'

export type SearchState =
  | { status: 'idle' }
  | { status: 'locating' }
  | { status: 'denied'; problem: LocationProblem }
  | { status: 'loading'; origin: Origin }
  | { status: 'ready'; origin: Origin; result: PharmacyResult }
  | { status: 'empty'; origin: Origin; radiusM: number }
  | { status: 'error'; origin: Origin; message: string }
