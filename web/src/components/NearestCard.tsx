import type { Ref } from 'react'
import { directionsUrl, formatDistance, formatWalk, telHref } from '../domain/format'
import type { OpenStatus } from '../domain/openingHours'
import type { Origin, Pharmacy } from '../domain/types'

const WHEELCHAIR_TEXT: Record<NonNullable<Pharmacy['wheelchair']>, string> = {
  yes: 'Wheelchair accessible',
  limited: 'Partly wheelchair accessible',
  no: 'Not wheelchair accessible',
}

export function OpenBadge({ open }: { open: OpenStatus | undefined }) {
  if (!open) return <span className="np-open">Checking hours…</span>
  return (
    <span className={`np-open np-open--${open.status}`}>
      <span className="np-open__dot" aria-hidden="true" />
      <span className="np-open__text">
        <span className="np-open__label">{open.label}</span>
        {open.detail && `${open.status === 'unknown' ? ': ' : ' · '}${open.detail}`}
      </span>
    </span>
  )
}

export function PharmacyFacts({ pharmacy }: { pharmacy: Pharmacy }) {
  return (
    <>
      {pharmacy.address && <p className="np-address">{pharmacy.address}</p>}
      {pharmacy.phone && <p className="np-meta">{pharmacy.phone}</p>}
      {pharmacy.wheelchair && <p className="np-meta">{WHEELCHAIR_TEXT[pharmacy.wheelchair]}</p>}
    </>
  )
}

interface PharmacyLinksProps {
  origin: Origin
  pharmacy: Pharmacy
  primary?: boolean
}

export function PharmacyLinks({ origin, pharmacy, primary = false }: PharmacyLinksProps) {
  const { name, phone, website } = pharmacy
  const tel = telHref(phone)

  return (
    <div className="np-links">
      <a
        className={primary ? 'np-btn np-btn--primary' : 'np-btn np-btn--secondary'}
        href={directionsUrl(origin, pharmacy)}
        target="_blank"
        rel="noreferrer"
      >
        Directions<span className="np-sr"> to {name} (opens in a new tab)</span>
      </a>
      {tel && (
        <a className="np-btn np-btn--secondary" href={tel}>
          Call<span className="np-sr"> {name}</span>
        </a>
      )}
      {website && (
        <a className="np-btn np-btn--secondary" href={website} target="_blank" rel="noreferrer">
          Website<span className="np-sr"> of {name} (opens in a new tab)</span>
        </a>
      )}
    </div>
  )
}

interface NearestCardProps {
  origin: Origin
  pharmacy: Pharmacy
  open: OpenStatus | undefined
  /** Set when the nearest is closed and another one is open. */
  nearestOpen: Pharmacy | undefined
  /** Opening hours and phone numbers couldn't be loaded, for any of the pharmacies. */
  detailsMissing: boolean | undefined
  headingRef: Ref<HTMLHeadingElement>
  onShow(id: string): void
  onRetry(): void
}

export function NearestCard({
  origin,
  pharmacy,
  open,
  nearestOpen,
  detailsMissing,
  headingRef,
  onShow,
  onRetry,
}: NearestCardProps) {
  return (
    <article className="np-nearest" aria-labelledby="np-nearest-name">
      <p className="np-nearest__eyebrow">Nearest to {origin.source === 'gps' ? 'you' : origin.label}</p>
      <h2 id="np-nearest-name" ref={headingRef} tabIndex={-1}>
        {pharmacy.name}
      </h2>
      <p className="np-figure">
        <span className="np-figure__distance">{formatDistance(pharmacy.distanceM)}</span>
        <span className="np-figure__notes">
          <span>straight line</span>
          {pharmacy.walkMinutes && <span>about {formatWalk(pharmacy.walkMinutes)}</span>}
        </span>
      </p>
      <p>
        <OpenBadge open={open} />
      </p>
      {nearestOpen && (
        <button
          type="button"
          className="np-btn np-btn--primary np-nearest__open"
          onClick={() => onShow(nearestOpen.id)}
        >
          Nearest open: {nearestOpen.name}, {formatDistance(nearestOpen.distanceM)}
        </button>
      )}
      <p className="np-meta">
        OpenStreetMap may list pharmacies that have closed down. Check before you go.
      </p>
      {/* With an open alternative above, the facts keep these links from reading as its own. */}
      {nearestOpen && <PharmacyFacts pharmacy={pharmacy} />}
      <PharmacyLinks origin={origin} pharmacy={pharmacy} primary={!nearestOpen} />
      {!nearestOpen && <PharmacyFacts pharmacy={pharmacy} />}
      {detailsMissing && (
        <div className="np-nearest__warning">
          <svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true">
            <path d="M12 3.5 21.5 20h-19zM12 10v4.5M12 17v.5" />
          </svg>
          <p>Opening hours and phone numbers couldn't be loaded.</p>
          <button type="button" className="np-btn np-btn--secondary" onClick={onRetry}>
            Try again<span className="np-sr"> to load opening hours and phone numbers</span>
          </button>
        </div>
      )}
    </article>
  )
}
