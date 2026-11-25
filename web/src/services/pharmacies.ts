import type { Origin, PharmacyResult } from '../domain/types'
import { lookupTags } from './nominatim'
import { parseDetails } from './osm'
import { queryPhoton } from './photon'

const MAX_RADIUS_M = 50_000
const RADII_M = [2_000, 5_000, 20_000, MAX_RADIUS_M]
/** Wide enough for this many, so that one closed pharmacy isn't the whole list. */
const MIN_RESULTS = 3
/** Nominatim's policy allows looking up the results shown, not downloading an area's pharmacies. */
const MAX_RESULTS = 20

async function addDetails(result: PharmacyResult, signal: AbortSignal): Promise<PharmacyResult> {
  try {
    const tags = await lookupTags(result.pharmacies.map((p) => p.id), signal)
    const pharmacies = result.pharmacies.map((p) => ({ ...p, ...parseDetails(tags.get(p.id) ?? {}) }))
    return { ...result, pharmacies }
  } catch {
    signal.throwIfAborted()
    return { ...result, detailsMissing: true }
  }
}

export async function findPharmacies(
  { position }: Origin,
  signal: AbortSignal,
): Promise<PharmacyResult> {
  const found = await queryPhoton(position, MAX_RADIUS_M, signal)
  const enoughM = found[MIN_RESULTS - 1]?.distanceM ?? Infinity
  const radiusM = RADII_M.find((radius) => radius >= enoughM) ?? MAX_RADIUS_M
  const pharmacies = found.filter((p) => p.distanceM <= radiusM)
  const result = {
    pharmacies: pharmacies.slice(0, MAX_RESULTS),
    radiusM,
    truncated: pharmacies.length > MAX_RESULTS,
  }
  return addDetails(result, signal)
}
