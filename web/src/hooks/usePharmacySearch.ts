import { useEffect, useRef, useState } from 'react'
import type { LookupState, Origin, SearchState } from '../domain/types'
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
    searchRef.current?.abort()
    const controller = new AbortController()
    searchRef.current = controller
    const { signal } = controller

    setLookup({ status: 'idle' })
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
