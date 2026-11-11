export type Outcome = 'success' | 'client-error' | 'server-error' | 'network-error'

export function outcomeOf(status: number): Outcome {
  if (status === 0) return 'network-error'
  if (status >= 500) return 'server-error'
  if (status >= 400) return 'client-error'
  return 'success'
}

export function isFailure(status: number): boolean {
  return outcomeOf(status) !== 'success'
}

/** Nearest-rank percentile; `p` is between 0 and 100. Returns null for no values. */
export function percentile(values: readonly number[], p: number): number | null {
  if (values.length === 0) return null
  const sorted = [...values].sort((a, b) => a - b)
  const rank = Math.ceil((p / 100) * sorted.length)
  return sorted[Math.max(rank - 1, 0)]!
}

export function formatLatency(ms: number | null): string {
  if (ms === null) return '–'
  if (ms >= 1000) return `${(ms / 1000).toFixed(2)} s`
  return `${Math.round(ms)} ms`
}

export function formatPercent(ratio: number | null): string {
  if (ratio === null) return '–'
  return `${(ratio * 100).toFixed(ratio === 1 ? 0 : 1)}%`
}
