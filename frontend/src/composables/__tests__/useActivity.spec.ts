import { describe, expect, it, vi } from 'vitest'

import type { RequestRecord } from '@/api/client'
import type { Endpoint } from '@/api/endpoints'
import { ENDPOINTS } from '@/api/endpoints'

import { MAX_RECORDS, useActivity } from '../useActivity'

function fakeSend(statusFor: (endpoint: Endpoint) => number, latencyMs = 100) {
  let id = 0
  return vi.fn(async (endpoint: Endpoint): Promise<RequestRecord> => ({
    id: ++id,
    endpointId: endpoint.id,
    method: endpoint.method,
    url: endpoint.path,
    status: statusFor(endpoint),
    latencyMs,
    requestId: `req-${id}`,
    timestamp: new Date(),
  }))
}

const noWait = () => Promise.resolve()
const [login, checkout] = ENDPOINTS as [Endpoint, Endpoint]

describe('useActivity', () => {
  it('starts empty', () => {
    const { records, stats } = useActivity({ send: fakeSend(() => 200) })

    expect(records.value).toEqual([])
    expect(stats.value).toMatchObject({ sent: 0, successRate: null, p95LatencyMs: null })
  })

  it('counts outcomes per session and per endpoint', async () => {
    const activity = useActivity({ send: fakeSend((e) => (e.id === 'login' ? 401 : 200)) })

    await activity.run(login)
    await activity.run(checkout)
    await activity.run(checkout)

    expect(activity.stats.value.sent).toBe(3)
    expect(activity.stats.value.outcomes['client-error']).toBe(1)
    expect(activity.stats.value.successRate).toBeCloseTo(2 / 3)
    expect(activity.byEndpoint.login).toEqual({ sent: 1, failed: 1, inFlight: 0 })
    expect(activity.byEndpoint.checkout).toEqual({ sent: 2, failed: 0, inFlight: 0 })
  })

  it('keeps the newest records first, up to the limit', async () => {
    const activity = useActivity({ send: fakeSend(() => 200) })

    for (let i = 0; i < MAX_RECORDS + 5; i++) await activity.run(login)

    expect(activity.records.value).toHaveLength(MAX_RECORDS)
    expect(activity.records.value[0]!.id).toBe(MAX_RECORDS + 5)
    expect(activity.stats.value.sent).toBe(MAX_RECORDS + 5)
  })

  it('fires a burst and reports progress', async () => {
    const send = fakeSend(() => 200)
    const activity = useActivity({ send, wait: noWait })

    await activity.fireBurst(8)

    expect(send).toHaveBeenCalledTimes(8)
    expect(activity.burst).toEqual({ running: false, done: 8, total: 8 })
  })

  it('clears the log and the counters', async () => {
    const activity = useActivity({ send: fakeSend(() => 500) })
    await activity.run(login)

    activity.clear()

    expect(activity.records.value).toEqual([])
    expect(activity.stats.value.sent).toBe(0)
    expect(activity.byEndpoint.login).toEqual({ sent: 0, failed: 0, inFlight: 0 })
  })
})
