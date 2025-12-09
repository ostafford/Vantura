import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="countdown"
export default class extends Controller {
  static targets = ["number"]
  static values = {
    seconds: { type: Number, default: 3 },
    url: String
  }

  connect() {
    this.timeLeft = this.secondsValue
    this.startCountdown()
  }

  disconnect() {
    if (this.interval) {
      clearInterval(this.interval)
    }
  }

  startCountdown() {
    this.interval = setInterval(() => {
      this.timeLeft--
      
      if (this.hasNumberTarget) {
        this.numberTarget.textContent = this.timeLeft
      }
      
      if (this.timeLeft <= 0) {
        clearInterval(this.interval)
        Turbo.visit(this.urlValue)
      }
    }, 1000)
  }
}