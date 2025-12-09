import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["filterBar", "filterToggleText", "advancedFilters", "advancedToggleText", "analyticsSection", "analyticsToggleText"]
  static classes = ["hidden"]

  connect() {
    // Filter bar hidden by default
    if (this.hasFilterBarTarget) {
      this.filterBarTarget.classList.add(this.hiddenClass)
    }
  }

  toggleFilters() {
    if (this.hasFilterBarTarget) {
      this.filterBarTarget.classList.toggle(this.hiddenClass)
      const isHidden = this.filterBarTarget.classList.contains(this.hiddenClass)
      if (this.hasFilterToggleTextTarget) {
        this.filterToggleTextTarget.textContent = isHidden ? "Show Filters" : "Hide Filters"
      }
    }
  }

  toggleAdvanced(event) {
    event.preventDefault()
    if (this.hasAdvancedFiltersTarget) {
      this.advancedFiltersTarget.classList.toggle(this.hiddenClass)
      const isHidden = this.advancedFiltersTarget.classList.contains(this.hiddenClass)
      if (this.hasAdvancedToggleTextTarget) {
        this.advancedToggleTextTarget.textContent = isHidden ? "▼ Advanced Filters" : "▲ Hide Advanced Filters"
      }
    }
  }

  toggleAnalytics(event) {
    event.preventDefault()
    if (this.hasAnalyticsSectionTarget) {
      this.analyticsSectionTarget.classList.toggle(this.hiddenClass)
      const isHidden = this.analyticsSectionTarget.classList.contains(this.hiddenClass)
      if (this.hasAnalyticsToggleTextTarget) {
        this.analyticsToggleTextTarget.textContent = isHidden ? "▶ Show Analytics" : "▼ Hide Analytics"
      }
    }
  }

  removeFilter(event) {
    event.preventDefault()
    const button = event.target.closest("button")
    if (!button) return
    
    const filterName = button.dataset.filterName
    const form = this.element.querySelector("form")
    
    if (form) {
      const input = form.querySelector(`[name="${filterName}"]`)
      if (input) {
        input.value = ""
        // Submit form to update filters
        form.requestSubmit()
      }
    }
  }

  savePreset(event) {
    event.preventDefault()
    
    // Placeholder for filter preset functionality
    // This will be implemented in a future update
    // Planned implementation: Save to localStorage and allow quick access to saved filter combinations
    
    const form = this.element.querySelector("form")
    if (!form) return
    
    const presetName = prompt("Name this filter preset (coming soon):")
    if (!presetName) return
    
    // TODO: Implement localStorage-based filter preset saving
    // For now, just show a message
    alert(`Filter preset "${presetName}" will be saved in a future update. This feature will allow you to quickly apply common filter combinations.`)
    
    // Future implementation:
    // const formData = new FormData(form)
    // const filters = Object.fromEntries(formData)
    // localStorage.setItem(`transaction_filter_preset_${presetName}`, JSON.stringify(filters))
  }

  get hiddenClass() {
    return this.hiddenClasses?.[0] || "hidden"
  }
}

