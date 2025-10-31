import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"

export default class extends Controller {
  static targets = ["canvas", "periodYear", "periodMonth", "entity", "ids", "yearBtn", "monthBtn"]
  static values = { endpoint: String, period: { type: String, default: "month" }, year: Number, month: Number }

  connect() {
    this.abortController = null
    // Sync year/month from URL params if present (Turbo navigation)
    const urlParams = new URLSearchParams(window.location.search)
    const urlYear = urlParams.get('year')
    const urlMonth = urlParams.get('month')
    if (urlYear) this.yearValue = parseInt(urlYear, 10)
    if (urlMonth) this.monthValue = parseInt(urlMonth, 10)
    this.render()
  }

  disconnect() {
    if (this.chart) { this.chart.destroy(); this.chart = null }
    if (this.abortController) { this.abortController.abort(); this.abortController = null }
  }

  showYear() { this.periodValue = "year"; this.render() }
  showMonth() { this.periodValue = "month"; this.render() }

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

    const res = await fetch(url.toString(), { signal: this.abortController.signal })
    const json = await res.json()
    this._updateToggle()
    this._renderApex(json)
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
      "text-gray-700",
      "dark:text-gray-300",
      "hover:bg-gray-50",
      "dark:hover:bg-gray-700",
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


