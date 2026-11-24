export class ServiceError extends Error {
  override readonly name = 'ServiceError'
  /** The HTTP status, when the service answered with an error. */
  readonly status: number | undefined

  constructor(message: string, options?: ErrorOptions & { status?: number }) {
    super(message, options)
    this.status = options?.status
  }
}

export function withTimeout(signal: AbortSignal, ms: number): AbortSignal {
  return AbortSignal.any([signal, AbortSignal.timeout(ms)])
}

export async function fetchJson(url: string, init: RequestInit): Promise<unknown> {
  const response = await fetch(url, init)
  if (!response.ok) throw new ServiceError(`HTTP ${response.status}`, { status: response.status })
  try {
    return await response.json()
  } catch (cause) {
    throw new ServiceError('Invalid JSON', { cause })
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
