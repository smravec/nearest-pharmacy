import { useEffect } from 'react'

interface KeyboardHandlers {
  onSlash(): void
  onEscape(): void
}

function isEditable(target: EventTarget | null): boolean {
  return (
    target instanceof HTMLElement && (target.isContentEditable || target.matches('input, textarea, select'))
  )
}

/** Page-wide shortcuts. Handlers have to be stable: changing one re-subscribes. */
export function useKeyboard({ onSlash, onEscape }: KeyboardHandlers): void {
  useEffect(() => {
    function onKeyDown(event: KeyboardEvent) {
      if (event.defaultPrevented || event.isComposing) return
      // Shift is allowed: "/" is Shift+7 on Nordic keyboards.
      if (event.ctrlKey || event.metaKey || event.altKey) return

      if (event.key === '/' && !isEditable(event.target)) {
        event.preventDefault()
        onSlash()
      } else if (event.key === 'Escape') {
        onEscape()
      }
    }
    document.addEventListener('keydown', onKeyDown)
    return () => document.removeEventListener('keydown', onKeyDown)
  }, [onSlash, onEscape])
}
