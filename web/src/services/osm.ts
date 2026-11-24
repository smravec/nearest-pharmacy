import { haversineM, walkMinutes } from '../domain/distance'
import type { LatLng, Pharmacy } from '../domain/types'
import { firstText, httpUrl } from './http'

export type OsmTags = Record<string, unknown>

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

/** For requests: about 11 m, so a service never gets the exact position. Distances use the exact one. */
export function roundCoordinate(degrees: number): string {
  return degrees.toFixed(4)
}

/** A position from two untrusted values, or undefined unless both are numbers on the globe. */
export function toLatLng(lat: unknown, lng: unknown): LatLng | undefined {
  if (typeof lat !== 'number' || typeof lng !== 'number') return undefined
  return Math.abs(lat) <= 90 && Math.abs(lng) <= 180 ? { lat, lng } : undefined
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

function parseWheelchair(value: unknown): Pharmacy['wheelchair'] {
  if (value === 'designated') return 'yes'
  return value === 'yes' || value === 'limited' || value === 'no' ? value : undefined
}

export function parseDetails(
  tags: OsmTags,
): Pick<Pharmacy, 'phone' | 'website' | 'openingHours' | 'wheelchair'> {
  return {
    phone: firstText(tags, 'phone', 'contact:phone', 'contact:mobile'),
    website: httpUrl(tags.website) ?? httpUrl(tags['contact:website']) ?? httpUrl(tags.url),
    openingHours: firstText(tags, 'opening_hours'),
    wheelchair: parseWheelchair(tags.wheelchair),
  }
}
