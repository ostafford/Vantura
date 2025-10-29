/**
 * Filter Form Component
 * Create and edit custom filters for analysis
 */

import React, { useState } from 'react'
import { QueryProvider } from '../../providers/QueryProvider'
import { ErrorBoundary } from '../shared/ErrorBoundary'
import { useCreateFilter, useUpdateFilter } from '../../hooks/useFilters'
import type { Filter } from '../../types/models'

interface FilterFormProps {
  filterId?: number
  initialFilter?: Partial<Filter>
  availableCategories?: string[]
  availableMerchants?: string[]
  availableStatuses?: string[]
  onSuccess?: () => void
  onCancel?: () => void
}

function FilterFormContent({
  filterId,
  initialFilter,
  availableCategories = [],
  availableMerchants = [],
  availableStatuses = [],
  onSuccess,
  onCancel
}: FilterFormProps): React.JSX.Element {
  const createFilter = useCreateFilter()
  const updateFilter = useUpdateFilter()

  const [name, setName] = useState(initialFilter?.name || '')
  const [filterTypes, setFilterTypes] = useState<string[]>(initialFilter?.filter_types || [])
  const [filterParams, setFilterParams] = useState(initialFilter?.filter_params || {})
  const [dateRange, setDateRange] = useState<'custom' | string>('current_month')
  const [customStartDate, setCustomStartDate] = useState<string>('')
  const [customEndDate, setCustomEndDate] = useState<string>('')
  const [errors, setErrors] = useState<Record<string, string>>({})

  const isEditMode = !!filterId

  const handleFilterTypeChange = (type: string, checked: boolean) => {
    if (checked) {
      setFilterTypes([...filterTypes, type])
    } else {
      setFilterTypes(filterTypes.filter(t => t !== type))
      // Remove params for unselected type
      const newParams = { ...filterParams }
      if (type === 'category') delete newParams.categories
      if (type === 'merchant') delete newParams.merchants
      if (type === 'status') delete newParams.statuses
      if (type === 'recurring_transactions') delete newParams.recurring_transactions
      setFilterParams(newParams)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setErrors({})

    // Validation
    if (!name.trim()) {
      setErrors({ name: 'Filter name is required' })
      return
    }
    if (filterTypes.length === 0) {
      setErrors({ filter_types: 'At least one filter type must be selected' })
      return
    }

    // Build filter params
    const params: Record<string, unknown> = {}
    if (filterTypes.includes('category') && filterParams.categories) {
      params.categories = filterParams.categories
    }
    if (filterTypes.includes('merchant') && filterParams.merchants) {
      params.merchants = filterParams.merchants
    }
    if (filterTypes.includes('status') && filterParams.statuses) {
      params.statuses = filterParams.statuses
    }
    if (filterTypes.includes('recurring_transactions') && filterParams.recurring_transactions) {
      params.recurring_transactions = filterParams.recurring_transactions
    }

    // Build date range
    let dateRangeData: { start_date: string | null; end_date: string | null } | null = null
    if (dateRange === 'custom' && customStartDate && customEndDate) {
      dateRangeData = {
        start_date: customStartDate,
        end_date: customEndDate
      }
    } else if (dateRange !== 'custom') {
      // Calculate date ranges (simplified - in production, calculate actual dates)
      dateRangeData = null // Simplified for now
    }

    try {
      if (isEditMode && filterId) {
        await updateFilter.mutateAsync({
          id: filterId,
          params: {
            filter: {
              name,
              filter_types: filterTypes,
              filter_params: params,
              date_range: dateRangeData
            }
          }
        })
      } else {
        await createFilter.mutateAsync({
          filter: {
            name,
            filter_types: filterTypes,
            filter_params: params,
            date_range: dateRangeData
          }
        })
      }

      // Reload page to show updated filter
      if (onSuccess) {
        onSuccess()
      } else {
        window.location.reload()
      }
    } catch (error) {
      console.error('Failed to save filter:', error)
      setErrors({ submit: 'Failed to save filter. Please try again.' })
    }
  }

  return (
    <form onSubmit={handleSubmit} className="p-6">
      <div className="space-y-5">
        {/* Filter Name */}
        <div>
          <label htmlFor="filter-name" className="block text-sm font-semibold text-gray-700 dark:text-gray-200 mb-2">
            Filter Name
          </label>
          <input
            type="text"
            id="filter-name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            required
            className={`w-full px-4 py-3 border-2 rounded-lg focus:ring-2 focus:ring-primary-700 focus:border-primary-700 dark:focus:border-primary-500 transition-all ${
              errors.name ? 'border-red-500' : 'border-gray-200 dark:border-gray-600'
            } bg-gray-50 dark:bg-primary-900 text-gray-900 dark:text-white`}
            placeholder="e.g., High Value Expenses"
          />
          {errors.name && <p className="mt-1 text-sm text-red-600 dark:text-red-400">{errors.name}</p>}
        </div>

        {/* Filter Types */}
        <div>
          <label className="block text-sm font-semibold text-gray-700 dark:text-gray-200 mb-2">Filter Types</label>
          <p className="text-xs text-gray-500 dark:text-gray-400 mb-3">Select one or more filter types to combine</p>
          <div className="grid grid-cols-2 gap-2">
            {['category', 'merchant', 'status', 'recurring_transactions'].map((type) => (
              <label
                key={type}
                className="flex items-center p-3 border-2 border-gray-200 dark:border-gray-600 rounded-lg cursor-pointer hover:bg-gray-50 dark:hover:bg-primary-900 transition-all"
              >
                <input
                  type="checkbox"
                  checked={filterTypes.includes(type)}
                  onChange={(e) => handleFilterTypeChange(type, e.target.checked)}
                  className="mr-2"
                />
                <span className="text-sm text-gray-700 dark:text-gray-300 capitalize">
                  {type.replace('_', ' ')}
                </span>
              </label>
            ))}
          </div>
          {errors.filter_types && (
            <p className="mt-1 text-sm text-red-600 dark:text-red-400">{errors.filter_types}</p>
          )}
        </div>

        {/* Filter Parameters - Dynamic based on selected types */}
        <div id="filter-params" className="space-y-4">
          {filterTypes.includes('category') && (
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Categories</label>
              <select
                multiple
                value={(filterParams.categories as string[]) || []}
                onChange={(e) => {
                  const selected = Array.from(e.target.selectedOptions, (option) => option.value)
                  setFilterParams({ ...filterParams, categories: selected })
                }}
                className="w-full px-4 py-3 border-2 border-gray-200 dark:border-gray-600 rounded-lg bg-gray-50 dark:bg-primary-900 text-gray-900 dark:text-white"
                size={5}
              >
                {availableCategories.map((cat) => (
                  <option key={cat} value={cat}>
                    {cat.replace(/_/g, ' ')}
                  </option>
                ))}
              </select>
              <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">Hold Ctrl/Cmd to select multiple</p>
            </div>
          )}

          {filterTypes.includes('merchant') && (
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Merchants</label>
              <select
                multiple
                value={(filterParams.merchants as string[]) || []}
                onChange={(e) => {
                  const selected = Array.from(e.target.selectedOptions, (option) => option.value)
                  setFilterParams({ ...filterParams, merchants: selected })
                }}
                className="w-full px-4 py-3 border-2 border-gray-200 dark:border-gray-600 rounded-lg bg-gray-50 dark:bg-primary-900 text-gray-900 dark:text-white"
                size={5}
              >
                {availableMerchants.map((merchant) => (
                  <option key={merchant} value={merchant}>
                    {merchant}
                  </option>
                ))}
              </select>
              <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">Hold Ctrl/Cmd to select multiple</p>
            </div>
          )}

          {filterTypes.includes('status') && (
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Statuses</label>
              <select
                multiple
                value={(filterParams.statuses as string[]) || []}
                onChange={(e) => {
                  const selected = Array.from(e.target.selectedOptions, (option) => option.value)
                  setFilterParams({ ...filterParams, statuses: selected })
                }}
                className="w-full px-4 py-3 border-2 border-gray-200 dark:border-gray-600 rounded-lg bg-gray-50 dark:bg-primary-900 text-gray-900 dark:text-white"
              >
                {availableStatuses.map((status) => (
                  <option key={status} value={status}>
                    {status}
                  </option>
                ))}
              </select>
            </div>
          )}

          {filterTypes.includes('recurring_transactions') && (
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Recurring Transactions</label>
              <select
                value={(filterParams.recurring_transactions as 'true' | 'false' | 'both') || 'both'}
                onChange={(e) => {
                  setFilterParams({ ...filterParams, recurring_transactions: e.target.value as 'true' | 'false' | 'both' })
                }}
                className="w-full px-4 py-3 border-2 border-gray-200 dark:border-gray-600 rounded-lg bg-gray-50 dark:bg-primary-900 text-gray-900 dark:text-white"
              >
                <option value="true">From Recurring Only</option>
                <option value="false">Non-Recurring Only</option>
                <option value="both">Both</option>
              </select>
            </div>
          )}
        </div>

        {/* Date Range - Simplified */}
        <div className="mt-6 pt-6 border-t border-gray-200 dark:border-gray-700">
          <label className="block text-sm font-semibold text-gray-700 dark:text-gray-200 mb-3">Date Range (Optional)</label>
          <select
            value={dateRange}
            onChange={(e) => setDateRange(e.target.value)}
            className="w-full px-4 py-3 border-2 border-gray-200 dark:border-gray-600 rounded-lg bg-gray-50 dark:bg-primary-900 text-gray-900 dark:text-white"
          >
            <option value="current_month">Current Month</option>
            <option value="last_month">Last Month</option>
            <option value="3_months">3 Months</option>
            <option value="6_months">6 Months</option>
            <option value="custom">Custom Range</option>
          </select>
          {dateRange === 'custom' && (
            <div className="grid grid-cols-2 gap-4 mt-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Start Date</label>
                <input
                  type="date"
                  value={customStartDate}
                  onChange={(e) => setCustomStartDate(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">End Date</label>
                <input
                  type="date"
                  value={customEndDate}
                  onChange={(e) => setCustomEndDate(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
                />
              </div>
            </div>
          )}
        </div>

        {errors.submit && (
          <div className="p-3 bg-red-100 dark:bg-red-900/30 border border-red-300 dark:border-red-700 rounded-lg">
            <p className="text-sm text-red-800 dark:text-red-300">{errors.submit}</p>
          </div>
        )}

        {/* Submit Buttons */}
        <div className="mt-6 pt-6 border-t border-gray-200 dark:border-gray-700">
          <div className="flex gap-3">
            <button
              type="submit"
              disabled={createFilter.isPending || updateFilter.isPending}
              className="flex-1 bg-gradient-to-r from-primary-700 to-primary-500 hover:from-primary-900 hover:to-primary-700 text-white px-5 py-3 rounded-lg font-semibold shadow-md hover:shadow-lg transition-all disabled:opacity-50"
            >
              {isEditMode ? 'Update Filter' : 'Save Filter'}
            </button>
            {onCancel && (
              <button
                type="button"
                onClick={onCancel}
                className="px-5 py-3 bg-white dark:bg-primary-950 border-2 border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-50 dark:hover:bg-primary-900 font-semibold transition-all"
              >
                Cancel
              </button>
            )}
          </div>
        </div>
      </div>
    </form>
  )
}

export default function FilterForm(props: FilterFormProps): React.JSX.Element {
  return (
    <ErrorBoundary>
      <QueryProvider>
        <FilterFormContent {...props} />
      </QueryProvider>
    </ErrorBoundary>
  )
}

