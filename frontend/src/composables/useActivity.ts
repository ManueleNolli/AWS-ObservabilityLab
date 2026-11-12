import { computed, reactive, shallowRef } from 'vue'

import { sendRequest, type RequestRecord } from '@/api/client'
import { ENDPOINTS, type Endpoint, type EndpointId } from '@/api/endpoints'
import { randomItem, sleep } from '@/lib/random'
import { outcomeOf, percentile, type Outcome } from '@/lib/stats'

/** How many requests the activity log keeps; totals are counted over the whole session. */
export const MAX_RECORDS = 200
/** Burst sizes offered in the UI; the first is the default. */
export const BURST_SIZES = [20, 100] as const
export const BURST_WINDOW_MS = 3000

export type OutcomeCounts = Record<Outcome, number>

export interface EndpointStats {
  sent: number
  failed: number
  inFlight: number
}

export interface SessionStats {
  sent: number
  outcomes: OutcomeCounts
  successRate: number | null
  /** p95 of the requests still in the log. */
  p95LatencyMs: number | null
}

export interface BurstProgress {
  running: boolean
  done: number
  total: number
}

export interface ActivityOptions {
  send?: (endpoint: Endpoint) => Promise<RequestRecord>
  wait?: (ms: number) => Promise<void>
}

const emptyOutcomes = (): OutcomeCounts => ({
  success: 0,
  'client-error': 0,
  'server-error': 0,
  'network-error': 0,
})

const emptyEndpointStats = (): Record<EndpointId, EndpointStats> =>
  Object.fromEntries(ENDPOINTS.map((e) => [e.id, { sent: 0, failed: 0, inFlight: 0 }])) as Record<
    EndpointId,
    EndpointStats
  >

/** Session state: sends requests, keeps the log and derives the numbers shown in the UI. */
export function useActivity({ send = sendRequest, wait = sleep }: ActivityOptions = {}) {
  // Newest first. Records are immutable, so a shallow ref is enough.
  const records = shallowRef<readonly RequestRecord[]>([])
  const outcomes = reactive(emptyOutcomes())
  const byEndpoint = reactive(emptyEndpointStats())
  const burst = reactive<BurstProgress>({ running: false, done: 0, total: 0 })

  async function run(endpoint: Endpoint): Promise<RequestRecord> {
    const endpointStats = byEndpoint[endpoint.id]
    endpointStats.inFlight++
    try {
      const record = await send(endpoint)
      const outcome = outcomeOf(record.status)
      outcomes[outcome]++
      endpointStats.sent++
      if (outcome !== 'success') endpointStats.failed++
      records.value = [record, ...records.value].slice(0, MAX_RECORDS)
      return record
    } finally {
      endpointStats.inFlight--
    }
  }

  /** Fire `size` requests at random endpoints, spread randomly over `windowMs`. */
  async function fireBurst(
    size: number = BURST_SIZES[0],
    windowMs = BURST_WINDOW_MS,
  ): Promise<void> {
    if (burst.running) return
    Object.assign(burst, { running: true, done: 0, total: size })
    try {
      await Promise.all(
        Array.from({ length: size }, async () => {
          await wait(Math.random() * windowMs)
          await run(randomItem(ENDPOINTS))
          burst.done++
        }),
      )
    } finally {
      burst.running = false
    }
  }

  function clear(): void {
    records.value = []
    Object.assign(outcomes, emptyOutcomes())
    // In-flight counts stay: those requests are still running.
    for (const endpointStats of Object.values(byEndpoint)) {
      endpointStats.sent = 0
      endpointStats.failed = 0
    }
  }

  const stats = computed<SessionStats>(() => {
    const sent = Object.values(outcomes).reduce((sum, n) => sum + n, 0)
    return {
      sent,
      outcomes: { ...outcomes },
      successRate: sent === 0 ? null : outcomes.success / sent,
      p95LatencyMs: percentile(
        records.value.map((r) => r.latencyMs),
        95,
      ),
    }
  })

  return { records, stats, byEndpoint, burst, run, fireBurst, clear }
}

export type Activity = ReturnType<typeof useActivity>
