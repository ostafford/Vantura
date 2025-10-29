/**
 * Recurring Transaction Form Component
 * Create recurring transactions from existing transactions or from scratch
 */

import React, { useState, useEffect } from 'react'
import { QueryProvider } from '../../providers/QueryProvider'
import { ErrorBoundary } from '../shared/ErrorBoundary'
import { useCreateRecurringTransaction } from '../../hooks/useRecurringMutations'
import type { RecurringFrequency, TransactionType } from '../../types/models'

interface RecurringTransactionFormProps {
  transactionId?: number
  description?: string
  amount?: number
  transactionDate?: string
  onSuccess?: () => void
  onCancel?: () => void
}

function RecurringTransactionFormContent({
  transactionId,
  description: initialDescription,
  amount: initialAmount,
  transactionDate: initialTransactionDate,
  onSuccess,
  onCancel
}: RecurringTransactionFormProps): React.JSX.Element {
  const createRecurring = useCreateRecurringTransaction()

  const [description, setDescription] = useState(initialDescription || '')
  const [amount, setAmount] = useState(initialAmount || 0)
  const [frequency, setFrequency] = useState<RecurringFrequency>('monthly')
  const [nextOccurrenceDate, setNextOccurrenceDate] = useState<string>('')
  const [transactionType, setTransactionType] = useState<TransactionType>(initialAmount && initialAmount < 0 ? 'expense' : 'income')
  const [projectionMonths, setProjectionMonths] = useState<string>('indefinite')
  const [amountTolerance, setAmountTolerance] = useState<number>(1.0)
  const [errors, setErrors] = useState<Record<string, string>>({})

  // Calculate default next occurrence date based on frequency and transaction date
  useEffect(() => {
    if (!nextOccurrenceDate && initialTransactionDate) {
      const date = new Date(initialTransactionDate)
      const newDate = new Date(date)
      
      switch (frequency) {
        case 'weekly':
          newDate.setDate(date.getDate() + 7)
          break
        case 'fortnightly':
          newDate.setDate(date.getDate() + 14)
          break
        case 'monthly':
          newDate.setMonth(date.getMonth() + 1)
          break
        case 'quarterly':
          newDate.setMonth(date.getMonth() + 3)
          break
        case 'yearly':
          newDate.setFullYear(date.getFullYear() + 1)
          break
      }
      
      setNextOccurrenceDate(newDate.toISOString().split('T')[0])
    }
  }, [frequency, initialTransactionDate, nextOccurrenceDate])

  // Update next occurrence when frequency changes
  useEffect(() => {
    if (initialTransactionDate) {
      const date = new Date(initialTransactionDate)
      const newDate = new Date(date)
      
      switch (frequency) {
        case 'weekly':
          newDate.setDate(date.getDate() + 7)
          break
        case 'fortnightly':
          newDate.setDate(date.getDate() + 14)
          break
        case 'monthly':
          newDate.setMonth(date.getMonth() + 1)
          break
        case 'quarterly':
          newDate.setMonth(date.getMonth() + 3)
          break
        case 'yearly':
          newDate.setFullYear(date.getFullYear() + 1)
          break
      }
      
      setNextOccurrenceDate(newDate.toISOString().split('T')[0])
    }
  }, [frequency])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setErrors({})

    // Validation
    if (!description.trim()) {
      setErrors({ description: 'Description is required' })
      return
    }
    if (!nextOccurrenceDate) {
      setErrors({ next_occurrence_date: 'Next occurrence date is required' })
      return
    }

    try {
      await createRecurring.mutateAsync({
        transaction_id: transactionId,
        recurring_transaction: {
          description,
          amount,
          frequency,
          next_occurrence_date: nextOccurrenceDate,
          transaction_type: transactionType,
          projection_months: projectionMonths,
          amount_tolerance: amountTolerance,
          is_active: true
        }
      })

      if (onSuccess) {
        onSuccess()
      } else {
        // Close modal and reload
        window.location.reload()
      }
    } catch (error) {
      console.error('Failed to create recurring transaction:', error)
      setErrors({ submit: 'Failed to create recurring pattern. Please try again.' })
    }
  }

  return (
    <form onSubmit={handleSubmit} className="p-6">
      <div className="space-y-5">
        {/* Transaction Preview */}
        {(initialDescription || description) && (
          <div className="bg-success-500/5 dark:bg-success-700/10 border-2 border-success-500/20 dark:border-success-700 rounded-lg p-4">
            <div className="flex items-center gap-3 mb-3">
              <div className="inline-flex items-center justify-center w-9 h-9 bg-success-500/10 dark:bg-success-700/20 rounded-lg">
                <svg className="w-5 h-5 text-success-500 dark:text-success-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                </svg>
              </div>
              <p className="text-sm font-semibold text-gray-700 dark:text-gray-300">Transaction Details</p>
            </div>
            <p className="text-lg font-bold text-gray-900 dark:text-white mb-1">{description || initialDescription}</p>
            <p className="text-sm text-gray-600 dark:text-gray-400">
              Amount: <span className="font-semibold text-gray-900 dark:text-white">${Math.abs(amount).toFixed(2)}</span>
            </p>
          </div>
        )}

        {/* Description */}
        <div>
          <label htmlFor="recurring-description" className="block text-sm font-semibold text-gray-700 dark:text-gray-200 mb-2">
            Description
          </label>
          <input
            type="text"
            id="recurring-description"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            required
            className="w-full px-4 py-3 border-2 border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-primary-900 text-gray-900 dark:text-white rounded-lg focus:ring-2 focus:ring-success-500 focus:border-success-500 transition-all"
          />
          {errors.description && <p className="mt-1 text-sm text-red-600 dark:text-red-400">{errors.description}</p>}
        </div>

        {/* Transaction Type */}
        <div>
          <label className="block text-sm font-semibold text-gray-700 dark:text-gray-200 mb-2">Transaction Type</label>
          <div className="grid grid-cols-2 gap-2">
            <label className="flex items-center p-3 border-2 border-gray-200 dark:border-gray-600 rounded-lg cursor-pointer hover:bg-gray-50 dark:hover:bg-primary-900 transition-all">
              <input
                type="radio"
                name="transaction_type"
                value="expense"
                checked={transactionType === 'expense'}
                onChange={() => setTransactionType('expense')}
                className="mr-2"
              />
              <span className="text-sm text-gray-700 dark:text-gray-300">Expense</span>
            </label>
            <label className="flex items-center p-3 border-2 border-gray-200 dark:border-gray-600 rounded-lg cursor-pointer hover:bg-gray-50 dark:hover:bg-primary-900 transition-all">
              <input
                type="radio"
                name="transaction_type"
                value="income"
                checked={transactionType === 'income'}
                onChange={() => setTransactionType('income')}
                className="mr-2"
              />
              <span className="text-sm text-gray-700 dark:text-gray-300">Income</span>
            </label>
          </div>
        </div>

        {/* Amount */}
        <div>
          <label htmlFor="recurring-amount" className="block text-sm font-semibold text-gray-700 dark:text-gray-200 mb-2">
            Amount
          </label>
          <input
            type="number"
            id="recurring-amount"
            value={amount}
            onChange={(e) => setAmount(parseFloat(e.target.value) || 0)}
            step="0.01"
            required
            className="w-full px-4 py-3 border-2 border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-primary-900 text-gray-900 dark:text-white rounded-lg focus:ring-2 focus:ring-success-500 focus:border-success-500 transition-all"
          />
        </div>

        {/* Frequency */}
        <div>
          <label htmlFor="frequency" className="block text-sm font-semibold text-gray-700 dark:text-gray-200 mb-2">
            How often does this occur?
          </label>
          <select
            id="frequency"
            value={frequency}
            onChange={(e) => setFrequency(e.target.value as RecurringFrequency)}
            required
            className="w-full px-4 py-3 border-2 border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-primary-900 text-gray-900 dark:text-white rounded-lg focus:ring-2 focus:ring-success-500 focus:border-success-500 transition-all"
          >
            <option value="weekly">Weekly (every 7 days)</option>
            <option value="fortnightly">Fortnightly (every 14 days)</option>
            <option value="monthly">Monthly</option>
            <option value="quarterly">Quarterly (every 3 months)</option>
            <option value="yearly">Yearly</option>
          </select>
        </div>

        {/* Next Occurrence Date */}
        <div>
          <label htmlFor="nextOccurrenceDate" className="block text-sm font-semibold text-gray-700 dark:text-gray-200 mb-2">
            When is the next occurrence?
          </label>
          <input
            type="date"
            id="nextOccurrenceDate"
            value={nextOccurrenceDate}
            onChange={(e) => setNextOccurrenceDate(e.target.value)}
            required
            className="w-full px-4 py-3 border-2 border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-primary-900 text-gray-900 dark:text-white rounded-lg focus:ring-2 focus:ring-success-500 focus:border-success-500 transition-all"
          />
          <p className="text-xs text-gray-500 dark:text-gray-400 mt-1.5">We'll project future occurrences from this date</p>
          {errors.next_occurrence_date && (
            <p className="mt-1 text-sm text-red-600 dark:text-red-400">{errors.next_occurrence_date}</p>
          )}
        </div>

        {/* Projection Duration */}
        <div>
          <label htmlFor="projection_months" className="block text-sm font-semibold text-gray-700 dark:text-gray-200 mb-2">
            How far ahead to project?
          </label>
          <select
            id="projection_months"
            value={projectionMonths}
            onChange={(e) => setProjectionMonths(e.target.value)}
            className="w-full px-4 py-3 border-2 border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-primary-900 text-gray-900 dark:text-white rounded-lg focus:ring-2 focus:ring-success-500 focus:border-success-500 transition-all"
          >
            <option value="indefinite">Indefinite (recommended)</option>
            <option value="3">3 months</option>
            <option value="6">6 months</option>
            <option value="12">12 months</option>
            <option value="24">24 months</option>
          </select>
          <p className="text-xs text-gray-500 dark:text-gray-400 mt-1.5">
            Indefinite will continue projecting as you navigate future months
          </p>
        </div>

        {/* Amount Tolerance */}
        <div>
          <label htmlFor="recurring_transaction_amount_tolerance" className="block text-sm font-semibold text-gray-700 dark:text-gray-200 mb-2">
            Amount matching tolerance
          </label>
          <div className="relative">
            <span className="absolute left-4 top-3 text-gray-500 dark:text-gray-400 font-semibold">±$</span>
            <input
              type="number"
              id="recurring_transaction_amount_tolerance"
              value={amountTolerance}
              onChange={(e) => setAmountTolerance(parseFloat(e.target.value) || 0)}
              step="0.01"
              min="0"
              className="w-full pl-10 pr-4 py-3 border-2 border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-primary-900 text-gray-900 dark:text-white rounded-lg focus:ring-2 focus:ring-success-500 focus:border-success-500 transition-all"
            />
          </div>
          <p className="text-xs text-gray-500 dark:text-gray-400 mt-1.5">Allows matching transactions with slightly different amounts</p>
        </div>

        {/* Info Box */}
        <div className="bg-success-500/10 dark:bg-success-700/10 border border-success-500/30 dark:border-success-700 rounded-lg p-4">
          <div className="flex items-start gap-3">
            <svg className="w-5 h-5 text-success-500 dark:text-success-300 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <div>
              <p className="text-sm font-semibold text-gray-800 dark:text-gray-200 mb-1">How it works</p>
              <p className="text-xs text-gray-700 dark:text-gray-300 leading-relaxed">
                We'll automatically add this transaction to future months. When Up Bank syncs the real transaction, we'll match and replace it.
              </p>
            </div>
          </div>
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
              disabled={createRecurring.isPending}
              className="flex-1 bg-gradient-to-r from-success-500 to-success-700 hover:from-success-700 hover:to-success-500 text-white px-5 py-3 rounded-lg font-semibold shadow-md hover:shadow-lg transition-all disabled:opacity-50"
            >
              Create Pattern
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

export default function RecurringTransactionForm(props: RecurringTransactionFormProps): React.JSX.Element {
  return (
    <ErrorBoundary>
      <QueryProvider>
        <RecurringTransactionFormContent {...props} />
      </QueryProvider>
    </ErrorBoundary>
  )
}

