import { Controller } from "@hotwired/stimulus"

/**
 * Income View Toggle Controller
 * 
 * Manages toggle between "Recurring" and "Historical" income view.
 * Persists preference in localStorage.
 * 
 * @see .cursor/rules/conventions/code_style/stimulus_controller_style.mdc
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 */
export default class extends Controller {
  static targets = ["recurringButton", "historicalButton", "valueDisplay", "labelDisplay"]
  static values = {
    hasRecurring: { type: Boolean, default: false },
    hasHistorical: { type: Boolean, default: false },
    recurringValue: { type: Number, default: 0 },
    historicalValue: { type: Number, default: 0 },
    currentMonthValue: { type: Number, default: 0 }
  }

  connect() {
    // Determine default: recurring if exists, else historical
    const defaultView = this.hasRecurringValue ? "recurring" : "historical"
    
    // Load saved preference or use default
    const savedView = localStorage.getItem("incomeViewPreference")
    this.currentView = savedView || defaultView
    
    // Apply initial state
    this.updateView()
  }

  switchToRecurring() {
    this.currentView = "recurring"
    this.updateView()
    this.savePreference()
  }

  switchToHistorical() {
    this.currentView = "historical"
    this.updateView()
    this.savePreference()
  }

  updateView() {
    // Determine which value to show
    let displayValue
    let displayLabel
    
    if (this.currentView === "recurring" && this.hasRecurringValue) {
      displayValue = this.recurringValueValue
      displayLabel = "from recurring income"
    } else if (this.currentView === "historical" && this.hasHistoricalValue) {
      displayValue = this.historicalValueValue
      displayLabel = "estimated from past 6 months"
    } else {
      // Fallback to current month if neither available
      displayValue = this.currentMonthValueValue
      displayLabel = "this month so far"
    }

    // Update value display
    if (this.hasValueDisplayTarget) {
      this.valueDisplayTarget.textContent = `$${displayValue.toFixed(2)}`
    }

    // Update label display
    if (this.hasLabelDisplayTarget) {
      this.labelDisplayTarget.textContent = displayLabel
      this.labelDisplayTarget.classList.remove("hidden")
    }

    // Update button states
    if (this.hasRecurringButtonTarget) {
      if (this.currentView === "recurring") {
        this.recurringButtonTarget.classList.add("bg-white/10", "text-white")
        this.recurringButtonTarget.classList.remove("text-white/60", "hover:text-white/80")
      } else {
        this.recurringButtonTarget.classList.remove("bg-white/10", "text-white")
        this.recurringButtonTarget.classList.add("text-white/60", "hover:text-white/80")
      }
    }

    if (this.hasHistoricalButtonTarget) {
      if (this.currentView === "historical") {
        this.historicalButtonTarget.classList.add("bg-white/10", "text-white")
        this.historicalButtonTarget.classList.remove("text-white/60", "hover:text-white/80")
      } else {
        this.historicalButtonTarget.classList.remove("bg-white/10", "text-white")
        this.historicalButtonTarget.classList.add("text-white/60", "hover:text-white/80")
      }
    }
  }

  savePreference() {
    localStorage.setItem("incomeViewPreference", this.currentView)
  }
}

