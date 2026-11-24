import 'maplibre-gl/dist/maplibre-gl.css'
import { useEffect, useEffectEvent, useId, useRef, useState } from 'react'
import type { Origin, Pharmacy } from '../domain/types'
import { useMediaQuery } from '../hooks/useMediaQuery'
import { MapController } from './map/MapController'
import './PharmacyMap.css'

/** A new origin or list builds a new map. Within one, only the selection and the color scheme change. */
interface PharmacyMapProps {
  origin: Origin
  /** Nearest first. */
  pharmacies: Pharmacy[]
  selectedId: string | null
  onSelect(id: string): void
}

export default function PharmacyMap({
  origin,
  pharmacies,
  selectedId,
  onSelect,
}: PharmacyMapProps) {
  const dark = useMediaQuery('(prefers-color-scheme: dark)')
  const descriptionId = useId()
  const rootRef = useRef<HTMLDivElement>(null)
  const containerRef = useRef<HTMLDivElement>(null)
  const controllerRef = useRef<MapController | null>(null)
  /** Keeps keyboard focus here when the map and its fallback replace each other. */
  const keepFocus = useRef(false)
  const [failed, setFailed] = useState(false)

  const selectPin = useEffectEvent((id: string) => onSelect(id))
  const createController = useEffectEvent((container: HTMLElement, onFail: () => void) => {
    return new MapController({
      container,
      origin,
      pharmacies,
      selectedId,
      dark,
      descriptionId,
      onSelect: (id) => selectPin(id),
      onFail,
    })
  })

  useEffect(() => {
    const container = containerRef.current
    if (failed || !container) {
      if (keepFocus.current) rootRef.current?.focus()
      return
    }
    let active = true
    const fail = () => {
      if (!active) return
      keepFocus.current ||= rootRef.current?.contains(document.activeElement) ?? false
      setFailed(true)
    }
    try {
      controllerRef.current = createController(container, fail)
      if (keepFocus.current) controllerRef.current.focus()
      keepFocus.current = false
    } catch {
      // No WebGL. Deferred so the effect itself does not set state.
      queueMicrotask(fail)
    }
    return () => {
      active = false
      controllerRef.current?.destroy()
      controllerRef.current = null
    }
  }, [failed, origin, pharmacies])

  useEffect(() => {
    controllerRef.current?.select(selectedId)
  }, [selectedId])

  useEffect(() => {
    controllerRef.current?.setDark(dark)
  }, [dark])

  const retry = () => {
    keepFocus.current = true
    setFailed(false)
  }

  if (failed) {
    return (
      <div className="pmap pmap--failed" ref={rootRef} role="region" aria-label="Map" tabIndex={-1}>
        <p className="pmap__failed-title">Map unavailable</p>
        <p className="pmap__failed-text">The map couldn’t load. The list still has every pharmacy.</p>
        <button type="button" className="pmap__retry" onClick={retry}>
          Try again
        </button>
      </div>
    )
  }

  return (
    <div className="pmap" ref={rootRef}>
      <p id={descriptionId} className="pmap__description">
        Arrow keys move the map, plus and minus zoom. The list has the same pharmacies.
      </p>
      <div className="pmap__container" ref={containerRef} />
      <div className="pmap__controls">
        <button type="button" aria-label="Zoom in" onClick={() => controllerRef.current?.zoomBy(1)}>
          <svg viewBox="0 0 20 20" aria-hidden="true">
            <path d="M10 4v12M4 10h12" />
          </svg>
        </button>
        <button type="button" aria-label="Zoom out" onClick={() => controllerRef.current?.zoomBy(-1)}>
          <svg viewBox="0 0 20 20" aria-hidden="true">
            <path d="M4 10h12" />
          </svg>
        </button>
        <button type="button" aria-label="Recenter map" onClick={() => controllerRef.current?.recenter()}>
          <svg viewBox="0 0 20 20" aria-hidden="true">
            <circle cx="10" cy="10" r="4.5" />
            <path d="M10 2v3M10 15v3M2 10h3M15 10h3" />
          </svg>
        </button>
      </div>
    </div>
  )
}
