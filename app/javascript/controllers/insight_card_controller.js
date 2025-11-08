import { Controller } from "@hotwired/stimulus"

/**
 * Insight Card Controller
 * 
 * Manages insight card behavior including:
 * - Accordion expansion/collapse for evidence
 * - Dismissal of insights
 * 
 * @see .cursor/rules/conventions/code_style/stimulus_controller_style.mdc
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 */
export default class extends Controller {
  static targets = ["evidenceContainer", "evidenceToggle", "evidenceContent", "evidenceIcon"]
  static values = {
    id: String,
    type: String
  }

  connect() {
    // Initialize evidence as collapsed
    this.evidenceExpanded = false
  }

  // Toggle evidence accordion
  toggleEvidence(event) {
    event?.preventDefault()
    
    if (!this.hasEvidenceContentTarget || !this.hasEvidenceIconTarget) return
    
    if (this.evidenceExpanded) {
      // Collapse
      this.evidenceContentTarget.classList.add("hidden")
      this.evidenceIconTarget.classList.remove("rotate-180")
      this.evidenceExpanded = false
    } else {
      // Expand
      this.evidenceContentTarget.classList.remove("hidden")
      this.evidenceIconTarget.classList.add("rotate-180")
      this.evidenceExpanded = true
    }
  }

  // Dismiss insight card
  dismiss(event) {
    event?.preventDefault()
    
    if (!this.typeValue) {
      console.error("[InsightCard] Cannot dismiss: insight type is missing")
      return
    }

    // Animate out first
    this.element.style.transition = "opacity 0.3s ease-out, transform 0.3s ease-out"
    this.element.style.opacity = "0"
    this.element.style.transform = "translateY(-10px)"
    
    // Call API to persist dismissal
    const formData = new FormData()
    formData.append("insight_type", this.typeValue)
    
    fetch("/insights/dismiss", {
      method: "POST",
      body: formData,
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "",
        "Accept": "application/json"
      },
      credentials: "same-origin"
    })
    .then(response => {
      if (!response.ok) {
        throw new Error("Failed to dismiss insight")
      }
      return response.json()
    })
    .then(data => {
      // Remove element after successful API call
      setTimeout(() => {
        this.element.remove()
      }, 300)
    })
    .catch(error => {
      console.error("[InsightCard] Error dismissing insight:", error)
      // Revert animation on error
      this.element.style.opacity = "1"
      this.element.style.transform = "translateY(0)"
    })
  }
}

