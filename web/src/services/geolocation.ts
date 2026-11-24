import type { LocationProblem, Origin } from '../domain/types'

export class LocationError extends Error {
  override readonly name = 'LocationError'
  readonly problem: LocationProblem

  constructor(problem: LocationProblem) {
    super(`Location ${problem}`)
    this.problem = problem
  }
}

const OPTIONS: PositionOptions = { enableHighAccuracy: true, timeout: 10_000, maximumAge: 60_000 }

function toProblem(error: GeolocationPositionError): LocationProblem {
  switch (error.code) {
    case error.PERMISSION_DENIED:
      return 'denied'
    case error.TIMEOUT:
      return 'timeout'
    default:
      return 'unavailable'
  }
}

function toOrigin({ coords }: GeolocationPosition): Origin {
  return {
    position: { lat: coords.latitude, lng: coords.longitude },
    label: 'Your location',
    source: 'gps',
    accuracyM: Number.isFinite(coords.accuracy) ? Math.round(coords.accuracy) : undefined,
  }
}

/** Asks for the position synchronously, so a call from a click handler still counts as a user gesture. */
export function locate(): Promise<Origin> {
  return new Promise((resolve, reject) => {
    if (!navigator.geolocation || !window.isSecureContext) {
      reject(new LocationError('unsupported'))
      return
    }
    navigator.geolocation.getCurrentPosition(
      (position) => resolve(toOrigin(position)),
      (error) => reject(new LocationError(toProblem(error))),
      OPTIONS,
    )
  })
}
