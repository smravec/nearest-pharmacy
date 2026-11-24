import { LngLatBounds, Map as MapLibreMap, Marker, setWorkerUrl, type StyleSpecification } from 'maplibre-gl'
import workerUrl from 'maplibre-gl/dist/maplibre-gl-worker.mjs?url'
import type { Origin, Pharmacy } from '../../domain/types'
import { createPharmacyPin, createUserPin, updatePharmacyPin } from './pins'

// MapLibre cannot find its own worker in a Vite build, so it is emitted as an asset and named here.
setWorkerUrl(workerUrl)

const READY_TIMEOUT_MS = 10_000
const FIT_COUNT = 3
const FIT_MAX_ZOOM = 16
const FIT_PADDING = 64
// Pins stand above their point: the selected shape and its tag reach 90 px up.
const FIT_PADDING_TOP = 96
const SELECT_ZOOM = 15
const MOVE_MS = 700

function styleUrl(dark: boolean) {
  return `https://tiles.openfreemap.org/styles/${dark ? 'dark' : 'positron'}`
}

export interface MapView {
  origin: Origin
  pharmacies: Pharmacy[]
  nearestId: string | null
  selectedId: string | null
}

export interface MapControllerOptions {
  container: HTMLElement
  view: MapView
  dark: boolean
  descriptionId: string
  onSelect(id: string): void
  onFail(): void
}

/** Owns the MapLibre instance. React creates it, feeds it views and destroys it. */
export class MapController {
  private readonly map: MapLibreMap
  private readonly userMarker: Marker
  private readonly pins = new Map<string, Marker>()
  private readonly options: MapControllerOptions
  private view: MapView
  private dark: boolean
  private styleLoaded = false
  private ready = false
  private sawError = false
  private deadlinePassed = false
  private fitPending = false
  /** What moved the camera last. Right after a fit the nearest pin is already framed. */
  private lastMove: 'fit' | 'select' | 'user' = 'fit'
  private clickedId: string | null = null
  private styleRequest: AbortController | null = null
  private readonly deadline: number

  /** Throws when WebGL is unavailable. */
  constructor(options: MapControllerOptions) {
    const { container, view, dark, descriptionId } = options
    this.options = options
    this.view = view
    this.dark = dark
    this.map = new MapLibreMap({
      container,
      style: styleUrl(dark),
      center: [view.origin.position.lng, view.origin.position.lat],
      zoom: 14,
      attributionControl: { compact: false },
      dragRotate: false,
      pitchWithRotate: false,
      touchPitch: false,
      // On touch screens the map sits in a scrolling page, so one finger has to keep scrolling it.
      cooperativeGestures: window.matchMedia('(pointer: coarse)').matches,
      locale: { 'Map.Title': 'Map of nearby pharmacies' },
    })
    this.map.touchZoomRotate.disableRotation()
    this.map.keyboard.disableRotation()
    this.map.getCanvas().setAttribute('aria-describedby', descriptionId)

    this.userMarker = new Marker({ element: createUserPin(), anchor: 'center' })
      .setLngLat([view.origin.position.lng, view.origin.position.lat])
      .addTo(this.map)
    this.syncPins()
    this.fit(false)

    this.map.once('style.load', () => {
      this.styleLoaded = true
    })
    this.map.on('error', () => this.handleError())
    this.map.once('idle', () => this.handleFirstIdle())
    this.map.on('resize', () => {
      if (this.fitPending) this.fit(false)
    })
    this.map.on('movestart', (event) => {
      if (event.originalEvent) this.lastMove = 'user'
    })
    // Wheel zooms start without an originalEvent, so movestart alone misses them.
    this.map.on('wheel', () => {
      this.lastMove = 'user'
    })
    this.deadline = window.setTimeout(() => {
      this.deadlinePassed = true
      if (!this.ready && this.sawError) this.options.onFail()
    }, READY_TIMEOUT_MS)
  }

  update(view: MapView) {
    const previous = this.view
    this.view = view
    this.syncPins()

    const { lng, lat } = view.origin.position
    if (view.origin !== previous.origin) this.userMarker.setLngLat([lng, lat])

    if (view.origin !== previous.origin || view.pharmacies !== previous.pharmacies) {
      this.clickedId = null
      this.fit(true)
    } else if (view.selectedId !== previous.selectedId) {
      this.showSelection()
    }
  }

