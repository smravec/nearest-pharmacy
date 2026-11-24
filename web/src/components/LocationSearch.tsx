import { useRef, useState } from 'react'
import type { ChangeEvent, SubmitEvent } from 'react'
import type { LookupState } from '../domain/types'
import { deniedCopy } from './StatusViews'

interface LocationSearchProps {
  lookup: LookupState
  /** With a search on the page, a location failure is shown here and locating is no longer the main action. */
  hasSearch: boolean
  onEdit(): void
  onSearch(query: string): void
  onLocate(): void
}

export function lookupErrorText(lookup: LookupState): string {
  switch (lookup.status) {
    case 'locationFailed': {
      const { title, text } = deniedCopy(lookup.problem)
      return `${title}. ${text}`
    }
    case 'addressFailed':
      return lookup.problem === 'notFound'
        ? `No place found for “${lookup.query}”. Check the spelling or add a city.`
        : `Search for “${lookup.query}” didn't work. Check your connection and try again.`
    default:
      return ''
  }
}

export function LocationSearch({
  lookup,
  hasSearch,
  onEdit,
  onSearch,
  onLocate,
}: LocationSearchProps) {
  const [query, setQuery] = useState('')
  const inputRef = useRef<HTMLInputElement>(null)
  const locating = lookup.status === 'locating'
  const addressFailed = lookup.status === 'addressFailed'
  const showError = addressFailed || (hasSearch && lookup.status === 'locationFailed')

  function handleChange(event: ChangeEvent<HTMLInputElement>) {
    setQuery(event.target.value)
    onEdit()
  }

  function handleSubmit(event: SubmitEvent<HTMLFormElement>) {
    event.preventDefault()
    const trimmed = query.trim()
    if (trimmed) onSearch(trimmed)
    else inputRef.current?.focus()
  }

  return (
    <div className="np-search">
      <button
        type="button"
        className={hasSearch ? 'np-btn np-btn--secondary' : 'np-btn np-btn--primary'}
        onClick={onLocate}
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
          aria-invalid={addressFailed || undefined}
          aria-describedby={addressFailed ? 'np-lookup-error' : undefined}
        />
        <button type="submit" className="np-btn np-btn--secondary">
          {lookup.status === 'searching' ? 'Searching…' : 'Search'}
        </button>
      </form>
      {showError && (
        <p id="np-lookup-error" className="np-search__error">
          {lookupErrorText(lookup)}
        </p>
      )}
    </div>
  )
}
