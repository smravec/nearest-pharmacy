import { useRef, useState } from 'react'
import type { ChangeEvent, SubmitEvent } from 'react'
import type { GeocodeState } from '../hooks/usePharmacySearch'

interface LocationSearchProps {
  geocode: GeocodeState
  locating: boolean
  onEdit(): void
  onSearch(query: string): void
  onLocate(): void
}

export function geocodeErrorText(geocode: GeocodeState): string | null {
  switch (geocode.status) {
    case 'notFound':
      return `No place found for “${geocode.query}”. Check the spelling or add a city.`
    case 'failed':
      return `Search for “${geocode.query}” didn't work. Check your connection and try again.`
    default:
      return null
  }
}

export function LocationSearch({
  geocode,
  locating,
  onEdit,
  onSearch,
  onLocate,
}: LocationSearchProps) {
  const [query, setQuery] = useState('')
  const inputRef = useRef<HTMLInputElement>(null)
  const searching = geocode.status === 'searching'
  const error = geocodeErrorText(geocode)

  function handleChange(event: ChangeEvent<HTMLInputElement>) {
    setQuery(event.target.value)
    onEdit()
  }

  function handleLocate() {
    if (!locating) onLocate()
  }

  function handleSubmit(event: SubmitEvent<HTMLFormElement>) {
    event.preventDefault()
    if (searching) return
    const trimmed = query.trim()
    if (trimmed) onSearch(trimmed)
    else inputRef.current?.focus()
  }

  return (
    <div className="np-search">
      <button
        type="button"
        className="np-btn np-btn--primary"
        aria-disabled={locating || undefined}
        onClick={handleLocate}
      >
        {locating ? 'Finding your location…' : 'Use my location'}
      </button>
      <form className="np-search__form" role="search" onSubmit={handleSubmit}>
        <label className="np-search__label" htmlFor="np-q">
          Address or place
        </label>
        <input
          ref={inputRef}
          id="np-q"
          className="np-input"
          type="text"
          inputMode="search"
          enterKeyHint="search"
          autoComplete="off"
          placeholder="For example Kallio, Helsinki"
          value={query}
          onChange={handleChange}
          aria-invalid={error ? true : undefined}
          aria-describedby={error ? 'np-q-error' : undefined}
        />
        <button type="submit" className="np-btn np-btn--secondary" aria-disabled={searching || undefined}>
          {searching ? 'Searching…' : 'Search'}
        </button>
      </form>
      {error && (
        <p id="np-q-error" className="np-search__error">
          {error}
        </p>
      )}
    </div>
  )
}
