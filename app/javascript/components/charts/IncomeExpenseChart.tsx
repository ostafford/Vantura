/**
 * Income vs Expense comparison chart component
 * Uses ApexCharts for visualization
 */

import React from 'react'
import Chart from 'react-apexcharts'
import { QueryProvider } from '../../providers/QueryProvider'
import { ErrorBoundary } from '../shared/ErrorBoundary'
import { useTrendsData } from '../../hooks/useTrendsData'

interface IncomeExpenseChartProps {
  // Props can be passed from ERB view if needed
  height?: number
}

function IncomeExpenseChartContent({ height = 400 }: IncomeExpenseChartProps): React.JSX.Element {
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

  const chartOptions = {
    chart: {
      type: 'bar' as const,
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
    plotOptions: {
      bar: {
        horizontal: false,
        columnWidth: '55%',
        endingShape: 'rounded' as const
      }
    },
    dataLabels: {
      enabled: true,
      style: {
        fontSize: '12px',
        fontWeight: 'bold'
      },
      formatter: (val: number) => `$${val.toFixed(0)}`
    },
    stroke: {
      show: true,
      width: 2,
      colors: ['transparent']
    },
    xaxis: {
      categories: ['Current Month', 'Last Month'],
      labels: {
        style: {
          colors: window.matchMedia('(prefers-color-scheme: dark)').matches
            ? '#e5e7eb'
            : '#374151'
        }
      }
    },
    yaxis: {
      title: {
        text: 'Amount ($)',
        style: {
          color: window.matchMedia('(prefers-color-scheme: dark)').matches
            ? '#e5e7eb'
            : '#374151'
        }
      },
      labels: {
        formatter: (val: number) => `$${val.toFixed(0)}`,
        style: {
          colors: window.matchMedia('(prefers-color-scheme: dark)').matches
            ? '#e5e7eb'
            : '#374151'
        }
      }
    },
    fill: {
      opacity: 1
    },
    colors: ['#10B981', '#EF4444'], // Green for income, red for expenses
    legend: {
      show: true,
      position: 'top' as const,
      horizontalAlign: 'right' as const,
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

  const chartSeries = [
    {
      name: 'Income',
      data: [trendsData.current_month_income, trendsData.last_month_income]
    },
    {
      name: 'Expenses',
      data: [trendsData.current_month_expenses, trendsData.last_month_expenses]
    }
  ]

  return (
    <div className="w-full">
      <Chart
        options={chartOptions}
        series={chartSeries}
        type="bar"
        height={height}
      />
    </div>
  )
}

/**
 * IncomeExpenseChart - Wrapped with QueryProvider and ErrorBoundary
 */
export default function IncomeExpenseChart(props: IncomeExpenseChartProps): React.JSX.Element {
  return (
    <ErrorBoundary>
      <QueryProvider>
        <IncomeExpenseChartContent {...props} />
      </QueryProvider>
    </ErrorBoundary>
  )
}