  setDark(dark: boolean) {
    if (dark === this.dark) return
    this.dark = dark
    this.styleRequest?.abort()
    const request = new AbortController()
    this.styleRequest = request
    // setStyle drops the old style before the new one arrives. Fetching it first means a failed
    // request leaves the current map in place instead of a blank one.
    fetch(styleUrl(dark), { signal: request.signal })
      .then((response) => {
        if (!response.ok) throw new Error(`Map style request failed: ${response.status}`)
        return response.json() as Promise<StyleSpecification>
      })
      .then((style) => {
        if (!request.signal.aborted) this.map.setStyle(style, { diff: false })
      })
      .catch(() => {
        // Aborted or offline: keep the style that is already drawn.
      })
  }

  recenter() {
    this.fit(true)
  }

  zoomBy(delta: 1 | -1) {
    this.lastMove = 'user'
    this.map.easeTo({ zoom: Math.round(this.map.getZoom()) + delta, duration: 250 })
  }

  focus() {
    this.map.getCanvas().focus()
  }

  destroy() {
    window.clearTimeout(this.deadline)
    this.styleRequest?.abort()
    this.map.remove()
  }

  private handleError() {
    if (this.ready) return
    this.sawError = true
    // MapLibre does not retry a style, so an error before it loads is final.
    if (!this.styleLoaded || this.deadlinePassed) this.options.onFail()
  }

  /** `load` fires even when every tile failed, so an error counts as fatal if nothing was drawn. */
  private handleFirstIdle() {
    if (this.sawError && this.map.queryRenderedFeatures().length === 0) {
      this.options.onFail()
      return
    }
    this.ready = true
    window.clearTimeout(this.deadline)
  }

  private syncPins() {
    const { pharmacies, nearestId, selectedId } = this.view
    const wanted = new Set(pharmacies.map((pharmacy) => pharmacy.id))
    for (const [id, marker] of this.pins) {
      if (wanted.has(id)) continue
      marker.remove()
      this.pins.delete(id)
    }
    for (const { id, name, position } of pharmacies) {
      let marker = this.pins.get(id)
      if (marker) {
        marker.setLngLat([position.lng, position.lat])
      } else {
        marker = new Marker({ element: createPharmacyPin(() => this.handlePinClick(id)), anchor: 'bottom' })
          .setLngLat([position.lng, position.lat])
          .addTo(this.map)
        this.pins.set(id, marker)
      }
      updatePharmacyPin(marker.getElement(), name, id === nearestId, id === selectedId)
    }
  }

  private handlePinClick(id: string) {
    if (id !== this.view.selectedId) this.clickedId = id
    this.options.onSelect(id)
  }

  /** Frames the origin and the nearest few pharmacies, waiting for a size if there is none yet. */
  private fit(animate: boolean) {
    const { clientWidth, clientHeight } = this.map.getContainer()
    const shortest = Math.min(clientWidth, clientHeight)
    this.fitPending = shortest === 0
    if (this.fitPending) return

    const { origin, pharmacies } = this.view
    const bounds = new LngLatBounds()
    for (const { lng, lat } of [origin.position, ...pharmacies.slice(0, FIT_COUNT).map((p) => p.position)]) {
      bounds.extend([lng, lat])
    }
    const padding = Math.min(FIT_PADDING, shortest / 4)
    this.lastMove = 'fit'
    this.map.fitBounds(bounds, {
      padding: { top: Math.min(FIT_PADDING_TOP, shortest / 2), right: padding, bottom: padding, left: padding },
      maxZoom: FIT_MAX_ZOOM,
      duration: animate ? MOVE_MS : 0,
    })
  }

  private showSelection() {
    const { selectedId, nearestId, pharmacies } = this.view
    const clicked = this.clickedId === selectedId
    this.clickedId = null
    const selected = pharmacies.find((pharmacy) => pharmacy.id === selectedId)
    if (!selected) return
    if (selectedId === nearestId && this.lastMove === 'fit') return

    const center: [number, number] = [selected.position.lng, selected.position.lat]
    this.lastMove = 'select'
    // MapLibre jumps instead of animating under prefers-reduced-motion.
    if (clicked) this.map.easeTo({ center, duration: MOVE_MS })
    else this.map.flyTo({ center, zoom: Math.max(this.map.getZoom(), SELECT_ZOOM), duration: MOVE_MS })
  }
}
