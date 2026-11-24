import { useEffect } from 'react'
import type { Ref } from 'react'
import { formatRadius } from '../domain/format'
import type { LocationProblem, LookupState, Origin } from '../domain/types'

const SLOW_AFTER_MS = 4000

interface Copy {
  title: string
  text: string
}

const DENIED_COPY: Record<LocationProblem, Copy> = {
  denied: {
    title: 'Location access is off',
    text: 'Search for an address above, or allow location for this site in your browser settings and try again.',
  },
  unavailable: {
    title: "Your location isn't available",
    text: "Your device couldn't work out where you are. Search for an address above instead.",
  },
  timeout: {
    title: 'Finding your location took too long',
    text: 'Try again, or search for an address above.',
  },
  unsupported: {
    title: "This browser can't share your location",
    text: 'Search for an address above instead.',
  },
}

export const ERROR_TITLE = "Pharmacies couldn't be loaded"
export const ERROR_TEXT =
  "We couldn't reach the pharmacy data services. Check your connection and try again."

export function deniedCopy(problem: LocationProblem): Copy {
  return DENIED_COPY[problem]
}

export function emptyCopy(origin: Origin, radiusM: number): Copy {
  const place = origin.source === 'gps' ? 'your location' : origin.label
  return {
    title: `No pharmacies within ${formatRadius(radiusM)}`,
    text: `OpenStreetMap lists none around ${place}. Try a nearby town above.`,
  }
}

const PRIMER_ROWS = [
  {
    icon: 'M12 3l7 3v5c0 4.5-3 8-7 10-4-2-7-5.5-7-10V6z',
    text: 'Your browser will ask first. Nothing is sent until you choose.',
  },
  {
    icon: 'M12 21c-4-4.5-7-8-7-11a7 7 0 0 1 14 0c0 3-3 6.5-7 11zM12 12.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z',
    text: 'Your coordinates or search text go to public OpenStreetMap services to find pharmacies and draw the map. Directions opens Google Maps.',
  },
  {
    icon: 'M3 12c2.5-4 5.5-6 9-6s6.5 2 9 6c-2.5 4-5.5 6-9 6s-6.5-2-9-6zM4 20L20 4',
    text: 'This app has no account, no server of its own and no tracking.',
  },
]

function Primer() {
  return (
    <section className="np-panel">
      <h2>Before you share your location</h2>
      <ul className="np-primer">
        {PRIMER_ROWS.map(({ icon, text }) => (
          <li key={text} className="np-primer__row">
            <svg className="np-primer__icon" viewBox="0 0 24 24" width="24" height="24" aria-hidden="true">
              <path d={icon} />
            </svg>
            <span>{text}</span>
          </li>
        ))}
      </ul>
    </section>
  )
}

function LocatingView() {
  return (
    <section className="np-panel">
      <h2>Finding your location…</h2>
      <p>If your browser asks, choose Allow. You can also search for an address above.</p>
    </section>
  )
}

interface DeniedViewProps {
  problem: LocationProblem
  headingRef: Ref<HTMLHeadingElement>
}

function DeniedView({ problem, headingRef }: DeniedViewProps) {
  const { title, text } = deniedCopy(problem)
  return (
    <section className="np-panel">
      <h2 ref={headingRef} tabIndex={-1}>
        {title}
      </h2>
      <p>{text}</p>
    </section>
  )
}

interface IdleViewProps {
  lookup: LookupState
  headingRef: Ref<HTMLHeadingElement>
}

export function IdleView({ lookup, headingRef }: IdleViewProps) {
  switch (lookup.status) {
    case 'locating':
      return <LocatingView />
    case 'locationFailed':
      return <DeniedView problem={lookup.problem} headingRef={headingRef} />
    default:
      return <Primer />
  }
}

interface LoadingViewProps {
  origin: Origin
  slow: boolean
  onSlow(origin: Origin): void
}

export function LoadingView({ origin, slow, onSlow }: LoadingViewProps) {
  useEffect(() => {
    const timer = setTimeout(() => onSlow(origin), SLOW_AFTER_MS)
    return () => clearTimeout(timer)
  }, [origin, onSlow])

  return (
    <section className="np-panel">
      <h2>Looking for pharmacies…</h2>
      {slow && <p>Still looking. The public map service is slow right now.</p>}
      <div className="np-skeletons" aria-hidden="true">
        <div className="np-skeleton np-skeleton--card" />
        <div className="np-skeleton np-skeleton--row" />
        <div className="np-skeleton np-skeleton--row" />
        <div className="np-skeleton np-skeleton--row" />
      </div>
    </section>
  )
}

interface EmptyViewProps {
  origin: Origin
  radiusM: number
  headingRef: Ref<HTMLHeadingElement>
}

export function EmptyView({ origin, radiusM, headingRef }: EmptyViewProps) {
  const { title, text } = emptyCopy(origin, radiusM)
  return (
    <section className="np-panel">
      <h2 ref={headingRef} tabIndex={-1}>
        {title}
      </h2>
      <p>{text}</p>
    </section>
  )
}

interface ErrorViewProps {
  onRetry(): void
  headingRef: Ref<HTMLHeadingElement>
}

export function ErrorView({ onRetry, headingRef }: ErrorViewProps) {
  return (
    <section className="np-panel">
      <h2 ref={headingRef} tabIndex={-1}>
        {ERROR_TITLE}
      </h2>
      <p>{ERROR_TEXT}</p>
      <button type="button" className="np-btn np-btn--primary" onClick={onRetry}>
        Try again
      </button>
    </section>
  )
}
