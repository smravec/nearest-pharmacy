import type OpeningHours from 'opening_hours'
import type { OpenState, Pharmacy } from './types'

export interface OpenStatus extends OpenState {
  label: string
  detail?: string
}

export type EvaluateHours = (p: Pharmacy, now: Date) => OpenStatus

/** For hours we can't evaluate: the listed value, if there is one, with its holiday codes spelled out. */
export function unevaluatedHours({ openingHours }: Pharmacy): OpenStatus {
  if (!openingHours) return { status: 'unknown', label: 'Hours unavailable' }
  const detail = openingHours.replace(/\bPH\b/g, 'public holidays').replace(/\bSH\b/g, 'school holidays')
  return { status: 'unknown', label: 'Listed hours', detail }
}

/**
 * Holidays need a country and sun times need coordinates. Without them the library throws or,
 * for sun times, silently gives wrong answers.
 */
const NEEDS_LOCATION = /\b(PH|SH|sunrise|sunset|dawn|dusk)\b/i

const MAX_HOPS = 10
const DAY_MS = 86_400_000

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

// The library reads a Date's local fields. A "wall" Date is one whose local fields, in the browser's
// zone, show the pharmacy's clock. It can't show the hour that the browser's zone skips when daylight
// saving starts: on that day, clock times within it count as an hour later, which is accepted.

const formatters = new Map<string, Intl.DateTimeFormat>()

function formatterFor(zone: string): Intl.DateTimeFormat {
  let formatter = formatters.get(zone)
  if (!formatter) {
    formatter = new Intl.DateTimeFormat('en-US', {
      timeZone: zone,
      hourCycle: 'h23',
      year: 'numeric',
      month: 'numeric',
      day: 'numeric',
      hour: 'numeric',
      minute: 'numeric',
      second: 'numeric',
    })
    formatters.set(zone, formatter)
  }
  return formatter
}

/** The zone's clock at an instant, read as if it were UTC. */
function zoneClock(instant: Date, zone: string): number {
  const parts = formatterFor(zone).formatToParts(instant)
  const field = (type: Intl.DateTimeFormatPartTypes) =>
    Number(parts.find((part) => part.type === type)?.value)
  return Date.UTC(
    field('year'),
    field('month') - 1,
    field('day'),
    field('hour'),
    field('minute'),
    field('second'),
  )
}

function toWall(instant: Date, zone: string): Date {
  const clock = new Date(zoneClock(instant, zone))
  return new Date(
    clock.getUTCFullYear(),
    clock.getUTCMonth(),
    clock.getUTCDate(),
    clock.getUTCHours(),
    clock.getUTCMinutes(),
    clock.getUTCSeconds(),
  )
}

function stateAt(hours: OpeningHours, wall: Date): OpenState['status'] {
  if (hours.getState(wall)) return 'open'
  return hours.getUnknown(wall) ? 'unknown' : 'closed'
}

/** The next time the state really differs: the library also reports rule boundaries within it. */
function nextStateChange(hours: OpeningHours, wall: Date): Date | undefined {
  const current = stateAt(hours, wall)
  let next = hours.getNextChange(wall)
  for (let hop = 0; next && stateAt(hours, next) === current; hop++) {
    if (hop === MAX_HOPS) return undefined
    next = hours.getNextChange(next)
  }
  return next
}

function calendarDaysBetween(from: Date, to: Date): number {
  const day = (d: Date) => Date.UTC(d.getFullYear(), d.getMonth(), d.getDate())
  return (day(to) - day(from)) / DAY_MS
}

function formatTime(wall: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${pad(wall.getHours())}:${pad(wall.getMinutes())}`
}

function formatChange(status: 'open' | 'closed', wall: Date, next: Date): string {
  const verb = status === 'open' ? 'until' : 'opens'
  const time = formatTime(next)
  const days = calendarDaysBetween(wall, next)

  const isTonight = status === 'open' && days === 1 && next.getHours() < 12
  if (days === 0 || isTonight) return `${verb} ${time}`
  if (days < 7) return `${verb} ${WEEKDAYS[next.getDay()]} ${time}`
  return `${verb} ${next.getDate()} ${MONTHS[next.getMonth()]} ${time}`
}

function describe(hours: OpeningHours, zone: string, now: Date): OpenStatus | undefined {
  const wall = toWall(now, zone)
  const status = stateAt(hours, wall)
  if (status === 'unknown') return undefined

  const label = status === 'open' ? 'Open' : 'Closed'
  const next = nextStateChange(hours, wall)
  if (!next) return status === 'open' ? { status, label, detail: '24 hours' } : { status, label }

  // Closed until something we can't evaluate, such as "by appointment", is not an opening time.
  const opensUnknown = status === 'closed' && stateAt(hours, next) === 'unknown'
  if (next <= wall || opensUnknown) return { status, label }
  return { status, label, detail: formatChange(status, wall, next) }
}

async function load(): Promise<EvaluateHours> {
  const [{ default: OpeningHours }, { default: tzLookup }] = await Promise.all([
    import('opening_hours'),
    import('@photostructure/tz-lookup'),
  ])

  // Parsing takes milliseconds, and the statuses are re-evaluated every minute.
  const parsed = new Map<string, OpeningHours | null>()
  const zones = new Map<string, string>()

  function parse(value: string): OpeningHours | null {
    let hours = parsed.get(value)
    if (hours === undefined) {
      try {
        // Not null: that makes the library assume a default country.
        hours = new OpeningHours(value, undefined)
      } catch {
        hours = null
      }
      parsed.set(value, hours)
    }
    return hours
  }

  function zoneOf({ id, position }: Pharmacy): string {
    let zone = zones.get(id)
    if (zone === undefined) {
      zone = tzLookup(position.lat, position.lng)
      zones.set(id, zone)
    }
    return zone
  }

  return (pharmacy, now) => {
    const { openingHours } = pharmacy
    const unevaluated = unevaluatedHours(pharmacy)
    if (!openingHours || NEEDS_LOCATION.test(openingHours)) return unevaluated
    try {
      const hours = parse(openingHours)
      return (hours && describe(hours, zoneOf(pharmacy), now)) ?? unevaluated
    } catch {
      return unevaluated
    }
  }
}

let evaluator: Promise<EvaluateHours> | undefined

/** Loads the parser and the time zone table on first use, to keep them out of the main bundle. */
export function loadOpeningHours(): Promise<EvaluateHours> {
  evaluator ??= load().catch((error: unknown) => {
    evaluator = undefined
    throw error
  })
  return evaluator
}
