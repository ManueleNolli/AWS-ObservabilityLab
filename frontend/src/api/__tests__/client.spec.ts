import { afterEach, describe, expect, it, vi } from 'vitest'

import { buildUrl, sendRequest } from '../client'
import type { Endpoint } from '../endpoints'

const login: Endpoint = {
  id: 'login',
  label: 'Login',
  description: '',
  method: 'POST',
  path: '/api/login',
}

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('buildUrl', () => {
  it('appends the query string when the endpoint has one', () => {
    expect(buildUrl({ ...login, query: () => ({ q: 'red shoes' }) })).toBe('/api/login?q=red+shoes')
    expect(buildUrl(login)).toBe('/api/login')
  })
})

describe('sendRequest', () => {
  it('records status, method and request ID', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(new Response(null, { status: 401, headers: { 'X-Request-ID': 'abc123' } }))
    vi.stubGlobal('fetch', fetchMock)

    const record = await sendRequest(login)

    expect(fetchMock).toHaveBeenCalledWith('/api/login', { method: 'POST' })
    expect(record).toMatchObject({ endpointId: 'login', status: 401, requestId: 'abc123' })
    expect(record.latencyMs).toBeGreaterThanOrEqual(0)
  })

  it('records network failures as status 0 instead of throwing', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('Failed to fetch')))

    const record = await sendRequest(login)

    expect(record.status).toBe(0)
    expect(record.requestId).toBeNull()
  })
})
