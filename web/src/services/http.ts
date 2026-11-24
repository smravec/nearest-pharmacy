export class ServiceError extends Error {
  override readonly name = 'ServiceError'
}

/** Rejects with the caller's reason if `signal` aborts. Any other rejection, a timeout too, is a failure. */
export async function fetchJson(
  url: string,
  signal: AbortSignal,
  timeoutMs: number,
  init?: RequestInit,
): Promise<unknown> {
  signal.throwIfAborted()
  // Not AbortSignal.any, which Safari lacks before 17.4.
  const controller = new AbortController()
  const abort = () => controller.abort()
  const timer = setTimeout(abort, timeoutMs)
  signal.addEventListener('abort', abort)
  try {
    const response = await fetch(url, { ...init, signal: controller.signal })
    if (!response.ok) throw new ServiceError(`HTTP ${response.status}`)
    return await response.json()
  } catch (error) {
    signal.throwIfAborted()
    throw error
  } finally {
    clearTimeout(timer)
    signal.removeEventListener('abort', abort)
  }
}

export function sleep(ms: number, signal: AbortSignal): Promise<void> {
  return new Promise((resolve, reject) => {
    if (signal.aborted) {
      reject(signal.reason)
      return
    }
    const onAbort = () => {
      clearTimeout(timer)
      reject(signal.reason)
    }
    const timer = setTimeout(() => {
      signal.removeEventListener('abort', onAbort)
      resolve()
    }, ms)
    signal.addEventListener('abort', onAbort, { once: true })
  })
}

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

/** The first of the keys that holds a non-blank string, trimmed. */
export function firstText(record: Record<string, unknown>, ...keys: string[]): string | undefined {
  for (const key of keys) {
    const value = record[key]
    const text = typeof value === 'string' ? value.trim() : ''
    if (text) return text
  }
  return undefined
}

export function httpUrl(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined
  try {
    const url = new URL(value.trim())
    return url.protocol === 'http:' || url.protocol === 'https:' ? url.href : undefined
  } catch {
    return undefined
  }
}
