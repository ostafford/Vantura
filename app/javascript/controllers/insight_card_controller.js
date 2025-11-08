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
    event.preventDefault()
    
    // Verify targets exist before accessing them
    if (!this.hasEvidenceContentTarget || !this.hasEvidenceIconTarget) {
      return
    }
    
    // Check current state by looking at the content visibility
    const isCurrentlyExpanded = !this.evidenceContentTarget.classList.contains("hidden")
    
    if (isCurrentlyExpanded) {
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
    event.preventDefault()
    
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
        "Accept": "text/vnd.turbo-stream.html, text/html, application/json"
      },
      credentials: "same-origin"
    })
    .then(response => {
      if (!response.ok) {
        throw new Error("Failed to dismiss insight")
      }
      // Check if response is Turbo Stream
      const contentType = response.headers.get("content-type")
      if (contentType && contentType.includes("text/vnd.turbo-stream.html")) {
        return response.text().then(html => {
          // Process Turbo Stream
          Turbo.renderStreamMessage(html)
          // Remove element after animation
          setTimeout(() => {
            this.element.remove()
            // Check if section should be hidden after card removal
            this.hideSectionIfEmpty()
          }, 300)
        })
      } else {
        // Fallback to JSON for backwards compatibility
        return response.json().then(data => {
          setTimeout(() => {
            this.element.remove()
            // Check if section should be hidden after card removal
            this.hideSectionIfEmpty()
          }, 300)
        })
      }
    })
    .catch(error => {
      console.error("[InsightCard] Error dismissing insight:", error)
      // Revert animation on error
      this.element.style.opacity = "1"
      this.element.style.transform = "translateY(0)"
    })
  }

  hideSectionIfEmpty() {
    // Check if the insights section should be hidden when all cards are removed
    const insightsSection = document.getElementById('dashboard-financial-insights-section')
    if (insightsSection) {
      const gridContainer = insightsSection.querySelector('.grid')
      if (gridContainer && gridContainer.children.length === 0) {
        // All cards removed - hide the entire section with animation
        insightsSection.style.transition = 'opacity 0.3s ease-out, margin-bottom 0.3s ease-out'
        insightsSection.style.opacity = '0'
        insightsSection.style.marginBottom = '0'
        setTimeout(() => {
          insightsSection.style.display = 'none'
        }, 300)
      }
    }
  }
}

