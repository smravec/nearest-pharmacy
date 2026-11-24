import type { Ref } from 'react'
import { formatDistance, formatRadius, formatWalk } from '../domain/format'
import type { OpenStatus } from '../domain/openingHours'
import type { Origin, PharmacyResult } from '../domain/types'
import { OpenBadge, PharmacyFacts, PharmacyLinks } from './NearestCard'

interface PharmacyListProps {
  origin: Origin
  result: PharmacyResult
  selectedId: string | null
  openStates: ReadonlyMap<string, OpenStatus>
  rowsRef: Ref<HTMLOListElement>
  onSelect(id: string | null): void
  onRetry(): void
}

export function PharmacyList({
  origin,
  result,
  selectedId,
  openStates,
  rowsRef,
  onSelect,
  onRetry,
}: PharmacyListProps) {
  const { pharmacies, radiusM, truncated, detailsMissing } = result

  return (
    <section className="np-results__list" aria-labelledby="np-list-title">
      <div className="np-list">
        <h2 id="np-list-title" className="np-list__title">
          {truncated
            ? `Nearest ${pharmacies.length} pharmacies`
            : `${pharmacies.length} ${pharmacies.length === 1 ? 'pharmacy' : 'pharmacies'} within ${formatRadius(radiusM)}`}
        </h2>
        {detailsMissing && (
          <div className="np-list__warning">
            <svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true">
              <path d="M12 3.5 21.5 20h-19zM12 10v4.5M12 17v.5" />
            </svg>
            <p>Opening hours and phone numbers couldn't be loaded.</p>
            <button type="button" className="np-btn np-btn--secondary" onClick={onRetry}>
              Try again
            </button>
          </div>
        )}
        <ol ref={rowsRef} className="np-list__rows">
          {pharmacies.map((pharmacy, index) => {
            const { id } = pharmacy
            const selected = id === selectedId
            return (
              <li key={id} className={selected ? 'np-item np-item--selected' : 'np-item'}>
                <button
                  type="button"
                  className="np-row"
                  aria-expanded={selected}
                  onClick={() => onSelect(selected ? null : id)}
                >
                  <span className="np-row__rank" aria-hidden="true">
                    {index + 1}
                  </span>
                  <span className="np-row__name">{pharmacy.name}</span>
                  <span className="np-row__distance">{formatDistance(pharmacy.distanceM)}</span>
                  {pharmacy.walkMinutes && (
                    <span className="np-row__walk">{formatWalk(pharmacy.walkMinutes)}</span>
                  )}
                  <span className="np-row__open">
                    <OpenBadge open={openStates.get(id)} />
                  </span>
                </button>
                {selected && (
                  <div className="np-item__panel">
                    {/* The card above already shows these facts for the nearest one. */}
                    {index > 0 && <PharmacyFacts pharmacy={pharmacy} />}
                    <PharmacyLinks origin={origin} pharmacy={pharmacy} />
                  </div>
                )}
              </li>
            )
          })}
        </ol>
      </div>
      <div className="np-notes">
        <p>
          Opening hours come from OpenStreetMap and may be wrong, especially on public holidays. Call ahead
          if it matters.
        </p>
        <p>Distances are straight lines. Walking times assume 5 km/h and can be longer on real streets.</p>
      </div>
    </section>
  )
}
