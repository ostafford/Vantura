import React from 'react';

export type SortDirection = 'asc' | 'desc';

export interface Column<T> {
  id: keyof T;
  header: string;
  sortable?: boolean;
  // Optional accessor if value is nested/derived
  accessor?: (row: T) => unknown;
  // Optional width or class hooks
  headerClassName?: string;
  cellClassName?: string;
}

export interface ResponsiveTableProps<T> {
  ariaLabel: string;
  columns: readonly Column<T>[];
  rows: readonly T[];
  getRowId: (row: T, index: number) => string;
  renderCell?: (row: T, column: Column<T>) => React.ReactNode;
  rowClassName?: (row: T, index: number) => string | undefined;
  sortState: { key: keyof T | null; direction: SortDirection };
  onSortChange: (key: keyof T) => void;
  loading?: boolean;
  emptyState?: React.ReactNode;
}

function getAriaSort<T>(col: Column<T>, sortKey: keyof T | null, dir: SortDirection) {
  if (!col.sortable) return 'none' as const;
  if (sortKey === col.id) return (dir === 'asc' ? 'ascending' : 'descending') as const;
  return 'none' as const;
}

export function ResponsiveTable<T>(props: ResponsiveTableProps<T>) {
  const { ariaLabel, columns, rows, getRowId, renderCell, rowClassName, sortState, onSortChange, loading, emptyState } = props;

  if (!loading && rows.length === 0) {
    return <div role="status" aria-live="polite">{emptyState ?? 'No results'}</div>;
  }

  return (
    <div className="w-full">
      {/* Desktop table */}
      <div className="hidden md:block overflow-x-auto">
        <table className="min-w-full" role="table" aria-label={ariaLabel}>
          <thead>
            <tr>
              {columns.map((col) => {
                const ariaSort = getAriaSort(col, sortState.key, sortState.direction);
                return (
                  <th key={String(col.id)} scope="col" className={col.headerClassName} aria-sort={ariaSort}>
                    {col.sortable ? (
                      <button type="button" onClick={() => onSortChange(col.id)} className="inline-flex items-center gap-1">
                        <span>{col.header}</span>
                        {ariaSort === 'ascending' && <span aria-hidden>▲</span>}
                        {ariaSort === 'descending' && <span aria-hidden>▼</span>}
                      </button>
                    ) : (
                      <span>{col.header}</span>
                    )}
                  </th>
                );
              })}
            </tr>
          </thead>
          <tbody>
            {rows.map((row, index) => (
              <tr key={getRowId(row, index)} className={rowClassName?.(row, index)}>
                {columns.map((col) => (
                  <td key={String(col.id)} className={col.cellClassName}>
                    {renderCell ? renderCell(row, col) : String(col.accessor ? col.accessor(row) : (row as any)[col.id])}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Mobile cards */}
      <div className="md:hidden space-y-3" role="list" aria-label={`${ariaLabel} (mobile)`}>
        {rows.map((row, index) => (
          <div key={getRowId(row, index)} role="listitem" className={`rounded border p-3 ${rowClassName?.(row, index) || ''}`}>
            {columns.map((col) => (
              <div key={String(col.id)} className="flex justify-between py-1">
                <div className="text-sm text-gray-500">{col.header}</div>
                <div className="text-sm font-medium">
                  {renderCell ? renderCell(row, col) : String(col.accessor ? col.accessor(row) : (row as any)[col.id])}
                </div>
              </div>
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}

export default ResponsiveTable;


