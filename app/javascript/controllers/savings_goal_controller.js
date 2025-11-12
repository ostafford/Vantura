import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modeOption",
    "rateGroup",
    "amountGroup",
    "rateInput",
    "amountInput",
    "rateValue"
  ]

  connect() {
    this.updateVisibility()
    this.updateRateValue()
  }

  handleModeChange() {
    this.updateVisibility()
  }

  updateRateValue() {
    if (!this.hasRateInputTarget || !this.hasRateValueTarget) return

    const value = parseFloat(this.rateInputTarget.value || 0)
    this.rateValueTarget.textContent = `${isNaN(value) ? "0" : value.toFixed(1)}%`
  }

  updateVisibility() {
    const selectedMode = this.selectedMode()

    this.toggleGroup(this.rateGroupTargets, selectedMode === "rate")
    this.toggleGroup(this.amountGroupTargets, selectedMode === "amount")

    if (this.hasRateInputTarget) {
      this.rateInputTarget.disabled = selectedMode !== "rate"
    }

    if (this.hasAmountInputTarget) {
      this.amountInputTarget.disabled = selectedMode !== "amount"
    }
  }

  selectedMode() {
    const checked = this.modeOptionTargets.find((input) => input.checked)
    return checked ? checked.value : "break_even"
  }

  toggleGroup(targets, shouldShow) {
    targets.forEach((element) => {
      element.classList.toggle("hidden", !shouldShow)
      element.setAttribute("aria-hidden", (!shouldShow).toString())
    })
  }
}

