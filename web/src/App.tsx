import { lazy, Suspense, useCallback, useEffect, useRef, useState } from 'react'
import type { RefObject } from 'react'
import { flushSync } from 'react-dom'
import { Attribution } from './components/Attribution'
import { Header } from './components/Header'
import { Hero } from './components/Hero'
import { announcement, LiveRegion } from './components/LiveRegion'
import { LocationSearch } from './components/LocationSearch'
import { MapBoundary } from './components/MapBoundary'
import { NearestCard } from './components/NearestCard'
import type { PharmacyMapHandle } from './components/pharmacyMap.types'
import { PharmacyList } from './components/PharmacyList'
import {
  DeniedView,
  EmptyView,
  ErrorView,
  LoadingView,
  LocatingView,
  Primer,
} from './components/StatusViews'
import type { Origin, PharmacyResult } from './domain/types'
import { useKeyboard } from './hooks/useKeyboard'
import { useOpenStates } from './hooks/useOpenStates'
import { usePharmacySearch } from './hooks/usePharmacySearch'

/** Where layout.css puts the list next to the map. */
const TWO_COLUMNS = '(min-width: 960px)'

const PharmacyMap = lazy(() => import('./components/PharmacyMap'))

interface ResultsProps {
  origin: Origin
  result: PharmacyResult
  selectedId: string | null
  headingRef: RefObject<HTMLHeadingElement | null>
  rowRefs: RefObject<Map<string, HTMLButtonElement>>
  onSelect(id: string | null): void
}

function Results({ origin, result, selectedId, headingRef, rowRefs, onSelect }: ResultsProps) {
  const { pharmacies } = result
  const openStates = useOpenStates(pharmacies)
  const mapRef = useRef<PharmacyMapHandle>(null)
  const nearest = pharmacies[0]

  function handlePin(id: string) {
    // Rendered first, so that the scroll includes the links the selected item gains.
    flushSync(() => onSelect(id))
    // In one column, scrolling to the list would move the map out of view.
    if (!window.matchMedia(TWO_COLUMNS).matches) return
    rowRefs.current.get(id)?.closest('li')?.scrollIntoView({ block: 'nearest' })
  }

  return (
    <div className="np-results">
      {nearest && (
        <NearestCard
          origin={origin}
          pharmacy={nearest}
          open={openStates.get(nearest.id)}
          headingRef={headingRef}
        />
      )}
      <section className="np-map">
        <MapBoundary
          fallback={
            <p className="np-map__message">The map couldn't load. The list has the same pharmacies.</p>
          }
        >
          <Suspense fallback={<p className="np-map__message np-map__message--loading">Loading map…</p>}>
            <PharmacyMap
              ref={mapRef}
              origin={origin}
              pharmacies={pharmacies}
              nearestId={nearest?.id ?? null}
              selectedId={selectedId}
              onSelect={handlePin}
            />
          </Suspense>
        </MapBoundary>
      </section>
      <PharmacyList
        origin={origin}
        result={result}
        selectedId={selectedId}
        openStates={openStates}
        rowRefs={rowRefs}
        onSelect={onSelect}
        onEnterMap={() => mapRef.current?.focus()}
      />
    </div>
  )
}

export function App() {
  const { state, geocode, locate, search, retry } = usePharmacySearch()
  const inputRef = useRef<HTMLInputElement>(null)
  const headingRef = useRef<HTMLHeadingElement>(null)
  const rowRefs = useRef<Map<string, HTMLButtonElement>>(new Map())
  const pendingFocus = useRef<{ from: Element | null } | null>(null)

  const [choice, setChoice] = useState<{ result: PharmacyResult; id: string | null } | null>(null)
  const [slowOrigin, setSlowOrigin] = useState<Origin | null>(null)

  const result = state.status === 'ready' ? state.result : null
  const firstId = result?.pharmacies[0]?.id ?? null
  // Tied to the result, so a new one starts on its nearest pharmacy again.
  const selectedId = choice && choice.result === result ? choice.id : firstId
  const slow = state.status === 'loading' && slowOrigin === state.origin

  // Declared first: a failed address search has to drop the pending move before the next effect runs.
  useEffect(() => {
    if (geocode.status === 'notFound' || geocode.status === 'failed') pendingFocus.current = null
  }, [geocode])

  useEffect(() => {
    const pending = pendingFocus.current
    if (!pending || state.status === 'idle' || state.status === 'locating' || state.status === 'loading') {
      return
    }
    // This is an earlier load finishing while a new address is being looked up.
    if (geocode.status === 'searching') return
    pendingFocus.current = null
    // Anyone who moved on while waiting keeps their place.
    const active = document.activeElement
    if (active === document.body || active === pending.from) headingRef.current?.focus()
  }, [state, geocode])

  function beginRequest() {
    pendingFocus.current = { from: document.activeElement }
    // Origins can be reused by a retry or a repeated search, which would show the slow notice at once.
    if (state.status !== 'loading') setSlowOrigin(null)
  }

  // Editing the address again means staying in the field when the results arrive.
  function handleEdit() {
    pendingFocus.current = null
  }

  function handleLocate() {
    beginRequest()
    locate()
  }

  function handleSearch(query: string) {
    beginRequest()
    search(query)
  }

  function handleRetry() {
    beginRequest()
    retry()
  }

  const handleSelect = useCallback(
    (id: string | null) => {
      if (result) setChoice({ result, id })
    },
    [result],
  )

  const handleSlash = useCallback(() => {
    inputRef.current?.focus()
    inputRef.current?.select()
  }, [])

  const handleEscape = useCallback(() => {
    const returnId = selectedId ?? firstId
    if (returnId && document.activeElement?.closest('.np-map')) rowRefs.current.get(returnId)?.focus()
    handleSelect(null)
  }, [selectedId, firstId, handleSelect])

  useKeyboard({ onSlash: handleSlash, onEscape: handleEscape })

  return (
    <>
      <a href="#main" className="np-skip">
        Skip to content
      </a>
      <div className="np-shell">
        <Header />
        <main id="main" className="np-main" tabIndex={-1}>
          <Hero state={state}>
            <LocationSearch
              geocode={geocode}
              locating={state.status === 'locating'}
              onEdit={handleEdit}
              onSearch={handleSearch}
              onLocate={handleLocate}
              inputRef={inputRef}
            />
          </Hero>
          {state.status === 'idle' && <Primer />}
          {state.status === 'locating' && <LocatingView />}
          {state.status === 'denied' && <DeniedView problem={state.problem} headingRef={headingRef} />}
          {state.status === 'loading' && (
            <LoadingView origin={state.origin} slow={slow} onSlow={setSlowOrigin} />
          )}
          {state.status === 'empty' && (
            <EmptyView origin={state.origin} radiusM={state.radiusM} headingRef={headingRef} />
          )}
          {state.status === 'error' && (
            <ErrorView message={state.message} onRetry={handleRetry} headingRef={headingRef} />
          )}
          {state.status === 'ready' && (
            <Results
              origin={state.origin}
              result={state.result}
              selectedId={selectedId}
              headingRef={headingRef}
              rowRefs={rowRefs}
              onSelect={handleSelect}
            />
          )}
        </main>
        <Attribution />
      </div>
      <LiveRegion message={announcement(state, geocode, slow)} />
    </>
  )
}
