import { useCallback, useEffect, useReducer, useRef } from 'react'
import type { Origin, SearchState } from '../domain/types'
import { locate as requestLocation, LocationError } from '../services/geolocation'
import { geocode as requestGeocode } from '../services/nominatim'
import { findPharmacies } from '../services/pharmacies'

export type GeocodeState =
  | { status: 'idle' | 'searching' }
  | { status: 'notFound' | 'failed'; query: string }

interface State {
  search: SearchState
  geocode: GeocodeState
}

type Action =
  | { type: 'search'; search: SearchState }
  | { type: 'geocode'; geocode: GeocodeState }

type LastRequest = { kind: 'locate' } | { kind: 'origin'; origin: Origin }

const INITIAL_STATE: State = { search: { status: 'idle' }, geocode: { status: 'idle' } }

const ERROR_MESSAGE =
  "We couldn't reach the pharmacy data services. Check your connection and try again."

function reducer(state: State, action: Action): State {
  switch (action.type) {
    case 'search':
      return { ...state, search: action.search }
    case 'geocode':
      return { ...state, geocode: action.geocode }
  }
}

export interface PharmacySearch {
  state: SearchState
  geocode: GeocodeState
  locate(): void
  search(query: string): void
  retry(): void
}

export function usePharmacySearch(): PharmacySearch {
  const [state, dispatch] = useReducer(reducer, INITIAL_STATE)
  /** The locate or load in flight, if any. */
  const runRef = useRef<AbortController | null>(null)
  const geoRef = useRef<AbortController | null>(null)
  const lastRef = useRef<LastRequest | null>(null)

  useEffect(
    () => () => {
      runRef.current?.abort()
      geoRef.current?.abort()
    },
    [],
  )

  const load = useCallback(async (origin: Origin) => {
    runRef.current?.abort()
    const controller = new AbortController()
    runRef.current = controller
    lastRef.current = { kind: 'origin', origin }
    const setSearch = (search: SearchState) => {
      if (!controller.signal.aborted) dispatch({ type: 'search', search })
    }

    setSearch({ status: 'loading', origin })
    try {
      const result = await findPharmacies(origin, controller.signal)
      setSearch(
        result.pharmacies.length > 0
          ? { status: 'ready', origin, result }
          : { status: 'empty', origin, radiusM: result.radiusM },
      )
    } catch {
      setSearch({ status: 'error', origin, message: ERROR_MESSAGE })
    }
  }, [])

  const locate = useCallback(async () => {
    runRef.current?.abort()
    geoRef.current?.abort()
    const controller = new AbortController()
    runRef.current = controller
    lastRef.current = { kind: 'locate' }

    dispatch({ type: 'geocode', geocode: { status: 'idle' } })
    dispatch({ type: 'search', search: { status: 'locating' } })
    try {
      const origin = await requestLocation()
      if (!controller.signal.aborted) void load(origin)
    } catch (error) {
      if (controller.signal.aborted) return
      const problem = error instanceof LocationError ? error.problem : 'unavailable'
      dispatch({ type: 'search', search: { status: 'denied', problem } })
    }
  }, [load])

  const search = useCallback(
    async (input: string) => {
      const query = input.trim()
      if (!query) return

      // A locate or load in flight keeps going until the place is found: if the geocode fails,
      // its result is still what the user should see.
      geoRef.current?.abort()
      const controller = new AbortController()
      geoRef.current = controller
      const setGeocode = (geocode: GeocodeState) => dispatch({ type: 'geocode', geocode })

      setGeocode({ status: 'searching' })
      try {
        const origin = await requestGeocode(query, controller.signal)
        if (controller.signal.aborted) return
        if (!origin) {
          setGeocode({ status: 'notFound', query })
          return
        }
        setGeocode({ status: 'idle' })
        void load(origin)
      } catch {
        if (!controller.signal.aborted) setGeocode({ status: 'failed', query })
      }
    },
    [load],
  )

  const retry = useCallback(() => {
    const last = lastRef.current
    if (last?.kind === 'locate') void locate()
    else if (last) {
      // Otherwise an earlier address error would stay next to the new result.
      geoRef.current?.abort()
      dispatch({ type: 'geocode', geocode: { status: 'idle' } })
      void load(last.origin)
    }
  }, [load, locate])

  return { state: state.search, geocode: state.geocode, locate, search, retry }
}
