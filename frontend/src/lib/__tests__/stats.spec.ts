import { describe, expect, it } from 'vitest'

import { formatLatency, formatPercent, outcomeOf, percentile } from '../stats'

describe('outcomeOf', () => {
  it.each([
    [200, 'success'],
    [302, 'success'],
    [401, 'client-error'],
    [500, 'server-error'],
    [0, 'network-error'],
  ])('classifies %i as %s', (status, outcome) => {
    expect(outcomeOf(status)).toBe(outcome)
  })
})

describe('percentile', () => {
  it('returns null without values', () => {
    expect(percentile([], 95)).toBeNull()
  })

  it('uses the nearest rank', () => {
    const values = Array.from({ length: 100 }, (_, i) => i + 1)
    expect(percentile(values, 95)).toBe(95)
    expect(percentile(values, 50)).toBe(50)
    expect(percentile([7], 95)).toBe(7)
  })

  it('does not depend on input order', () => {
    expect(percentile([30, 10, 20], 50)).toBe(20)
  })
})

describe('formatting', () => {
  it('formats latency in ms or s', () => {
    expect(formatLatency(null)).toBe('–')
    expect(formatLatency(42.4)).toBe('42 ms')
    expect(formatLatency(1530)).toBe('1.53 s')
  })

  it('formats ratios as percentages', () => {
    expect(formatPercent(null)).toBe('–')
    expect(formatPercent(1)).toBe('100%')
    expect(formatPercent(0.8333)).toBe('83.3%')
  })
})
