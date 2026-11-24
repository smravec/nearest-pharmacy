import type { LatLng, Origin, PharmacyResult } from '../domain/types'
import { ServiceError } from './http'
import { lookupTags } from './nominatim'
import { parseDetails } from './osm'
import { queryOverpass } from './overpass'
import { queryPhoton } from './photon'

const MAX_RADIUS_M = 50_000
const RADII_M = [2_000, 5_000, 20_000, MAX_RADIUS_M]
/** Wide enough for this many, so that one closed pharmacy isn't the whole list. */
const MIN_RESULTS = 3
/** Nominatim's policy allows looking up the results shown, not downloading an area's pharmacies. */
const MAX_RESULTS = 20

const OVERPASS_BUDGET_MS = 12_000
const OVERPASS_ATTEMPT_MS = 4_000

/**
 * Undefined if Overpass gave no answer. It often refuses or stalls and the fallback is good, so
 * retrying would only make people wait.
 */
async function searchOverpass(
  origin: LatLng,
  signal: AbortSignal,
): Promise<PharmacyResult | undefined> {
  const deadline = performance.now() + OVERPASS_BUDGET_MS
  let found: PharmacyResult | undefined
  try {
    for (const radiusM of RADII_M) {
      const timeoutMs = Math.min(OVERPASS_ATTEMPT_MS, deadline - performance.now())
      if (timeoutMs <= 0) throw new ServiceError('Overpass took too long')
      found = { pharmacies: await queryOverpass(origin, radiusM, signal, timeoutMs), radiusM }
      if (found.pharmacies.length >= MIN_RESULTS) break
    }
  } catch {
    signal.throwIfAborted()
    // The narrower radius may have found some. If it found none, there may still be some further away.
    if (!found?.pharmacies.length) return undefined
  }
  return found
}

async function searchPhoton(origin: LatLng, signal: AbortSignal): Promise<PharmacyResult> {
  const found = await queryPhoton(origin, MAX_RADIUS_M, signal)
  // The smallest step with enough results, so that both sources show comparable lists.
  const enoughM = found[MIN_RESULTS - 1]?.distanceM ?? Infinity
  const radiusM = RADII_M.find((radius) => radius >= enoughM) ?? MAX_RADIUS_M
  return { pharmacies: found.filter((p) => p.distanceM <= radiusM), radiusM }
}

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
  const overpass = await searchOverpass(position, signal)
  const { pharmacies, radiusM } = overpass ?? (await searchPhoton(position, signal))
  const result = {
    pharmacies: pharmacies.slice(0, MAX_RESULTS),
    radiusM,
    truncated: pharmacies.length > MAX_RESULTS,
  }
  return overpass ? result : addDetails(result, signal)
}
