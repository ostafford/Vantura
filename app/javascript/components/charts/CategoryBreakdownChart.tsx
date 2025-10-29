/**
 * Category breakdown pie chart component
 * Shows expense breakdown by category
 */

import React from 'react'
import Chart from 'react-apexcharts'
import { QueryProvider } from '../../providers/QueryProvider'
import { ErrorBoundary } from '../shared/ErrorBoundary'
import { useTrendsData } from '../../hooks/useTrendsData'

interface CategoryBreakdownChartProps {
  height?: number
}

function CategoryBreakdownChartContent({ height = 400 }: CategoryBreakdownChartProps): React.JSX.Element {
  const { data, isLoading, error } = useTrendsData()

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-gray-500 dark:text-gray-400">Loading chart data...</div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="p-4 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg">
        <div className="text-sm text-red-800 dark:text-red-200">
          Error loading chart: {error.error?.message || 'Unknown error'}
        </div>
      </div>
    )
  }

  const trendsData = data?.data
  if (!trendsData) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-gray-500 dark:text-gray-400">No data available</div>
      </div>
    )
  }

  // For now, show top merchant info as a simple representation
  // In a full implementation, this would show category breakdown from transactions
  const chartOptions = {
    chart: {
      type: 'pie' as const,
      height: height,
      fontFamily: 'Inter, sans-serif',
      toolbar: {
        show: false
      },
      animations: {
        enabled: true,
        easing: 'easeinout' as const,
        speed: 300
      }
    },
    labels: ['Top Merchant', 'Other'],
    colors: ['#3B82F6', '#E5E7EB'],
    dataLabels: {
      enabled: true,
      style: {
        fontSize: '12px',
        fontWeight: 'bold'
      },
      formatter: (val: number, opts: unknown) => {
        const labelIndex = (opts as { seriesIndex?: number }).seriesIndex ?? 0
        const labels = ['Top Merchant', 'Other']
        const label = labels[labelIndex] || ''
        return `${label}: ${val.toFixed(1)}%`
      }
    },
    legend: {
      show: true,
      position: 'bottom' as const,
      labels: {
        colors: window.matchMedia('(prefers-color-scheme: dark)').matches
          ? '#e5e7eb'
          : '#374151'
      }
    },
    tooltip: {
      y: {
        formatter: (val: number) => `$${val.toFixed(2)}`
      }
    },
    theme: {
      mode: (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light') as 'dark' | 'light'
    }
  }

  // Mock data - in real implementation, this would come from category breakdown
  const chartSeries = [trendsData.top_merchant.amount, Math.max(0, trendsData.current_month_expenses - trendsData.top_merchant.amount)]

  return (
    <div className="w-full">
      <div className="text-center mb-4">
        <div className="text-2xl font-bold text-gray-900 dark:text-white">
          ${trendsData.top_merchant.amount.toFixed(0)}
        </div>
        <div className="text-sm text-gray-500 dark:text-gray-400">
          Top: {trendsData.top_merchant.name}
        </div>
      </div>
      <Chart
        options={chartOptions}
        series={chartSeries}
        type="pie"
        height={height}
      />
    </div>
  )
}

/**
 * CategoryBreakdownChart - Wrapped with QueryProvider and ErrorBoundary
 */
export default function CategoryBreakdownChart(props: CategoryBreakdownChartProps): React.JSX.Element {
  return (
    <ErrorBoundary>
      <QueryProvider>
        <CategoryBreakdownChartContent {...props} />
      </QueryProvider>
    </ErrorBoundary>
  )
}

