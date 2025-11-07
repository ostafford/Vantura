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
    id: String
  }

  connect() {
    // Initialize evidence as collapsed
    if (this.hasEvidenceContentTarget) {
      this.hasEvidenceExpanded = false
    }
  }

  // Toggle evidence accordion
  toggleEvidence(event) {
    event.preventDefault()
    
    if (!this.hasEvidenceContentTarget || !this.hasEvidenceIconTarget) return
    
    if (this.hasEvidenceExpanded) {
      // Collapse
      this.evidenceContentTarget.classList.add("hidden")
      this.evidenceIconTarget.classList.remove("rotate-180")
      this.hasEvidenceExpanded = false
    } else {
      // Expand
      this.evidenceContentTarget.classList.remove("hidden")
      this.evidenceIconTarget.classList.add("rotate-180")
      this.hasEvidenceExpanded = true
    }
  }

  // Dismiss insight card
  dismiss(event) {
    event.preventDefault()
    
    // Animate out and remove
    this.element.style.transition = "opacity 0.3s ease-out, transform 0.3s ease-out"
    this.element.style.opacity = "0"
    this.element.style.transform = "translateY(-10px)"
    
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }
}

