/**
 * FilterDeleteBinder
 * Binds the existing "Delete Filter" button to the typed API client
 * Replaces inline fetch() logic without changing the UI markup
 */

import React from 'react'
import { QueryProvider } from '../../providers/QueryProvider'
import { ErrorBoundary } from '../shared/ErrorBoundary'
import { useDeleteFilter } from '../../hooks/useFilters'

function FilterDeleteBinderContent(): React.JSX.Element {
  const deleteFilter = useDeleteFilter()

  React.useEffect(() => {
    const filterDropdown = document.getElementById('analysis-filter') as HTMLSelectElement | null
    const deleteFilterBtn = document.getElementById('delete-filter-btn') as HTMLButtonElement | null

    if (!filterDropdown || !deleteFilterBtn) return

    const handleDelete = async (e: Event) => {
      e.preventDefault()
      e.stopPropagation()

      const value = filterDropdown.value
      if (!value.startsWith('custom_')) return
      const idPart = value.replace('custom_', '')
      const filterId = Number(idPart)
      if (!filterId || Number.isNaN(filterId)) return

      // Confirm
      // eslint-disable-next-line no-alert
      if (!confirm('Are you sure you want to delete this filter?')) return

      try {
        await deleteFilter.mutateAsync(filterId)
        // Navigate back to analysis without the filter
        // @ts-expect-error Turbo is available globally in Rails app
        if (window.Turbo && typeof window.Turbo.visit === 'function') {
          // @ts-expect-error Turbo global
          window.Turbo.visit('/analysis')
        } else {
          window.location.href = '/analysis'
        }
      } catch (err) {
        // eslint-disable-next-line no-alert
        alert('Error deleting filter. Please try again.')
        // eslint-disable-next-line no-console
        console.error('[FilterDeleteBinder] Delete failed:', err)
      }
    }

    deleteFilterBtn.addEventListener('click', handleDelete)
    return () => {
      deleteFilterBtn.removeEventListener('click', handleDelete)
    }
  }, [deleteFilter])

  // Renders nothing; acts as behavior binder
  return <></>
}

export default function FilterDeleteBinder(): React.JSX.Element {
  return (
    <ErrorBoundary>
      <QueryProvider>
        <FilterDeleteBinderContent />
      </QueryProvider>
    </ErrorBoundary>
  )
}


