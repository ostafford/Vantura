import { Controller } from "@hotwired/stimulus"

/**
 * Insight Restore Controller
 * 
 * Handles restoring dismissed insights via Turbo Streams
 * 
 * @see .cursor/rules/conventions/code_style/stimulus_controller_style.mdc
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 */
export default class extends Controller {
  restore(event) {
    event.preventDefault()
    
    const form = event.target.closest("form")
    if (!form) return
    
    const formData = new FormData(form)
    
    fetch(form.action, {
      method: "POST",
      body: formData,
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "",
        "Accept": "text/vnd.turbo-stream.html, text/html, application/json"
      },
      credentials: "same-origin"
    })
    .then(response => {
      if (response.ok) {
        // Reload page to show restored insights
        window.location.reload()
      } else {
        console.error("[InsightRestore] Failed to restore insight")
      }
    })
    .catch(error => {
      console.error("[InsightRestore] Error restoring insight:", error)
    })
  }
}
