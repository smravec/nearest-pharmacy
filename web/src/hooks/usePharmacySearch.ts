import { useEffect, useRef, useState } from 'react'
import type { LatLng, LookupState, Origin, SearchState } from '../domain/types'
import { locate as requestLocation, LocationError } from '../services/geolocation'
import { geocode } from '../services/nominatim'
import { findPharmacies } from '../services/pharmacies'

interface PharmacySearch {
  lookup: LookupState
  search: SearchState
  locate(): void
  searchAddress(query: string): void
  retry(): void
}

/** A lookup finds the place, then a search finds the pharmacies around it. One of each runs at a time. */
export function usePharmacySearch(): PharmacySearch {
  const [lookup, setLookup] = useState<LookupState>({ status: 'idle' })
  const [search, setSearch] = useState<SearchState>({ status: 'idle' })
  const lookupRef = useRef<AbortController | null>(null)
  const searchRef = useRef<AbortController | null>(null)
  const queryRef = useRef('')
  const loadingRef = useRef<LatLng | null>(null)

  useEffect(
    () => () => {
      lookupRef.current?.abort()
      searchRef.current?.abort()
    },
    [],
  )

  function startLookup(status: 'locating' | 'searching'): AbortSignal {
    lookupRef.current?.abort()
    const controller = new AbortController()
    lookupRef.current = controller
    setLookup({ status })
    return controller.signal
  }

  /** Ends the lookup and replaces the search, which keeps going until there is a new place. */
  async function load(origin: Origin) {
    lookupRef.current?.abort()
    setLookup({ status: 'idle' })
    // Asking again for the place that is loading would only start over.
    const { lat, lng } = origin.position
    if (loadingRef.current?.lat === lat && loadingRef.current.lng === lng) return

    searchRef.current?.abort()
    const controller = new AbortController()
    searchRef.current = controller
    loadingRef.current = origin.position
    const { signal } = controller

    setSearch({ status: 'loading', origin })
    try {
      const result = await findPharmacies(origin, signal)
      if (signal.aborted) return
      setSearch(
        result.pharmacies.length > 0
          ? { status: 'ready', origin, result }
          : { status: 'empty', origin, radiusM: result.radiusM },
      )
    } catch {
      if (!signal.aborted) setSearch({ status: 'error', origin })
    } finally {
      if (!signal.aborted) loadingRef.current = null
    }
  }

  async function locate() {
    const signal = startLookup('locating')
    try {
      const origin = await requestLocation()
      if (!signal.aborted) void load(origin)
    } catch (error) {
      if (signal.aborted) return
      const problem = error instanceof LocationError ? error.problem : 'unavailable'
      setLookup({ status: 'locationFailed', problem })
    }
  }

  async function searchAddress(input: string) {
    const query = input.trim()
    if (!query) return
    // Submitting the address that is being looked up again would only abort it and ask once more.
    if (lookup.status === 'searching' && query === queryRef.current) return
    queryRef.current = query
    const signal = startLookup('searching')
    try {
      const origin = await geocode(query, signal)
      if (signal.aborted) return
      if (origin) void load(origin)
      else setLookup({ status: 'addressFailed', problem: 'notFound', query })
    } catch {
      if (!signal.aborted) setLookup({ status: 'addressFailed', problem: 'noAnswer', query })
    }
  }

  function retry() {
    if ('origin' in search) void load(search.origin)
  }

  return { lookup, search, locate, searchAddress, retry }
}
