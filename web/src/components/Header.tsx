export function Header() {
  return (
    <header className="np-header">
      <svg className="np-header__mark" viewBox="0 0 24 24" width="24" height="24" aria-hidden="true">
        <rect width="24" height="24" rx="7" fill="var(--action)" />
        <path d="M10 6h4v4h4v4h-4v4h-4v-4H6v-4h4z" fill="var(--on-action)" />
      </svg>
      <span>Nearest pharmacy</span>
    </header>
  )
}
