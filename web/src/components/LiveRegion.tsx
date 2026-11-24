import { formatDistance, formatRadius, formatWalk } from '../domain/format'
import type { LookupState, PharmacyResult, SearchState } from '../domain/types'
import { lookupErrorText } from './LocationSearch'
import { emptyCopy, ERROR_TEXT, ERROR_TITLE } from './StatusViews'

/** One per state, so that neither can hide or repeat what the other has to say. */
export function LiveRegion({ message }: { message: string }) {
  return (
    <p className="np-sr" role="status" aria-live="polite" aria-atomic="true">
      {message}
    </p>
  )
}

export function lookupMessage(lookup: LookupState): string {
  switch (lookup.status) {
    case 'idle':
      return ''
    case 'locating':
      return 'Finding your location.'
    case 'searching':
      return 'Searching for the address.'
    default:
      return lookupErrorText(lookup)
  }
}

// Opening status is left out: it loads later and refreshes every minute, which would re-announce.
function readyMessage({ pharmacies, radiusM, truncated }: PharmacyResult): string {
  const [nearest] = pharmacies
  if (!nearest) return ''
  const distance = formatDistance(nearest.distanceM)
  const walk = nearest.walkMinutes ? `, about ${formatWalk(nearest.walkMinutes)}` : ''
  const count = truncated
    ? `Showing the nearest ${pharmacies.length}.`
    : `${pharmacies.length} found within ${formatRadius(radiusM)}.`
  return `Nearest pharmacy: ${nearest.name}, ${distance} away${walk}. ${count}`
}

export function searchMessage(search: SearchState, slow: boolean): string {
  switch (search.status) {
    case 'idle':
      return ''
    case 'loading':
      return slow ? 'Still looking for pharmacies.' : 'Looking for pharmacies.'
    case 'ready':
      return readyMessage(search.result)
    case 'empty': {
      const { title, text } = emptyCopy(search.origin, search.radiusM)
      return `${title}. ${text}`
    }
    case 'error':
      return `${ERROR_TITLE}. ${ERROR_TEXT}`
  }
}
