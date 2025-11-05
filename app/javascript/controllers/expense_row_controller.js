import { Controller } from "@hotwired/stimulus"

/**
 * Expense Row Controller
 * 
 * Manages expand/collapse behavior for expense rows showing contribution details.
 * Toggles visibility of contributions row and updates chevron icon state.
 * 
 * Cross-controller access: None (all elements are within controller scope)
 * 
 * @see .cursor/rules/conventions/code_style/stimulus_controller_style.mdc
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 */
export default class extends Controller {
  static targets = ["contributionsRow", "chevron"]

  toggle(event) {
    // Prevent event if clicking on action links/buttons
    if (event.target.closest('a, button, form')) {
      return
    }

    // Find the contributions row (next sibling <tr> element)
    const contributionsRow = this.element.nextElementSibling
    if (!contributionsRow || !contributionsRow.hasAttribute('data-expense-row-target')) {
      return
    }
    
    const isHidden = contributionsRow.classList.contains('hidden')
    // Use Stimulus target instead of querySelector
    // Per rules: Elements within controller scope should use targets
    const chevron = this.hasChevronTarget ? this.chevronTarget : null
    
    if (isHidden) {
      contributionsRow.classList.remove('hidden')
      // Update chevron icon to point down (rotate 90 degrees from right)
      if (chevron) {
        chevron.classList.add('rotate-90')
      }
    } else {
      contributionsRow.classList.add('hidden')
      // Update chevron icon to point right (remove rotation)
      if (chevron) {
        chevron.classList.remove('rotate-90')
      }
    }
  }
}

