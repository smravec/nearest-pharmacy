import { lazy, Suspense, useEffect, useRef, useState } from 'react'
import type { RefObject } from 'react'
import { flushSync } from 'react-dom'
import { Attribution } from './components/Attribution'
import { Header } from './components/Header'
import { Hero } from './components/Hero'
import { announcement, LiveRegion } from './components/LiveRegion'
import { LocationSearch } from './components/LocationSearch'
import { MapBoundary } from './components/MapBoundary'
import { NearestCard } from './components/NearestCard'
import { PharmacyList } from './components/PharmacyList'
import {
  DeniedView,
  EmptyView,
  ErrorView,
  LoadingView,
  LocatingView,
  Primer,
} from './components/StatusViews'
import type { Origin, Pharmacy, PharmacyResult } from './domain/types'
import { useOpenStates } from './hooks/useOpenStates'
import { usePharmacySearch } from './hooks/usePharmacySearch'

/** Where layout.css puts the list next to the map. */
const TWO_COLUMNS = '(min-width: 960px)'

const PharmacyMap = lazy(() => import('./components/PharmacyMap'))

interface ResultsProps {
  origin: Origin
  result: PharmacyResult
  headingRef: RefObject<HTMLHeadingElement | null>
  onRetry(): void
}

function Results({ origin, result, headingRef, onRetry }: ResultsProps) {
  const { pharmacies } = result
  const openStates = useOpenStates(pharmacies)
  const rowsRef = useRef<HTMLOListElement>(null)
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const nearest = pharmacies[0]

  const statusOf = (pharmacy?: Pharmacy) => pharmacy && openStates.get(pharmacy.id)?.status
  const nearestOpen =
    statusOf(nearest) === 'closed' ? pharmacies.find((p) => statusOf(p) === 'open') : undefined

  /** Returns the selected row. Rendered first, so that a scroll includes the panel it gains. */
  function select(id: string) {
    flushSync(() => setSelectedId(id))
    return rowsRef.current?.querySelector<HTMLElement>('[aria-expanded="true"]')
  }

  function handlePin(id: string) {
    const row = select(id)
    // In one column, scrolling to the list would move the map out of view.
    if (window.matchMedia(TWO_COLUMNS).matches) row?.closest('li')?.scrollIntoView({ block: 'nearest' })
  }

  function handleShow(id: string) {
    const row = select(id)
    row?.focus()
    row?.closest('li')?.scrollIntoView({ block: 'nearest' })
  }

  return (
    <div className="np-results">
      {nearest && (
        <NearestCard
          origin={origin}
          pharmacy={nearest}
          open={openStates.get(nearest.id)}
          nearestOpen={nearestOpen}
          headingRef={headingRef}
          onShow={handleShow}
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
        rowsRef={rowsRef}
        onSelect={setSelectedId}
        onRetry={onRetry}
      />
    </div>
  )
}

export function App() {
  const { state, geocode, locate, search, retry } = usePharmacySearch()
  const headingRef = useRef<HTMLHeadingElement>(null)
  const pendingFocus = useRef<{ from: Element | null } | null>(null)
  const [slowOrigin, setSlowOrigin] = useState<Origin | null>(null)
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

  return (
    <>
      <div className="np-shell">
        <Header />
        <main className="np-main">
          <Hero state={state}>
            <LocationSearch
              geocode={geocode}
              locating={state.status === 'locating'}
              onEdit={handleEdit}
              onSearch={handleSearch}
              onLocate={handleLocate}
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
              headingRef={headingRef}
              onRetry={handleRetry}
            />
          )}
        </main>
        <Attribution />
      </div>
      <LiveRegion message={announcement(state, geocode, slow)} />
    </>
  )
}
