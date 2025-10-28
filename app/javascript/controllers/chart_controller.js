import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"

export default class extends Controller {
  static values = {
    type: String,
    series: Array,
    labels: Array,
    colors: Array,
    height: Number
  }

  connect() {
    // For pie charts, we need to ensure the element is visible and has dimensions
    if (this.typeValue === 'pie' || this.typeValue === 'donut') {
      // Wait a bit to ensure the element is fully rendered
      setTimeout(() => {
        this.renderChart()
      }, 100)
    } else {
      // Use requestAnimationFrame for other charts
      requestAnimationFrame(() => {
        this.renderChart()
      })
    }
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }

  renderChart() {
    // Check if we have data to render
    if (!this.seriesValue || this.seriesValue.length === 0) {
      console.log('No series data available')
      this.element.innerHTML = '<div class="flex items-center justify-center h-full text-gray-500">No data available</div>'
      return
    }

    console.log('Chart data:', {
      series: this.seriesValue,
      labels: this.labelsValue,
      type: this.typeValue
    })

    // Limit data points for better performance (max 20 items)
    const maxDataPoints = 20
    let limitedSeries = this.seriesValue.slice(0, maxDataPoints)
    let limitedLabels = this.labelsValue.slice(0, maxDataPoints)

    let seriesData
    
    // Format series data based on chart type
    if (this.typeValue === 'pie' || this.typeValue === 'donut') {
      seriesData = limitedSeries
    } else if (this.typeValue === 'bar') {
      seriesData = [{
        name: 'Amount',
        data: limitedSeries
      }]
    } else if (this.typeValue === 'line') {
      seriesData = [{
        name: 'Amount',
        data: limitedSeries
      }]
    } else {
      seriesData = limitedSeries
    }

    const options = {
      chart: {
        type: this.typeValue,
        height: this.heightValue || 400,
        fontFamily: "Inter, sans-serif",
        toolbar: {
          show: false,
        },
        // Performance optimizations
        animations: {
          enabled: true, // Enable animations for pie charts
          easing: 'easeinout',
          speed: 300
        },
        redrawOnParentResize: true,
        redrawOnWindowResize: true
      },
      series: seriesData,
      labels: limitedLabels,
      colors: this.colorsValue || ['#3B82F6', '#EF4444', '#10B981', '#F59E0B', '#8B5CF6', '#06B6D4', '#84CC16', '#F97316', '#EC4899', '#6B7280'],
      dataLabels: {
        enabled: true,
        style: {
          fontSize: '12px',
          fontWeight: 'bold',
        },
        formatter: function (val, opts) {
          if (this.typeValue === 'pie') {
            return opts.w.config.labels[opts.seriesIndex] + ": " + val.toFixed(1) + "%"
          }
          return val.toFixed(0)
        }.bind(this)
      },
      legend: {
        show: false,
      },
      tooltip: {
        enabled: true,
        y: {
          formatter: function (val) {
            return "$" + val.toFixed(0)
          }
        }
      },
      // Performance optimization for large datasets
      noData: {
        text: 'No data available',
        align: 'center',
        verticalAlign: 'middle',
        style: {
          color: '#6B7280',
          fontSize: '14px'
        }
      }
    }

    // Add specific options based on chart type
    if (this.typeValue === 'pie' || this.typeValue === 'donut') {
      options.plotOptions = {
        pie: {
          donut: {
            size: this.typeValue === 'donut' ? '70%' : '0%'
          },
          expandOnClick: false
        }
      }
      
      // Set explicit dimensions for pie chart container
      const containerWidth = this.element.offsetWidth || 400
      const containerHeight = this.heightValue || 400
      
      options.chart.width = containerWidth
      options.chart.height = containerHeight
      
      // Ensure the element itself has dimensions
      if (!this.element.style.height) {
        this.element.style.minHeight = containerHeight + 'px'
      }
      
      // Force pie chart to render
      options.chart.animations = {
        enabled: true,
        easing: 'easeinout',
        speed: 400
      }
    }
    
    if (this.typeValue === 'bar') {
      options.plotOptions = {
        bar: {
          horizontal: true,
          borderRadius: 4,
          dataLabels: {
            position: 'center'
          }
        }
      }
      options.xaxis = {
        categories: limitedLabels,
        type: 'category' // Use category type for better performance
      }
    }
    
    if (this.typeValue === 'line') {
      options.stroke = {
        curve: 'smooth',
        width: 3
      }
      options.xaxis = {
        categories: limitedLabels,
        type: 'category' // Use category type for better performance
      }
      options.yaxis = {
        title: {
          text: 'Amount ($)'
        }
      }
      // Performance optimization for line charts
      options.markers = {
        size: 4,
        hover: {
          size: 6
        }
      }
    }

    // Create chart with error handling
    try {
      console.log(`Rendering ${this.typeValue} chart with:`, {
        series: seriesData,
        seriesType: typeof seriesData,
        seriesIsArray: Array.isArray(seriesData),
        labels: limitedLabels,
        colors: this.colorsValue,
        element: this.element,
        elementDimensions: {
          width: this.element.offsetWidth,
          height: this.element.offsetHeight,
          clientWidth: this.element.clientWidth,
          clientHeight: this.element.clientHeight
        },
        options: options
      })
      
      this.chart = new ApexCharts(this.element, options)
      this.chart.render().then(() => {
        console.log(`${this.typeValue} chart rendered successfully!`)
      }).catch((error) => {
        console.error("Chart rendering failed:", error)
        this.element.innerHTML = '<div class="flex items-center justify-center h-full text-red-500">Chart rendering failed</div>'
      })
    } catch (error) {
      console.error("Chart creation failed:", error)
      this.element.innerHTML = '<div class="flex items-center justify-center h-full text-red-500">Chart creation failed</div>'
    }
  }
}

