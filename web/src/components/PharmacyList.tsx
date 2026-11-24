import { useState } from 'react'
import type { KeyboardEvent, RefObject } from 'react'
import { formatDistance, formatRadius, formatWalk } from '../domain/format'
import type { OpenStatus } from '../domain/openingHours'
import type { Origin, PharmacyResult } from '../domain/types'
import { useMediaQuery } from '../hooks/useMediaQuery'
import { OpenBadge, PharmacyFacts, PharmacyLinks } from './NearestCard'

interface PharmacyListProps {
  origin: Origin
  result: PharmacyResult
  selectedId: string | null
  openStates: ReadonlyMap<string, OpenStatus>
  rowRefs: RefObject<Map<string, HTMLButtonElement>>
  onSelect(id: string | null): void
  onEnterMap(): void
}

/**
 * Buttons in a list rather than a listbox: selected rows expand to hold links, and options may not
 * contain interactive content.
 */
export function PharmacyList({
  origin,
  result,
  selectedId,
  openStates,
  rowRefs,
  onSelect,
  onEnterMap,
}: PharmacyListProps) {
  const { pharmacies, radiusM, truncated, detailsMissing } = result
  const hasKeyboard = useMediaQuery('(hover: hover) and (pointer: fine)')
  const [lastFocusedId, setLastFocusedId] = useState<string | null>(null)
  const tabStopId = selectedId ?? lastFocusedId ?? pharmacies[0]?.id

  function moveTo(index: number) {
    const target = pharmacies[index]
    if (!target) return
    rowRefs.current.get(target.id)?.focus()
    onSelect(target.id)
  }

  function handleKeyDown(event: KeyboardEvent, index: number, id: string) {
    if (event.ctrlKey || event.metaKey || event.altKey) return
    switch (event.key) {
      case 'ArrowDown':
        moveTo(index + 1)
        break
      case 'ArrowUp':
        moveTo(index - 1)
        break
      case 'Home':
        moveTo(0)
        break
      case 'End':
        moveTo(pharmacies.length - 1)
        break
      case 'Enter':
        onSelect(id)
        onEnterMap()
        break
      default:
        return
    }
    event.preventDefault()
  }

  return (
    <section className="np-results__list" aria-labelledby="np-list-title">
      <div className="np-list">
        <div className="np-list__head">
          <h2 id="np-list-title">
            {truncated
              ? `Nearest ${pharmacies.length} pharmacies`
              : `${pharmacies.length} ${pharmacies.length === 1 ? 'pharmacy' : 'pharmacies'} within ${formatRadius(radiusM)}`}
          </h2>
          {hasKeyboard && (
            <p className="np-list__hint">Use ↑ and ↓ to move, Enter to show on the map, Esc to clear.</p>
          )}
        </div>
        <ol className="np-list__rows">
          {pharmacies.map((pharmacy, index) => {
            const { id } = pharmacy
            const selected = id === selectedId
            // OSM ids contain a slash, so the index makes the DOM id.
            const panelId = `np-d-${index}`
            return (
              <li key={id} className={selected ? 'np-item np-item--selected' : 'np-item'}>
                <button
                  ref={(node) => {
                    if (!node) return
                    rowRefs.current.set(id, node)
                    return () => {
                      rowRefs.current.delete(id)
                    }
                  }}
                  type="button"
                  className="np-row"
                  tabIndex={id === tabStopId ? 0 : -1}
                  aria-expanded={selected}
                  aria-controls={selected ? panelId : undefined}
                  aria-current={selected ? 'true' : undefined}
                  onClick={() => onSelect(selected ? null : id)}
                  onFocus={() => setLastFocusedId(id)}
                  onKeyDown={(event) => handleKeyDown(event, index, id)}
                >
                  <span className="np-row__rank" aria-hidden="true">
                    {index + 1}
                  </span>
                  <span className="np-row__name">{pharmacy.name}</span>
                  <span className="np-row__distance">{formatDistance(pharmacy.distanceM)}</span>
                  <span className="np-row__walk">{formatWalk(pharmacy.walkMinutes)}</span>
                  <span className="np-row__open">
                    <OpenBadge open={openStates.get(id)} />
                  </span>
                </button>
                {selected && (
                  <div id={panelId} className="np-item__panel">
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
        {detailsMissing ? (
          <p className="np-notes__warning">
            <svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true">
              <path d="M12 3.5 21.5 20h-19zM12 10v4.5M12 17v.5" />
            </svg>
            <span>Opening hours and phone numbers couldn't be loaded.</span>
          </p>
        ) : (
          <p>
            Opening hours come from OpenStreetMap and may be out of date. Public holidays aren't taken into
            account, so call ahead if it matters.
          </p>
        )}
        <p>Distances are straight lines. Walking times assume 5 km/h and can be longer on real streets.</p>
      </div>
    </section>
  )
}
