import { Component } from 'react'
import type { ComponentProps, ComponentType } from 'react'
import type PharmacyMap from './PharmacyMap'

type MapProps = ComponentProps<typeof PharmacyMap>

/** Kept between results, so that only the first map waits for its chunk. */
let LoadedMap: ComponentType<MapProps> | undefined

/** Loads the map as its own chunk. Keeps the list usable when it can't be downloaded or can't render. */
export class MapBoundary extends Component<MapProps, { Map?: ComponentType<MapProps>; failed: boolean }> {
  state = { Map: LoadedMap, failed: false }

  static getDerivedStateFromError() {
    return { failed: true }
  }

  componentDidMount() {
    if (!LoadedMap) this.load()
  }

  load = () => {
    this.setState({ failed: false })
    import('./PharmacyMap').then(
      (module) => {
        LoadedMap = module.default
        this.setState({ Map: LoadedMap })
      },
      () => this.setState({ failed: true }),
    )
  }

  render() {
    const { Map, failed } = this.state
    if (failed) {
      return (
        <div className="np-map__message">
          <p>The map couldn't load. The list has the same pharmacies.</p>
          <button type="button" className="np-btn np-btn--secondary" onClick={this.load}>
            Try again
          </button>
        </div>
      )
    }
    if (!Map) return <p className="np-map__message np-map__message--loading">Loading map…</p>
    return <Map {...this.props} />
  }
}
