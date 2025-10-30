import { useCallback, useMemo, useState } from 'react';

export type SortDirection = 'asc' | 'desc';

export interface SortState<T> {
  key: keyof T | null;
  direction: SortDirection;
}

export interface UseTableSortParams<T> {
  rows: readonly T[];
  defaultSort?: { key: keyof T; direction?: SortDirection };
  accessor?: (row: T, key: keyof T) => unknown;
}

export interface UseTableSortResult<T> {
  sortedRows: readonly T[];
  sortState: SortState<T>;
  sortBy: (key: keyof T) => void;
}

function toComparable(value: unknown): string | number | Date | null {
  if (value == null) return null;
  if (value instanceof Date) return value;
  if (typeof value === 'number') return value;
  if (typeof value === 'string') return value.toLowerCase();
  // Attempt to coerce common primitives
  if (typeof (value as any).valueOf === 'function') {
    const v = (value as any).valueOf();
    if (typeof v === 'number' || typeof v === 'string') return (typeof v === 'string' ? v.toLowerCase() : v);
  }
  return String(value).toLowerCase();
}

function compareValues(a: unknown, b: unknown): number {
  const ca = toComparable(a);
  const cb = toComparable(b);
  if (ca === cb) return 0;
  if (ca == null) return -1;
  if (cb == null) return 1;
  // Date
  if (ca instanceof Date && cb instanceof Date) {
    return ca.getTime() - cb.getTime();
  }
  // Number
  if (typeof ca === 'number' && typeof cb === 'number') {
    return ca - cb;
  }
  // String (case-insensitive already)
  const sa = String(ca);
  const sb = String(cb);
  if (sa < sb) return -1;
  if (sa > sb) return 1;
  return 0;
}

export function useTableSort<T>(params: UseTableSortParams<T>): UseTableSortResult<T> {
  const { rows, defaultSort, accessor } = params;

  const [sortState, setSortState] = useState<SortState<T>>({
    key: defaultSort?.key ?? null,
    direction: defaultSort?.direction ?? 'asc',
  });

  const getValue = useCallback(
    (row: T, key: keyof T | null): unknown => {
      if (!key) return null;
      if (accessor) return accessor(row, key);
      return (row as any)[key];
    },
    [accessor]
  );

  const sortedRows = useMemo(() => {
    if (!sortState.key) return rows;
    const arr = [...rows];
    arr.sort((a, b) => {
      const cmp = compareValues(getValue(a, sortState.key), getValue(b, sortState.key));
      return sortState.direction === 'asc' ? cmp : -cmp;
    });
    return arr;
  }, [rows, sortState, getValue]);

  const sortBy = useCallback(
    (key: keyof T) => {
      setSortState((prev) => {
        if (prev.key === key) {
          const nextDir: SortDirection = prev.direction === 'asc' ? 'desc' : 'asc';
          return { key, direction: nextDir };
        }
        return { key, direction: 'asc' };
      });
    },
    []
  );

  return { sortedRows, sortState, sortBy };
}

export default useTableSort;


