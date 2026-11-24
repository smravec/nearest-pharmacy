import { useEffect, useMemo, useState } from 'react'
import { loadOpeningHours, unevaluatedHours } from '../domain/openingHours'
import type { EvaluateHours, OpenStatus } from '../domain/openingHours'
import type { Pharmacy } from '../domain/types'

const REFRESH_MS = 60_000

interface Snapshot {
  evaluate: EvaluateHours
  now: Date
}

/** Open or closed by pharmacy id, kept current. Empty until the opening hours parser has loaded. */
export function useOpenStates(pharmacies: Pharmacy[]): ReadonlyMap<string, OpenStatus> {
  const [snapshot, setSnapshot] = useState<Snapshot | 'failed' | null>(null)

  useEffect(() => {
    let live = true
    loadOpeningHours()
      .then((evaluate) => {
        if (live) setSnapshot({ evaluate, now: new Date() })
      })
      .catch(() => {
        if (live) setSnapshot('failed')
      })

    const refresh = () =>
      setSnapshot((current) =>
        current === null || current === 'failed' ? current : { ...current, now: new Date() },
      )
    // Background tabs throttle timers, so catch up on return.
    const onVisibilityChange = () => {
      if (document.visibilityState === 'visible') refresh()
    }
    const interval = setInterval(refresh, REFRESH_MS)
    document.addEventListener('visibilitychange', onVisibilityChange)
    return () => {
      live = false
      clearInterval(interval)
      document.removeEventListener('visibilitychange', onVisibilityChange)
    }
  }, [])

  return useMemo(() => {
    const states = new Map<string, OpenStatus>()
    if (snapshot === null) return states
    for (const pharmacy of pharmacies) {
      const status =
        snapshot === 'failed' ? unevaluatedHours(pharmacy) : snapshot.evaluate(pharmacy, snapshot.now)
      states.set(pharmacy.id, status)
    }
    return states
  }, [pharmacies, snapshot])
}
