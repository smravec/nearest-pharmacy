import type { Ref } from 'react'
import type { Origin, Pharmacy } from '../domain/types'

export interface PharmacyMapHandle {
  focus(): void
}

export interface PharmacyMapProps {
  origin: Origin
  pharmacies: Pharmacy[]
  nearestId: string | null
  selectedId: string | null
  onSelect(id: string): void
  ref?: Ref<PharmacyMapHandle>
}
