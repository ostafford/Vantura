import { describe, it, expect } from 'vitest'
import { renderHook, act } from '@testing-library/react'
import { useTableSort } from '../useTableSort'

interface Row {
  id: number
  name: string
  amount: number
  date: string
}

const rows: readonly Row[] = [
  { id: 1, name: 'Banana', amount: 10, date: '2024-01-03' },
  { id: 2, name: 'apple', amount: 5, date: '2024-01-01' },
  { id: 3, name: 'Cherry', amount: 20, date: '2024-01-02' },
]

describe('useTableSort', () => {
  it('sorts by number ascending/descending', () => {
    const { result } = renderHook(() =>
      useTableSort<Row>({ rows, defaultSort: { key: 'amount', direction: 'asc' } })
    )
    expect(result.current.sortedRows.map((r) => r.id)).toEqual([2, 1, 3])

    act(() => result.current.sortBy('amount'))
    expect(result.current.sortedRows.map((r) => r.id)).toEqual([3, 1, 2])
  })

  it('sorts by string case-insensitive', () => {
    const { result } = renderHook(() =>
      useTableSort<Row>({ rows, defaultSort: { key: 'name', direction: 'asc' } })
    )
    expect(result.current.sortedRows.map((r) => r.name)).toEqual(['apple', 'Banana', 'Cherry'])
  })

  it('sorts by date with accessor', () => {
    const { result } = renderHook(() =>
      useTableSort<Row>({
        rows,
        defaultSort: { key: 'date', direction: 'asc' },
        accessor: (row, key) => (key === 'date' ? new Date(row.date) : (row as any)[key]),
      })
    )
    expect(result.current.sortedRows.map((r) => r.date)).toEqual(['2024-01-01', '2024-01-02', '2024-01-03'])
  })
})


