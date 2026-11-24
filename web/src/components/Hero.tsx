import type { ReactNode } from 'react'
import { formatDistance } from '../domain/format'
import type { Origin, SearchState } from '../domain/types'

const LOW_ACCURACY_M = 200

interface HeroProps {
  state: SearchState
  children: ReactNode
}

function title(origin: Origin | null): string {
  if (!origin) return 'Find the nearest pharmacy'
  return origin.source === 'gps' ? 'Pharmacies near you' : `Pharmacies near ${origin.label}`
}

export function Hero({ state, children }: HeroProps) {
  const origin = 'origin' in state ? state.origin : null
  const accuracyM = origin?.accuracyM ?? 0

  return (
    <section className={origin ? 'np-hero np-hero--compact' : 'np-hero'} aria-labelledby="np-title">
      <div>
        <h1 id="np-title">{title(origin)}</h1>
        {!origin && (
          <p className="np-hero__lead">
            See which pharmacy is closest to you, how far it is and whether it is open.
          </p>
        )}
        {accuracyM > LOW_ACCURACY_M && (
          <p className="np-hero__note">
            Your location is accurate to about {formatDistance(accuracyM)}, so the order may be off.
          </p>
        )}
      </div>
      {children}
    </section>
  )
}
