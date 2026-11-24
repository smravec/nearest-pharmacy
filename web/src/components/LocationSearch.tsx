import { useState } from 'react'
import type { RefObject, SubmitEvent } from 'react'
import { useMediaQuery } from '../hooks/useMediaQuery'
import type { GeocodeState } from '../hooks/usePharmacySearch'

interface LocationSearchProps {
  geocode: GeocodeState
  locating: boolean
  onSearch(query: string): void
  onLocate(): void
  inputRef: RefObject<HTMLInputElement | null>
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

export function LocationSearch({ geocode, locating, onSearch, onLocate, inputRef }: LocationSearchProps) {
  const [query, setQuery] = useState('')
  const hasKeyboard = useMediaQuery('(hover: hover) and (pointer: fine)')
  const searching = geocode.status === 'searching'
  const error = geocodeErrorText(geocode)

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
        <span className="np-search__field">
          {/* type="search" would let Esc clear the text natively. */}
          <input
            ref={inputRef}
            id="np-q"
            className="np-input"
            type="text"
            inputMode="search"
            enterKeyHint="search"
            autoComplete="street-address"
            placeholder="For example Kallio, Helsinki"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            aria-invalid={error ? true : undefined}
            aria-describedby={error ? 'np-q-error' : undefined}
          />
          {hasKeyboard && (
            <kbd className="np-kbd" aria-hidden="true">
              /
            </kbd>
          )}
        </span>
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
