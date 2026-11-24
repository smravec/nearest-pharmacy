import { formatDistance, formatRadius, formatWalk } from '../domain/format'
import type { PharmacyResult, SearchState } from '../domain/types'
import type { GeocodeState } from '../hooks/usePharmacySearch'
import { geocodeErrorText } from './LocationSearch'
import { deniedCopy, emptyCopy, ERROR_TITLE } from './StatusViews'

export function LiveRegion({ message }: { message: string }) {
  return (
    <p className="np-sr" role="status" aria-live="polite" aria-atomic="true">
      {message}
    </p>
  )
}

// Opening status is left out: it loads later and refreshes every minute, which would re-announce.
function readyMessage({ pharmacies, radiusM, truncated }: PharmacyResult): string {
  const [nearest] = pharmacies
  if (!nearest) return ''
  const distance = formatDistance(nearest.distanceM)
  const walk = formatWalk(nearest.walkMinutes)
  const count = truncated
    ? `Showing the nearest ${pharmacies.length}.`
    : `${pharmacies.length} found within ${formatRadius(radiusM)}.`
  return `Nearest pharmacy: ${nearest.name}, ${distance} away, about ${walk}. ${count}`
}

function stateMessage(state: SearchState, slow: boolean): string {
  switch (state.status) {
    case 'idle':
      return ''
    case 'locating':
      return 'Finding your location.'
    case 'denied': {
      const { title, text } = deniedCopy(state.problem)
      return `${title}. ${text}`
    }
    case 'loading':
      return slow ? 'Still looking for pharmacies.' : 'Looking for pharmacies.'
    case 'ready':
      return readyMessage(state.result)
    case 'empty': {
      const { title, text } = emptyCopy(state.origin, state.radiusM)
      return `${title}. ${text}`
    }
    case 'error':
      return `${ERROR_TITLE}. ${state.message}`
  }
}

export function announcement(state: SearchState, geocode: GeocodeState, slow: boolean): string {
  if (geocode.status === 'searching') return 'Searching for the address.'
  const message = stateMessage(state, slow)
  const error = geocodeErrorText(geocode)
  if (!error) return message
  // Otherwise an outcome that arrives after a failed address lookup would never be announced.
  const waiting = state.status === 'idle' || state.status === 'locating' || state.status === 'loading'
  return waiting ? error : `${error} ${message}`
}
