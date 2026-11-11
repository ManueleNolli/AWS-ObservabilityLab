import { randomItem } from '@/lib/random'

export type HttpMethod = 'GET' | 'POST'

export type EndpointId = 'login' | 'checkout' | 'search' | 'error'

export interface Endpoint {
  id: EndpointId
  label: string
  description: string
  method: HttpMethod
  path: string
  query?: () => Record<string, string>
}

const SEARCH_TERMS = ['shoes', 'laptop', 'coffee', 'books', 'headphones']

/** The demo endpoints, in the order they appear in the UI. */
export const ENDPOINTS: readonly Endpoint[] = [
  {
    id: 'login',
    label: 'Login',
    description: 'Rejected with 401 now and then.',
    method: 'POST',
    path: '/api/login',
  },
  {
    id: 'checkout',
    label: 'Checkout',
    description: 'Slow, and fails with 500 once in a while.',
    method: 'POST',
    path: '/api/checkout',
  },
  {
    id: 'search',
    label: 'Search',
    description: 'Fast and reliable.',
    method: 'GET',
    path: '/api/search',
    query: () => ({ q: randomItem(SEARCH_TERMS) }),
  },
  {
    id: 'error',
    label: 'Trigger error',
    description: 'Raises an unhandled exception, always 500.',
    method: 'POST',
    path: '/api/error',
  },
]

export const HEALTH_PATH = '/api/health'
