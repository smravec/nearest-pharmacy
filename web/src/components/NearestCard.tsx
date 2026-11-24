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
      <span>
        <span className="np-open__label">{open.label}</span>
        {open.detail && ` ${open.detail}`}
      </span>
    </span>
  )
}

export function PharmacyFacts({ pharmacy }: { pharmacy: Pharmacy }) {
  return (
    <>
      {pharmacy.address && <p className="np-address">{pharmacy.address}</p>}
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
          Call
          <span className="np-sr">
            {' '}
            {name}, {phone}
          </span>
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
  headingRef: Ref<HTMLHeadingElement>
}

export function NearestCard({ origin, pharmacy, open, headingRef }: NearestCardProps) {
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
          <span>about {formatWalk(pharmacy.walkMinutes)}</span>
        </span>
      </p>
      <p>
        <OpenBadge open={open} />
      </p>
      <PharmacyFacts pharmacy={pharmacy} />
      <PharmacyLinks origin={origin} pharmacy={pharmacy} primary />
    </article>
  )
}
