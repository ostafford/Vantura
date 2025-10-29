/**
 * Merchant analysis chart component
 * Shows breakdown by merchant using ApexCharts
 */

import React from 'react'
import Chart from 'react-apexcharts'
import { QueryProvider } from '../../providers/QueryProvider'
import { ErrorBoundary } from '../shared/ErrorBoundary'
import { useAnalysisData } from '../../hooks/useAnalysisData'

interface MerchantAnalysisChartProps {
  filterId?: number
  height?: number
  chartType?: 'pie' | 'bar'
}

function MerchantAnalysisChartContent({
  filterId,
  height = 400,
  chartType = 'pie'
}: MerchantAnalysisChartProps): React.JSX.Element {
  const { data, isLoading, error } = useAnalysisData(filterId)

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

  const analysisData = data?.data
  if (!analysisData || !analysisData.breakdowns.merchant) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-gray-500 dark:text-gray-400">No merchant data available</div>
      </div>
    )
  }

  const merchantBreakdown = analysisData.breakdowns.merchant
  const sortedMerchants = Object.entries(merchantBreakdown)
    .sort(([, a], [, b]) => Math.abs(b as number) - Math.abs(a as number))
    .slice(0, 8) // Top 8 merchants

  const labels = sortedMerchants.map(([merchant]) => merchant || 'Uncategorized')
  const series = sortedMerchants.map(([, amount]) => Math.abs(amount as number))
  const total = series.reduce((sum, val) => sum + val, 0)

  const colors = ['#3B82F6', '#EF4444', '#10B981', '#F59E0B', '#8B5CF6', '#06B6D4', '#84CC16', '#F97316']

  const baseOptions = {
    chart: {
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
    colors: colors,
    labels: labels,
    dataLabels: {
      enabled: true,
      style: {
        fontSize: '12px',
        fontWeight: 'bold'
      }
    },
    legend: {
      show: chartType === 'pie',
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

  const chartOptions =
    chartType === 'pie'
      ? {
          ...baseOptions,
          chart: { ...baseOptions.chart, type: 'pie' as const },
          dataLabels: {
            ...baseOptions.dataLabels,
            formatter: (val: number, opts: unknown) => {
              const labelIndex = (opts as { seriesIndex?: number }).seriesIndex ?? 0
              const label = labels[labelIndex] || ''
              return `${label}: ${val.toFixed(1)}%`
            }
          }
        }
      : {
          ...baseOptions,
          chart: { ...baseOptions.chart, type: 'bar' as const },
          plotOptions: {
            bar: {
              horizontal: false,
              columnWidth: '55%',
              endingShape: 'rounded' as const
            }
          },
          xaxis: {
            categories: labels,
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
          }
        }

  return (
    <div className="w-full">
      <div className="text-center mb-4">
        <div className="text-2xl font-bold text-gray-900 dark:text-white">
          ${total.toFixed(0)}
        </div>
        <div className="text-sm text-gray-500 dark:text-gray-400">Total by Merchant</div>
      </div>
      <Chart
        options={chartOptions}
        series={chartType === 'pie' ? series : [{ name: 'Merchant', data: series }]}
        type={chartType}
        height={height}
      />
    </div>
  )
}

/**
 * MerchantAnalysisChart - Wrapped with QueryProvider and ErrorBoundary
 */
export default function MerchantAnalysisChart(props: MerchantAnalysisChartProps): React.JSX.Element {
  return (
    <ErrorBoundary>
      <QueryProvider>
        <MerchantAnalysisChartContent {...props} />
      </QueryProvider>
    </ErrorBoundary>
  )
}

