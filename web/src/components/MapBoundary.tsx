import { Component } from 'react'
import type { ReactNode } from 'react'

interface MapBoundaryProps {
  children: ReactNode
  fallback: ReactNode
}

/** Keeps the list usable when the map can't render or its chunk can't be downloaded. */
export class MapBoundary extends Component<MapBoundaryProps, { failed: boolean }> {
  state = { failed: false }

  static getDerivedStateFromError() {
    return { failed: true }
  }

  render() {
    return this.state.failed ? this.props.fallback : this.props.children
  }
}
