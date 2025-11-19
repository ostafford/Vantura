import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"

export default class extends Controller {
  static targets = ["canvas", "periodYear", "periodMonth", "entity", "ids", "yearBtn", "monthBtn"]
  static values = { endpoint: String, period: { type: String, default: "year" }, year: Number, month: Number }

  connect() {
    this.abortController = null
    
    // Read year/month from data attributes (set by server when element is rendered)
    this._readDataAttributes()
    this._syncYearMonth()
    this.render()
    
    // Listen for month navigation changes (from month-nav controller)
    this.boundHandleMonthChanged = this._handleMonthChanged.bind(this)
    window.addEventListener('month:changed', this.boundHandleMonthChanged)
    
    // Listen for Turbo navigation/updates to sync year/month when page navigates
    this.boundHandleTurboLoad = this._handleTurboLoad.bind(this)
    this.boundHandleStreamRender = this._handleStreamRender.bind(this)
    document.addEventListener('turbo:load', this.boundHandleTurboLoad)
    document.addEventListener('turbo:frame-load', this.boundHandleTurboLoad)
    // Listen for Turbo Stream updates (which is how month-nav updates the page)
    document.addEventListener('turbo:after-stream-render', this.boundHandleStreamRender)
  }

  disconnect() {
    if (this.chart) { this.chart.destroy(); this.chart = null }
    if (this.abortController && !this.abortController.signal.aborted) {
      this.abortController.abort()
    }
    this.abortController = null
    window.removeEventListener('month:changed', this.boundHandleMonthChanged)
    document.removeEventListener('turbo:load', this.boundHandleTurboLoad)
    document.removeEventListener('turbo:frame-load', this.boundHandleTurboLoad)
    document.removeEventListener('turbo:after-stream-render', this.boundHandleStreamRender)
  }

  showYear() { this.periodValue = "year"; this.render() }
  showMonth() { 
    // Ensure we're using the selected month from navigation
    this._syncYearMonth()
    this.periodValue = "month"; 
    this.render() 
  }

  _handleTurboLoad(event) {
    // After Turbo navigation/updates, sync year/month and re-render if values changed
    // Only process if this element is still connected (not replaced)
    if (!this.element.isConnected) return
    this._checkAndUpdate()
  }

  _handleMonthChanged(event) {
    // Direct event from month-nav controller when month changes
    const { year, month } = event.detail
    const yearChanged = this.hasYearValue ? this.yearValue !== year : true
    const monthChanged = this.hasMonthValue ? this.monthValue !== month : true
    
    if (yearChanged || monthChanged) {
      this.yearValue = year
      this.monthValue = month
      // Only auto-render if currently in month view
      if (this.periodValue === 'month') {
        this.render()
      }
    }
  }

  _handleStreamRender(event) {
    // After Turbo Stream renders (like month-nav updates), check if we need to update
    // Use a small delay to ensure DOM is fully updated
    setTimeout(() => {
      if (!this.element.isConnected) return
      this._checkAndUpdate()
    }, 10)
  }

  _checkAndUpdate() {
    const oldYear = this.hasYearValue ? this.yearValue : null
    const oldMonth = this.hasMonthValue ? this.monthValue : null
    
    // Sync from both URL params and data attributes (data attributes might be updated by Turbo Stream)
    this._syncYearMonth()
    
    // Re-render if year/month changed
    const yearChanged = oldYear !== (this.hasYearValue ? this.yearValue : null)
    const monthChanged = oldMonth !== (this.hasMonthValue ? this.monthValue : null)
    if (yearChanged || monthChanged) {
      this.render()
    }
  }

  _readDataAttributes() {
    // Read data attributes directly from element (updated when Turbo Stream replaces element)
    const dataYear = this.element.dataset.bentoBarChartYearValue
    const dataMonth = this.element.dataset.bentoBarChartMonthValue
    
    if (dataYear) {
      this.yearValue = parseInt(dataYear, 10)
    }
    if (dataMonth) {
      this.monthValue = parseInt(dataMonth, 10)
    }
  }

