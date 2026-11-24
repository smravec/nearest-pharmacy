import { useEffect, useRef, useState } from 'react'
import type { RefObject } from 'react'
import { flushSync } from 'react-dom'
import { Attribution } from './components/Attribution'
import { Header } from './components/Header'
import { Hero } from './components/Hero'
import { LiveRegion, lookupMessage, searchMessage } from './components/LiveRegion'
import { LocationSearch } from './components/LocationSearch'
import { MapBoundary } from './components/MapBoundary'
import { NearestCard } from './components/NearestCard'
import { PharmacyList } from './components/PharmacyList'
import { EmptyView, ErrorView, IdleView, LoadingView } from './components/StatusViews'
import type { Origin, Pharmacy, PharmacyResult } from './domain/types'
import { useOpenStates } from './hooks/useOpenStates'
import { usePharmacySearch } from './hooks/usePharmacySearch'

/** Where layout.css puts the list next to the map. */
const TWO_COLUMNS = '(min-width: 960px)'

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
          detailsMissing={result.detailsMissing}
          headingRef={headingRef}
          onShow={handleShow}
          onRetry={onRetry}
        />
      )}
      <section className="np-map">
        <MapBoundary
          origin={origin}
          pharmacies={pharmacies}
          selectedId={selectedId}
          onSelect={handlePin}
        />
      </section>
      <PharmacyList
        origin={origin}
        result={result}
        selectedId={selectedId}
        openStates={openStates}
        rowsRef={rowsRef}
        onSelect={setSelectedId}
      />
    </div>
  )
}

export function App() {
  const { lookup, search, locate, searchAddress, retry } = usePharmacySearch()
  const headingRef = useRef<HTMLHeadingElement>(null)
  const pendingFocus = useRef<{ from: Element | null } | null>(null)
  const [slowOrigin, setSlowOrigin] = useState<Origin | null>(null)
  const slow = search.status === 'loading' && slowOrigin === search.origin

  useEffect(() => {
    const pending = pendingFocus.current
    if (!pending || lookup.status === 'locating' || lookup.status === 'searching') return
    // A lookup that fails beside an earlier search changes nothing but the message at the controls.
    const failed = lookup.status !== 'idle' && search.status !== 'idle'
    if (!failed && search.status === 'loading') return
    pendingFocus.current = null
    if (failed) return
    // Anyone who moved on while waiting keeps their place.
    const active = document.activeElement
    // An address error on its own has no heading, so the focus stays in the field.
    if (active === document.body || active === pending.from) headingRef.current?.focus()
  }, [lookup, search])

  function beginRequest() {
    pendingFocus.current = { from: document.activeElement }
    // Origins can be reused by a retry or a repeated search, which would show the slow notice at once.
    if (search.status !== 'loading') setSlowOrigin(null)
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
    searchAddress(query)
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
          <Hero search={search}>
            <LocationSearch
              lookup={lookup}
              hasSearch={search.status !== 'idle'}
              onEdit={handleEdit}
              onSearch={handleSearch}
              onLocate={handleLocate}
            />
          </Hero>
          {search.status === 'idle' && <IdleView lookup={lookup} headingRef={headingRef} />}
          {search.status === 'loading' && (
            <LoadingView origin={search.origin} slow={slow} onSlow={setSlowOrigin} />
          )}
          {search.status === 'empty' && (
            <EmptyView origin={search.origin} radiusM={search.radiusM} headingRef={headingRef} />
          )}
          {search.status === 'error' && <ErrorView onRetry={handleRetry} headingRef={headingRef} />}
          {search.status === 'ready' && (
            <Results
              origin={search.origin}
              result={search.result}
              headingRef={headingRef}
              onRetry={handleRetry}
            />
          )}
        </main>
        <Attribution />
      </div>
      <LiveRegion message={lookupMessage(lookup)} />
      <LiveRegion message={searchMessage(search, slow)} />
    </>
  )
}
