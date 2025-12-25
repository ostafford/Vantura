import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    type: String,
    data: Object,
    options: Object
  }

  connect() {
    // Chart.js UMD bundle exposes Chart on window
    const Chart = window.Chart
    
    if (!Chart) {
      console.error('Chart.js is not loaded. Make sure it is included in your importmap.')
      return
    }

    const chartOptions = this.optionsValue || {}
    
    // Enhance options with currency formatting
    if (chartOptions.scales && chartOptions.scales.y) {
      chartOptions.scales.y.ticks = chartOptions.scales.y.ticks || {}
      chartOptions.scales.y.ticks.callback = function(value) {
        return '$' + value.toFixed(2)
      }
    }
    
    if (chartOptions.plugins && chartOptions.plugins.tooltip) {
      chartOptions.plugins.tooltip.callbacks = chartOptions.plugins.tooltip.callbacks || {}
      chartOptions.plugins.tooltip.callbacks.label = function(context) {
        if (context.dataset.label) {
          return context.dataset.label + ': $' + context.parsed.y.toFixed(2)
        }
        return '$' + context.parsed.y.toFixed(2)
      }
    }
    
    // For doughnut charts, add percentage to tooltip
    if (this.typeValue === 'doughnut' && chartOptions.plugins && chartOptions.plugins.tooltip) {
      chartOptions.plugins.tooltip.callbacks.label = function(context) {
        const label = context.label || ''
        const value = context.parsed || 0
        const total = context.dataset.data.reduce((a, b) => a + b, 0)
        const percentage = total > 0 ? ((value / total) * 100).toFixed(1) : 0
        return label + ': $' + value.toFixed(2) + ' (' + percentage + '%)'
      }
    }
    
    this.chart = new Chart(this.element, {
      type: this.typeValue,
      data: this.dataValue,
      options: chartOptions
    })
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }

  update() {
    if (this.chart) {
      this.chart.data = this.dataValue
      this.chart.update()
    }
  }
}

