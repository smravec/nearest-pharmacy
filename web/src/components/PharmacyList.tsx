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
}

export function PharmacyList({
  origin,
  result,
  selectedId,
  openStates,
  rowsRef,
  onSelect,
}: PharmacyListProps) {
  const { pharmacies, radiusM, truncated } = result

  return (
    <section className="np-results__list" aria-labelledby="np-list-title">
      <div className="np-list">
        <h2 id="np-list-title" className="np-list__title">
          {truncated
            ? `Nearest ${pharmacies.length} pharmacies`
            : `${pharmacies.length} ${pharmacies.length === 1 ? 'pharmacy' : 'pharmacies'} within ${formatRadius(radiusM)}`}
        </h2>
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
        <p>Opening hours may be wrong, especially on public holidays.</p>
        <p>Distances are straight lines. Walking times assume 5 km/h and can be longer on real streets.</p>
      </div>
    </section>
  )
}