  _syncYearMonth() {
    // Priority: 1) URL params (from month navigation), 2) data attributes (from server render via Turbo Stream)
    const urlParams = new URLSearchParams(window.location.search)
    const urlYear = urlParams.get('year')
    const urlMonth = urlParams.get('month')
    
    // Also re-read data attributes (they get updated when Turbo Stream replaces the element)
    this._readDataAttributes()
    
    // Use URL params first (most up-to-date), then data attributes (already read above)
    if (urlYear) {
      this.yearValue = parseInt(urlYear, 10)
    }
    // If URL doesn't have it, use data attribute (already set by _readDataAttributes)
    
    if (urlMonth) {
      this.monthValue = parseInt(urlMonth, 10)
    }
    // If URL doesn't have it, use data attribute (already set by _readDataAttributes)
  }

  async render() {
    const url = new URL(this.endpointValue, window.location.origin)
    url.searchParams.set("period", this.periodValue)
    if (this.hasYearValue && this.yearValue) url.searchParams.set("year", this.yearValue)
    if (this.hasMonthValue && this.monthValue) url.searchParams.set("month", this.monthValue)

    const groupBy = this._readGroupBy()
    if (groupBy) url.searchParams.set("group_by", groupBy)
    const ids = this._readIds()
    ids.forEach(id => url.searchParams.append("ids[]", id))

    if (this.abortController) this.abortController.abort()
    this.abortController = new AbortController()

    try {
      const res = await fetch(url.toString(), { signal: this.abortController.signal })
      const json = await res.json()
      this._updateToggle()
      this._renderApex(json)
    } catch (error) {
      // Silently ignore AbortErrors - they occur when controller disconnects during Turbo Stream updates
      // This is expected behavior and doesn't need to be logged
      if (error.name !== 'AbortError') {
        console.error('Error rendering chart:', error)
      }
    }
  }

  _renderApex({ labels, datasets }) {
    if (this.chart) { this.chart.destroy(); this.chart = null }

    const series = datasets.map(ds => ({ name: ds.name, data: ds.data }))
    const colors = datasets.map(ds => ds.color)

    const options = {
      chart: {
        type: 'bar',
        height: 260,
        toolbar: { show: false }
      },
      series,
      colors,
      xaxis: { categories: labels, axisBorder: { show: false }, axisTicks: { show: false } },
      yaxis: { labels: { formatter: (v) => `$${(v/100).toFixed(0)}` } },
      tooltip: { y: { formatter: (v) => `$${(v/100).toFixed(2)}` } },
      dataLabels: { enabled: false },
      plotOptions: { bar: { borderRadius: 4, columnWidth: '55%' } },
      legend: { show: datasets.length > 1 }
    }

    this.chart = new ApexCharts(this.canvasTarget, options)
    this.chart.render()
  }

  _readGroupBy() {
    if (!this.hasEntityTarget) return "none"
    const el = this.entityTarget
    return el.value || "none"
  }

  _readIds() {
    if (!this.hasIdsTarget) return []
    // Expect comma-separated values in a hidden input/select-multiple
    const el = this.idsTarget
    if (el.tagName === 'SELECT') {
      return Array.from(el.selectedOptions).map(o => o.value)
    }
    return (el.value || '').split(',').map(s => s.trim()).filter(Boolean)
  }

  _updateToggle() {
    const activeClasses = [
      "bg-primary-700",
      "text-white",
      "shadow-sm"
    ]
    const inactiveClasses = [
      "text-neutral-700",
      "dark:text-neutral-300",
      "hover:bg-neutral-50",
      "dark:hover:bg-neutral-700",
      "bg-transparent"
    ]

    if (this.hasYearBtnTarget && this.hasMonthBtnTarget) {
      const makeActive = (el) => {
        el.classList.remove(...inactiveClasses)
        el.classList.add(...activeClasses)
      }
      const makeInactive = (el) => {
        el.classList.remove(...activeClasses)
        el.classList.add(...inactiveClasses)
      }

      if (this.periodValue === 'year') {
        makeActive(this.yearBtnTarget)
        makeInactive(this.monthBtnTarget)
      } else {
        makeActive(this.monthBtnTarget)
        makeInactive(this.yearBtnTarget)
      }
    }
  }
}


