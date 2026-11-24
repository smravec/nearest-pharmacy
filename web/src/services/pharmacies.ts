import type { Origin, PharmacyResult } from '../domain/types'
import { ServiceError, sleep, withTimeout } from './http'
import { OVERPASS_ENDPOINTS, queryOverpass } from './overpass'
import { queryPhoton } from './photon'

const RADII_M = [1000, 2000, 5000, 10000] as const
const MAX_RADIUS_M = 10000

const OVERPASS_BUDGET_MS = 12_000
const ATTEMPT_MS = 4_000
/** A failure quicker than this is likely a momentary rejection, worth one retry. */
const FAST_FAIL_MS = 1_000
const RETRY_DELAY_MS = 700
const PHOTON_TIMEOUT_MS = 6_000

/** Widens the radius until Overpass finds something. Undefined if no endpoint gave an answer. */
async function searchOverpass(
  origin: Origin,
  signal: AbortSignal,
): Promise<PharmacyResult | undefined> {
  const deadline = performance.now() + OVERPASS_BUDGET_MS
  let radiusIndex = 0

  for (const endpoint of OVERPASS_ENDPOINTS) {
    let retried = false
    for (;;) {
      const radiusM = RADII_M[radiusIndex]
      if (radiusM === undefined) {
        return { pharmacies: [], radiusM: MAX_RADIUS_M, source: 'overpass' }
      }
      const startedAt = performance.now()
      const remaining = deadline - startedAt
      if (remaining <= 0) return undefined

      try {
        const attempt = withTimeout(signal, Math.min(ATTEMPT_MS, remaining))
        const pharmacies = await queryOverpass(endpoint, origin.position, radiusM, attempt)
        if (pharmacies.length > 0) return { pharmacies, radiusM, source: 'overpass' }
        radiusIndex++
      } catch {
        signal.throwIfAborted()
        const failedAt = performance.now()
        const failedFast = failedAt - startedAt < FAST_FAIL_MS
        if (retried || !failedFast || deadline - failedAt <= RETRY_DELAY_MS) break
        retried = true
        await sleep(RETRY_DELAY_MS, signal)
      }
    }
  }
  return undefined
}

async function searchPhoton(origin: Origin, signal: AbortSignal): Promise<PharmacyResult> {
  try {
    const found = await queryPhoton(origin.position, withTimeout(signal, PHOTON_TIMEOUT_MS))
    const nearestM = found[0]?.distanceM ?? Infinity
    // The smallest step that has a result, so both sources show comparable lists.
    const radiusM = RADII_M.find((radius) => radius >= nearestM) ?? MAX_RADIUS_M
    return {
      pharmacies: found.filter((p) => p.distanceM <= radiusM),
      radiusM,
      source: 'photon',
    }
  } catch (cause) {
    signal.throwIfAborted()
    throw new ServiceError('No pharmacy data service responded', { cause })
  }
}

export async function findPharmacies(origin: Origin, signal: AbortSignal): Promise<PharmacyResult> {
  signal.throwIfAborted()
  return (await searchOverpass(origin, signal)) ?? searchPhoton(origin, signal)
}
