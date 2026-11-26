import type { Endpoint, EndpointId, HttpMethod } from './endpoints'

/** One completed request, as seen from the browser. */
export interface RequestRecord {
  id: number
  endpointId: EndpointId
  method: HttpMethod
  url: string
  /** HTTP status, or 0 when the request never got a response. */
  status: number
  latencyMs: number
  /** Backend request ID, for finding the matching log lines. */
  requestId: string | null
  timestamp: Date
}

let nextId = 1

export function buildUrl(endpoint: Endpoint): string {
  if (!endpoint.query) return endpoint.path
  return `${endpoint.path}?${new URLSearchParams(endpoint.query())}`
}

/** Call an endpoint and measure it. Never throws: network failures are recorded as status 0. */
export async function sendRequest(endpoint: Endpoint): Promise<RequestRecord> {
  const url = buildUrl(endpoint)
  const started = performance.now()
  let status = 0
  let requestId: string | null = null
  try {
    const response = await fetch(url, { method: endpoint.method })
    status = response.status
    requestId = response.headers.get('X-Request-ID')
  } catch {
    // Network error: keep status 0.
  }
  return {
    id: nextId++,
    endpointId: endpoint.id,
    method: endpoint.method,
    url,
    status,
    latencyMs: performance.now() - started,
    requestId,
    timestamp: new Date(),
  }
}

export async function isHealthy(path: string): Promise<boolean> {
  try {
    return (await fetch(path)).ok
  } catch {
    return false
  }
}
