import { describe, it, expect } from 'vitest'
import { formatAmount, formatDate } from '../formatting'

describe('formatting', () => {
  it('formats amount with fallbacks', () => {
    const s = formatAmount(1234.5, { locale: 'en-US', currency: 'USD' })
    expect(s).toContain('$')
  })

  it('formats date default options', () => {
    const s = formatDate('2024-01-02', { locale: 'en-US' })
    expect(typeof s).toBe('string')
  })
})


